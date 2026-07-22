# M0.3 Phase 15.5 — Render Projection Hygiene: Technical Deep-Dive

> Retroactive technical devlog. **Inserted tech-debt phase** —
> not in the original M0.3 roadmap. Filed 2026-05-23, executed
> 2026-06-04. Code shown **as built on 2026-06-04**; a drift section at the
> end tracks what changed since and why.

## Starting point

Phase 15's visual check (2026-05-23) put the orbit demo on screen for
the first time and the rendered orbit was wrong two ways: the trajectory sat
offset toward the bottom-right of the frame, and on the 2552×1556 test window
(aspect 1.64) the physically near-circular Moon orbit read as visibly
eccentric. Both traced to M0.1-era shader code that had never been exercised
at orbit scale: `line.vert` multiplied raw vertex positions by `ndc_scale`
with no centering term (unlike `disk.vert`, which used
`pc.camera_relative_center`), and no orbit-demo shader compensated for
viewport aspect — identical NDC scale on x and y stretches geometry
horizontally on any non-square window.

The 2026-05-23 tech-debt decision inserted Phase 15.5 between 15 and 16 —
the third debt item to get its own dedicated phase before the milestone
closed, after Phase 10.5 and Phase 14.5 (filed the same evening). The
trail/HUD/energy-readout bugs from the same check stayed inside Phase
15's fix-loop: new-code bugs in Phase 15 deliverables, not M0.1 debt.

An open question remained: the missing-camera-center hypothesis for the
bottom-right offset did not reconcile, because trail and conic vertices
are already Earth-origin-relative and the origin maps to NDC (0,0) —
screen center. Pinning the real root cause came before any fix. The
2026-06-04 research pass did: the offset and the apparent eccentricity
were **aspect stretch plus dropped-z foreshortening of the inclined Moon
orbit** — there was no missing camera term at all.

## What was built

### The CPU contract

`engine/include/interstellar/render/projection.hpp` — a header-only function
that is the single source of truth for the world→NDC map (the engine has no
view/projection matrix yet):

```cpp
// world_xy is already camera-relative (center pre-subtracted). aspect = width/height.
[[nodiscard]] inline glm::vec2 project_to_ndc(glm::vec2 world_xy, float ndc_scale, float aspect) {
    return glm::vec2{world_xy.x * ndc_scale / aspect, world_xy.y * ndc_scale};
}

// GLSL PARITY (line.vert / disk.vert must compute byte-equivalent):
//   gl_Position = vec4(world_xy.x * pc.ndc_scale / pc.aspect,
//                      world_xy.y * pc.ndc_scale, 0.0, 1.0);
```

GLSL cannot `#include` a C++ header, so parity is enforced the same way the
repo pins its push-constant struct mirrors: a comment stating the exact
duplicated expression, plus a test on the CPU side.
`tests/unit/render/test_projection.cpp` locks three cases: world origin →
NDC (0,0) exactly; aspect divides x and preserves y (one world unit on each
axis lands at `1/aspect` and `1.0` — a circle stays a circle); aspect = 1 is
a no-op. The test deliberately asserts nothing about inclined-orbit
foreshortening — that's correct by design.

### A rename, never an insert

The 48-byte `ShapePushConstants` block was hand-mirrored in four TUs
(`vulkan_context.cpp`, `disk_renderer.cpp`, `orbit_demo.cpp`,
`text_overlay.cpp`), each guarded by `static_assert(sizeof == 48)`. The
std430 layout had spare pad floats after `ndc_scale`, so `aspect` landed by
renaming `_pad0` at offset 36 — no field insert, no reorder, all four
static_asserts still hold, and the shared `orbit_pipeline_layout_` needs no
range change (48 bytes sits well inside the guaranteed 128).

Shader side:

- `disk.vert` gained `float aspect;` after `ndc_scale` and the divide:
  `gl_Position = vec4(world_xy.x * pc.ndc_scale / pc.aspect, world_xy.y *
  pc.ndc_scale, 0.0, 1.0);`. Its existing center+radius math was untouched.
- `line.vert`'s push block was non-canonical
  (`center_unused/radius_unused/base_color/ndc_scale`) and was rewritten to
  the shared shape. `main()` became `vec2 world_xy =
  pc.camera_relative_center.xy + pos.xy;` followed by the same
  aspect-divide-x map — the centering term is (0,0,0) for the Earth-origin
  demo, so a visual no-op today, kept as plumbing for a future camera.
- `hud.vert` renamed its trailing field to `aspect_unused` for
  pipeline-layout parity and still writes `ndc_pos` straight through — the
  HUD is pixel-anchored top-left; applying aspect would shift it off-screen.

Wiring in `OrbitDemo::render()`: the viewport fetch was hoisted above the
line draws, `aspect = width/height` computed once per frame, written into
the push constants at both the conic and trail draws and passed to both
`DiskRenderer::draw` calls (which gained a trailing `float aspect` param).
`world_to_ndc_scale_` stayed isotropic (`1.0/half_extent_m`) — aspect is
applied exactly once, in the shader.

### Verification

118/118 ctest green in both Release and Debug; M0.2 and M0.3 math-locks
unchanged. One tooling note: `ctest -R projection` matches nothing,
because Catch2 registers tests by TEST_CASE display name, not source file.
The visual check re-run (2026-06-04, user-verified) passed on the honest
criterion: Earth disk at screen center, no stretch under mid-run window
resize, predicted conic closed and tracking the trail. The orbit still
renders as a thin ellipse — the inclined Moon orbit projected top-down with
z dropped is foreshortened by design; a literal on-screen circle needs a
view matrix, ruled out of scope for this phase.

## Why it was built this way

- **Divide x, preserve y:** keeps the y-axis scale fixed so vertical
  framing and zoom feel unchanged; the alternative (multiply y) rescales the
  whole scene on every resize.
- **`float aspect`, not `vec2(width, height)`:** nothing in scope
  needed full extent; the spare pad slot fit a float without touching the
  48-byte layout. Promotion to `vec2` stays available if HUD pixel-snap ever
  wants it.
- **The centering term kept as plumbing despite being a no-op:** one
  centering mechanism across all orbit pipelines (`camera_relative_center`
  push constant, matching `disk.vert`) rather than a CPU pre-subtract
  special case for lines — and the fix's provenance stays honest: the
  visual defect is attributed to the aspect-divide change, not to the
  centering term.
- **No true-scale bodies:** disks stay visibility-sized (fixed screen
  px). Real physical radii are sub-pixel at orbit zoom. Phase 15.5 makes
  the *trajectory* geometrically honest, not the body sizes.
- **Header-only CPU source of truth:** the same one-source-plus-pinned-
  duplicate discipline the 48-byte mirrors already used, extended to math
  that lives in two languages.

## Where it is now (drift since 2026-06-04)

- **The shaders have not moved.** `line.vert`, `disk.vert`, and `hud.vert`
  are unmodified since this phase landed; `test_projection.cpp` likewise.
- **The same day's review pass hardened the edges** (2026-06-04):
  `project_to_ndc` gained a Debug assert (finite, positive
  aspect — a minimized viewport with height 0 would divide by zero) and
  `OrbitDemo::render()` now skips the frame entirely on a zero-extent
  swapchain; a follow-up fix collapsed the four hand-mirrored structs into
  one shared `render/shape_push_constants.hpp` — the size assert caught
  drift but not field reordering, and the single definition removes the
  hazard the rename-only discipline was working around.
- **The aspect path scaled to multi-body unchanged.** Phase 21 renders
  every active body; all disks share the one per-frame aspect via the same
  `DiskRenderer::draw` param.
- **The camera arrived, and took the road the centering term didn't
  build.** Phase 41's focus/zoom camera (2026-07-09) recenters by
  subtracting the focused body's position from trail data CPU-side before
  upload; the line-draw push writes still leave `camera_relative_center` at
  (0,0,0) (`orbit_demo.cpp:196-241`). The in-shader centering term remains
  correct, tested — and unused by a moving camera as of 2026-07-21.
- **Current locations:** `project_to_ndc` at
  `engine/include/interstellar/render/projection.hpp:31-34`; aspect fetch +
  zero-extent skip at `engine/src/orbit_demo.cpp:401-412`; the shared
  layout comment (offset 36 = aspect) in
  `engine/include/interstellar/render/shape_push_constants.hpp`.

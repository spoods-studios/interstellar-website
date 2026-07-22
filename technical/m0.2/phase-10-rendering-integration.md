# M0.2 Phase 10 — Rendering Integration: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-04-22**; a
> drift section at the end tracks what changed since and why.

## Starting point

Phases 7–9 built the coordinate stack — types, conversions,
`CoordinateService` — all unit-tested, none of it reaching the GPU. The
renderer still drew M0.1's RGB triangle at hardcoded NDC positions in
`triangle.vert`; `VulkanContext` took no coordinate input at all. Phase 10
connects the two: the triangle gets a world position in int64 mm, the
camera gets one, and the shader receives their camera-relative difference
each frame.

## What was built

### Ownership — main.cpp owns the world, the renderer borrows

```cpp
struct Camera {
    coords::Vec3i64 position{};
};
```

`camera.hpp` is 15 lines: one field, no orientation, no fov, no
matrices — deferred until code demands them (M0.4+). `main.cpp`
owns the `CoordinateService`, the `Camera`, and the triangle's world
position `Vec3i64 triangle_world_pos{500, 0, 0}` (0.5 m on +X);
`VulkanContext` takes `coords::CoordinateService&` in its constructor
and stores a non-owning reference. Declaration order in
`main.cpp` carries the lifetime contract: service before context, so C++
reverse-destruction order destroys the context first.
`VulkanContext` owning the service was rejected: the M0.3 physics thread
needs the same instance.

### The push-constant range

```cpp
struct PushConstants {
    float offset_x;
    float offset_y;
    float offset_z;
    float _pad;  // std430 vec3 alignment
};
static_assert(sizeof(PushConstants) == 16, "PushConstants must be 16 bytes for std430 vec3 alignment");
```

Push constants are the transform mechanism: a
small payload recorded directly into the command buffer via
`vkCmdPushConstants`, no uniform buffer, no descriptor sets. The Vulkan
spec guarantees a 128-byte minimum push-constant budget; the payload is a
single vec3 padded to 16 bytes because GLSL std430 aligns vec3 to 16, and
the `static_assert` pins the C++ struct to the shader-side layout.
`create_pipeline_layout` declares one `vk::PushConstantRange` with
`vk::ShaderStageFlagBits::eVertex` and `sizeof(PushConstants)` — vertex
stage only. A push-constant block in `triangle.frag`, or stage flags wider
than the shaders that declare the block, fires
`VUID-vkCmdPushConstants-stageFlags-01795`; the fragment shader was left
untouched for that reason. The write lands in `record_command_buffer`,
between `bindPipeline` and `draw`:

```cpp
PushConstants pc{offset.x, offset.y, offset.z, 0.0f};
cmd.pushConstants<PushConstants>(*pipeline_layout_, vk::ShaderStageFlagBits::eVertex, 0, pc);
```

The value is captured at record time, per command buffer: with
`MAX_FRAMES_IN_FLIGHT = 2`, each in-flight frame re-records its own buffer
with its own offset, so there is no shared mutable transform state for two
frames to race on.

### The shader

```glsl
layout(push_constant) uniform PushConstants {
    vec3 offset;
} pc;

const float SCALE = 0.5;

void main() {
    vec2 pos = positions[gl_VertexIndex] + pc.offset.xy * SCALE;
    gl_Position = vec4(pos, 0.0, 1.0);
    fragColor = colors[gl_VertexIndex];
}
```

The positions and colors arrays are unchanged from M0.1; the
one behavioral change is the `+ pc.offset.xy * SCALE` term. `SCALE = 0.5`
maps 1 m to 0.5 NDC units, so the 0.5 m triangle offset renders 0.25 NDC
units right of center — visibly off-center without leaving the screen.
There is no projection matrix; meters-to-NDC by constant is the whole
camera model this milestone.

### render_frame — int64 in, float32 out

`render_frame(coords::Vec3i64 camera_pos, coords::Vec3i64 object_pos)` is
the renderer's new public API: two int64 world positions per call,
converted inside via
`coord_service_.to_camera_relative(object_pos, camera_pos)`. The int64
subtraction happens in the Phase 8-locked path before any float cast, so
callers cannot reintroduce catastrophic cancellation by precomputing in
float. Argument order is load-bearing: object first, camera second;
swapping sign-flips the offset. The mutation contract:
`shift_origin` is called only from `main.cpp` between frames;
`vulkan_context.cpp` contains no call to it.

### The F-key smoke, and what it proves

```cpp
if (event.key.keysym.scancode == SDL_SCANCODE_F && !event.key.repeat) {
    interstellar::coords::Vec3i64 new_origin =
        service.get_origin() + interstellar::coords::Vec3i64{1'000'000, 0, 0};
    service.shift_origin(new_origin);
    std::cout << std::format(
        "Origin shifted to ({}, {}, {}) mm\n",
        new_origin.x, new_origin.y, new_origin.z);
}
```

Each F press moves the origin +1,000,000 mm (1 km) on X. The
`!event.key.repeat` guard matters: SDL synthesizes auto-repeat KEYDOWN
events while a key is held, and an unguarded handler fires a 1 km shift
per repeat event; the guard pins one shift per physical press. 16 presses
across two runs produced exactly 16 log lines, origin incrementing by 1 km
each, triangle stationary throughout.

A 2026-04-24 review finding narrowed what that stationary triangle is
evidence of. `to_camera_relative(object_pos, camera_pos)` computes a
camera-relative delta — it never reads the origin — so the triangle stays
put because the render math is origin-independent by construction. The
test proves the `shift_origin` call path is wired and the repeat guard
works, nothing more. Real origin invariance needs a camera that moves and
an origin that re-anchors to follow it, deferred to the milestone that
introduces moving cameras.

The `std::cout` in that handler is also why the log line later moved to
stderr. C++ iostreams block-buffer stdout when it is a pipe instead of a
terminal, so `Origin shifted` lines sit in the buffer until process exit —
invisible to anything reading the pipe live.

Debug runs of this phase surfaced `VUID-vkQueueSubmit-pSignalSemaphores-00067`,
a latent M0.1 semaphore-indexing bug, fixed in Phase 10.5 before the
milestone closed.

## Why it was built this way

- **Push constant over UBO:** one object, one camera. Uniform
  buffers need a descriptor pool, descriptor sets, and per-frame buffer
  management — roughly 100 lines of infrastructure that buys nothing at
  this object count. The hybrid UBO+push-constant split was deferred to
  the milestone with many objects.
- **Borrow, don't own:** `render_frame` takes positions as
  parameters instead of `VulkanContext` storing camera or object state —
  cheaper to reverse than owning-then-separating once a scene list exists.
- **No new tests:** the coordinate math was already pinned by the
  Phase 7–9 unit suites (49 tests, all still green). Phase 10's proof
  obligations were compile-clean, validation-layer-clean, and two visual
  checks; the automated origin-shift-under-frames-in-flight test was
  Phase 11's deliverable.

## Where it is now (drift since 2026-04-22)

`camera.hpp` and `triangle.vert` have not changed since. The C++ around
them absorbed the M0.2 review fixes and two milestones of renderer
growth:

- **2026-04-24:** the conversion feeding the
  push constant hardened — `std::abs(INT64_MIN)` UB replaced with a signed
  two-sided range check, the inexact `×0.001f` scale replaced by an exact
  `÷1000.0f`, and a finite-check assert added so NaN/Inf cannot reach the
  push constant silently.
- **A later fix (2026-04-25):** `record_command_buffer` had
  called `swapchain_.getImages()` every frame — two driver round-trips
  plus a `std::vector` heap allocation, ~424 ns/frame. Image handles are
  now cached at swapchain creation, invalidated on recreate.
- **2026-04-25:** `CoordinateService::to_camera_relative`
  — the method `render_frame` called — was deleted; it never read the
  service's origin state (the same fact established above). `render_frame`
  now calls the free function `coords::to_camera_relative`.
- **2026-04-25:** the F-key handler now calls
  `set_origin` — "shift" reads as apply-a-delta, but the argument is an
  absolute origin.
- **Phase 10.5:** `render_finished_semaphores_` became per-image
  (indexed by `image_index`, not `current_frame_`), closing VUID-00067.
- **Phase 14.5 (2026-05-23):** the acquire in `render_frame` is
  wrapped in try/catch — vk-hpp's throwing `acquireNextImage` raises
  `vk::OutOfDateKHRError` (`eErrorOutOfDateKHR` is not in its success-code
  list), so the Phase 10-era post-return result check was dead code and
  every compositor surface invalidation was a fatal crash.
- **M0.4 renderer fixes (2026-06-04):** `load_shader_code` (which
  loads `triangle.vert.spv`) now rejects mis-sized SPIR-V; the
  orbit demo's `ShapePushConstants` lives in a shared header, aliased in
  `vulkan_context.cpp` beside Phase 10's `PushConstants`; the
  origin-shift log moved to stderr as `[origin-shift] new origin (...) mm`
  to share a capture stream with the physics worker.
- **Live path today:** `main.cpp`'s loop drives `render_orbit_frame` (the
  M0.4+ orbit demo with its own shape pipelines); `render_frame` and the
  triangle push-constant path remain compiled but are no longer the loop's
  call. The F-key handler is still live — an M0.7-era comment keeps it as
  the M0.2 carry-over smoke, validating that origin shifts stay
  transparent with the physics worker thread and orbit render path active.

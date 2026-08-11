# M1.2 Phase 60 — Map View Integration: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-08-03**. M1.2 is
> not yet closed, and a later hardening pass this milestone touched several of
> the functions below — the drift section at the end covers what changed and
> why, not a milestone-end reconciliation.

## Starting point

Phase 58 landed the maneuver-node data model, a screen-space picking kernel,
and the velocity-aligned handle frame, all exercised as pure functions with no
mouse in sight. Phase 59 landed a predictor that draws two segments of a
trajectory in dim white and bright amber, again with no way for a player to
touch either one. Both phases deliberately stopped short of SDL. Phase 60 is
the wiring phase — screen pixels into world coordinates, clicks into node
placement, drags into a delta-v edit, and a palette that makes the predicted
line read as distinct from everything else already on screen. Four plans, all
landing 2026-08-03.

## One hit-testing space, and why NDC isn't it

The obvious shortcut is to compare distances directly in normalized device
coordinates, since `project_to_ndc` already divides x by the viewport aspect
to keep world circles circular on screen. That shortcut is wrong. NDC spans
[−1, 1] across the window's *width* on x and its *height* on y, so one NDC
unit is `width/2` pixels horizontally and `height/2` pixels vertically — a
radius compared in NDC is an ellipse on any non-square window. A 12-pixel hit
radius would render roughly 12 pixels tall and 21 pixels wide at a 16:9
aspect ratio. The aspect division inside `project_to_ndc` doesn't rescue
this: that division makes a world-space circle *render* circular, which is a
statement about world-to-screen, not about NDC-to-pixel.

So a fourth conversion joins the world-to-NDC pair in `render/projection.hpp`:

```cpp
// ndc_xy is camera-relative NDC; the result is camera-relative world metres.
[[nodiscard]] inline glm::vec2 unproject_from_ndc(glm::vec2 ndc_xy, float ndc_scale, float aspect) {
    return glm::vec2{ndc_xy.x * aspect / ndc_scale, ndc_xy.y / ndc_scale};
}

// NDC → window pixels: the space ALL hit-testing happens in.
[[nodiscard]] inline glm::vec2 ndc_to_screen_px(glm::vec2 ndc, glm::vec2 viewport_extent) {
    return glm::vec2{(ndc.x + 1.0f) * 0.5f * viewport_extent.x,
                     (ndc.y + 1.0f) * 0.5f * viewport_extent.y};
}
```

`unproject_from_ndc` sits directly beneath `project_to_ndc`, off the same two
parameters, as its exact algebraic inverse — checked by a round-trip test at
zoom levels from LEO-scale to interplanetary. It carries a banner restricting
its own use: unprojection is for *deltas and pan only*. Hit-testing runs the
other way — candidates get projected forward into pixel space and compared
there, the precedent Phase 58's segment-picking kernel already set.
Unprojecting the mouse and comparing world distances would make every hit
radius zoom-dependent, silently.

`screen_px_to_ndc` (the pixels-to-NDC half) carries no y-flip, and that's a
fact about the pipeline rather than a convention: SDL reports mouse y
increasing downward from the window's top-left, and Vulkan NDC y increases
downward too, since the swapchain viewport is declared with a plain
non-negative height. Both axes already agree, so a flip here would invert
every drag — a plausible-looking wrong fix the header states explicitly, with
a test pinning the no-flip corner and center mapping.

The unprojection path also documents its own pixel-quantization budget: one
screen pixel spans `ndc_per_screen_px / eff_ndc_scale` world metres, and at
the widest zoom-out on a 1080-pixel-tall window that's about 8.6×10¹⁰
metres — roughly 0.58 AU per pixel. The figure scales with the window's
*minor* axis, so it's quoted with a window dimension attached rather than as
a bare constant.

## The mouse lands beside the wheel

`main.cpp` already had an `SDL_MOUSEWHEEL` case for zoom — render-only,
logging unthrottled. The three new mouse cases sit right beside it,
structurally identical:

```cpp
case SDL_MOUSEBUTTONDOWN: {
    if (event.button.button != SDL_BUTTON_LEFT) break;
    const std::optional<glm::vec2> ndc = mouse_ndc(event.button.x, event.button.y);
    if (!ndc) break;
    const auto press = map_input.on_button_down(*ndc, orbit_demo.map_hit_test(*ndc));
    if (press.action == interstellar::render::MapPress::Action::place_node) {
        orbit_demo.map_place_node(press.pick);
    }
    break;
}
```

Nothing mouse-driven reaches the physics worker's input ring — every case is
render-only, the same boundary the wheel handler already enforced, so no
mouse action can perturb a flown trajectory. The handlers stay thin: `main.cpp`
asks the composer what's under the cursor, hands that and the raw position to
the input controller, and switches on the verdict. Every decision lives in
the controller's transition table; every geometric conversion lives in the
pure kernels. Candidate building — projecting the six handle positions and
the sampled orbit curve into pixel space — lives inside the composer rather
than the event pump itself: the predictor and the planner are private members
of the composer, and the camera center is a per-frame local of its render
call, so building candidates in `main.cpp` would mean publishing all three
just to let the event pump see them.

## The state machine

`MapInputController` owns exactly three things: the current state, the
previous cursor position, and which handle (if any) is active — nothing about
the camera, the planner, or a candidate set, which is what makes every
transition testable from literals with no window, no event queue, and no
Vulkan device.

```
                 ┌──────────────── button_up ───────────────┐
                 v                                          │
   idle ──motion(handle)──> hover_handle ──down──> dragging_handle
     │  <──motion(none)────      │
     │                           └──────────── (no reachable pan path)
     ├──motion(orbit)──> hover_orbit ──down──> [place_node ACTION]
     └──down(none)────> panning ──motion──> pan delta ──button_up──> idle
```

Placement is deliberately **not** a state. It completes inside the single
button-down event that triggers it, so a persistent state would be entered
and left with no event in between — it's an action carried on the press
verdict instead, and that verdict is `[[nodiscard]]` so a caller can't
silently drop a placement.

The drag-lock is structural rather than a checked condition: pan and
handle-drag are mutually exclusive branches of the *one* switch inside
`on_motion`. While `dragging_handle` is the current state, there is no code
path in that switch that produces a pan delta — the lock isn't a flag that
could be forgotten, it's the absence of a branch. The regression test asserts
this on the *very first* motion after the grab, deliberately, because a test
that lets the drag settle before checking can't see a one-frame leak.

Ordering matters at the hit-test level too: handles are checked before the
orbit line, which is checked before falling back to a pan. A handle sitting
directly on the sampled curve is the more specific target — checking the
line first would make every handle ungrabbable exactly where it visually
sits. Hover is re-evaluated from a fresh hit test on every motion event
rather than cached, so a zoom between two mouse-move events can't leave the
hover state pointing at stale candidates.

## The pan that leaves two line families alone

Panning composes additively at the one place the camera center is formed
each frame:

```cpp
const coords::Vec3f64 unpanned_center = primary_pos + center_residual_;
const coords::Vec3f64 effective_center = unpanned_center + pan_offset_;
```

Everything drawn camera-relative to `effective_center` pans for free, because
those passes — the body discs, the whole craft-geometry family — recompute
from float64 world state every frame. `pan_by` just accumulates a world-metre
offset in `pan_offset_`.

Two **legacy** line families — the long-lived body trail and its predicted
conic — can't take that shortcut. They store camera-relative float32 points
accumulated across thousands of past frames in a ring buffer. Storing them
under the *current* pan would anchor every older point to whatever pan was
active when it was appended, and dragging the view would visibly shear the
trail as newer points shift and older ones don't. They stay stored against
the **unpanned** center instead, and receive the **negated** pan offset as a
per-draw push constant:

```
drawn = camera_relative_center + pos = (-pan) + (p - unpanned_center)
                                     =  p - effective_center            ✓
```

`camera_relative_center` isn't a new field — it's a push constant `line.vert`
has carried, zero-initialized and unused, since the line-strip renderer's
first version, four milestones earlier, as plumbing left in for "a future
moving camera" that this phase is. The shader change count for the whole pan
feature is zero.

Both re-centering keybinds — cycling focus and jumping to the craft — reset
the pan to zero. The pan is an offset *from* the focused body; carrying it
across a re-center would leave the newly focused body sitting off screen by
however far the previous one had been dragged, which reads as a bug rather
than a preserved view — both functions already reseeded the trail for the
same reason. Zoom needs no equivalent reset: the pan offset is stored in
world metres, so it's zoom-scale independent by construction, which is also
what keeps a grabbed point under the cursor when the wheel turns mid-drag.

## Making the predicted path distinct

The predicted polyline was already drawn — two named regions inside the
existing craft-geometry vertex buffer, filled once per frame in dim white and
bright amber. What this phase adds is the styling itself, plus the two rules
that draw depended on, pulled out as pure, unit-pinned kernels:

```cpp
struct PredictedPathRanges { std::uint32_t pre_offset, pre_count, post_offset, post_count; };

[[nodiscard]] constexpr PredictedPathRanges predicted_path_ranges(
    std::size_t pre_count, std::size_t post_count,
    std::uint32_t pre_offset,  std::uint32_t pre_capacity,
    std::uint32_t post_offset, std::uint32_t post_capacity) noexcept;

[[nodiscard]] inline coords::Vec3f32 predicted_path_point(coords::Vec3f64 sample,
                                                           coords::Vec3f64 ref_offset) {
    return coords::to_render(sample + ref_offset);
}
```

Each segment clamps against its *own* capacity rather than a shared pool —
a correctness choice, not a memory one. With a shared pool a long pre-node
segment could eat the post-node segment's space, silently shortening the
line the player is dragging. `predicted_path_ranges` being `constexpr` buys
three compile-time checks on the buffer layout: a fully-clamped pre-node
segment ends exactly where the post-node segment begins, the post-node
segment ends at the buffer boundary, and the predicted region begins right
after the prograde marker's vertices with no gap. A future re-layout that
overlaps any of those fails the build instead of drawing garbage.

`predicted_path_point` is the narrow-once rule: add this frame's reference
offset in float64, narrow to float32 exactly once. A point re-narrowed on
every frame — rather than once, from the float64 original — accumulates
rounding a single narrowing avoids entirely; the regression test adds two
interplanetary-magnitude terms whose *sum* is one kilometre and asserts the
kilometre survives, with a narrow-first control that loses it.

The palette:

| line | color | alpha |
|---|---|---|
| pre-node predicted | `0.55, 0.95, 0.55` — dim, desaturated green | 0.55 |
| post-node predicted | `0.30, 1.00, 0.30` — bright, saturated green | 0.95 |

Green, because it was the one unclaimed color family — the amber the
predicted path shipped with collides with the amber prograde marker already
on screen, and two bright amber lines force a player to work out which is
which. Pre-node and post-node differ *within* the family rather than by hue,
because they're two states of one thing: the pre-node segment is dim because
it's context — and while a handle is held, it's byte-frozen, so reading as
"locked" is literally true. The post-node segment is bright because it's the
answer to "what does this burn do," and it's the segment that moves under
the player's hand.

## The node made tangible

A node needs to be a thing a player can point at. Seven disk-renderer draw
calls do it — a bright green node marker plus six handle glyphs, sharing the
disk renderer the body markers already use. The node marker takes the
post-node line's bright green because it *is* the burn point on that line.

The load-bearing decision is that one function produces the positions for
both the draw and the hit test:

```cpp
bool OrbitDemo::map_node_geometry(
    double offset_len_m, coords::Vec3f64& out_node_rel,
    std::array<coords::Vec3f64, kMapHandleCount>& out_handle_rel) const {
    const physics::ManeuverNode node = planner_.node();
    const physics::State at_node = planner_.predicted_state_at(node.time_s);
    const physics::TnbBasis basis = physics::tnb_frame_basis(at_node);
    if (!basis.valid) return false;
    out_node_rel = at_node.r + map_ref_offset_;
    out_handle_rel = node_handle_offsets(out_node_rel, basis, offset_len_m);
    return true;
}
```

Both `draw_node_handles` and the hit-testing candidate builder call this same
function. A glyph drawn at one position and clickable at a different one —
the classic version of that defect — is structurally unreachable here
without deleting the shared function itself. The frame basis is derived from
the craft's *predicted* state at the node's own future epoch, never from the
craft's current state: on any orbit that isn't circular, the velocity
direction some minutes from now isn't the velocity direction right now, and
that divergence is exactly what a maneuver-node handle needs to show.

Glyph size is recomputed from the current eased zoom every frame rather than
cached, using the same constant-screen-size construction the attitude triad
and the prograde marker already use — a world-fixed offset would collapse
all six handles into the node the moment the player zoomed out. The
pointed-at handle draws at 1.4× radius and full opacity *before* any grab,
sourced from the input controller's own hover state. That highlight is
continuous across the grab — it doesn't blink off at the instant the player
commits — and during a drag it follows the *grabbed* handle rather than the
live cursor, since the player is still editing that handle after the cursor
has moved off it.

## The test battery

34 new cases land across the phase, entirely SDL-free, window-free and
device-free: round-trip projection tests from zoom 1/256 to 65536× using
*relative* tolerance (an absolute tolerance would pin floating-point noise at
10¹¹-metre magnitudes rather than the real round-trip error), the inverse
projection checked term-by-term independently of the forward function so a
matching sign error in both can't hide inside a round-trip, every transition
in the state diagram above with the drag-lock asserted on the first motion
after a grab, a scale change *between* two motion events proven not to
corrupt an in-flight drag (it reads an NDC step and never consults the
projection scale), handle hit-testing (nearest-within-radius, an inclusive
boundary pinned bit-exactly, ties resolving to the lowest index, non-finite
input), handle-offset geometry (every handle exactly the offset distance from
the node, an invalid frame basis collapsing to six copies of the node
position rather than NaN), and drag-to-delta-v (outward increases, inward
decreases, perpendicular motion contributes nothing, a degenerate axis and
non-finite input both return exactly zero).

## Where it is now

The shapes above haven't changed, but a later hardening pass this milestone
reached several of these functions directly.

**NDC and screen pixels became distinct types.** Both spaces used to be
spelled as a bare `glm::vec2`, distinguishable only by which variable name a
reader trusted. An NDC magnitude sits around [−1, 1] — small enough that,
passed where a screen-pixel candidate was expected, every candidate falls
inside a 12-pixel hit radius, and the handle hit test returns the same
handle for every cursor position on screen. `Ndc` and `ScreenPx` are now
distinct wrapper types around the same `glm::vec2`, and projection.hpp's four
conversions are the only legal way to cross between them — passing one where
the other is expected is now a compile error instead of a silent wrong
answer.

**A degenerate projection scale is now checked at the boundary that
matters.** `unproject_from_ndc` documented its non-zero, finite scale
contract as an assertion, which a release build compiles out entirely, so
the handle candidate producer divided by whatever the current zoom scale
held regardless. An explicit check now sits in that producer, returning its
ordinary no-candidates result on a degenerate scale rather than projecting
every handle to infinity and hit-testing against the result.

**The drag-cancel path gained focus-loss handling.** A held handle drag used
to be cleared only by the mouse-button-up event, so a button-up lost to a
focus change (alt-tab, an OS overlay, switching windows) left the controller
convinced a drag was still live indefinitely, and every subsequent mouse
motion kept editing the node's delta-v with no button actually held. The
window's focus-lost and minimized events now cancel any live drag or pan
through the same release transition the normal button-up path already uses,
and log their own line naming the reason — reusing the release path's log
line would misreport an alt-tab as a completed edit the player never
committed to.

**The drag's precision is under continued scrutiny.** `handle_drag_dv`
projects the cursor's screen-pixel motion onto the handle's own screen axis
entirely in float32 before widening the result to float64 for the stored
delta-v scalar. A direct comparison against the same projection carried in
full float64 precision found the single-precision result differs by roughly
5×10⁻⁸ m/s — about 52 nanometres per second — on a diagonal drag, accurate
enough that the existing test tolerance, calibrated years earlier to a much
tighter bound, had to widen to match what the shipped arithmetic actually
delivers rather than an idealized figure it never hit. Computing that
projection in float64 throughout, rather than only at the final cast, is on
the roadmap for the next milestone.

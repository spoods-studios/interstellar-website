# M1.1 Phase 53.3 — Camera Stability & Re-Fly: Technical Deep-Dive

> Retroactive technical devlog. **Inserted fix phase** — not in the original
> M1.1 roadmap. Code shown **as built on 2026-07-23**, which is still what the
> tree holds — nothing has touched this surface since.

## Starting point

Phase 53 put a debug HUD and a visible craft on screen. Flying it end to end
surfaced one defect that had nothing to do with physics: the camera jumped.
Every camera keybind moved the view in a single frame, so the picture teleported
instead of moving. There are four such keybinds, all handled in `main.cpp`'s
SDL2 event loop: `TAB` calls `cycle_focus()` to advance the centred body slot by
one and wrap, `[` and `]` call `zoom_out()` and `zoom_in()` for a ×0.5 or ×2
step, and `C` calls `focus_craft(apoapsis_m)` to centre on the craft and refit
the view to its current orbit.

Phase 53.3 is the third and last of the inserted fixes that closed out Phase 53.
It is render-only — no physics file, no worker file, and no locked kernel is in
its diff.

## What was actually wrong

Both pieces of camera state were written directly by the keybind handlers, and
both were read directly by the render transform on the same frame. The zoom
lived in one member, written by `zoom_by` and read by the transform:

```cpp
zoom_factor_ = clamp_zoom(zoom_factor_, multiplier, kZoomMin, kZoomMax);
// ...
const float eff_ndc_scale = world_to_ndc_scale_ * zoom_factor_;
```

One `]` press doubles `eff_ndc_scale` between one presented frame and the next.
`C` is worse: `focus_craft` computes a fit zoom from the craft's live apoapsis
and assigns it outright, so the factor can move by orders of magnitude in one
frame, anywhere inside the `kZoomMin = 1/256` to `kZoomMax = 65536` clamp.

The camera centre had the same shape. `focus_slot_` was assigned in the keybind
handler, and `render()` read the centred body's position straight out of the
worker snapshot into `primary_pos`, which is subtracted from every drawn
position to build the camera-relative frame. Switching the slot from the Sun to
the Earth changes that subtrahend by about 1.5 × 10¹¹ m in one frame, and every
body, trail point, and piece of craft geometry moves by that amount at once.

### What was not wrong

The obvious suspect for a camera jump in this engine is the floating-origin
re-anchor — the periodic rebasing that keeps float32 render coordinates small.
It was ruled out before any code changed. Re-anchoring is already continuous at
code level, and `craft_trail_no_phantom_kick` locks that: a re-anchor produces
no discontinuity in the drawn trail. The snap came entirely from the instant
assignments above, and the re-anchor path was left untouched.

## The filter

The fix splits each piece of camera state into a target and a rendered value,
and moves the rendered value toward the target by a fixed fraction each rendered
frame. Two pure helpers implement that step, placed next to `clamp_zoom` in
`craft_geometry.cpp` — the file that already holds the snapshot-free camera
kernels:

```cpp
float exp_approach(float current, float target, float k) noexcept {
    const float kc = std::clamp(k, 0.0f, 1.0f);
    return current + (target - current) * kc;
}

coords::Vec3f64 exp_decay(coords::Vec3f64 residual, float k) noexcept {
    const double kc = std::clamp(static_cast<double>(k), 0.0, 1.0);
    return residual * (1.0 - kc);
}
```

`exp_approach` is a one-pole low-pass filter written in its error form. Let
`e_n = target − current_n` be the remaining distance after n frames. One step
gives `e_{n+1} = (1 − k)·e_n`, so the error is a geometric sequence
`e_n = (1 − k)^n · e_0`. The ease factor is shared by both helpers and lives on
`OrbitDemo` as `static constexpr float kCameraEaseFactor = 0.18f;`, making the
per-frame retention `1 − k = 0.82` and the time constant, in frames,
`τ = −1 / ln(0.82) ≈ 5.04`. The closed fractions follow: `0.82¹² ≈ 0.092`, so
about 91% of the move is complete after 12 frames, and `0.82¹⁵ ≈ 0.051`, about
95% after 15. At a 60 Hz present rate that is a ~84 ms time constant and a
~0.25 s settle.

The clamp is part of the contract, not defensive padding. Forcing `k` into
`[0, 1]` makes two degenerate cases safe by construction: `k ≥ 1` lands exactly
on the target in one step and can never overshoot, and `k ≤ 0` holds the current
value rather than stepping backwards or diverging. At `current == target` the
expression evaluates to exactly `target` for every `k`, so a settled camera is a
stable fixed point and cannot jitter.

### Frame-rate independence

The filter is **not** frame-rate independent, and that is worth stating plainly
because the formulation reads like it might be. `k` is applied once per rendered
frame, with no `dt` term anywhere in either helper or at either call site. The
recurrence advances in frame index, not in seconds. The glide settles in a fixed
15 frames regardless of how long those frames take — about 0.25 s at 60 Hz,
0.5 s at 30 Hz, 0.10 s at 144 Hz. The swap chain prefers `eMailbox` and falls
back to the spec-guaranteed `eFifo`, so the wall-clock duration follows either
the display refresh rate or whatever rate the render loop achieves.

The frame-rate-independent form of the same filter is
`k_eff = 1 − exp(−dt / τ)` with τ in seconds, evaluated per frame from the
measured frame time. That is the right form for a production camera, and not
what this phase built — a wall-clock-correct ease would have added a frame timer
to a class that does not currently own one.

### Zoom: target and rendered value

`zoom_factor_` keeps its meaning — it is the target the keybinds write. A second
member, `float zoom_current_`, holds the value the transform uses. `render()`
advances it once, then frames with it:

```cpp
zoom_current_ = exp_approach(zoom_current_, zoom_factor_, kCameraEaseFactor);
const float eff_ndc_scale = world_to_ndc_scale_ * zoom_current_;
```

`zoom_by`, `zoom_in`, `zoom_out`, and `focus_craft` are unchanged in how they
write the target, and the stderr `[camera]` lines still report `zoom_factor()`.
One constructor line, immediately after `world_to_ndc_scale_` is computed, keeps
the first frame from gliding in from a stale value:
`zoom_current_ = zoom_factor_;`.

## Focus recenter: a residual, not a lerp between positions

The centre could not use `exp_approach` on the position directly. The old and
new focus bodies both move every frame, and the floating origin can rebase
between frames, so interpolating between two absolute positions would have to
answer which frame's coordinates those positions are in. The chosen form
sidesteps that by easing a **difference** — a `coords::Vec3f64 center_residual_`
member holding the leftover offset between where the camera is centred and where
the new focus body is. Every frame the render path computes:

```cpp
const coords::Vec3f64 effective_center = primary_pos + center_residual_;
center_residual_ = exp_decay(center_residual_, kCameraEaseFactor);
```

Three properties fall out of that shape.

1. **It is invariant to a floating-origin shift.** A rebase adds the same
   constant offset to every position in the snapshot, and a difference of two
   positions is unchanged by that. A stored residual stays correct across a
   rebase, so there is nothing to compensate for mid-glide.
2. **The new body is tracked immediately.** `primary_pos` is re-read every
   frame, so the camera follows the new focus body's real motion from the first
   frame and only the constant offset decays. Interpolating between two frozen
   positions would lag a moving target.
3. **A residual of exactly zero stays exactly zero.** `exp_decay` on a zero
   vector returns componentwise `0.0` for every `k`, so a settled centre is
   bit-stable and `effective_center` reduces to `primary_pos` exactly.

The residual is `Vec3f64`, not `Vec3f32`, because of its magnitude. A Sun→Earth
recentre starts it at roughly 1.5 × 10¹¹ m, where binary32 has a ULP of
2¹⁴ = 16384 m — a float residual would quantise the glide to 16 km steps and
never reach a clean zero.

### Folding, not overwriting

On a focus change the residual is added to, not replaced:

```cpp
center_residual_ = (snap.pos_at(prev_slot) - primary_pos) + center_residual_;
```

This is what makes a focus change **during** an in-progress glide continuous.
Write `p_old` for the outgoing focus body's position, `p_new` for the incoming
one, and `r` for the residual already in flight. Before the change the camera is
centred at `p_old + r`. After folding, the residual is `(p_old − p_new) + r`, so
the new effective centre is `p_new + (p_old − p_new) + r = p_old + r` — exactly
where the camera already was. Overwriting the residual with `p_old − p_new`
would have discarded `r` and reintroduced a jump on the second of two quick
presses, the case a `TAB` cycle through five bodies hits constantly. The same
algebra covers a single press: with `r = 0` the effective centre is exactly
`p_old`, so the frame the key is pressed on renders identically to the one
before it. The decay is applied after `effective_center` is computed, so the
glide starts on the following frame.

### Deferred capture

`cycle_focus` and `focus_craft` cannot compute the residual themselves. They run
on the main thread outside `render()`, which owns the only snapshot the render
path has. Reading a second snapshot in the keybind handler would mean an extra
snapshot copy off the render path, and the two reads could straddle a worker
publish — mixing a pre-shift `p_old` with a post-shift `p_new` and reintroducing
the discontinuity the difference form exists to avoid. So the handlers record
intent only — `prev_focus_slot_ = focus_slot_;`, the slot move, then
`focus_change_pending_ = true;` — and `render()` resolves it against the one
fresh snapshot it already holds:

```cpp
if (focus_change_pending_) {
    const std::size_t prev_slot =
        (prev_focus_slot_ < snap.count) ? prev_focus_slot_ : 0;
    center_residual_ = (snap.pos_at(prev_slot) - primary_pos) + center_residual_;
    focus_change_pending_ = false;
}
```

Both slot positions come from the same snapshot, so the captured delta is a
single-instant difference. `focus_craft` sets the pending flag only inside its
`craft_hud_enabled_` branch — with the craft HUD off, the focus slot does not
move and only the zoom eases. `effective_center` then replaces `primary_pos` at
all three camera-relative subtractions in `render()`: the legacy trail's
leading-satellite position, the body disks, and the centre argument
`draw_craft_geometry` receives for the craft trail, conic, attitude triad, and
prograde marker. `draw_craft_geometry` itself is unmodified — it takes a centre
and subtracts it, so passing a different centre is the whole change. That is why
the Phase 53.1 attitude indicator and the Phase 53.2 spline trail glide with the
camera without either of them knowing the camera eases at all.

## The test suite

`tests/unit/render/test_camera_ease.cpp` tests the two helpers directly, from
literals — no Vulkan, no snapshot, no window. It pins four properties, mapping
one-to-one onto what the render integration assumes:

1. **Monotonic approach, no overshoot.** Both directions, over 200 steps:
   ascending from the startup fit 1.0 to a 180× target, and descending from 180×
   back to 0.5×. Every step is asserted not to pass the target, and to move
   strictly toward it while the glide is in progress.
2. **Bounded convergence.** After 15 steps at `k = 0.18` the remaining fraction
   of the original distance is asserted under 0.06 — the `0.82¹⁵ ≈ 0.051` figure
   checked, not assumed. `exp_decay` gets the same assertion on magnitude.
3. **Exact no-op at the fixed point.** `exp_approach(42.0f, 42.0f, k) == 42.0f`
   for `k` in `{0, 0.18, 0.5, 1, 2}`, and `exp_decay` on a zero residual returns
   componentwise `0.0` for the same set. Exact equality, not a tolerance.
4. **The `k` clamp.** `k` of 1, 2, and 1000 all land exactly on the target in one
   step; `k` of 0 and −5 hold the current value; `exp_decay` at `k ≥ 1` collapses
   to exactly zero and never past it.

The residual case starts from `{1.5e11, -4.0e10, 7.0e9}` — a Sun→Earth scale
offset, so the suite exercises the magnitude the double precision exists for.
After 200 steps the magnitude is asserted under 1 mm; it lands around 9 × 10⁻⁷ m.

One adjustment landed in the test rather than in production code: the two
monotonic cases guard their strict-progress assertion to remaining distances
above `1.0e-3`. Below that a 32-bit step of `remaining × 0.18` rounds away
against the ULP at the target's magnitude and `current` plateaus — a plateau,
never a reversal — so only that assertion relaxes to `>=` once settled, while
no-overshoot still runs on every step.

## Where the craft-control stack stands

With this in, the Phase 53 chain is complete and the demo flies end to end.
Flown at 128× time scale on 2026-07-23: the camera glides on `C`, `TAB`, `[`,
and `]` with no snap; the HUD's live readouts track mass, fuel, throttle, body
rates, and velocity; a burn visibly grows the orbit as a smooth conic with the
spline trail following it; and a mid-burn floating-origin shift stays clean. The
Phase 52 attitude and RCS behaviour is visible for the first time on the same
flight — the triad swings under rotation input, `T` damps a tumble to a stop,
and six-direction RCS translation moves the craft without inducing one.

The full suite runs **903/903** in both the Release and debug builds. The
deterministic force kernel `nbody_force.cpp`, both worker translation units, and
`step_dt = 300` are byte-untouched — the diff is `craft_geometry.{hpp,cpp}`,
`orbit_demo.{hpp,cpp}`, the test file, and its `tests/CMakeLists.txt`
registration. The origin-shift locks `craft_trail_no_phantom_kick` and
`craft_latch_origin_shift` are green, and a craft-absent run is unaffected: the
easing has no craft dependency, and the residual path keys off focus-slot
changes alone.

## The limitation this code still carries

The demo launches at 128× time scale, and it has to. The worker advances with
`while (accumulator_ >= step_dt)`, the accumulator fills at
`real_time × time_scale`, and `step_dt = 300.0 s`. At 1× that is 300 real
seconds per step — the simulation is frozen, no craft-present snapshot is ever
published, and every craft-gated HUD element is absent. Confirmed headless:
31 frames, `t = 0.000` throughout, zero `[craft]` lines.

`step_dt = 300` cannot simply shrink. The Phase 52 attitude subcycle is built on
`N = 16384 = step_dt / kAttDt` being an exact integer with `kAttDt = 75·2⁻¹² s`
an exact binary64 value, so changing `step_dt` breaks the exactness argument
that whole subcycle rests on. Three linked gaps follow from that one number:

1. **1× real-time launch.** Gameplay wants the player to start at real time and
   warp up deliberately. 128× is a stopgap.
2. **Fine interactive throttle.** A tank that lasts under manual throttle needs
   `time_scale ≤ 10`; a visibly live orbit needs `time_scale ≥ 300`. Those two
   ranges do not overlap at a 300 s step.
3. **Burn-trajectory accuracy.** A burn is applied as 300 s impulses at the
   thrust kick seams. The Δv magnitude is exact — Tsiolkovsky is integrated
   correctly — but the trajectory is a coarse impulsive approximation, with no
   bound-lock against a continuously-thrusted one.

All three close with the same missing machinery: a craft position, fuel, and
thrust step finer than the 300 s planetary step. Phase 52 subcycled attitude
only, enough to fly orientation but leaving translation on the coarse step.
Craft-orbital subcycling is the same nesting idea applied one level down, and it
is M1.2 work. A cheap partial that does not need it: publish the craft's initial
snapshot at `t = 0` so the HUD renders at 1× instead of vanishing. The orbit
still advances one step per 300 real seconds, so that buys a readable screen and
no more.

One cosmetic item also came out of the fly-through. The amber prograde marker
draws `craft_vel − earth_vel`, true LEO prograde and correctly tangent to the
92-minute orbit, but at the wide default heliocentric zoom that tangent can
point roughly sunward and read as a yellow line toward the Sun. Centring with
`C` shows it as tangent immediately; hiding or scaling the marker at extreme
zoom-out would fix the read, and the direction it draws is already correct.

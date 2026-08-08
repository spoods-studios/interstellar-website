# M1.1 Phase 53.1 — Demo Control Policy & Attitude Indicator: Technical Deep-Dive

> Retroactive technical devlog. **Inserted fix phase** — not in the original
> M1.1 roadmap. Code shown **as built on 2026-07-23**; a drift section at the
> end tracks what changed since and why.

## Starting point

Phase 53 put a craft HUD on screen — live wet mass, propellant, throttle,
attitude rates, velocity, a past-track trail, and a predicted conic. Every
kernel behind it was unit-locked at 882/882. Then the demo was flown on
2026-07-23, and four defects appeared that no unit test in the suite could
see. All four trace to one line of demo configuration.

The demo booted at `time_scale_init = 256.0`. The worker's clock is a drain
accumulator filled at the scaled wall rate:

```cpp
accumulator_ += scale * wall_dt;
...
while (accumulator_ >= quantum) { /* orbital step body */ }
```

So at 256× the flown integrator advances 256 seconds of simulated time per
real second, and everything downstream of it does too. The consequences, in
the order a pilot hits them:

1. **Propellant vanished on a tap.** The demo craft carries 600 kg of
   propellant (`kCraftWetMassKg = 1000.0`, `kCraftDryMassKg = 400.0`) and
   burns it at exactly 1 kg/s at full throttle — `kCraftThrustMaxN = 3000.0`
   over `kCraftVeMps = 3000.0` is a mass flow of 1.000 kg/s. That is 600
   seconds of simulated full throttle. At 256×, 600 seconds of simulated time
   is 2.3 real seconds.
2. **The throttle ramp popped instead of ramping.** Throttle ramps at
   `kThrottleRampPerTick = 2⁻⁶` per attitude tick, about 1.17 s of simulated
   time from idle to full. At 256× that completes inside roughly one rendered
   frame.
3. **The orbit was wrecked.** Periapsis ended at −2284 km — below the
   surface. That is the downstream consequence of a burn that dumped a third
   of the tank before the key came back up, not a kernel error.
4. **The craft's facing was unreadable.** The attitude triad drew three
   two-vertex body-axis segments in full-strength red, green, and blue, all at
   equal weight, so nothing on screen said which axis was the nose. There was
   no velocity reference at all.

Phase 53.1 owns items 1, 2, and 4. The trail and the camera went to Phases
53.2 and 53.3.

## The obvious fix froze the simulation

The first fix was the direct one: boot at real time, and gate the throttle
keys so a burn can only be commanded there. That shipped as two pure
predicates in a new header, `demo_control_policy.hpp`:

```cpp
[[nodiscard]] inline bool throttle_input_allowed(double time_scale) noexcept {
    return time_scale == 1.0;
}

[[nodiscard]] inline bool timescale_increase_allowed(double craft_throttle) noexcept {
    return std::isfinite(craft_throttle) && craft_throttle <= 0.0;
}
```

Both are exact by design. `throttle_input_allowed` is a bare `== 1.0` rather
than a tolerance band, and that bare compare rejects every non-finite scale
for free, since neither NaN nor infinity equals 1.0. `timescale_increase_allowed`
cannot use the mirror trick. The naive form `!(craft_throttle > 0.0)` would
**allow** a warp-up on a NaN throttle, because `NaN > 0.0` is false. The
explicit `std::isfinite` guard is what makes a non-finite throttle read as lit
and block.

The wiring was main-thread only. `push_craft_axis_state` zeroed
`c.throttle_axis` and stripped the `kAxisFlagThrottleFull` bit off the one-shot
when the gate was closed, while never touching `kAxisFlagThrottleCut`,
kill-rot, or precision — cutting the engine and steering stayed honored at any
scale. A blocked key emitted a throttled stderr line plus a transient on-screen
notice that `OrbitDemo` counted down over 120 rendered frames.

Then the demo was launched at 1×, and nothing moved.

The reason is the drain accumulator above. The demo's `step_dt` is 300.0
seconds. At `time_scale = 1.0` the accumulator gains one second of simulated
time per real second, so it needs 300 real seconds to reach the threshold for
a single orbital step. The worker therefore never publishes a craft-present
snapshot at launch, and every craft-gated HUD element is driven off that
publication — the craft block, the orbit block, the status line, and the
`[craft]` telemetry line all vanish. A headless run confirmed it exactly: 31
frames rendered, simulated time `t=0.000` throughout, zero `[craft]` lines.

## `step_dt = 300` cannot shrink

The obvious next move is to shrink `step_dt` until 1× is live. It is not
available. Phase 52's attitude subcycle is an exact integer division of the
orbital step:

```cpp
inline constexpr std::uint64_t kAttTicksPerStep = 16384;   // 2¹⁴
inline constexpr double        kAttDt = 75.0 * 0x1p-12;    // 300 / 16384, exact dyadic
```

`300 s = 75·2²`, so `kAttDt = 75·2⁻¹²` is an exact binary64 value —
18.310546875 ms, with no rounding. That exactness is the whole proof that
16384 fine attitude ticks telescope into precisely one orbital step, which is
what keeps the orbital step count bit-identical to the pre-Phase-52 loop.
Changing `step_dt` to any value that is not a dyadic multiple of an equally
exact `kAttDt` breaks that proof and the math-lock built on it.

## The arithmetic with no solution at this step size

With `step_dt` fixed, the two things a pilot needs turn out to be mutually
exclusive. Write `S` for the time scale.

1. **Controllable propellant.** 600 seconds of simulated full throttle must
   last long enough to modulate by hand. Call that a minute of real time, and
   `S ≤ 10`.
2. **A live orbit.** An orbital step must land often enough that the craft
   visibly moves. One step per real second means `300 / S ≤ 1`, so `S ≥ 300`.

The two ranges do not overlap, and no keybind policy closes a gap that wide.
Fine interactive throttle needs a finer craft-*orbital* step — orbital
subcycling, the position-and-velocity analogue of what Phase 52 built for
attitude. M1.1 never scoped that. What M1.1 did commit to is a visual and
numeric confirmation that thrust changed the orbit, and that works fine at an
accelerated scale.

## What shipped: a live 128×

So the launch scale became 128×, and the gate came out. At 128× a 300-second
step lands every ~2.3 real seconds, so the simulation visibly steps and the
craft HUD publishes at launch. Taps are gentler than the old 256× boot for
exactly the same reason the fuel drained there. And 128× still sits in the
flown tier, below the 2048 warp-in scale, so pressing `.` still walks the
scale up 128 → 256 → … → 2048 and crosses the flown-to-warp transition on the
way.

```cpp
interstellar::physics::PhysicsWorker::Config worker_config{
    .method = interstellar::physics::Yoshida4{},
    .step_dt = 300.0,
    .initial_state = sun_state,  // ignored on the multi-body path
    .mu_central = 0.0,
    .time_scale_init = 128.0,    // live scale, below warp_in_scale = 2048
    ...
};
```

The rescope is net-negative on the engine and test tree: 28 lines added, 254
removed. `demo_control_policy.hpp` and `test_demo_control_policy.cpp` are
deleted outright, along with their build registration. `log_craft_input_blocked`,
`kControlNoticeFrames`, `OrbitDemo::set_control_notice`, its two members, and
its draw block all come out. `push_craft_axis_state` and the comma/period
keybind handlers return byte-identical to the Phase 53 tip, with the launch
scale as the only surviving change. `step_dt` stays 300.0, and the
deterministic force kernel `nbody_force.cpp` and the worker translation units
stay byte-untouched, so craft-absent runs stay bit-identical.

The one thing that survives the rescope intact is the attitude indicator,
because it never depended on the time-scale question at all.

## The prograde marker

The marker is a pure geometry function that mirrors the existing
`craft_triad_segments` shape exactly: span output, `noexcept`, no snapshot, no
Vulkan, no I/O, testable from literals.

```cpp
void craft_prograde_marker(coords::Vec3f64 craft_rel_m,
                           coords::Vec3f64 vel_rel_ref_m_s,
                           double marker_len_m,
                           std::span<coords::Vec3f32> out) noexcept {
    if (out.size() < kCraftProgradeVertexCount) {
        return;
    }
    const coords::Vec3f32 base = coords::to_render(craft_rel_m);
    out[0] = base;
    const double v_sq = vel_rel_ref_m_s.length_squared();
    if (!std::isfinite(v_sq) || v_sq <= 0.0) {
        out[1] = base;
        return;
    }
    const coords::Vec3f64 dir = vel_rel_ref_m_s / std::sqrt(v_sq);
    out[1] = coords::to_render(craft_rel_m + dir * marker_len_m);
}
```

Three properties are load-bearing here.

1. **It encodes direction, not speed.** The velocity is normalized and then
   scaled by `marker_len_m`, which the caller derives from a screen-pixel
   constant. A craft doing 7000 m/s and a craft doing 100 m/s in the same
   direction draw the identical stalk.
2. **Degenerate velocity collapses instead of dividing.** A zero or non-finite
   velocity writes the tip onto the base. There is no divide by a zero norm,
   and no NaN ever narrows into the float32 vertex buffer.
3. **The `std::sqrt` is confined to a render translation unit.** The normalize
   is the only libm call the function needs, and `craft_geometry.cpp` is a
   render-tier file. No locked worker translation unit gains a symbol.

`kCraftProgradeVertexCount = 2` — a single disjoint two-vertex stalk. A
chevron at the tip was considered and dropped, because drawing one needs an
arbitrary perpendicular in 3D, and any such choice is fragile under rotation.
Colour carries identifiability instead.

## Wiring it into the frame

The marker rides the same single craft geometry buffer family the trail, the
conic, and the triad already share. The layout constants chain, so adding a
range grows the buffer and the scratch array automatically:

```cpp
static constexpr uint32_t kCraftProgradeVertexOffset =
    kCraftTriadVertexOffset + static_cast<uint32_t>(kCraftTriadVertexCount);
static constexpr uint32_t kCraftGeomVertexCount =
    kCraftProgradeVertexOffset + static_cast<uint32_t>(kCraftProgradeVertexCount);
```

`draw_craft_geometry` builds the marker from the same Earth-relative velocity
the predicted conic is keyed to, `snap.vel_at(craft_slot_) -
snap.vel_at(kCraftHudReferenceSlot)`. It never consults the mass-dominance scan.
The screen length comes from `kCraftProgradePixels = 32.0f`, computed at the
call site next to the triad's `kCraftTriadPixels = 24.0f` through the same
pixels-to-metres conversion. 32 px extends past the 24 px triad, so the
velocity cue reads as its own marker rather than a fourth axis.

The draw calls are where the nose becomes unambiguous. Before, the three triad
axes were `(1.0, 0.25, 0.25, 1.0)`, `(0.25, 1.0, 0.25, 1.0)`, and
`(0.25, 0.25, 1.0, 1.0)` — equal weight, full alpha. After:

```cpp
push_color(1.0f, 0.30f, 0.30f, 1.0f);
cmd.draw(2, 1, kCraftTriadVertexOffset + 0, 0);
push_color(0.15f, 0.45f, 0.15f, 0.55f);
cmd.draw(2, 1, kCraftTriadVertexOffset + 2, 0);
push_color(0.15f, 0.15f, 0.45f, 0.55f);
cmd.draw(2, 1, kCraftTriadVertexOffset + 4, 0);
push_color(1.0f, 0.82f, 0.10f, 1.0f);
cmd.draw(2, 1, kCraftProgradeVertexOffset, 0);
```

The body +X axis is the thrust axis, so it keeps full brightness and full
alpha. The +Y and +Z axes drop on both brightness and alpha. The marker draws
amber, a colour no other craft line owns.

## The test suite

`test_craft_prograde_marker.cpp` pins five cases, all from literals:

1. A velocity purely along +Y gives a stalk whose X and Z components are below
   tolerance and whose Y component is positive.
2. An arbitrary velocity `{300, -400, 1200}` gives a stalk whose unit vector
   dots to 1 with the unit velocity, within `1e-3`.
3. The same direction at 100 m/s and at 7000 m/s gives the same stalk length
   and the same tip position — a 70× speed difference changes nothing.
4. Zero, NaN, and infinite velocities each write two finite vertices with a
   near-zero separation.
5. An undersized span leaves its sentinel untouched, matching
   `craft_triad_segments`' size-guard contract.

Full suite after the phase: **888/888 in both build lanes**.

## Why it was built this way

- **The gate predicates were deleted rather than kept dormant.** They were
  correct code for a launch model that cannot exist at `step_dt = 300`. The
  worker's own warp-tier burn exclusion already blocks the one genuine hazard,
  which is burning into the symplectic tier at 2048× and above.
- **`step_dt` was never touched.** Shrinking it to buy a live 1× would have
  broken the exact-dyadic proof behind the attitude subcycle. The honest move
  was to change the launch scale, which is demo configuration, rather than a
  locked constant.
- **The marker is direction-only.** A speed-proportional marker would grow off
  screen at orbital velocity and shrink to nothing during a slow approach.
  Length would only restate a number the HUD already prints.
- **Enforcement, when it existed, lived on the main thread.** The gate decided
  whether an input was pushed and never how the worker consumed one. That is
  why adding it and then removing it both left the input ring contract and the
  fixed-tick determinism untouched.

## Where it is now (drift since 2026-07-23)

- **The launch scale held.** `time_scale_init = 128.0` is still what
  `main.cpp` boots with, with a comment carrying the full reasoning inline.
- **Both siblings landed on top of it.** Phase 53.2 replaced the chorded trail
  with a centripetal Catmull-Rom spline subdivided 16 ways
  (`craft_trail_spline`, `kCraftTrailSplineSubdiv = 16`) and recoloured the
  trail to a calm cyan against a brighter magenta conic. Phase 53.3 added a
  per-frame exponential ease on zoom and focus recentre
  (`kCameraEaseFactor = 0.18f`), which removed the camera snap. The full
  re-fly after 53.3 passed, and it confirmed the bright +X axis and the amber
  prograde marker read correctly across zoom, along with the attitude and RCS
  behaviour carried over from Phase 52.
- **One comment went stale.** The amber draw's comment still describes the
  trail as white; Phase 53.2 recoloured it to cyan the next day. The claim it
  protects — every craft line identifiable without a legend — still holds,
  since cyan, magenta, red, green, blue, and amber remain distinct.
- **Fine interactive throttle is a named M1.2 item.** Craft-orbital
  subcycling is what unblocks it, sitting alongside the map view and manoeuvre
  nodes already deferred there. M1.1's accepted bar is 6DOF attitude, thrust
  that demonstrably changes the orbit, and a Tsiolkovsky propellant readout —
  all three of which work at 128×.

# M1.2 Phase 58 — Maneuver-Node Data Model + Placement: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-31**. M1.2 is
> not yet closed, and a later hardening pass this milestone touched several of
> the functions below — the drift section at the end covers what changed and
> why, not a milestone-end reconciliation.

## Starting point

The engine draws a predicted orbit line already. Phase 58 is the first piece of
the maneuver-node feature: a data model for a burn planned somewhere on that
line, the math to place it by clicking a point on the drawn curve, six
handles that build a Δv vector in a frame the player actually recognizes, and
a readout of what that burn costs in propellant and time. No mouse plumbing,
no rendering, no crossing into the physics worker — those are later phases.
What has to exist first is the model and the pure functions the UI will wire
up: a node struct, a frame-basis kernel, a screen-space picking kernel, and a
Tsiolkovsky-inverted burn estimate.

The one hard problem underneath all of it is a naming collision. The engine's
existing orbital-element code speaks the CCSDS-502 RTN vocabulary — radial,
transverse, normal — where the transverse axis equals the velocity direction
only on a circular orbit. Every maneuver-node UI a player has ever used
(prograde/retrograde, normal/anti-normal, radial-in/out) means something else:
the velocity-aligned Frenet frame, T/N/W in Vallado's *Fundamentals of
Astrodynamics and Applications* §3.4. On an eccentric orbit the two frames
diverge, and "prograde" has to mean the velocity direction, not the textbook
transverse axis, or every non-circular node in the game points slightly wrong.

## The frame, and the table that keeps it from getting "fixed"

`tnb_frame_basis` builds three axes from a state, never from the orbital
elements' angle fields. Those angle fields carry their own
circular/equatorial singularities, and those singularities have nothing to
do with this triad:

```cpp
struct TnbBasis {
    coords::Vec3f64 t_hat{};
    coords::Vec3f64 b_hat{};
    coords::Vec3f64 r_out_hat{};
    bool valid{false};
};
```

`t_hat = v/|v|` (prograde), `b_hat = h/|h|` with `h = r × v` (normal),
`r_out_hat = t_hat × b_hat` (radial-out). The handedness of that last cross
product is the one thing the formula alone doesn't settle — `t̂ × b̂` and
`b̂ × t̂` point in opposite directions, and only one of them faces away from
the primary. The first fixture answers it directly: on a circular equatorial
orbit `r = (R,0,0)`, `v = (0,v,0)`, so `h = (0,0,Rv)`, `b̂ = ẑ`, `t̂ = ŷ`, and
`b̂ × t̂ = (−1,0,0)` — radial-*in*. `t̂ × b̂ = (+1,0,0)` is the one that points
outward, so that's the stored convention, and the test asserts
`r_out_hat · r_hat > 0` directly rather than trusting the algebra by
inspection:

```cpp
TEST_CASE("maneuver_node: TNB basis on a prograde circular orbit points "
          "radial-out away from the primary") {
    const State s = circular_fixture();
    const TnbBasis b = tnb_frame_basis(s);

    REQUIRE(b.valid);
    require_vec_close(b.t_hat, Vec3f64{0.0, 1.0, 0.0}, 1e-15);
    require_vec_close(b.b_hat, Vec3f64{0.0, 0.0, 1.0}, 1e-15);
    require_vec_close(b.r_out_hat, Vec3f64{1.0, 0.0, 0.0}, 1e-15);

    const Vec3f64 r_hat = s.r / kCircR;
    REQUIRE(b.r_out_hat.dot(r_hat) > 0.0);
}
```

A second test drives the same function against an eccentric fixture and
checks that prograde and radial-out visibly *disagree* with the RTN transverse
and radial axes computed from the same state — documented expected behavior,
not a bug a reviewer should "fix" back toward CCSDS-502. The `ManeuverNode`
struct's doc-comment carries the full mapping table (handle name, Frenet
axis, CCSDS-502 axis, whether they coincide) so the next person to touch this
code sees the collision in the same place they'd see the struct.

The node itself never stores a vector:

```cpp
struct ManeuverNode {
    double time_s{0.0};
    double prograde_mps{0.0};
    double normal_mps{0.0};
    double radial_mps{0.0};
    std::uint32_t sequence_index{0};
};
```

`time_s` is the ignition instant, not KSP's impulsive half-burn-before
convention — the finite burn starts there, because nothing downstream models
a burn as instantaneous. The three scalars compose into an inertial vector
fresh on every call:

```cpp
coords::Vec3f64 node_delta_v(const ManeuverNode& node, const TnbBasis& basis) noexcept {
    return basis.t_hat * node.prograde_mps
         + basis.b_hat * node.normal_mps
         + basis.r_out_hat * node.radial_mps;
}
```

Nothing about a burn is ever cached. Recompute a node's frame from a later
epoch estimate, or move the node itself, and the very next call to
`node_delta_v` reflects it — there's no stale-vector state to invalidate,
because there's no stored vector.

## Picking a point on the drawn curve

Placement itself resolves through `pick_nearest_segment`, which knows nothing
about orbits. It takes a screen-space polyline and a click point, both in
pixels, and returns the nearest segment and where along it:

```cpp
struct PickResult {
    bool hit{false};
    std::size_t segment_index{0};
    float t{0.0f};
};

[[nodiscard]] PickResult pick_nearest_segment(std::span<const ScreenPx> polyline_px,
                                              ScreenPx click_px,
                                              float pick_radius_px) noexcept;
```

The algorithm is the standard clamped-projection point-to-segment form
(Ericson, *Real-Time Collision Detection* §5.1.2): for each segment `a→b`,
`t = clamp(dot(click−a, b−a) / |b−a|², 0, 1)`, distances compared squared so
no per-segment square root runs. The pick radius (12 px) is inclusive; ties
resolve to the lowest segment index so a symmetric click can't flicker
between frames; a zero-length segment is treated as a point instead of
dividing by zero; and any non-finite vertex fails the whole call rather than
letting a garbage index survive a NaN comparison by accident.

The function returns `(segment_index, t)` and nothing else — no true anomaly,
no eccentricity, no orbital vocabulary anywhere in the header or source. That
was deliberate: the orbit polyline this phase picks against is an interim
256-sample two-body conic, and the real predicted trajectory that will
eventually replace it is a different shape of curve entirely. Because the
picking kernel only hands back an index and a fraction, swapping the curve
underneath it later is a change to the caller, not to this file.

The caller — not the picker — turns `(segment_index, t)` into a time. The
sampled curve is parametrised by true anomaly at
`ν_i = 2π·i / 256`, so a pick interpolates linearly to
`ν* = 2π·(segment_index + t) / 256` and then asks a dedicated kernel how long
it takes to fly there.

## From a true anomaly to an epoch

`elapsed_time_between_anomalies_s` is new: nothing in the engine needed a
true-anomaly-to-time conversion before a node had to be placed on a specific
future point of an orbit. It goes true anomaly → eccentric anomaly → mean
anomaly, all through the engine's existing libm-free trig primitives, and
returns the forward flight time in `[0, period)` — a request that crosses
periapsis wraps rather than going negative, because a node is always placed
ahead of the craft on its own orbit, never behind it:

```cpp
double n = kDetTwoPi / elem.period;
return wrap_two_pi(mean_anomaly(nu_to) - mean_anomaly(nu_from)) / n;
```

The eccentric anomaly gets normalized into `[0, 2π)` before Kepler's equation
runs, because the underlying `atan2` returns values in `(−π, π]`: without the
normalization, a sample landing a hair on either side of apoapsis would come
back as `−π` on one call and `+π` on the next, flipping the elapsed time by a
whole period.

Apsis symmetry pins the kernel independently of any circular fixture, where
true anomaly happens to sweep uniformly and would hide a linear-interpolation
bug wearing a Kepler-shaped disguise:

```cpp
TEST_CASE("maneuver_node: anomaly-to-time honours apsis symmetry on an "
          "eccentric orbit") {
    const KeplerElements elem = elliptic_elements(0.5, 1.0, 1.0);

    // Periapsis to apoapsis is exactly half a period, whatever the eccentricity.
    require_close(elapsed_time_between_anomalies_s(elem, 0.0, kPi),
                  elem.period / 2.0, 1e-12);

    const double up = elapsed_time_between_anomalies_s(elem, kPi / 2.0, 3.0 * kPi / 2.0);
    const double down = elapsed_time_between_anomalies_s(elem, 3.0 * kPi / 2.0, kPi / 2.0);

    REQUIRE(down > 0.0);
    REQUIRE(down < elem.period);
    require_close(down, elem.period - up, 1e-12);
    REQUIRE(down < up);  // apoapsis sits on the slow arc
}
```

The two complementary arcs around an eccentric orbit have to sum to exactly
one period, and the periapsis-crossing arc — the fast one — has to come out
shorter than its complement. A later placement test on a live e = 0.44
fixture (launch from periapsis at 1.2× circular speed) drives the same point
home end to end: a quarter turn of *true anomaly* on that orbit takes about
0.1145 of a period, not the 0.25 a naive linear-in-index guess would produce.
The domain is bound-elliptic only — the same domain the existing conic
sampler accepts — so a hyperbolic or parabolic element set returns NaN rather
than a number nobody drew a curve for.

## The burn estimate

`estimate_burn` inverts the engine's existing thrust kernel instead of
restating the rocket equation. Given a Δv and the craft's current mass and
thrust properties:

```cpp
struct BurnEstimate {
    double dv_mag_mps{0.0};
    double burn_time_s{0.0};
    double dv_available_mps{0.0};
    bool over_budget{false};
};
```

```cpp
const double m1 = craft_mass_kg * det_exp(-out.dv_mag_mps / props.v_e_mps);
const double fuel_needed_kg = craft_mass_kg - m1;
out.burn_time_s = fuel_needed_kg / mdot_max_kg_s(props);
out.dv_available_mps = dv_remaining_mps(props, craft_mass_kg);
out.over_budget = out.dv_mag_mps > out.dv_available_mps;
```

`det_exp` is the exact inverse of the `det_log` the flight thrust kernel's own
analytic log-kick already uses, so this estimate and the burn the craft
actually flies are the same arithmetic read in opposite directions — a
one-step burn of `burn_time_s` at full throttle returns the requested `|Δv|`
almost to the bit, pinned by a round-trip test against the flight kernel
itself.

`dv_available_mps` is the interesting line. The engine already had a
remaining-Δv figure on the flight HUD — `craft_dv_remaining_mps`, three lines
of `v_e · det_log(m/m_dry)` living in the HUD source file. Writing a second
copy of that formula for the node's over-budget check would have been a
second, independently-maintained definition of "how much Δv is left,"
identical today and free to drift the moment either copy got a guard tweaked
without the other. Instead the body moved: `physics::dv_remaining_mps` is now
the one definition, and `craft_dv_remaining_mps` is a one-line delegation to
it. A grep gate — searching `engine/src/` for the wet/dry `det_log(m_kg …)`
expression — has exactly one hit after the move, and every pre-existing HUD
test kept passing unmodified, which is the proof the delegation didn't change
what the flight HUD displays.

Over budget is flagged, never clamped:

```cpp
TEST_CASE("maneuver_node: an over-budget burn is flagged and never clamped") {
    const ThrustProps props = burn_props();
    const BurnEstimate est = estimate_burn(Vec3f64{0.0, 4000.0, 0.0}, props,
                                           kBurnCraftMassKg);

    REQUIRE(est.over_budget);
    require_close(est.dv_mag_mps, 4000.0, 4000.0 * kBurnRelTol);
    REQUIRE(est.dv_mag_mps > est.dv_available_mps);

    const double m1 = kBurnCraftMassKg * std::exp(-4000.0 / 3000.0);
    const double fuel_needed = kBurnCraftMassKg - m1;
    REQUIRE(fuel_needed > 1000.0);  // more fuel than the tank holds
    require_close(est.burn_time_s, fuel_needed / 10.0, (fuel_needed / 10.0) * kBurnRelTol);
}
```

A node the tank can't afford still reports its honest magnitude and its
honest — if physically unreachable — full-throttle duration. Clamping either
one would hide exactly the information the flag exists to surface. A
companion pair of tests pins the comparison at the boundary itself: a burn
spending precisely the remaining budget is not flagged, and one representable
double above it is — the `>` in `over_budget = dv_mag_mps > dv_available_mps`
is exact, not an approximation with slack on either side.

## Assembling it: `ManeuverPlanner`

`ManeuverPlanner` is the main-thread class that owns the node list and wires
the four kernels above into something exercisable end to end. It touches the
physics worker exactly once, through a read of the published snapshot. An
unarmed node is speculative player intent rather than a command, so it never
crosses into the worker this milestone. It also doesn't reach into the scene
renderer's cached copy of the predicted curve; instead it regenerates its own
256-sample conic from the snapshot on every refresh, using the same public
sampling function the renderer calls. A second O(256) pass is negligible
against a new coupling surface between two classes that have no reason to
share a curve.

Placement composes the whole chain: resolve the click through
`pick_nearest_segment`, interpolate a true anomaly from `(segment_index, t)`,
convert that to elapsed time through `elapsed_time_between_anomalies_s`, add
the frame clock, and store the result as `ManeuverNode::time_s`. The readout
draws the story together most directly:

```cpp
TEST_CASE("maneuver_planner: the readout derives the burn from the future frame") {
    ManeuverPlanner p = fresh_planner();
    p.refresh(circular_snapshot());
    REQUIRE(place_pick(p, quarter_turn_pick()));
    REQUIRE(p.set_node_dv(100.0, 0.0, 0.0));

    const NodeReadout r = readout_at_quarter_turn(p);

    // The craft's CURRENT velocity is +y; a quarter turn later it is -x. A
    // prograde burn at the node therefore points along -x.
    require_rel_close(r.dv_inertial_mps.x, -100.0, 1.0e-13);
    require_rel_close(r.dv_mag_mps, 100.0, 1.0e-14);
    REQUIRE(r.time_until_ignition_s == p.node().time_s - kSimTimeS);
}
```

A prograde command at a node a quarter orbit ahead of the craft points along
an axis the craft isn't even facing yet — that single assertion is what
proves the basis really comes from the *predicted* state at the node's own
epoch rather than the craft's current one, which was the whole point of
deriving the frame per-node instead of once per frame.

Deletion is a container operation — `clear_node()` erases the (at most one,
this milestone) stored node — and placing again replaces rather than
appends, since the UI this phase supports drives exactly one node at a time
even though the underlying store is a `std::vector` for a later multi-node
UI to grow into without a data-model change.

## Where it is now

The kernels and the planner above are unchanged in shape, but a later
hardening pass this milestone reached two places directly relevant to
placement.

**Epoch snapping.** The trajectory-prediction machinery that eventually
replaced the interim two-body conic runs on a fixed substep grid, and a node
epoch that didn't land exactly on that grid was an ignition-timing error the
player had no way to see: the drawn burn would start at the node's literal
epoch while the flown burn started at whatever grid boundary the scheduler
rounded to. `set_craft_source` now takes a `prediction_quantum_s` alongside
the craft slot and thrust properties, and `place_node` snaps the resolved
ignition time onto that grid by integer-truncating the number of quanta
between the frame clock and the raw epoch, then reconstructing the snapped
time from the truncated integer rather than rounding the floating-point time
directly. A quantum that isn't finite and positive leaves the planner inert
rather than placing an unsnapped node silently.

**A screen-space entry contract.** `place_node(const PickResult&)` — the
function described above — is no longer public. In its place are two named
entry points: `place_node_from_screen`, which takes a polyline, a click
point, and a radius and resolves the pick internally in one call, and
`place_node_at_sample`, which places directly at one of the planner's own
sampled points for the scripted demo seed that needs a node with no click and
no camera behind it. Both funnel into the same private placement ladder, so
neither can drift out of step with its guards, but a bare `PickResult` built
by a caller with no link to which polyline it was resolved against is no
longer an accepted input at all.

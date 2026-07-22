# M0.3 Phase 15 — Validation: Technical Deep-Dive

> Retroactive technical devlog. **Proof phase of M0.3 Basic
> Orbit** — the tests that turned "the engine produces correct two-body
> orbits" into a checkable claim. Code shown **as built on 2026-05-21**
> plus a fix-loop on 2026-06-04; phase closed 2026-06-04.

## Starting point

Phases 12–14 built the machinery — `evaluate_force`, Leapfrog KDK + Yoshida4
steppers, a physics worker thread — but none of it had been measured against
an external truth. Phase 15 owned the milestone's six validation
requirements: energy conservation, a Yoshida-vs-Leapfrog order regression,
JPL HORIZONS DE441 sanity, long-horizon stability, Kepler invariants, and a
human-verified visual check. The shared fixture is
the canonical orbit: circular Earth orbit at r = 7000 km,
`μ_Earth = 3.986004418e14 m³/s²` (Phase 12's IAU 2015 pin), `v₀ = √(μ/r) ≈
7546 m/s`, dt = 10 s, T ≈ 5828 s; 10⁵ steps ≈ 11.6 days ≈ 172 periods.

## What was built

### Energy conservation — calibrate, then lock

`test_energy_conservation.cpp` samples specific orbital energy
ε = v²/2 − μ/r at every full-step boundary — the KDK form synchronizes x and
v there; mid-step sampling would alias O(h²) into apparent drift — and
tracks the maximum relative energy drift |ΔE/E|. The
thresholds were not guessed: a calibration run measured the floors first,
bit-identical Debug and Release:

| Method | Measured \|ΔE/E\|_max | Locked threshold |
|---|---|---|
| Leapfrog (KDK) | 3.37564e-9 | 1e-6 |
| Yoshida4 | 1.08207e-13 | 1e-9 |

Yoshida4 sits at the float64 round-off floor: ~1 ULP per operation over 10⁵
steps accumulates to ~1e-10 absolute on ε ≈ −2.85e7 J/kg, i.e. ~1e-13
relative. The thresholds are tiered per method because
Leapfrog's (h/T)² floor cannot reach 1e-9 at dt = 10 s no matter how
correct the code is — a single gate would false-positive a correct
second-order integrator. The order-regression check is one assert on the
same data:

```cpp
REQUIRE(max_yoshida * 100.0 <= max_leapfrog);
```

The /100 floor targets a specific failure — a mis-composed Yoshida (a d₂
coefficient sign flip) silently degrades to second order and shows up only
as drift over many steps. Measured ratio: 31196, ~312× above the gate.

### Kepler elements and invariants

`extract_kepler_elements(State, mu)` in `physics_kepler.cpp` (166 lines) is
the Curtis/Vallado state-vector → elements algorithm: {a, e, i, Ω, ω, ν}
plus period, plane normal, periapsis direction, |h|; singular cases return
documented conventions (0 for undefined angles, +Inf period for e ≥ 1). The
same extractor feeds the demo's predicted conic.
`test_kepler_invariants.cpp` integrates 100 periods, samples every 100
steps, and bounds three invariants:

```cpp
constexpr double kSemiMajorRelBound = 1.0e-12;
constexpr double kEccentricityAbsBound = 5.0e-8;
constexpr double kAngMomRelBound = 1.0e-12;
```

Semi-major axis is an energy proxy (a = −μ/2ε), relative swing measured
~1.1e-13; |L| is conserved by a central force up to round-off, measured
~5e-15. Eccentricity gets a bound three orders looser because the
eccentricity vector `e = (v×h)/μ − r̂` subtracts two near-unit quantities
on a circular orbit — ULP accumulation floors at ~1.4e-8. Each bound sits
~3× above its measured floor.

### HORIZONS DE441 sanity and the redirect

This check was designed as Moon-around-Earth two-body. At execution time
that died on real physics: the Moon's geocentric J2000 state is not a
near-Keplerian solution — solar tidal acceleration on the Moon is
3.23e-5 m/s², 1.3% of Earth's pull at lunar distance, and pure two-body
integration drifts 28,000 km from DE441 in one day; the research assumption
(~m/day) was off by 4–5 orders of magnitude. The decision was amended
mid-phase: the check became Sun-Earth two-body in the heliocentric frame —
M0.2's `horizons_earth_j2000.hpp` IC plus DE441 samples at +1 day / +1 week
/ +1 month / +1 year, committed inline with the full query URL.

Calibration then measured 112.3 km drift at +1 day against an a-priori
estimate of <100 m — and the discrepancy itself validated the integrator.
The Moon pulls Earth around the Earth-Moon barycenter with amplitude ≈
384400 km × 0.0123/1.0123 ≈ 4671 km; a Kepler propagation from an IC
containing the wobble diverges from DE441 by Δr ≈ A(1 − cos(2πt/T_moon)):
predicted 124 km at +1 day (measured 112, ~10%), 4858 km at +1 week
(measured 5159, ~6%); month and year samples are dominated by unmodeled
planetary perturbations. Every upstream math-lock stayed green throughout —
the drift was physics-model incompleteness, not numerical error. Bounds
locked at measured floor × 2, with the physics-model gap explicitly
documented rather than treated as a bug:

```cpp
.bound_km = 250.0,     // +1d:  floor 112 km × ~2
.bound_km = 10000.0,   // +1w:  floor 5159 km × ~2
.bound_km = 65000.0,   // +1mo: floor 31681 km × ~2
.bound_km = 1300000.0, // +1yr: floor 656623 km × ~2
```

Loose by ephemeris standards (1.3 Gm ≈ 1% of an AU), but each still catches
every plausible integrator bug: a force sign flip diverges within a day, a
dt typo scales error ~1000×, a μ_Earth-for-μ_Sun swap breaks the conic, a
Moon-IC swap shifts Earth by the full 4671 km wobble.

### Long-horizon stability

`test_long_horizon.cpp` (opt-in `[.long]` tag) runs 1000 periods
(~580k substeps) through the worker's synthetic-dt `tick()` hook with
time_scale = 1024 and wall_dt = 9.765625e-3 s — exact powers of two, so the
accumulator advances exactly one step per tick, deterministically. The
gate: a, e, |L| must stay inside the *same* bounds the Kepler-invariants
check declares for 100 periods — long-horizon must not slacken what
short-horizon pins.

### The orbit demo and its fix-loop

The visual half: Earth and Moon as flat-color SDF disks, a 2000-slot trail
ring buffer of actual integrator positions, a predicted conic regenerated
per frame from the live Kepler elements, and a font8x8 HUD showing T+,
period, and live |ΔE/E| — three new pipelines (disk/line/HUD) on M0.2's
push-constant plumbing, ICs from `horizons_earth_moon_j2000.hpp`, sim clock
at J2000. Trail and conic are the KSP-style pair:
secular drift would make the conic visibly rotate or open against the trail.

The 2026-05-23 check found three new-code bugs, fixed in-phase: the
trail rendered no pixels — insertion oversampled into 2000 sub-pixel
duplicates, fixed by gating on ~0.003 NDC of movement; two HUD
lines vanished from a per-frame buffer clobber, not missing glyphs;
`Snapshot.rel_energy_error` was never written — wired as (ε−ε₀)/|ε₀|. The
same check also flushed out two pieces of M0.1-era debt fixed in their own
phases: the swapchain acquire throw on compositor activity (Phase 14.5) and
missing aspect compensation in the orbit shaders (Phase 15.5). The visual
check passed 2026-06-04 at 118/118 tests: centered, aspect-stable, closed
conic.

## Why it was built this way

- **Calibrate-then-lock.** Every numeric gate — energy thresholds,
  invariant bounds, HORIZONS distances — was measured first, then locked at
  2–3× the observed floor. A bound derived from a measurement is
  falsifiable; a guessed tolerance is either vacuous or flaky. This became
  the house pattern for every later math-lock.
- **Per-method tiers, not one bar** — the gate catches regressions in a
  correct build, not fourth-order behavior from a second-order method.
- **Orthogonal invariants.** Energy drift catches non-symplectic error
  growth; the L/Y ratio catches order regressions; a, e, |L| bound
  different error directions (radial scale, shape, plane/torque); HORIZONS
  anchors it all externally — the only test able to catch a
  self-consistent wrong μ.
- **Redirect over fudge.** Widening the Moon-orbit bounds until it fit
  would have left the test unable to catch anything; the Sun-Earth
  redirect kept a real DE441 comparison with a documented physics budget.
- **A human-run visual check beside the asserts.** The bounds prove
  numbers; the demo proved integration — and the visual check, not the
  suite, surfaced five real defects (three Phase 15 bugs, two M0.1 debts).

## Where it is now (drift since 2026-06-04)

- **2026-06-04**: locked the extractor's
  inclined/eccentric/hyperbolic/singular cases the Kepler-invariants
  check's circular orbit never exercised; a later fix added an energy lock
  at the shipped Moon IC (e ≈ 0.69); another moved |L| tracking to every
  step boundary; another corrected the Leapfrog theory comment
  ((h/T)² ≈ 2.9e-6), lock untouched.
- **2026-06-08, M0.4 Phase 21**: a new case added a Sun-Earth-Moon
  three-body test asserting it beats the two-body drift — 5.7 km vs 112 km
  at +1 day, ~20× tighter — two-body anchor kept additively.
- **2026-06-09, M0.4 Phase 21.7**: the in-tree
  HORIZONS pattern scaled to Mars + Jupiter SSB states and a 5-body
  multi-epoch fixture.
- **2026-06-15, M0.5**: the suite re-anchored to the
  locked deterministic force kernel; the M0.5 review added acos-domain
  clamps to `physics_kepler.cpp`.
- **2026-07-09, M0.7 Phase 41**: full-seed multi-epoch DE441
  fixture for the nested-WH seeds; a follow-up fix re-pinned the geocentric
  Moon block from a BODY CENTER fetch.
- **2026-07-12, M0.8 Phase 46.1**: 14-body ×
  4-epoch DE441 ladder + all-planet barycenter fixture — `tests/data/` now
  holds 13 HORIZONS headers on this phase's query-URL-provenance format.
- **The original locks are unmoved as of 2026-07-21**: the 1e-6/1e-9
  energy thresholds, the 1e-12/5e-8/1e-12 invariant bounds, and all four
  HORIZONS floor-×-2 distances are byte-identical to their 2026-05-21
  values.

# M0.4 Phase 21 — Multi-Body Enablement + Validation: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-08**; the
> drift section traces the seed and the energy scalar through today's
> 14-body live system.

## Starting point

Phases 18–20 built every piece of multi-body machinery without turning it
on: the N-capable SoA snapshot (P18), the direct O(N²) mutual force with a
`BodyProps` table and whole-vector `bound_accel_fn` dispatch (P19), and
Hill-radius close-encounter detection with the IAS15 fallback (P20).
Production still integrated one body — the worker hardcoded `active = 1`
against a fixed central μ. The second gravitating body was gated on all
three landing; on 2026-06-08 the gate released. Phase 21 is the flip plus
the proof: a live Sun-Earth-Moon system, a genuinely stiff bound encounter
for the IAS15 fallback, regression against JPL DE441 and a
restricted-three-body invariant, and the cross-platform physical-tolerance
designation, all committed 2026-06-08. The reference decision
(2026-06-08): validate against **in-tree HORIZONS DE441 data** committed
as `.hpp` headers plus a Jacobi-constant invariant — REBOUND as a live
dependency was rejected for the build/CI surface it adds on both
load-bearing lanes for a reference that committed data provides
reproducibly.

## What was built

### `state_` → `states_` vector promotion

The worker stored one `State state_` and built spans as
`std::span<State>{&state_, active}` — sound at `active == 1`, undefined
behavior the moment a second body raises the count, because `&state_`
addresses exactly one element. The fix promoted the member to
`std::vector<State> states_` and repointed all 8 span sites, with `active`
still pinned at 1 — no enablement in the same change as the structural
promotion. The gate: the full locked suite green with zero tolerance
change (208/208 Release), plus a new N=1 bit-identity regression — a
parked worker driven through a fixed 100-substep `tick()` sequence must
land on bit-exact doubles, compared as hex-float `==` so no decimal
round-trip can hide a ULP.

### Enablement: Config seed, DE441 data, live Sun-Earth-Moon

The committed reference data covered SSB Earth and Moon but not the Sun;
a follow-up commit added `tests/data/horizons_sun_ssb_j2000.hpp` (HORIZONS
`COMMAND='10' CENTER='@0'`, ICRF, TDB, J2000, DE441, with fetch date, exact
query URL, and raw CSV in the provenance block) plus `M_SUN`/`M_EARTH`/
`M_MOON` in `constants.hpp` — all three bodies in one solar-system-barycenter
(SSB) inertial frame, a self-consistent three-body initial condition.

Another commit added two additive vectors to the worker `Config` —
`initial_states` and `body_props`, default-empty — and lifted the hardcode:

```cpp
const std::size_t active =
    config_.body_props.empty() ? 1 : config_.body_props.size();
```

Empty vectors fall back to the single-body test-particle path, which is how
every M0.3/P19/P20 locked test keeps running `mu_central = MU_EARTH`
unchanged; the live config supplies three gravitating `BodyProps` rows and
sets `mu_central = 0` — pure mutual i<j gravity. That resolves the P19
scaffold question: the fixed central-μ source is **permanent, as a config
mode, not the production default** — removing it would break the N=1
math-lock, and it forward-serves the deferred massless-craft tier.

A further commit made it visible: `main.cpp` seeds Sun/Earth/Moon at
dt = 300 s; `orbit_demo.cpp` loops `[0, snap.count)` drawing a per-body
disk at its camera-relative position, trail following Earth. The two-body
predicted conic survives only in the single-body fallback — an osculating
conic is not a trajectory prediction in a three-body field. Visual testing
at implementation close surfaced "only 2 bodies visible" (the Moon
overlaps Earth at 1 AU zoom) and a garbled HUD, and the 2026-06-09
resolution reframed game-quality visualization as `interstellar-game`
scope — the bar (≥2 bodies integrated, trajectories rendered) was met by
the 3-body integration plus the Earth trail.

### The stiff deep-bound plunge

Phase 20's encounter energy gate used a fast flyby with a deliberately
loose 1e-9 bound — a bound high-eccentricity orbit between two
planet-mass bodies has a ~7.7M-step half-period, intractable for a unit
test. The fix is mass asymmetry: an Earth-mass primary with a Moon-mass
secondary at e = 0.998, a = 5.4911e8 m, gives a full period of 33,540
steps with a pericenter whose dynamical time is 360 s — exactly 3× the
120 s fixed step, so Yoshida4 under-resolves every plunge. A Sun-mass body
sits 30 AU away because `detect_regime` excludes the most-massive body
from its pair loop; the far dominant contributes ~2% of the binary's
internal force at apocenter but sets the Hill radius that keeps the whole
orbit in the ENCOUNTER regime.

Both arms integrate the same seed. Fixed-step Yoshida4 forced through the
plunge bleeds max|ΔE/E| = 0.2076 — a 21% energy error in one orbit; the real
selector hands the window to IAS15, which holds 9.73e-14, a 2.13e12× gap.
The lock: `kEnergyBound = 1e-11` (measured floor + ~2 orders headroom),
tighter than the flyby's 1e-9, with a `kBleedFloor = 1e-6` assertion on the
contrast arm so the gate cannot pass vacuously on a scenario that stopped
being stiff.

### DE441 tightening + Jacobi invariant

The M0.3 two-body test integrates Sun-Earth and attributes its DE441
drift — 112 km at +1 day, 5159 km at +1 week — to the missing Moon: the
real Earth orbits the Earth-Moon barycenter, and a model without the Moon
cannot reproduce that wobble in Earth's heliocentric position. A new test
integrates all three bodies from the SSB initial condition and extracts
Earth heliocentric as `r_earth_ssb − r_sun_ssb`, compared against the same
DE441 samples. The drift collapses to 5.7 km at +1 day (~20×) and 281 km
at +1 week (~18×); bounds locked at 12 km / 560 km (measured × ~2) — and
the calibrate-then-lock discipline caught its own shortcut mid-run when a
placeholder 220 km bound sat below the measured 280.6 km and failed until
re-measured.

A second test adds the structural cross-check. Energy conservation is a
weak diagnostic for symplectic integrators — secular frequencies corrupt
before energy does (Rein & Tamayo 2019). In the circular restricted
three-body problem (two primaries on circular orbits about their
barycenter plus a massless particle) the particle conserves neither
energy nor angular momentum individually; the one exact integral is the
Jacobi constant, in dimensional inertial form:

```
C_J = 2(μ_sun/d1 + μ_earth/d2) + n²ρ² − |v_inertial − n·ẑ×r|²
```

The velocity must be transformed into the rotating frame before squaring.
The gate is verify-flat-then-lock: C_J measured flat to 3.13e-15 over a
40-day integration, and a one-off probe with the `−Ω×r` term dropped drifts
at 3.72e-2 — 13 orders worse — proving the 1e-9 verify gate rejects the
plausible-wrong formula. Conservation locked at 1e-14, with cross-platform
float64 headroom folded in.

### Cross-platform tolerance + exit gate

This closing pass establishes physical tolerance, not bit-identity —
bit-identity is a same-binary guarantee, closed in P19; cross-platform
bit-identity would need FMA/libm/FTZ-DAZ pinning that M0.4 does not claim.
The three-body and two-body DE441 cases are asserted independently on
each CI lane (Fedora/GCC, Windows/MSVC) against the committed reference,
and green on both lanes is the cross-platform guarantee — no cross-lane
artifact diff exists. The phase closed 215/215 Release, 215/215 Debug,
TSan suppression-scoped gate green with zero un-suppressed warnings.

## Why it was built this way

- **The structural promotion shipped one wave before the enablement** so the
  span-UB fix could be gated on N=1 bit-identity in isolation; a combined
  refactor-plus-enable diff cannot attribute a changed trajectory.
- **Two independent validation axes**: DE441 measures fidelity to the real
  solar system; the Jacobi constant measures internal dynamical consistency
  on an idealized system where an exact integral exists. Ephemeris error
  cannot hide integrator error, and vice versa.
- **Every new tolerance is calibrate-then-lock** — M0.3's two-body DE441
  test showed a-priori bounds run 4–5 orders optimistic.

## Where it is now (drift since 2026-06-08)

- **2026-06-10, M0.4 gate:** a fix made the worker's `system_energy`
  mass-coherent for multi-body — the HUD ΔE/E scalar had been a
  specific-energy N=1 holdover — and another change rejects a
  central-field multi-body `Config` at the ctor (the two config modes may
  coexist, not mix). A further fix sources `props.mu` from published GMs.
  The three-body DE441 12/560 km locks and the Jacobi 1e-14 lock survived
  unmoved.
- **2026-06-09, Phase 21.7**: the seed grew to five bodies (Mars + Jupiter
  barycenters), with 100-year stability, period, and multi-epoch DE441 gates.
- **M0.6:** a Sun/EMB/Mars/Jupiter Wisdom-Holman warp worker joined the
  Yoshida4 seed; **M0.7:** the full HJS nested seed became the rendered
  worker.
- **2026-07-12, M0.8 Phase 46:** the live seed reached the full planetary
  set — 14 bodies, J2 + 1PN on — validated against a 14-body × 4-epoch
  DE441 ladder. The additive `Config` seed seam is still how every body
  enters the system.

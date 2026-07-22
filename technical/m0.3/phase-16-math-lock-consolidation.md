# M0.3 Phase 16 — Math-Lock Consolidation: Technical Deep-Dive

> Retroactive technical devlog. **Seventh phase of M0.3 Basic
> Orbit** — the last code phase before Phase 17's review. Code shown
> **as built on 2026-06-04**; the drift section traces the suite through
> the same-day strengthening and five subsequent milestones. In-tree lock
> contract: `tests/unit/integrator/README.md`.

## Starting point

Phases 12–15 left `tests/unit/integrator/` full of representative-point
tests: bit-exact constant pins, single-step references, energy conservation
on one canonical orbit, HORIZONS DE441 sanity, Kepler invariants along one
trajectory. Every one pins a specific sample — exactly the kind of gap
where a refactor can change observable math at untested magnitudes while
every point test stays green. M0.2 had closed this gap for coordinates
with a 10k-sample property suite; M0.3 needed the same before Phase 17
could lock the milestone.

Two inherited debts shaped the phase: M0.2's cross-compiler PCG determinism
existed only as a comment — required but nothing asserted it — and Catch2
v3.0.1 had removed the `[!hide]` tag, so any test written with it would
silently *run* instead of hiding.

## What was built

### Shared PCG + bitstream pin

`Pcg64` and `SeededRng` moved verbatim from M0.2's
`test_property_roundtrips.cpp` to `tests/unit/test_helpers/pcg.hpp`, so
both milestones' locks draw from one generator. Hand-rolled PCG-XSL-RR-64
rather than `<random>`: `std::uniform_int_distribution` and
`std::mt19937_64` are deterministic per seed but implementation-defined
across stdlibs — a pinned seed would bind only whichever toolchain it was
last green on.

`test_pcg_determinism.cpp` then pins the first 32 outputs of
`Pcg64{0x5e3dec0deULL}` as a bit-exact reference vector, generated at both
`-O0` and `-O3` (g++ 16.1.1, byte-identical). It deliberately pins the
ctor-advance quirk — the constructor calls `next()` once before the first
observable output — so a swap to a textbook PCG fails this one test with a
clear message instead of failing 10,000 orbits with confusing wrong-invariant
errors downstream.

### The property suite

`test_property_orbits.cpp`: 10,000 random Kepler orbits per invariant per
method, seeded at `0x4071710d3` — a fresh offset from M0.2's seed so the
two locks draw independent streams. The grid: `e ∈ [0.01, 0.5]` for
energy/LRL (`0.9` for angular momentum), `a ∈ [6.6e6, 4.2e7]` m log-uniform
with a `r_peri ≥ R_Earth + 200 km` rejection guard, `ν ∈ [0, 2π]`, ~50%
retrograde. Each orbit runs one full period at `dt = T/1000` under both
Leapfrog and Yoshida4 via `TEMPLATE_TEST_CASE`.

Calibrating the suite found two real bugs in its own orbit generator. The
scaffold built velocity as `vis_viva_magnitude × normalize(-sinν, e+cosν)`,
which destroys the radial/transverse split — the extracted eccentricity
jumped to 1.0 for an input `e` of 0.28. The fix uses the perifocal velocity
directly (Vallado Eq. 2-115):

```cpp
// v = (μ/h) · (−sin ν, e + cos ν, 0),   h = √(μ·a·(1−e²))
// NOTE: this vector's magnitude already equals vis-viva — do NOT
// normalize then re-scale by √(μ(2/r−1/a)); keep the (μ/h)·(…) form.
```

The second: flipping only `v.y` does not produce a retrograde orbit — it
collapses `L_z` (7.0e10 → −6e8) into a near-radial one. Retrograde is an
x-axis reflection — negate **both** `r.y` and `v.y` — which reverses `L_z`
while preserving `e` and `a` exactly.

Four invariants, each locked at `max(theory, 2 × worst_observed)` with the
full triple pinned next to the constant:

```cpp
// theory=1e-7 · worst_observed=3.25e-08 · locked=1e-07   (e ≤ 0.5)
constexpr double kEnergyBoundYoshida = 1.0e-7;
// theory=1e-5 · worst_observed=1.07e-04 · locked=3e-04   (e ≤ 0.5) [Rule #7]
constexpr double kEnergyBoundLeapfrog = 3.0e-4;
// theory=1e-12 · worst_observed=1.77e-14 · locked=1e-12  (e ≤ 0.9)
constexpr double kAngMomBound = 1.0e-12;
```

plus LRL magnitude and direction (the direction check — LRL points at
periapsis — is the early-warning signal for phase mismatch that magnitude
alone misses). Every `REQUIRE` carries seed, orbit index, initial state, and
retrograde flag in `INFO()`: one failing orbit reproduces without re-running
the grid.

### `[.long]` tripwires

`test_property_orbits_long.cpp`: a high-eccentricity block at
`e ∈ [0.9, 0.99]`, `dt = T/10000`, locked at |ΔE/E| < 6.0 — fixed-step
symplectic error at near-parabolic e is genuinely O(1); the loose bound
trips on *divergence*, not drift — and a dt-sweep randomizing
`dt ∈ [T/2000, T/500]` per orbit to catch dt-dependent regressions. Both
hidden behind `[.long]`, with an explicit
`add_test(NAME long_property_suite …)` because `catch_discover_tests` does
not register `[.]`-hidden tests — without it, `ctest -L long` matched nothing.

### Tag-policy lock + contract README

`test_tag_policy.cpp` walks Catch2's registry via
`getRegistryHub().getTestCaseRegistry().getAllInfos()` and machine-checks
that no `[integrator]` test carries the dead `[!hide]` tag, every
`[.long]` test pairs with a reason tag, and every `[integrator][property]`
test carries `[math-lock]`. `tests/unit/integrator/README.md` states
the lock contract in-tree: additive changes always fine; removals,
weakened tolerances, or relaxed grids require reviewer sign-off.

## Why it was built this way

- **What the property suite catches that point tests cannot**: a point test
  pins `f(x₀)`; the property suite asserts an invariant over 10k random
  draws of the whole orbit domain, so a refactor that shifts magnitudes
  *between* the sampled points has nowhere to hide. The sensitivity check is
  concrete: a sign-flipped Yoshida coefficient drives ≥1e-2 energy drift
  against a 1e-7 bound.
- **Calibrated, not guessed**: `max(theory, 2×worst_observed)` makes every
  bound evidence-backed; the in-file triples show which bounds are
  theory-tight and which sit further above theory. The Leapfrog bounds sit
  1–2.5 OOM above the theory pin — genuine 2nd-order truncation at moderate
  e, surfaced in the file header rather than silently widened.
- **dt = T/1000, not the planned T/10**: ten steps per period diverges even
  on a circular orbit (9e-3 |ΔE/E| against a ~1e-13 floor). The e ≤ 0.5
  split follows the same measurement: at e ≈ 0.9 the under-resolved
  periapsis passage costs 2.8e-3 even at T/1000 (Rein & Tamayo 2015), so
  high-e energy lives in the tripwire with an honest bound.
- **Angular momentum stays on the full e ≤ 0.9 grid**:
  symplectic-on-central-force conserves L exactly regardless of e — the
  measured 1.77e-14 worst is the FP-noise floor; the 1e-12 lock is the
  suite's tightest tooth.
- **Sampling hygiene**: invariants sample at full-step boundaries only —
  KDK synchronizes r and v there; mid-substep sampling aliases O(h²) as
  drift — compared endpoint-to-endpoint with no running accumulation.

## Where it is now (drift since 2026-06-04)

- **Same day**: added every-step-boundary angular-momentum tracking
  (endpoint-only can miss a mid-orbit excursion); a follow-up fix pinned
  energy at the exact shipped Moon IC (e≈0.69 sat in the e∈[0.5,0.9) grid
  gap); another corrected the theory-pin prose (Leapfrog (h/T)² ≈ 2.9e-6;
  locked bounds ~2.5–2.8× over observed, not "~300×") and additively
  bit-pinned the Yoshida coefficients, recording the shipped `yoshida_w1`
  1 ULP below the cbrt form. Leapfrog locks kept, not tightened. M0.3
  merged 2026-06-05.
- **2026-06-04**: the `long_property_suite` aggregate runs in
  default ctest too (~1 s) — the tripwires turned out always-on; docs fixed
  to match the CMake wiring.
- **2026-06-05**: test names ASCII-fied for Windows ctest as the
  cross-platform CI landed.
- **2026-06-08, M0.4 Phase 19**: the integrator seam moved to a
  whole-vector `bound_accel_fn`; the suite lifted its central force through a
  per-call scratch wrapper, bit-identical for N=1.
- **2026-06-13**: the README became the combined M0.3/M0.4 lock
  contract with a lock-tier column per file — the same shape scaled to
  the next milestone unchanged.
- **Tag policy held for five milestones**: the `[.long]`-reason whitelist
  grew additively (2026-06-09, then the M0.8 validation suites), per its
  extend-the-list clause.
- **The calibrated bounds are untouched since 2026-06-04**; the suite is
  green through every milestone gate from M0.4 to M0.8 (2026-07-13), and
  `pcg.hpp` shows a single-commit history — the shared bitstream has never
  moved.

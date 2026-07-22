# M0.5 Phase 28 — Determinism + Math-Lock Consolidation: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-15**; the
> drift section traces the arm64 deferral through today's stack.

## Starting point

Phase 27.5 closed the same day: Wisdom-Holman's democratic-heliocentric
back-transform was fixed (the dominant body's barycentric state had been
frozen, drifting the barycenter), and Phase 27 characterized WH honestly —
correct, in-tree, auto-selectable, but not the shipped default (Yoshida4
ships; WH is the time-warp lever for large steps). Phase 28 consolidated
the determinism and math-lock work ahead of Phase 29: close the
cross-platform determinism contract, holistically re-verify same-binary
determinism over the full integrated path, and land the two remaining
conserved-quantity locks — energy + angular momentum through a real
WH↔IAS15 window and AMD + barycenter/momentum drift in regular WH runs.

The phase was scoped as overwhelmingly additive lock reuse, not new
machinery: the energy/L/AMD/barycenter oracles already lived in
`multibody_energy.hpp`, the cross-platform physical-tolerance mechanism
already existed, the byte-exact golden-vector pattern was already
established, and the run-twice A==B harness was `test_nbody_determinism.cpp`.
Design decisions were locked before any code, the load-bearing ones:
two-tier arm64 verification (frozen golden mandatory + optional native
runner), an in-binary IAS15-tiny-step reference for the WH↔IAS15 window
lock (no external dependency), add-only consolidation — no physical file
merge, and one full-path A==B test as the first point WH + Kepler + the
predictive trigger + test particles all coexist.

## What was built

### Energy + L through a real WH↔IAS15 window

`test_mlock04_hybrid_window.cpp` drives a pericenter geometry
(`impact_b = 0.5·R_Hill`, `rel_speed = 240133.8 m/s`) at `step_dt = 60 s`
over 1600 steps, worker-driven so the predictive trigger genuinely fires
WH(REGULAR)→IAS15(ENCOUNTER)→WH(REGULAR) mid-run (~step 755), gated on
`any_encounter && returned_to_regular`.

The calibration run first tried the WH-scaled coarse step (6e4 s), which
overshoots the 240 km/s flyby in a single step — the window only registers
at the run start and the energy offset looks monotone (`dec_frac = 0`), a
false "secular" reading. At 60 s the flyby resolves and the energy is a
genuine bounded random walk (`dec_frac ≈ 0.52`) — no secular slope across
the changeover. The lock is on the seam, not the warp magnitude:

- max|dE/E| measured **1.04e-8** (the WH eccentric symplectic floor
  dominates, not the seam) → locked **1e-7** (+1 order), also inside a
  100× multiple of an earlier 1e-9 baseline.
- max|dL/L| measured **~7e-13** → locked **1e-11** (+1 order).
- `dec_frac(energy)` measured **~0.52** → locked anti-monotone floor
  **0.05** — the load-bearing "no secular slope" assertion.
- An IAS15-tiny-step reference arm (20× sub-steps, same ICs) confirms the
  WH+hybrid final E/L sit within a locked **1e-6** envelope of the
  near-exact reference.

### AMD conservation + barycenter/momentum drift

`test_mlock05_amd_drift.cpp` runs production-shape star-dominated
eccentric/inclined COM-frame tables (Jupiter+Saturn-mass, 3-body) at
`dt = 1e5/8e4 s` for 200,000 steps (~507–634 yr), with the Sun as the
central body.

The load-bearing finding: the *instantaneous osculating* AMD is not an
exact constant — Laskar-Petit AMD is the secular (orbit-averaged) invariant.
Measured instantaneous oscillation is **~3.1%** for the Jupiter+Saturn-mass
pair over 634 yr, and it **scales down with perturbation strength**
(0.36% at 1/100 mass) — physical secular e/i exchange, not a transform
bias. The diagnostic for a biased transform is secular AMD *growth*
(log-log slope → 1); measured slope is **~-0.03**, a bounded oscillation,
the unbiased signature:

- AMD log-log (Brouwer) slope measured **~-0.03** → locked **< 0.5** (the
  biased-transform sentinel — the load-bearing assertion).
- max AMD relative oscillation measured **~3.1%** → locked **10%**
  (physical secular-exchange envelope).
- V_cm + total linear-momentum drift measured **~3e-17** → locked
  **1e-12** — confirming the Phase 27.5 back-transform fix holds under
  eccentric/inclined ICs, a wider domain than the circular/coplanar cases
  that had hidden the original bug.

No biased transform surfaced (slope bounded, COM at roundoff), so no
follow-up debt phase opened.

### Holistic full-path A==B

`test_det03_wh_hybrid_path.cpp` is worker-driven through the real
production path: WH regular regime + Kepler drift (inside `wh_step`) + the
predictive trigger firing a real WH↔IAS15 changeover + 4 massless test
particles (`n_active=3`, total=7), `step_dt=100 s`, `time_scale=2e3`, 300
ticks. Result: bit-identical same-binary (`==`, not `Approx`) across all 7
slots including the test particles, non-vacuous — regime switched, active
bodies and test particles moved, WH selected (Kepler in the loop).

TSan required parking both workers before driving either: an unparked
worker's free loop raced the driven worker's `tick()` on the test-only
`g_last_lagrange`/`g_last_solve` diagnostic globals (`#ifdef
INTERSTELLAR_TESTING` only, not a production race). Fixed same-phase.

### Frozen full-state golden table

`test_det04_cross_platform.cpp` + `tests/data/det04_golden_fullstate.hpp`
generalize the existing committed-reference-plus-in-binary-tolerance
pattern to full N-body state, plus the byte-exact golden pattern already
used for Kepler. Two scenarios: S1 = WH-regular Jupiter+Saturn
eccentric/inclined (20,000 steps); S2 = WH↔IAS15 hybrid flyby (700 steps,
encounter confirmed). Two-band: same-family lanes (GCC/Clang x86_64,
`+-*/` + FMA-off trajectory) assert byte-exact `to_bits ==`; every lane runs
the physical band `pos_err < phys_bound_m`.

The golden was captured from the locked binary (dev GCC Release) via a
hidden capture-mode test generator, then frozen by hand. Same-family
byte-exact reproduction was confirmed on the dev lane — no stray libm had
leaked onto the WH/trigger/test-particle trajectory (a grep gate over
`std::sin/cos/sqrt/cbrt/pow/fma` on those paths also confirmed clean).
Regenerating the table requires reviewer sign-off. `phys_bound_m`
is calibrate-then-locked at a generous physical **1 km** budget over the
~1e11 m orbit-scale checkpoint (the same reasoning `test_horizons_sanity.cpp`
established: `+-*/` ⇒ cross-family divergence is bounded by the `det_*`
Newton primitives at ≤1 ULP, not an a-priori ULP guess).

### arm64 tier-2 — named deferral

An optional tier-2 (a native `ubuntu-24.04-arm64` GitHub-hosted
runner) was **not added**. Named blocker: the repo is private and the org
(`spoods-studios`) is on the GitHub free plan — Linux arm64 runners for a
private repo require a paid larger-runner tier (or a public repo), and the
runner-availability API needs `admin:org` scope not held here. Tier-1 (the
frozen golden table) satisfies the cross-platform requirement on its own;
the golden is forward-compatible, so a future arm64 lane runs
`det04_golden_fullstate.hpp` unchanged. `.github/workflows/ci.yml` was left
untouched; the deferral and a per-phase lock navigation map were recorded
alongside the integrator test suite.

## Why it was built this way

- **Calibrate-then-lock, always.** Every band (the golden table's physical
  bound, the WH↔IAS15 window's energy/L envelopes, the AMD-drift roundoff
  bands) was set from a measured value plus a documented margin — never an
  a-priori guess. The 6e4 s vs 60 s miscalibration in the window lock is
  the concrete example: the wrong step size produced a false-secular
  reading that a looser a-priori bound would have silently absorbed.
- **Consolidation is verification, not a merge.** "Consolidate"
  meant proving every prior lock plus the four new Phase-28 locks are
  green *together* — not physically relocating any test file.
- **A named deferral, not a silent gap.** The arm64 lane has a concrete
  structural blocker (org billing tier) and a forward-compatible fallback
  (the golden table works unchanged once a lane exists) — a legal
  deferral rather than an open-ended weakness.

## Where it is now (drift since 2026-06-15)

- **2026-06-16, Phase 29**: all four Phase-28 locks stayed green through
  the review; its Critical (WH silent-NaN) and Highs were fixed
  without touching any Phase-28 golden or envelope —
  `nbody_force.cpp` stayed byte-unchanged. The Kepler iteration raise
  (8→12) was verified byte-identical for every converged input against the
  Phase-28 goldens before landing.
- **2026-06-24, decision record**: the arm64 named deferral was
  re-affirmed during M0.6 backlog reconciliation — still no arm64 CI
  lane/runner exists; future home stays the M1.x cross-platform/
  portability pass.
- **M0.6–M0.8**: the calibrate-then-lock + additive-consolidation pattern
  this phase established is the standing template every subsequent
  milestone's math-lock work follows.

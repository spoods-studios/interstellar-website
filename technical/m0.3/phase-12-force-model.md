# M0.3 Phase 12 — Force Model: Technical Deep-Dive

> Retroactive technical devlog. **Opening phase of M0.3 Basic
> Orbit** — the engine's first physics milestone. Code shown **as built on
> 2026-05-21**; a drift section traces the kernel's descendants to today's
> locked `nbody_force.cpp`.

## Starting point

M0.2 closed on 2026-04-25 with a coordinate stack and zero physics: int64 mm
storage, float64 relative math, float32 rendering, all math-locked. M0.3 put
the first real physics on top of it — two-body Kepler orbits via a symplectic
integrator, validated against JPL HORIZONS. Phase 12 is the milestone's first
phase; the integrator, threading, and validation phases all call what it
builds.

One pitfall from the orbital-mechanics study that predates the phase
became its central lock: compute `r³ = r² · sqrt(r²)`, never `pow(r,3)`.

## What was built

### Constants header

`engine/include/interstellar/physics/constants.hpp`: an `inline constexpr
double` table under `namespace interstellar::physics`, each value with a
provenance comment citing source authority and year.

```cpp
// μ_Earth — IAU 2015 nominal / Ries 1992.
// 3.986004418e14 m³/s² — the value HORIZONS returns by default;
// 8-digit agreement with JPL DE440's 3.986004355507e14. Primary integrator
// constant for M0.3 (D-07a).
//
// Caveat: this is GM_Earth alone — Moon NOT included. M0.4 must decide
// whether to switch to Earth-Moon barycenter μ (12-RESEARCH hazard H6).
inline constexpr double MU_EARTH = 3.986004418e14;
```

Seven pins: `G = 6.67430e-11` (CODATA), `R_EARTH_EQUATORIAL = 6378137.0`
(WGS84), `R_EARTH_MEAN`, `G0_STANDARD = 9.80665` (CGPM 1901), `MU_EARTH`
(above), `MU_EARTH_DE441 = 3.98600435436e14` (for Phase 15's HORIZONS
regression only), `MU_SUN = 1.32712440041e20` (JPL DE440/DE441).

The header stores gravitational parameters μ = GM directly, never composes
them from G × M. G's relative uncertainty is 2.2e-5 — the worst-measured
fundamental constant — while the published μ products are known to 9–11
digits from ephemeris fits; a G·M composition would throw away four orders
of magnitude of precision. G is in the header for documentation only. The
μ_Earth comment also records that the IAU nominal and the DE441 fit disagree
in the 7th digit — two published values from different fits, documented so a
future reviewer doesn't "fix" them to agree.

### Constants unit-check

`tests/unit/integrator/test_constants.cpp` asserts every pin against its
source literal with `REQUIRE(MU_EARTH == 3.986004418e14)`-style **bit-exact
equality**, not ULP-bounded matchers. The target failure class is
transcription typos — transposed digits, a dropped trailing zero — which an
ULP-bounded comparison would let slide. A SECTION checks the Earth-surface
closed-form `g = MU_EARTH / R_EARTH_EQUATORIAL² ≈ 9.79828 m/s²` and comments
why the target is not `g₀ = 9.80665`: the CGPM value is definitional, and
the ~0.001 m/s² gap is centrifugal plus non-spherical-Earth effects that a
point-mass model does not include.

### The kernel

`engine/include/interstellar/physics/force.hpp` declares one canonical
function; `engine/src/physics_force.cpp` implements it in 44 lines:

```cpp
coords::Vec3f64 evaluate_force(double mu, coords::Vec3f64 r_relative) {
    // r² = dot(d,d); r³ = r²·sqrt(r²) — NOT pow(r,3) (research pitfall #4,
    // CONTEXT D-09). The locked pattern is one FMA + one sqrt + one multiply;
    // pow goes through exp(1.5·log(r)) and compounds ULP error from two
    // transcendentals (12-RESEARCH § 1).
    const double r2 = r_relative.dot(r_relative);
```

then `inv_r3 = 1.0 / (r2 * std::sqrt(r2))` and `a = -mu * inv_r3 *
r_relative`. The contract, per the header doc-comment:

- **Returns acceleration in m/s², not force in N.** Mass is folded
  into μ, so the integrator works directly in (r, v, a) with no division by
  mass at the substep boundary.
- **Input is `r_relative` in float64 meters.** The int64-mm subtract
  happens upstream — M0.2's subtract-before-convert contract is
  preserved end-to-end; the kernel never touches int64.
- **Precondition `r² > 0`**, Debug-asserted only. Release relies on
  IEEE-754 `1/0 = +Inf` deterministic propagation; the integrator's
  per-substep `try_to_absolute` filter (Phase 13) catches
  the Inf at the substep boundary. Zero hot-path branches.
- **No Plummer softening, no acceleration saturation** — both bias
  energy, wrong for a Kepler-correctness milestone.

Two forward-scaffolds ride along: `using force_fn = Vec3f64
(*)(double, Vec3f64)` — a function-pointer alias, not `std::function`, at
~5 cycles/call vs 6+ plus 21-cycle construction and possible heap allocation
— and an 8-line `evaluate_pair_forces(mu_A, mu_B, r_AB)` wrapper returning
both accelerations of a pair via the kernel's odd symmetry.

### Force-kernel test suite

`tests/unit/integrator/test_force.cpp`, 264 lines, five asserting TEST_CASEs
plus a benchmark, all tagged `[math-lock]`:

1. **Earth-surface closed-form** — `evaluate_force(MU_EARTH,
   {R_EARTH_EQUATORIAL, 0, 0})` magnitude within `WithinRel(9.79828466,
   1e-7)`; anchors μ_Earth and the r³ pattern in one assertion.
2. **Inverse-square scaling** — `|a(r/2)| / |a(r)| == 4.0` to 1e-13, on a
   non-axis-aligned direction to catch axis-only special-casing.
3. **Odd symmetry** — `a(-r) == -a(r)` componentwise, bit-exact: r² is
   invariant under r → −r, so anything short of equality means the kernel
   added spurious arithmetic.
4. **Earth/Sun mass-ratio** — `a_earth_from_sun.x / a_sun_from_earth.x ≈
   -(MU_SUN / MU_EARTH)` to 1e-13, Newton's third law in acceleration form;
   a SECTION checks `evaluate_pair_forces` matches the free calls bit-exactly.
5. **r³ refactor lock** — recomputes the locked `r2 * sqrt(r2)` chain inline
   at a non-round input, first REQUIREs `r3_ref != r3_pow` (the two paths
   disagree there, so the lock has teeth), then REQUIREs the kernel matches
   the reference bit-exactly. A cleanup that swaps in `std::pow` fails hard.
6. **ULP-gap benchmark** (non-asserting) — INFO-prints the locked-vs-pow gap
   at four regimes for future libm-regression visibility.

### Wiring and verification

This wiring step appended `src/physics_force.cpp` to the engine library and
the two test files to the unit-test target, creating
`tests/unit/integrator/` alongside M0.2's `coordinates/`. A separate
verification commit confirmed the 73-test M0.2 math-lock baseline green
Debug and Release, plus 7 new TEST_CASEs — suite at 80.

## Why it was built this way

- **μ-only API**: two-body Kepler around a fixed primary is the whole M0.3
  case; the symmetric pair is derivable at the call site, and n-body
  iteration (M0.4) was scaffolded in API shape only — no machinery.
- **The r³ pattern is an accuracy gate as well as a speed win.** Phase 15's
  energy-conservation gate is `|ΔE/E| < 1e-9` over 10⁵ steps. At 10⁵ steps ×
  4 Yoshida substeps, a 1–3 ULP-per-call noise floor from `pow`'s
  `exp(1.5·log(r))` path lands near 1e-11 — close enough to compete with
  what the gate measures. `r2 * sqrt(r2)` is one FMA, one sqrt, one multiply;
  REBOUND's `src/gravity.c` uses the same form and never calls `pow`.
- **Bit-exact where the math demands it**: constants against their source
  literals, odd symmetry, the r³ reference chain. Tolerances appear only
  where a derivation produces them (1e-13 for ratio checks).
- **Release-mode r²==0 handling costs nothing** because IEEE-754 already
  defines the failure path: `+Inf` propagates deterministically into the
  integrator's NaN/Inf filter one seam downstream. Three layers — Debug
  assert, Inf propagation, `try_to_absolute` — zero hot-path branches.
- **Representative points now, properties later**: each closed-form value
  anchors a distinct invariant; the 10k-orbit property suites land in
  Phase 16 (`test_property_orbits.cpp`) where there are orbits to sample.

## Where it is now (drift since 2026-05-21)

The kernel files themselves have not moved: `physics_force.cpp`,
`force.hpp`, and `test_force.cpp` each show a single-commit history as of
2026-07-21. Everything around them grew.

- **2026-06-04**: the value pinned as
  `MU_EARTH_DE441` was the DE430/431-era figure; re-pinned to the
  true DE440/441 `3.98600435507e14` (Park 2021), and `MU_SUN` extended from
  the truncated `1.32712440041e20` to the full `1.32712440041279419e20`.
  The bit-exact pin test moved with it. M0.3 merged
  2026-06-05.
- **2026-06-08, M0.4 Phase 19**: the n-body direct-force module
  `nbody_force.cpp` (`compute_accelerations` over a body table) took over as
  the production force path. An N=1 bit-identity gate routes
  the central-μ term through the byte-identical `evaluate_force` expression,
  so a single-body run reproduces M0.3 bit-for-bit — the contract is still
  documented in `worker_thread.hpp` today.
- **2026-06-10**: re-pinned the n-body
  masses as `M = GM/G` **by construction** — the shipped `M_SUN` had been
  GM_Sun(DE441)/G(CODATA-1986), making effective GM_Sun 2.566e-4 too strong.
  Phase 12's "never compose μ from G·M" rule still holds for central and
  energy paths; for the n-body kernel's `G·M` products the arrow reverses,
  so G cancels to ≤1 ULP and the dynamics inherit full DE440 GM precision.
  A follow-up fix added the per-side gravitating gate.
- **2026-06-15, M0.5 Phase 26**: `nbody_force.cpp` became the
  locked deterministic kernel — byte-untouched since, apart from a
  sanctioned strong-type parameter refactor on 2026-06-24.
  Every physics phase through M1.1 re-asserts the kernel is still
  byte-untouched.
- **The constants header kept the Phase 12 format and quadrupled**: Moon,
  Mars-system, and Jupiter-system GMs, Galilean GMs
  (2026-07-09), the 5-planet outer-set pins
  (2026-07-12) — each with the same provenance-comment-plus-bit-exact-pin
  discipline. `engine/src/` now holds five `*_force.cpp` files (n-body,
  oblateness, 1PN, thrust, and the original `physics_force.cpp`), all on
  the API convention Phase 12 set: float64 in, acceleration in m/s² out.

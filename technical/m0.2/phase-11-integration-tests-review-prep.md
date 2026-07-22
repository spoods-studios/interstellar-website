# M0.2 Phase 11 — Integration Tests + Review Prep: Technical Deep-Dive

> Retroactive technical devlog. **Closing phase of M0.2** — the
> milestone's integration tests plus the materials prepared for review. Code
> shown **as built on 2026-04-23**; the drift section tracks what those
> materials produced once review ran.

## Starting point

After Phase 10.5 the suite stood at 49 Catch2 TEST_CASEs from Phases 7–9.
Four integration tests remained, plus the review-prep materials — a
review briefing, the math-lock rule, the HORIZONS reference data, and a
same-day code review. Phase 11 closed M0.2, the first milestone to run a
review.

The binding fence: tests and docs only — zero edits under
`engine/src/**` or `engine/include/interstellar/**`; a test needing a
missing API stops the phase and opens a tech-debt phase. 10 commits.

## What was built

### Precision boundaries at five distances

One TEST_CASE, 5 SECTIONs: 1 m, 1 km, 1 AU, 1 light-second, 600 AU. Every
tolerance is the IEEE 754 actual, derived as
`ULP(M) = 2^(floor(log2(M)) - mantissa_bits)`, so a reviewer can re-derive
each bound. The float32 subcases at AU-and-beyond magnitudes use a
camera-at-distance pattern — `to_camera_relative` Debug-asserts
`|delta| < 4 km`, so the test places the *camera* at 1 AU and the object 1 m
away; the float32 path only ever sees the small delta. The 600 AU SECTION
locks the range edge:

```cpp
SECTION("600 AU — subtract-first preserves 1 mm exactly at the range edge") {
    // 600 AU in mm ~ 8.98e16, WELL ABOVE 2^53 ~ 9.01e15. Naive
    // static_cast<double>(600AU_mm) rounds to the nearest 16-mm multiple.
    constexpr int64_t six_hundred_au_mm = int64_t{149'597'870'700'000} * 600;
    const Vec3i64 far_origin{six_hundred_au_mm, 0, 0};
    const Vec3i64 near_pos{six_hundred_au_mm + 1, 0, 0};  // +1 mm beyond origin

    auto f64_delta = to_relative(near_pos, far_origin);
    REQUIRE_THAT(f64_delta.x, WithinAbs(0.001, 0.0));  // exact
}
```

Subtract in int64 first and the delta is exactly 1 mm; cast and multiply are
then exact in binary64. The negative adversarial case was already pinned by
one of Phase 8's tests; the SECTION above asserts only the positive path
and cites it.

### Origin-shift invariance

The integration-level version of Phase 9's unit tests. M0.2 has no
integrator, so a "physics step" is reinterpreted as a deterministic
`to_relative` query: 6 static Vec3i64 objects spanning mm to AU scales, 1000
query steps, run twice — Sequence 1 with no shift, Sequence 2 shifting the
origin by 10⁹ mm (1000 km) at step 500 and re-biasing post-shift results
into the common frame. All 6000 Vec3f64 pairs must satisfy
`WithinULP(b.x, 4)` — cast (1) + multiply (1) + re-bias add (1–2).

### 10M-cycle no-drift loop

```cpp
CoordinateService service{start_origin};
for (int i = 0; i < 10'000'000; ++i) {
    service.shift_origin(service.get_origin() + shift_delta);
    service.shift_origin(service.get_origin() - shift_delta);
}
REQUIRE(service.get_origin() == start_origin);
```

Ten million forward+back origin-shift cycles, final origin bit-exact via the
defaulted `Vec3i64 operator==`. The path is pure int64 — no floating point,
no atomics, no clocks — deterministic by construction. Ten million frames at
60 FPS would take ~46 hours to run for real; storage-only, the loop takes
0.27 s in Debug, so it runs in every PR rather than behind a CI flag.

### HORIZONS reference data

`test_multi_layer_consistency.cpp` locks the `render_frame` CPU contract:
`service.to_camera_relative(object_pos, camera_pos)` — the exact call the
render path makes before writing the push-constant offset — checked at 1 AU,
1 light-second, and 40 AU (near-Pluto), asserting the Vec3i64 / float64 /
float32 layers agree within their per-layer bounds. No GPU round-trip:
render-to-buffer plus readback is heavy infrastructure for a milestone whose
render layer is one push-constant triangle.

`tests/data/horizons_earth_j2000.hpp` provides Earth's J2000.0
state vector as `constexpr` arrays, with the full JPL HORIZONS API query in
the header — `COMMAND='399'`, `CENTER='@sun'`, `TLIST='2451545.0'`,
`REF_SYSTEM='ICRF'`, `VEC_TABLE='2'`, `OUT_UNITS='KM-S'` — so a reviewer can
re-run the URL and diff the values. A sanity TEST_CASE bounds |position| to
[1.4e8, 1.5e8] km and |velocity| to [29, 31] km/s. No orbit test consumes the
data yet; that needs M0.3's Leapfrog integrator.

### The math-lock rule

This phase codifies the math-lock: once a system passes review, its test
suite pins that system's behavior. Changes to any pinned source file must
keep the suite green. Adding tests is always fine — additive changes never
trigger re-review. Removing tests or weakening assertion tolerances
requires written reviewer sign-off. The rule is cross-milestone: each later
milestone becomes its own lock under it.

### Same-day code review

A same-day code review found 0 critical, 2 warnings, 5 info.
One finding: a comment claimed float32 ULP at magnitude 1000 is 2⁻¹³ ≈
1.22e-4; the exponent of 1000 is 9, so ULP = 2^(9-23) = 2⁻¹⁴ ≈ 6.1e-5 —
the file's stated property is that every bound is re-derivable. Another:
`REQUIRE(earth_j2000_jd_tdb == 2451545.0)` on a `constexpr double` is a
runtime tautology; replaced with a `static_assert`.

## Why it was built this way

- **Scope fence:** a test phase that quietly patches production code
  invalidates what the tests certify. Verified mechanically — a
  `git diff --name-only` over the full phase showed zero changes under
  `engine/` across all 10 commits.
- **Flat test layout:** a `unit/` + `integration/` split at 8 files
  was premature. "Abstract when it hurts, not before."
- **Fuzz deferred:** Tier 5 random fuzz was not required for this
  phase — a decision revisited within 48 hours (below).
- **Committed HORIZONS values over test-time fetch:** a network call in CI
  is a flakiness source; the query URL in the header keeps provenance
  checkable offline.

## Where it is now (drift since 2026-04-23)

The prepared materials went straight into use — and the review that
followed changed shape twice within 72 hours.

- **2026-04-23, a pre-peer-review pass** found 12 issues, among
  them a 22,000 km error in the committed HORIZONS data — the §7.6 fallback
  values were DE430-era while the documented query URL returned DE441, so a
  reviewer re-running it would get different numbers than committed. 10
  findings were fixed the next day (2026-04-24), including a live DE441
  re-fetch with per-component bounds tight enough to catch
  ephemeris-version drift.
- **2026-04-24, the math-lock strengthened:** the observation that the
  lock pins representative points, not the domain, was fixed
  in-phase: `test_property_roundtrips.cpp`, 7 property-based tests over
  10,000 pinned-seed samples spanning ±600 AU. The property suite
  immediately caught a bug the 54 point tests could not — the
  `distance_squared` safe bound of 2³¹ mm overflows int64 (3·(2³¹)² >
  2⁶³−1); corrected to 2³⁰ mm. The math-lock now requires point tests and
  property suites together, and no known weakness is deferred past the
  milestone that surfaced it. Suite: 54 → 61 tests.
- **2026-04-24,** a review pass across 14 angles synthesized 1
  Critical and ~15 High findings; Phase 11's briefing, coverage
  map, and HORIZONS header served as its entry materials unchanged.
- **2026-04-24/25, the fix series that followed** reshaped the module the
  tests pin — saturating `distance_squared`, `std::nearbyint` half-to-even
  rounding, ULP-derived margins replacing Catch2 `Approx` defaults,
  seqlock origin reads — each covered in the Phase 7–10.5 posts' drift
  sections. Phase 11's tests stayed green through all of it. M0.2 merged
  2026-04-25.
- **The four test files are all live** in `tests/unit/coordinates/` as of
  2026-07-21, 8 coordinate test files total. Two renames touched the
  excerpts above: `shift_origin` → `set_origin` and
  `distance_from_origin` → `distance_squared_from_origin`. The flat layout
  eventually hurt: `tests/unit/` now has `coordinates/`, `integrator/`,
  `physics/`, `render/`, and `test_helpers/` (where the property suite's PCG
  generator moved); the `coordinates/` files themselves never split.
- **The HORIZONS pattern scaled:** `tests/data/` now holds 13 ephemeris
  headers — per-planet J2000 states, multi-body epochs, outer-planet seed
  epochs — all in Phase 11's provenance format (query URL, raw CSV response,
  ephemeris version, fetch date). The M0.2 header carries a history note on
  the DE430/DE441 incident.
- **The math-lock rule** — adding tests is fine, weakening a tolerance
  needs sign-off, property suites are required alongside point tests — is
  unchanged since this review week.

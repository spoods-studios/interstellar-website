# M0.3 Phase 17 — Findings + Fixes: Technical Deep-Dive

> Retroactive technical devlog. **Closing phase of M0.3 Basic
> Orbit.** Review ran **2026-06-04**; fix loop the same day; merged
> 2026-06-05.

## Starting point

By 2026-06-04 every M0.3 build phase was closed: force kernel (12),
integrators (13), worker thread (14), HORIZONS validation (15), math-lock
(16), plus debt phases 14.5 and 15.5. Suite at 129 tests, the visual check
passed, tech-debt surface clean by the time this phase opened.

This was the second review of the engine's tree. The 2026-04-25 review
(retroactive) established a fix discipline still visible in the tree: the
`FE_TONEAREST` pin via `std::fesetround` plus CI smoke test,
`to_absolute`'s one-shot Release stderr, ULP-derived margins replacing
Catch2's ~1.19e-5 `Approx` defaults. That review had named the per-substep
NaN/Inf filter's structural closure as a concrete M0.3 carry-over. This
review's double job: audit the new physics, and check whether the
carry-overs closed.

## What it found

The review ran 2026-06-04, examining the milestone's math, code, tests,
and runtime behavior; every Critical/High finding was reproduced and
verified before disposition.

**0 Critical, 11 High, 14 Medium, 6 Low**, plus 3 practitioner/scope
items. Zero Critical because nothing shipped a wrong number in the demo;
the Highs are all latent — silent-failure paths, weak-memory hazards,
reproducibility holes. The headline set:

- **Reproduced:** the per-substep NaN/Inf filter — the M0.2
  carry-over itself — validates only position. A non-finite
  acceleration at the final half-kick writes a non-finite velocity that
  escapes `step<M>` without throwing and gets published — reproduced at
  `-O2 -DNDEBUG`: `NO THROW (LEAKED): v=(inf,7546,0)`.
- **Seqlock tear on weak memory order:** both seqlock writers publish
  the odd in-progress marker with a release store — which constrains only
  *prior* operations, so the payload write can hoist above the odd marker
  on weakly ordered hardware (ARM) and a reader sees even/even around a
  concurrent write: a torn snapshot. x86/TSO masks it, which is why it
  survived testing.
- **UBSan-verified:** `to_absolute` checks the meters→mm
  conversion but not the final `origin + delta` int64 addition — a
  finite input wraps to a negative absolute coordinate. M0.2 code.
- **Reproduced:** no `-ffp-contract` pin in any CMake. On an
  FMA-capable target the force TU emits `vfmadd` and a 200k-step
  trajectory diverges several ULP — cross-machine reproducibility
  silently broken.
- **Math-lock coverage gap:** the Kepler extractor's 6 of 10
  outputs and all singular/hyperbolic branches were unasserted — every
  test used circular-equatorial orbits (i/Ω/ω/ν = 0). The extractor was
  confirmed *correct*; the finding is a math-lock gap on a conic-driving
  function.
- **Stale constant:** `MU_EARTH_DE441` carried the DE430/431-era
  value; `MU_SUN` was truncated below DE441 precision.
- **Practitioner judgment:** the shipped Moon orbit (e≈0.69) sat
  inside the property-grid's energy/LRL coverage gap (e ∈ (0.5, 0.9)) —
  the one orbit anyone looks at was the regime the lock didn't pin.

Cross-checking mattered: of the 11 Highs, seven were caught by only one
review angle — findings a narrower review would have had one chance to
catch.

## The fixes

The disposition (2026-06-04) approved all 11 High + 14 Medium + 6 Low
findings for in-phase fix, deferred exactly two with named blockers, and
settled the scope questions: keep the symplectic substrate and worker as
the M0.4 foundation, keep Leapfrog as KDK kernel + educational
integrator. Seven fix commits, 15:53–16:37.

### Integrator and worker

The fix validates velocity (isfinite triple) at every substep
boundary, with regression tests injecting non-finite acceleration at the
`a1` eval for both integrators; the throw now carries value, component,
and stage. A companion fix closes the input-validation cluster:
`set_time_scale(NaN)` had passed `std::clamp` (all NaN compares false)
and frozen the worker; `step_dt ≤ 0` hung the accumulator loop; the
unpaused worker busy-spun a full core republishing the seqlock ~67M
times/s (now publishes only when a step ran, CV-waits otherwise); and
SimClock moved from `+= dt` accumulation to integer `step_count_`
arithmetic (the float path drifted 5.4 s over 1e8 non-dyadic steps).

### M0.2 math-lock territory

Both seqlock writers now use the canonical ordering — `store(s+1,
relaxed); fence(release); payload; fence(release); store(s+2, relaxed)`
— verified TSan-clean plus 60 s contention. `to_absolute` /
`try_to_absolute` check the final add via `__builtin_add_overflow`
(in-range path bit-identical to plain `+`); `CoordinateService` validates
`shift_threshold_mm` *before* squaring; `Vec3i64` gained Debug per-axis
overflow asserts. This fix re-pinned the constants: `MU_EARTH_DE441`
3.98600435436e14 → **3.98600435507e14** (true DE440/441, Park 2021),
`MU_SUN` → **1.32712440041279419e20** (full DE441); the bit-exact pin
tests moved with them, so the correction is an explicit signed-off diff.

### Build determinism and supply chain

`-ffp-contract=off` (GNU/Clang) / `/fp:precise` (MSVC) pinned top-level
for engine and tests, documented next to the FE_TONEAREST pin;
FetchContent moved from mutable git tags to immutable commit SHAs for
EnTT and Catch2.

### Render, observability, math-lock strengthening

`load_shader_code` no longer OOB-writes on non-4-byte SPIR-V (ASan had
SEGV'd it on a 1-byte file); `project_to_ndc` guards aspect; swapchain
queries check for empty results; the hand-duplicated 48-byte
push-constant struct moved to one header. A companion fix closed the test
gaps: full Kepler element lock (inclined, eccentric, hyperbolic,
singular branches, both quadrant sides), a Moon-IC (e≈0.69) energy lock
closing the earlier coverage-gap finding, per-step angular-momentum
excursion tracking, an r=0 end-to-end throw test, bit-pinned Yoshida
coefficients. A final commit refreshed the stale docs.

Close: 16:45 — **PASSED**. 152/152
Debug + Release + TSan (suite 129 → 152, all additive), M0.2 math-lock
intact, both reproduced production Highs re-confirmed fixed. Deferred
with named blockers: the single-body `Snapshot` POD's inability to carry
N-body state, and the lack of close-encounter regularization — both
scoped as concrete M0.4 obligations, not open-ended deferrals.

### Cross-platform gaps found at milestone close (2026-06-05)

When the milestone closed, CI — Windows/MSVC only at the time —
compiled it for the first time and surfaced six real defects the
review could not see, because nothing had built on that toolchain:
vcpkg baseline skew, GCC-only `__builtin_add_overflow` and `M_PI`, a
vk-hpp debug-callback signature newer Vulkan-Headers reject, and 13
non-ASCII `TEST_CASE` names breaking Windows ctest discovery.
No physics, tolerance, or lock assertion changed — 152/152 byte-identical
throughout. The gap was recorded, and a same-day decision added a
Linux/GCC CI lane and made both lanes required on every push, so future
reviews run against a green build matrix.

## Where it is now (drift since 2026-06-05)

- **The named blockers closed on schedule.** The 2026-06-05 M0.4
  architecture decision resolved both: the SoA snapshot redesign, and the
  adaptive fallback locked as IAS15-class Gauss-Radau, clean-room from
  Rein & Spiegel 2015 (both reference implementations are GPLv3).
- **Independent review continued as the standing practice.** M0.4
  (2026-06-10: 2 Critical, 11 High), M0.5 (2026-06-16), M0.6
  (2026-06-25), M0.7 (2026-07-10), and M0.8 (2026-07-13) each ran a full
  review with findings disposed before merge — the invariant this
  phase's amendment established has held for every milestone since.
- **The fixes held.** The canonical seqlock ordering, checked
  `to_absolute` add, `-ffp-contract` pin, and the corrected constant
  values are all still in the tree; the Kepler element lock and Moon-IC
  energy lock ride in every suite run since. The CI lanes added at close
  still run on every push; the cross-platform defect chain has not
  recurred.

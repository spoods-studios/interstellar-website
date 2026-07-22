# M0.4 Phase 22 — Findings + Fixes: Technical Deep-Dive

> Retroactive technical devlog. **Closing phase of M0.4 Multi-Body
> Gravity.** A review pass ran 2026-06-10; every finding reached a
> disposition the same morning; fourteen dedicated fix phases landed
> 2026-06-10..13; the gate closed 2026-06-13 and the milestone merged
> 2026-06-14.

## Starting point

By the morning of 2026-06-10 every M0.4 build phase was closed: SoA snapshot
(18), direct O(N²) force + state promotion (19), IAS15 close-encounter
fallback (20), multi-body enablement (21), telemetry + warp ceiling (21.5),
expanded validation (21.7). The live binary integrated five bodies —
Sun/Earth/Moon/Mars/Jupiter from DE440 initial conditions — with periods,
100-yr stability, and multi-epoch position error all calibrate-then-locked.
Suite at 218, and a fresh 2026-06-10 diagnosis attributing the period
test's residuals to a moving-Sun heliocentric-frame artifact.

## What the gate ran

A read-only adversarial review pass ran 2026-06-10, with reproducers
checked and every finding carried to a disposition before any source edit
(2026-06-10, 11:56).

## What it found

**2 Critical, 11 High, 14 Medium, 1 Low bundle (18 items).** Both
Criticals were found independently by multiple review passes (the
`mu = G·M` convention violation, the `system_energy` incoherence), and
both were reproduced before disposition:

- `constants.hpp` pinned `M_SUN = 1.98892e30` kg — GM_Sun(DE441)
  divided by CODATA-**1986** G. The force kernel composes `G(2018)·M`, so
  effective GM_Sun sat +2.566e-4 off DE441: Earth's year 0.19 d short, and
  the period and multi-epoch validation bounds had been calibrate-then-locked
  *around the bug*. The morning's frame-artifact diagnosis was refuted the
  same day: swapping in DE441-consistent GM products (only change) improved
  Earth's period error 92× and collapsed the multi-epoch +1yr Earth error
  4.97e5 → 6.5e3 km.
- The shipped 5-body config was permanently in the ENCOUNTER regime. Earth–
  Moon is a bound satellite pair living inside its own mutual Hill sphere
  (separation 4.02e8 m = 9% of k_in·R_Hill; lunar apogee 4.07e8 m can never
  clear k_out·R_Hill = 5.32e9 m, so hysteresis never releases) —
  `detect_regime` returned ENCOUNTER from step 0, and every acceptance gate
  had validated the `step<Yoshida4>` path the binary never executed.
  Silent because IAS15 is *accurate* (divergence 0.000 km over 30 d) —
  4.9× the per-step cost, with zero regime observability.

The High set led with the `[telemetry]` dE/E channel being dimensionally
incoherent (masking real drift by ~1.3e10×), a slot-order-dependent
`gravitating` gate, a lost wakeup TSan provably cannot see, and the
milestone branch never having been pushed — zero CI coverage on ~3,700
new lines.

## The fixes

The disposition approved everything for in-phase fix — no deferrals — as
fourteen dedicated fix phases landed 2026-06-10 through 2026-06-13. The
seven finding-driven fixes:

### Constants / GM repin — 2026-06-10

Body masses defined `M_X = GM_X_DE440 / G` by construction, so the kernel's
`G·(GM/G)` cancels G — round-trip ULP distance 1 for the Sun, 0 for the
other four, asserted in the constants math-lock. `props.mu` now carries
published GMs; the osculating oracle uses published GM instead of the mass
table under test. The period and multi-epoch tests relocked on correct
GMs: Earth 92× tighter (2e-5), Mars 10×, Jupiter honestly *loosened*
4.0e-4 → 8e-4 — the old bound was a two-error cancellation. The
frame-artifact diagnosis was superseded on the record. `nbody_force.cpp`
diff empty.

### Detector design — 2026-06-10

`pair_is_bound()` classifies a permanent satellite pair (ε < 0, e < 0.9
non-radial guard, r_apo < k_out·R_Hill) and exempts it from both switch-IN
and clear-OUT — the live J2000 config now classifies REGULAR and the
shipped binary runs the validated Yoshida4 path. A dominant-body timescale
trigger switches IN when `sqrt(d³/μ_dom) < n_min·step_dt` (n_min
calibrate-then-locked at 30.0 — Earth sits at 558× margin, a 0.01 AU
sun-grazer fires), closing the detector's structural blindness to
dominant-body close approach. NaN-conservative predicates
(`!(sep > k·r_hill)` — NaN holds the prior regime instead of clearing an
active ENCOUNTER) plus a massless-Hill guard round out the fix. Regime
published in the snapshot and `[telemetry]`, with a rate-limited
transition log. `detect_regime` arity 5 → 7 re-triggered the Phase 20
lock; this gate signed off.

### `system_energy` coherence — 2026-06-10

`system_energy` summed specific KE (½v², m²/s²) with mass-weighted PE
(joules); at N=5 the KE block is 1.8e-11 of one ULP of the PE block —
bitwise invisible, so the published dE/E was PE geometry variation
(1.578e-2/yr) instead of true drift (1.19e-12). The multi-body branch now
mass-weights KE, replicating the in-tree 100-year stability oracle
op-for-op so the value pin holds at exact `==`; the N=1/central-field path
is byte-identical. One residual case: `mu_central != 0 && n > 1` still
fell through to the incoherent mix — now rejected at the worker ctor.

### Force-kernel gravitating gate — 2026-06-10

The kernel's outer `if (!props.gravitating(i)) continue;` made the
`gravitating` flag slot-order-dependent: a non-gravitating body at slot 0
never appears as `j` in the `i<j` loop, so it felt zero force (0 vs
8.13 m/s² by slot order). Replaced with per-side gates —
`gravitating(j)` gates the `accel[i]` update, `gravitating(i)` gates
`accel[j]` — which for all-gravitating production tables executes the
identical FP sequence in the identical pair order, byte-identical to
before. Slot-permutation and massive-non-gravitating tests pin the
contract; a follow-up fix short-circuits pairs where *neither* body
gravitates before any distance math, killing `1/0 = Inf` on coincident
no-force pairs.

### Pause/resume lost wakeup — 2026-06-11

`request_pause()`/`request_resume()` stored `paused_` relaxed *outside*
`pause_mutex_`, then `notify_all()` — the worker could read a stale
predicate, block in `condition_variable` wait after the notify fired, and
park forever (~2%/cycle; reproduced at cycles 6/65/151 of 100k;
production-reachable via the Space keybind). TSan is provably blind — a
lost wakeup is not a data race — so the green `*_tsan` gate sat over the
live bug. Fix: hold `pause_mutex_` across the flag store, notify after
release; 10k pause/park/resume hammer as regression (`[.long]`), baseline
sampled after parking per follow-up review.

### CI enablement — 2026-06-11..13

The milestone branch had never been pushed: zero CI runs across all of
M0.4 while tests cited "green on BOTH CI lanes" as the cross-platform
guarantee. Before pushing, the 12 non-ASCII `TEST_CASE` names (em-dash,
≡, →, subscripts) were ASCII-renamed — the exact Windows-ctest discovery
breakage M0.3 had already fixed once — and a permanent
`check_ascii_test_names.py` ctest guard added (hardened string/comment-aware
across three follow-up commits). Lane triage: `M_PI` →
`std::numbers::pi` for MSVC; a final test-only `det_cbrt` dense-sweep
relax to ≤2 ULP landed as the closing commit. Both lanes green there —
the cross-platform claim made true.

### Detector cost + cost model — 2026-06-11

Steady-state `detect_regime` is a second O(N²) pass — measured 139 µs vs
19.7 µs force eval at N=100 — absent from the cost-vs-N benchmark, which
also counted Yoshida4 at 3 force evals/step (actual 6; the repo's own
benchmark table shows 6.26). Fix: mass gate in `pair_predicate` (skip
zero-mass pairs before distance/Hill math — decision-identical for
all-gravitating tables, so determinism holds), a `detect_ns` benchmark
column plus max-warp×N table, and the three 3→6 corrections. An FSAL 6→4
eval-reuse optimization was declined: the locked summation form takes
priority. A follow-up fix re-derived the benchmark with a dominant-star
fixture that forces full O(N²) scans.

### Hardening bundles — 2026-06-12..13

The remaining Medium/Low clusters, seven fixes in two days: symmetric
`PhysicsWorker::Config` ctor guards, span/scratch boundary hardening, and
a per-key `KeyedLogThrottle`; IAS15 conformance — the dead
`max_substep_fraction` knob wired, acceleration-relative corrector
convergence per Rein & Spiegel 2015 §2.2, a denormal b̃₆-band guard, and
silent-degradation observability; deterministic `cbrt` on the trajectory
path, an MSVC ≥ 19.30 floor, and vcpkg pins matched to the FetchContent
sources; the M0.4 N-body property suite plus the 100-year stability
oracle's pins; `run_due_steps`/`publish_with` extraction plus a genuinely
zero-alloc `latest_snapshot` out-param; per-class `to_absolute`
observability flags with the finite+range guard hoisted above the
float→int cast; and a doc-rot sweep that extended the math-lock README to
all 20 M0.4 lock files.

Close: 2026-06-13 — 14/14 fix phases RESOLVED, both CI lanes green, suite
218 → 289 Release / 287 Debug. Merged 2026-06-14. One post-gate debt
item — a TSan test-routing gap — closed the same night as inserted
Phase 22.1 — separate post.

## Where it is now (drift since 2026-06-13)

- **Masses-by-construction became the standing pattern**: M0.8's planetary-set
  expansion pins GMs and derives masses the same way (2026-07-12). The
  G·M↔GM ULP assertions this gate added to the constants lock ride in
  every suite run since.
- **The per-side gravitating gate carried the craft tier**: M0.5's
  test-particle two-block kernel builds on this gate's contract; the
  kernel was later strong-typed (2026-06-24) with determinism still
  locked.
- **The detector kept evolving through gates**: M0.5 added the predictive
  trigger (`detect_regime_predictive`, Phase 25) alongside this gate's
  BOUND exemption and dominant-body trigger; regime telemetry remains the
  observability channel this gate introduced.
- **The pause-path fix above is still the last commit touching it** — the
  lost wakeup has not recurred through five subsequent milestones of
  TSan-gated suites.
- **The same review-pass format held**: M0.5 (2026-06-16), M0.6, M0.7, and
  M0.8 (2026-07-13) all ran the same structured review with the
  machine-readable status header this gate introduced.

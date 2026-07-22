# M0.6 Phase 35 — Findings + Fixes: Technical Deep-Dive

> Retroactive technical devlog. Closing phase of M0.6 WH Shipped
> Integrator. A review pass against the post-Phase-34 tree ran 2026-06-25;
> six fix phases landed the same day; merged the same day.

## The review pass

A review pass against the post-Phase-34 tree ran 2026-06-25.

## What it found

**0 Critical, 7 High, 18 Medium, 13 Low.** Every Critical/High finding was
reproduced. No Critical: the WH/eligibility math, `det_sqrt`, the
Phase-34 strong-type delta to the locked kernel, and the determinism
posture all verified clean. Independent checks confirmed that strong-type
signature change emits a byte-identical FP instruction stream — an
identical assembly diff and an identical per-operation hash across all 67
ops — with 0 FMA / 0 libm on the trajectory path and `-ffp-contract=off`
reaching every TU.

**The milestone's central question** was this: `main.cpp:203` constructs a
second `PhysicsWorker emb_worker` whose ctor selects Wisdom-Holman, then
`(void)`-discards it. WH runs, but on no consumed trajectory, and its
worker-thread exception channel is never drained — `check_and_rethrow()` is
called on the primary `worker` at three sites but never on `emb_worker`.
This split into two High findings:

- **High — the dead error channel itself.** A WH NaN/Inf step
  throws `std::runtime_error`, is captured under `error_mutex_`, and the
  thread dies silently in Release. A reproduction built a `PhysicsWorker`
  mirror that poisons `emb_worker` and polls only the primary: output
  `primary_check=clean` / `wh_running=0` / `wh_check=threw: step: Wh (post
  KDK) body 0 non-finite r` — the exception is invisible until the second
  worker is explicitly polled. `grep -n "emb_worker\." engine/src/main.cpp`
  confirms only the ctor-assert and the `(void)` cast reference it — no
  `check_and_rethrow`, `is_running`, or `tick`.
- **High — a scope-honesty gap.** The project's own status
  documentation described WH as "the active/shipped REGULAR-tier
  integrator," but the rendered trajectory is Yoshida4; WH runs only on the
  discarded worker. Coupled with a second defect on the same surface: those
  docs still asserted unqualified "byte-identity preserved," which the
  same-day sanctioned strong-type override to the locked kernel (a 9-line
  signature change to `nbody_force.cpp`, kernel logic verbatim) had
  already invalidated.

Neither is Critical — the physics forcing the EMB-only config is correct
(η≈0.40 for the Moon rightly excludes it from heliocentric WH; the M0.7
nested-WH split was already decided 2026-06-24). The defects are the
unqualified "shipped" claim and the unpolled error channel, not the physics.

The other five Highs:

- **High — a vector-vs-scalar math-contract violation.**
  `physics_integrator_wh.cpp:250-262`'s η eligibility
  gate summed `Σ|a_ij|²` (scalar sum of per-perturber squared magnitudes)
  instead of `|Σa_ij|²` (the squared net interaction vector). Newtonian
  acceleration superposes as a vector; the scalar sum ignores cancellation,
  so symmetric perturbers get counted as a large perturbation when the
  true net is near zero. A standalone reproduction
  confirmed genuine cancellation: two perturbers placed symmetrically
  above/below give `scalar_eta2=2.02e-4 → INELIGIBLE` vs `vector_eta2=0.0 →
  ELIGIBLE` — a math-contract violation, though it only ever over-rejects
  toward Yoshida4, never falsely keeps WH.
- **High — a benchmark's structural gates never ran in CI.**
  `test_perf_ias15_degrade.cpp:111` tags its only
  case `[.benchmark]`, and `tests/CMakeLists.txt:139-140` compiles the file
  without `add_test`. The load-bearing structural asserts (dispatch fired,
  substeps accepted, all-finite) run only on a manual invocation —
  `ctest --test-dir build -N | grep ias15_degrade` returns nothing.
- **High — Release-only out-of-bounds writes.** `wh_step`'s
  `helio_scratch` size/alias checks and
  `compute_accelerations`'s output/body-table/`n_active` checks are
  plain `assert`s, stripped under `NDEBUG`. A reproduction compiled
  repo-source reproducers with `-DNDEBUG -fsanitize=address`: both
  `wh_step` (states=2, scratch=1) and `compute_accelerations` (states=2,
  accel=1) abort with a heap/stack-buffer-overflow at
  `to_democratic_heliocentric:327` and inside `compute_accelerations`
  respectively — a silent Release OOB write for any caller that doesn't
  happen to size the scratch correctly (today's single production caller
  does).
- **High — zero test coverage on the energy-drift alarm.** The
  Phase-34.2 energy-drift alarm and AMD oracle
  (`physics_worker_thread.cpp:286-317`, `:236-283`) have zero test
  coverage. `grep -rn 'kEnergyDriftAlarm\|ENERGY-DRIFT' tests/` and
  `grep -rln amd_secular tests/` come back empty except a format-string
  test — the regression tripwire for the M0.5 frozen-Sun bug class could be
  silently disabled by an edit to the threshold, the comparison operator, or
  the call site with 436/436 still green.
- **High — a noise-sensitive benchmark conclusion.** The Phase-33
  results document swept N∈{3,5,10,20} at 1
  substep/window and concluded "no degrade cliff" plus a 2.0× MERCURIUS
  re-add threshold "NOT REACHED." Running the built binary read-only —
  `./build/tests/unit-tests "[ias15_degrade]"` — gave N=3 ratios
  1.88/1.84/1.86× on one run and 2.06/2.05/2.07× on another: the ratio
  straddles 2.0× run-to-run, so the "not reached" conclusion is
  timing-noise-sensitive and non-reproducible. A second doc bug rode
  along: the same document labels the shipped step 21,600 s while the live
  EMB worker uses `1.0e5`.

**18 Mediums** covered boundary gaps in the same eligibility gate (r⁴
overflow/underflow bypassing the `r²>0` guard, NaN perturber mass admitted,
non-gravitating dominant body admitted, an unbracketed `>=100.0×` dominant-
mass boundary), API-contract gaps (`step<Wh>` fails at link time instead of
a concept diagnostic, `Config::force_override` silently ignored on the WH
arm), observability gaps (no field distinguishing a WH-run REGULAR step from
a Yoshida4-run one, the alarm not self-defending against NaN `dE/E`), and a
missing 2-reader seqlock soak for the now-two-worker config. **13 Lows** were
mostly doc/comment staleness (a "DKD" banner comment three phases stale, a
garbled Cardano-cubic comment, CI dependency-pin hygiene).

## The fixes

All 7 Highs were fixed in-milestone (disposed 2026-06-25); no disputes, no
deferrals. Six phases, five code/test plus one doc bundle, folding all 18
Mediums and 9 of the 13 Lows along the way.

### η eligibility uses the net-vector norm

Replaces the scalar `Σ|a_ij|²` sum with a true vector superposition —
`a_int,i = Σ G·mass(j)·(r_j−r_i)/|r_j−r_i|³`, then `|a_int,i|²` — using
`det_sqrt` per pair (the same libm-free root `interaction_kick` already
uses, so the decision stays bit-identical across GCC/MSVC). The pinned
threshold `1.0e-4` is unchanged: the vector norm is ≤ the old scalar sum, so
every existing margin holds (EMB η²≈1.4e-8, bound-Moon η²≈0.16) with no
recalibration needed. Also folds in a post-square finite guard closing the
r⁴ overflow/underflow bypass, keeps `η²==threshold` at ELIGIBLE (documented
as closed-below), tightens the knee bracket to 0.98×/1.02×, adds a
ULP-tight `>=100.0×` dominant-mass boundary test, rejects a non-gravitating
dominant body, and rejects a NaN perturber mass. Adds a vector-cancellation
regression (legacy scalar rejects, vector accepts, predicate agrees).
`nbody_force.cpp` byte-untouched; Release ctest 439/439.

### Fail-closed scratch/output guards

Build-independent guards ahead of the existing `assert`s: `wh_step` returns
without writing if `helio_scratch.size() < n`, `compute_accelerations`
returns if its output/body-table/`n_active` sizes disagree — both as a
pre-arithmetic early return, so the locked kernel below the guard stays
byte-identical. The `wh_step` alias check is un-gated from
`INTERSTELLAR_TESTING` to a plain Debug assert. An `n=2` undersized-scratch
boundary test proves the Release path now returns safely instead of
overflowing. Also documents the scratch as ctor-static, naming the
dynamic-body milestone as the grow-seam owner.

### IAS15 degrade structural gate registered in CI

A second, non-`[.benchmark]` TEST_CASE (`ias15_degrade_gate`) runs one small
cell and asserts only the structural gates — dispatch fired, substeps
accepted, all-finite — registered via `add_test` so it runs in default
`ctest`. The wall-time table stays hidden. Also adds a shared
`emb_warp_config.hpp` test factory replacing three hand-duplicated seed
literals (`main.cpp` parity documented), makes the ENCOUNTER negative
control check that the worker published `ENCOUNTER` rather than
inferring it from finiteness alone, and adds a worker-driven
`tick`/`run_due_steps` zero-alloc counter check on the EMB WH path, in
addition to standalone `wh_step`.

### Energy-drift alarm + AMD test coverage

`test_energy_drift_alarm.cpp` captures stderr around a worker tick seeded to
publish `|dE/E| > 1e-2` (REQUIREs the alarm line), a healthy seed (REQUIREs
silence), and an `active_amd` case pinned against the `test_helpers::amd`
oracle on the EMB seed. Also adds a `method=` telemetry field
distinguishing a WH-run REGULAR step from a Yoshida4-run one (threaded
through `FrameMeta`/`SnapshotView`), makes the alarm self-defend
against non-finite `dE/E` with a distinct line instead of depending on an
upstream guard, and has the AMD mirror read `dom_slot_` instead of
a hardcoded `central_idx=0`. Additive test coverage; no re-review needed
since nothing existing changed.

### emb_worker error-channel drain

Both `PhysicsWorker`s route through a small fleet helper so every main-loop
and shutdown drain site checks both error channels, and the EMB worker is
polled once per frame with a throttled stderr alarm if it stops. Also
splits a narrower `KdkMethod` concept from `IntegratorMethod` so
`step<Wh>` fails at the concept boundary instead of at link time, rejects
`Config::force_override` combined with `Wh` at construction instead
of silently ignoring it, and adds a two-reader origin-seqlock TSan soak
for the now-two-worker config.

### Benchmark honesty + scope/status reword

Three tasks in one fix. **Task A:** the results document is retitled from
"Degrade-Cliff Characterization" to "No-Cliff Floor (small-N,
single-substep regime)"; adds an explicit "not characterized" subsection
(N≫20, substeps/window ≫1, the 2.0× threshold's own reproducibility);
reruns at the shipped `1.0e5` s step instead of the stale 21,600 s; adds
repeated-run statistics including the N=3 straddle across the 2.0× line;
adds an absolute ns/step column; adds a hidden warning-only multi-substep
tripwire. **Task B:** rewords the project's status documentation to "WH
available + gate-selected + validated + monitored on a WH-valid config,
not yet driving consumed flight — the visible worker stays Yoshida4/IAS15
until M0.7"; records the matching 2026-06-25 decision; replaces the
unqualified byte-identity claim with one naming the sanctioned strong-type
override as the new baseline; fixes the stale WH-auto-select comment in
`wisdom_holman.hpp:119-121`. **Task C:** applies the remaining doc-level
lows — dependency-floor notes, a shared Catch2 `--rng-seed` var, the
"DKD" banner comment (shipped composition has been KDK since M0.5), the
garbled Cardano-cubic comment, a dimensional typo in the recorded η
denominator, CI pin hygiene.

## Why it was fixed this way

- **All 7 Highs fixed in-milestone, no deferrals.** Unlike M0.5's Phase 29 —
  which had one legitimate deferral (the O(N²) ceiling, genuinely
  missing spatial-partition machinery) — nothing here needed a new milestone.
  The O(N²) surface reappears as a named, already-deferred blocker
  from 2026-06-16; it wasn't re-litigated here.
- **Severity settled by reproduction.** The eligibility-gate finding's
  severity was contested; a standalone cancellation case confirmed the
  vector norm and scalar sum diverge on a physically real configuration,
  settling it at High. The full vector-sum rewrite was chosen over the
  cheaper rename-and-recalibrate option, since the fix was inside the
  same effort bucket either way.
- **Scope-honesty fixed as wording, not as a forced architecture change.**
  The underlying physics was already correct — the Moon's η≈0.40
  correctly excludes it from heliocentric WH, and the M0.7 nested-WH split
  had already been decided the day before. The defect was the milestone's
  own status prose overstating what shipped; the fix is the prose, not a
  rush to wire WH into the render path a milestone early.

## Close

Closed 2026-06-25, tagged as gate-passed, suite Debug 445/445, Release
449/449. `nbody_force.cpp` is **not** byte-identical to the M0.5
baseline — the same-day sanctioned strong-type override (9-line
signature delta) plus the fail-closed guards fix both touch it — but the
locked kernel logic beneath is byte-identical, confirmed by an unchanged
emitted FP instruction stream. Merged and tagged the same day.

Two Windows-CI regressions surfaced before merge and were fixed rather than
deferred: Phase 34's Vulkan SDK bump (1.4.309.0 →
1.4.341.0) left `Vulkan_LIBRARY-NOTFOUND` on the pinned installer action,
reverted; Phase 34's energy-drift-alarm test used bare POSIX
`pipe`/`dup`/`dup2` under `<unistd.h>`, which doesn't exist on MSVC — an
`os_*` shim over `<io.h>` fixed it test-only, Unix path byte-identical.

## Where it is now (drift since 2026-06-25)

- **2026-07-09** (M0.7 Phase 41): the `emb_worker` scaffolding this phase
  drained and polled was removed outright — the live HJS nested-WH tier
  superseded it as the rendered warp path, so the worker it was
  guarding no longer exists. The eligibility gate this phase hardened
  remains live math-lock infrastructure.
- **2026-07-10** (M0.7 Phase 42): the six Mediums/Lows
  this phase named but didn't fold were closed under a dedicated
  debt ledger, verified against a zero-silent-drop accounting.

# M0.6 Phase 33 — IAS15 Degrade-Cliff Benchmark: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-24**; the
> drift section covers the rewrite of both the test file and the results
> doc the next day.

## Starting point

M0.5's Phase 29 (2026-06-16) deferred this question with a named blocker:
whole-system IAS15 fallback drags the *entire* active set into the small
adaptive step whenever any one pair enters its Hill band, and as the
craft/debris population grows that wall-time cost was uncharacterized. The
named blocker was two things — a benchmark of wall-time vs. encounter
frequency and N_active, and naming the MERCURIUS (Rein et al. 2019
per-encounter hybrid) re-add condition. Phase 33 runs after Phase 32 flips
Wisdom-Holman live as the REGULAR-tier integrator, so the fallback measured is
the real dispatch path, not the disabled M0.5 state. The phase is scoped to
a read-only benchmark file, no `engine/` source change.

## What was built

`test_perf_ias15_degrade.cpp` (288 lines at landing) adds one
`[.benchmark]`-tagged `TEST_CASE` sweeping `N_active ∈ {3,5,10,20} × enc_freq
∈ {0,1,2,4}` encounters per 100 steps, over `kNSteps = 2000` WH steps at the
shipped `step_dt = 21,600 s` (6 h — see drift below). For each `N`, the
dominant-star fixture (`m_body/M_star ≈ 5e-7`) gets a dedicated low-mass
encounter pair *appended* at indices `N`/`N+1`, placed 0.05 AU apart — inside
`k_in · R_Hill` — rather than perturbing an existing satellite, so the wide-orbit
bodies' REGULAR-path timing stays clean. At each scheduled encounter step the
pair resets to that close-approach geometry (deterministic frequency), calls
`integrate_window` (whole-system IAS15) with a local `Ias15Stats` sink; every
other step calls `wh_step`.

Three structural gates fire before any number is trusted: `REQUIRE(dom.
dominated)` — a dispatch guard, because an equal-mass fixture
short-circuits the encounter detector and times a degenerate path (the M0.4
precedent: 151 ns measured vs. 142,586 ns true, a 940× miss);
`REQUIRE(total_accepted_substeps > 0)`, confirming IAS15 fired rather than
measuring an idle path; and `REQUIRE(all_finite)`. Timings are
`std::chrono::steady_clock` + `WARN()`, the existing `perf_fixture.hpp`
pattern — no Catch2 `BENCHMARK` macro, since its dynamic iteration count
conflicts with the callsite-counter discipline the determinism invariant
needs. A results document holds the numbers, cross-referencing the
archived M0.4/M0.5 benchmark it builds on. `tests/CMakeLists.txt` gains
one source-list line and no `add_test` alias — `[.benchmark]` keeps it
off the default ctest tier.

One bug surfaced during the first run: the plan's structure computed `dom`
from a temporary fixture's `BodyTable` view, destroyed at the end of the full
expression, so `REQUIRE(dom.dominated)` read freed memory and failed
intermittently (2 of 3 runs). The fix keeps the fixture alive in a named `f`
for the whole `N` iteration and derives `dom` from `f.table()`; folded into
the initial commit before first land.

## Key results (as measured 2026-06-24)

- Max `IAS15_ratio` = **1.76×**, at `N=5, enc_freq=1/100` — every other cell
  sat lower, from 1.14× (`N=20, enc_freq=1`) up through the grid.
- The ratio *decayed* as `N` grew: 1.76× at `N=5` down to 1.16× at `N=20`. The
  per-window IAS15 setup/control cost is roughly fixed; WH's own per-body cost
  grows with `N`, so the fixed IAS15 overhead gets diluted across more active
  bodies.
- Every encounter window in the grid accepted exactly **one substep**
  (`acc_substeps == enc_windows`) — the injected 0.05 AU geometry crosses the
  Hill-band trigger but never forces deep adaptive subdivision at a 6-hour
  window.
- No sharp cliff anywhere in the tested grid. `MERCURIUS_COST_FACTOR` was
  named at `2.0×` and reported **not reached**; the fallback-cost question
  was marked closed.

## Why it was built this way

- **Dominant-star fixture is non-negotiable.** It's the only fixture shape
  that forces the detector to do a full pair scan instead of short-circuiting
  on the first (equal-mass) pair — the exact M0.4 trap the header comment
  quotes by number.
- **A dedicated appended pair, not a perturbed satellite.** Keeping the
  encounter geometry separate from the wide-orbit bodies means the
  non-encounter steps measure pure REGULAR-path cost, uncontaminated by
  whatever the encounter pair is doing.
- **`chrono` + `WARN`, never `BENCHMARK`.** Wall-time is hardware-variable and
  reported non-gating; only the dispatch/fired/finite facts are `REQUIRE`d in
  the (hidden) case.
- **The encounter-pair reset stays inside the timed region**, by design — at
  `N ≤ 20` a two-`State` assignment is under 0.5% of one step's cost, and the
  plan documents that as accepted overhead rather than hiding it outside
  `t0`/`t1`.

## Where it is now (drift since 2026-06-24)

Phase 35 (2026-06-25) found two High-severity issues in this exact file,
both fixed in-milestone before the milestone closed.

- **A gate fix (2026-06-25):** the benchmark's structural gates
  only ran manually. `[.benchmark]` keeps the case off the default ctest
  tier and no `add_test` alias existed, so a regression that broke encounter
  injection — the same 940×-miss class the header warns about — could publish
  a silently-wrong table with zero failing tests. Fix: a second, non-hidden
  `TEST_CASE` (`ias15_degrade_gate`, `N=3, enc_freq=2`, 200 steps) runs only
  the dispatch/substep/finite gates with no timing `WARN`, registered via
  `add_test` so it runs in the default suite.
- **Another fix, the same day (2026-06-25):** the "no cliff / 1.76× max / 2.0×
  not reached" conclusion didn't hold up under a second look. A rerun of
  the same binary crossed 2.0× at `N=3` (2.06/2.05/2.07×) on a run where
  the doc's table topped out at 1.76× — the ratio is noise-sensitive at
  small `N`, not a stable structural fact. The WH and
  IAS15 costs are both O(N²), and `N ≤ 20` sits below the knee where that
  term dominates, so "ratio shrinks with N" doesn't generalize past this
  range. Every measured cell accepted exactly one substep per window — the
  stiff, multi-substep regime the 2.0× threshold exists to guard against was
  never exercised. And the benchmark's `step_dt` (21,600 s / 6 h) didn't
  match the shipped EMB warp worker's actual step (`1.0e5 s`, ~27.8 h) — it
  measured a non-shipped operating point.

  The fix rewrote the results document wholesale: retitled "IAS15 No-Cliff
  Floor (small-N, single-substep regime)"; rerun at the real `1.0e5 s`
  step; a "Repeated-Run Spread" table showing the `N=3` cells straddling
  2.0× across four immediate repeats (ratio 0.949–2.117); an absolute
  `ns/step` column alongside the per-body ratio; a "Not Characterized"
  section naming `N ≫ 20`, `substeps/window ≫ 1`, and production hardware
  under load as explicitly untested, cross-referencing the O(N²)
  force-loop deferral recorded 2026-06-16; and a new hidden, warning-only
  `TEST_CASE` (`[ias15_degrade_stiff]`) that forces
  `max_substep_fraction = 0.02` so a window accepts far more than one
  substep and `WARN`s — never `REQUIRE`s — if the resulting ratio crosses
  2.0 (one sample run measured 3.249× at `N=3`). The doc's closing
  "Honest Finding" states it plainly: no demonstrated cliff in the tested
  floor, and the 2.0× MERCURIUS threshold remains named but unvalidated.
- The same day, an unrelated type-safety pass wrapped
  `compute_accelerations`'s scalar arguments in `GravConstant`/`CentralMu`
  strong types; the benchmark's accel lambda picked up the new call shape —
  compile-time only, no numeric effect.
- As of 2026-07-21, `test_perf_ias15_degrade.cpp` carries three `TEST_CASE`s
  (the default-tier structural gate, the hidden timing sweep, the hidden
  stiff tripwire) at 480 lines, still calling production `integrate_window`/
  `wh_step` directly with no `engine/` source touched. Neither M0.7's nested
  WH nor M0.8's oblateness/1PN work has touched this file since.

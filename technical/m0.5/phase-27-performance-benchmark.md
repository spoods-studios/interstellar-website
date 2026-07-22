# M0.5 Phase 27 — Performance + Benchmark: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-15**;
> Phase 27.5's fix landed between the two halves of this phase and has
> its own deep-dive.

## Starting point

Phase 24 shipped Wisdom-Holman as the production REGULAR-tier integrator
and Phase 26 gave it a test-particle tier; neither phase measured whether
WH was faster than the M0.4 Yoshida4 baseline it replaced. Phase
27's job was to answer that honestly. The load-bearing constraint carried
forward from an earlier M0.4 finding: a benchmark that times a
short-circuited or degenerate path can publish a number that's wrong by
orders of magnitude (M0.4's case: 151 ns measured vs 142,586 ns true, a
940× miss) without failing a single assertion. Every benchmark this phase
writes has to prove the path it measured is the real one — WH dispatch
asserted, no NaN, and the timed cost cross-checked against a deterministic
force-eval count — before it's allowed to report a number.

## What was built

### First pass — the Pareto front that caught a bug

The initial measurement wave built three pieces: a shared production-SSB
fixture and callsite force-eval counter (`perf_fixture.hpp`); a cost model
asserting Yoshida4's force pass count is exactly 6 and reading WH's
measured kick/Kepler-solve counts off the landed `wh_step`; and a Pareto
sweep comparing `|dE/E|` vs wall-time for both integrators over
the *same* frozen 5-body SSB initial conditions and the same 200-day
horizon — only `step_dt` and the integrator varied, the REBOUND
archive-discipline comparison.

The sweep's gating assertion was meant to certify something reassuring:
that WH's energy error is step-independent (the symplectic floor, not
truncation). It measured that correctly — and the floor it measured was
**~2.67e-5, growing secularly with horizon** (slope ≈ 1), never reaching
the target accuracy `A* = 1e-9` at any step, against Yoshida4's flat
~1e-13. A correct symplectic integrator's error is bounded; a floor that
grows linearly with simulated time is a modeling defect, not a numerics
one. The commit reported it as a null result and moved on to the
test-particle scaling benchmark (confirming Phase 26's O(n_active·N)
visit count against the production kernel directly) — but the Pareto
number itself was the tell.

### The revert

A barycenter-drift probe confirmed the diagnosis directly: run the WH map
2000 steps and check the Sun's position and velocity — both **exactly
zero change** — while the system barycenter, which must be conserved,
drifted ~1.7×10⁹ m. The landed democratic-heliocentric transform stored
and restored the dominant body's absolute state verbatim instead of
reconstructing it from the barycenter; freezing the Sun drops its reflex
motion. Because the Sun carries nearly all the system's mass, the
frozen-wrong velocity feeds directly into the energy sum — step-independent
because the freeze doesn't depend on step size, secular because the true
Sun velocity diverges from the frozen one as the system evolves.

`main.cpp`'s production seed was reverted to `Yoshida4{}` at 300 s the same
session — Yoshida4 was always retained as the no-dominant-mass fallback,
so the revert was a one-line seed change, not a rebuild. The
three measurement commits stayed in the tree: they were honest and
determinism-clean, and reverting the *seed* rather than the *benchmarks*
preserved the evidence that found the bug. Phase 27.5 opened to fix the
transform; Phase 27 stayed open, blocked on the perf claim until the fix
landed and re-validated.

### Second pass — the honest characterization

With Phase 27.5's fix landed and WH's floor down to ~4.4e-8 (frame-correct,
boost-invariant), the original small-N Pareto still didn't flip in WH's
favor — on the production 5-body SSB fixture, Yoshida4 is both cheaper and
more accurate at every matched step. Rather than re-run the same comparison
hoping for a different number, Phase 27 resumed by asking the sharper
question the null result implied: *where* does WH win?

`test_perf_warp.cpp` built a clean Sun+2-planet fixture in its
own COM rest frame (so the measurement reflects pure truncation behavior,
not a residual frame artifact) and swept step size as a fraction of the
shortest orbital period, `dt/T`:

| dt/T | Yoshida4 \|dE/E\| | WH \|dE/E\| | winner |
|-----:|------------------:|------------:|:-------|
| 0.002 | 1.8e-14 | 5.0e-9 | Yoshida4 |
| 0.03 | 2.2e-8 | 8.7e-8 | Yoshida4 (last point it wins) |
| 0.05 | 1.8e-5 | 1.2e-7 | **WH** (first point it wins) |
| 0.5 | 3.9 (dead) | 2.2e-6 (bounded) | WH only |

The gating assertion pins the crossover directly: `REQUIRE` Yoshida4 wins
at `dt/T=0.002`, WH wins at `dt/T=0.1`, and WH stays under `1e-3` even at a
half-period step where Yoshida4 has diverged past 100% error. A follow-up
commit extended the existing cost model with a per-step-cost N-sweep: WH's
ns/step is higher than Yoshida4's for every N from 5 to 320 (the
Yoshida4/WH ratio climbs from 0.26 to 0.60 but never reaches 1) — WH's
`(N−1)` Kepler solves and frame transforms dominate at small N regardless
of body count, so the crossover where WH's per-step cost undercuts
Yoshida4's sits at N ≈ 10,000+, far past anything M0.5 or its near-term
successors touch. The perf-warp benchmark was then registered as a plain
(non-hidden) ctest alias so the crossover assertion gates every CI run,
and a final commit appended both crossovers, the two-column cost model
(Yoshida4: 6 force passes / 0 Kepler solves; WH: 2 kick passes / N−1
Kepler solves / 1 jump), and the full Pareto null-result table to the
same benchmark document that already held the M0.4 cost-vs-N table, with
every number tagged to its pinned hardware, step, and accuracy target —
the standing ban on a bare "max warp × N" claim.

## Why it was built this way

- **The benchmark is a correctness gate.** Phase 27 was built to report a
  perf comparison; measuring the real path instead of a convenient
  operating point is what caught a correctness bug the earlier phase
  gates missed. A fixed-accuracy comparison run honestly serves as a
  correctness gate as well as a perf report.
- **Revert the seed, keep the evidence.** Reverting `main.cpp` to the
  validated Yoshida4 was the safe, reversible action; deleting or softening
  the Pareto benchmark that had proven something was wrong would have
  destroyed the finding.
- **Answer the sharper question instead of re-running the same one.** A
  null result on "is WH faster at N=5, 300s steps" doesn't mean WH has no
  win — it means the win isn't in that dimension. Re-shaping the
  measurement around step size (WH's actual lever, per the WH-Yoshida
  operator-split theory) is what turned a null result into an honest,
  useful characterization instead of a dead end.
- **Structural facts gate; wall-clock never does.** Every timing number
  here is benchmark-tagged and non-gating (hardware-variable); only
  deterministic facts — force-pass counts, dispatch-happened, the
  crossover's direction — are required assertions in the default suite.

## Where it is now (drift since 2026-06-15)

- **2026-06-16, Phase 29:** the review found that WH
  eligibility is gated purely by mass ratio when it should be gated by a
  perturbation-ratio test — deferred with a named re-add trigger of
  "whenever WH is flipped on as the shipped warp integrator," since Phase
  27's finding means that hasn't happened yet.
- **2026-06-17, M0.6 scope:** the decision record names Phase 27's crossover
  characterization directly as the reason M0.6 seats WH in the warp-tier
  ladder rather than as a small-N default — "route to WH when the desired
  step exceeds ~3% of the shortest resolved period."
- As of 2026-07-21 production still ships Yoshida4 at 300 s; the two
  crossover benchmarks (`perf_warp`, the cost-model N-sweep) remain the
  gating record of exactly when that stops being true.

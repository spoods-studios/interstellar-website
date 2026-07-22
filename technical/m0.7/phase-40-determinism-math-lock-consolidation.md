# M0.7 Phase 40 — Determinism + Math-Lock Consolidation: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on
> 2026-07-09**; the drift section traces the M0.8 J2/1PN extensions
> through today's stack.

## Starting point

Phase 39 closed the warp↔flown handoff — synchronized-boundary export, the
corrector, keep-unsynchronized peek. Phase 40 was the consolidation gate
ahead of Phase 43's closing review: pin the determinism contract
for the M0.7 hierarchical-Jacobi (HJS) coordinate path, land the two
remaining math-locks — energy invariance under the coordinate change
and a Jacobi-vs-democratic-heliocentric (DHC) artificial-precession
guard — and close out two open items on M0.7's own debt ledger:
`hjs_map_eligible` missing a structural-validity check, and the
massless-test-particle drift-tier deferral not yet written up as a
named blocker.

Four additive stages: the energy lock, the precession guard, the
eligibility fix plus a test-particle property-pin, then the
determinism golden itself plus the contract write-up and ledger
reconciliation. The phase's own discipline: math-lock strengthening is
tests and documentation, not production-numeric change — the entire
phase touches exactly one production line, described below.

## What was built

### Energy invariance under the HJS coordinate change

First, `gen_valid_tree`/`GenTree`/`rand_double` — the random-valid-HJS-tree
generator `test_hjs_coords.cpp` already used for the Phase-36 property
suite — was extracted into a shared header,
`tests/unit/test_helpers/hjs_tree_gen.hpp`.
Pure code motion, verified rather than assumed: two scratch fingerprinters (one
with the old inline generator, one with the new header) replayed the exact
Phase-36 draw pattern across 3 seeds x 500 trees and FNV-1a-hashed every tree's
masses and orbit specs — both `a64392b15089d9df`.

Clause 1 checks that the Jacobi-representation energy (the diagonalized
kinetic-energy sum plus pair potential on `g2b`-reconstructed positions) equals
the independent barycentric `total_energy` oracle, over 10,000 random valid
trees, within a derived bound. A naive `C·ε·(|KE|+|PE|)` bound is fragile: the
potential energy is evaluated on positions carrying the P1 round-trip error
(`≤ C·ε·‖xb‖_∞` per body), which propagates through `d(1/r)=dr/r²` and blows up
for close pairs. The bound adds a third, derived term —
`2·C·ε·‖xb‖_∞·Σ(|PE_ij|/r_ij)` — that scales with each pair's separation, still
inside the `C=4N` ULP family, no magic constant. Worst measured
residual/bound ratio: **0.153751**. A crossing-chain negative control (an
invalid tree fed through the same identity) breaks it by **3.72e11x**.

Clause 2 ports the M0.5-locked `brouwer_slope` harness to `hjs_map_step` on the
bound-Moon nested seed. Default run (~100 Moon periods): slope **0.130**,
max|dE/E| **7.28e-11**. The `[.long]` tier runs 1000 periods across a
4-member ensemble perturbed 0.1% off the initial conditions — an initial
position perturbation destabilized the bound inner orbit (member
1: slope 12.76, max|dE/E| 1.4e-3). A 0.1% perturbation of the full
barycentric position is ~1.5e8 m, roughly 40% of the 3.84e8 m Earth-Moon
separation — not gentle for a hierarchically nested system. Perturbing
velocities only (all bodies at the comparable ~3e4 m/s heliocentric scale)
keeps the induced inner-orbit eccentricity around 0.04: all four members land
at slope ≤ 0.40, max|dE/E| ≤ 1.4e-10. The ceiling locked at **1e-8** — 10x the
worst measured value rounded to a power of ten, ~70x margin.

Release 520/520, Debug 516/516 (both +4 over the Phase-39 baseline).

### Jacobi-vs-DHC artificial-precession guard

The guard needed no new stepper: flat Wisdom-Holman **is** the
democratic-heliocentric map, already math-locked. `test_hjs_precession_guard.cpp`
drives `wh_step` and `hjs_map_step` directly on one WH-eligible two-body
config — never `compute_accelerations` — and measures apsidal precession with
an eccentricity-vector (Laplace-Runge-Lenz, Hernandez 2026 eq. 24)
stroboscopic fit: sample the apsidal angle once per orbit, unwrap, least-squares
slope. Once-per-orbit sampling cancels the in-orbit periodic wobble and leaves
the secular rate.

Default-tier smoke (300 orbits): flat WH precesses at a measured
**-3.56e-14 rad/s**, HJS at **1.33e-23 rad/s** — the assertion is the contrast
(nonzero flat-WH rate, ≥100x HJS), not the magnitude. The `[.long]` anchor at
2000 orbits (h = P/50) converges the flat-WH rate to **-8.86575e-14 rad/s**
against a Hernandez 2026 eq. 39 prediction of **-8.82810e-14 rad/s** —
measured/predicted **1.00426**, sign **retrograde** as measured (not hard-coded
from the paper: the engine advances the DHC jump term inside the drift, an
ABA/Strang-conjugate form rather than the paper's BAB kick-drift-kick, and per
Hernandez & Dehnen 2017 eqs. 47-49 that conjugation swap could have flipped
the sign or rescaled the coefficient — it did neither here). HJS sits at
**1.47174e-23 rad/s**, the round-off floor of the exact Kepler step underneath
it; the noise ceiling locked at **1.5e-22**, ~10x that floor. Halving the step
quarters the flat-WH rate as predicted:
|rate(P/50)|/|rate(P/100)| = **4.01299** against a [3.8,4.2] band.

The 300-orbit smoke's own rate (3.56e-14) undershoots the converged 8.87e-14
by more than half — a longer-than-orbital LRL modulation contaminates short
fits until the secular term dominates around 1000 orbits (1000- and 2000-orbit
runs both give 8.87e-14). The eq. 39 band is pinned around the converged rate,
not the smoke value; the smoke asserts contrast only, so the under-measurement
is harmless there.

Release 522/522, Debug 518/518.

### `hjs_map_eligible` now requires `valid(tree)`

The phase's only production-code edit. A review finding on the M0.7 gate
noted that `hjs_map_eligible` checked size, all-massive, and
non-degenerate reduced mass, but not the structural `valid()` predicate — a
hand-built tree bypassing `build_tree` could be structurally invalid (a
crossing chain, a broken center/satellite partition) and still read eligible,
silently integrating garbage through `b2g`/KDK/`g2b`.

```cpp
if (!valid(tree)) {
    return false;
}
```

Placed after the existing N-range guard (so `valid()` never indexes the
fixed-capacity arrays past `kHjsMaxBodies` on an oversized tree) and before the
existing all-massive checks, unreordered. `valid()` is mass-independent and
float-free, so the conjunct changes outcomes only for structurally invalid
trees — every valid all-massive tree still returns eligible with a
byte-identical step. RED before the fix (Probe 12:
`REQUIRE_FALSE(hjs_map_eligible(tree))` failed), GREEN after.

Four call sites were re-audited: `hjs_map_step`'s false branch is a whole-state
no-op (the fix); `hjs_nested_eligible`'s false branch propagates the same
no-op to the nested path; the test-only traced variant refuses invalid trees;
and the live physics-worker constructor (`physics_worker_thread.cpp:791`)
already throws on an invalid `HjsTree` *before* reaching this predicate at
`:799` — so the strengthening cannot regress a previously-working config, and
a previously-eligible-but-invalid config was already unreachable in the live
worker.

A follow-up commit landed a four-arm random-tree domain sweep, 10,000 trees
each off `gen_valid_tree`: all-massive trees stay eligible and advance; the
massless-test-particle contract holds across both reachable TP
geometries — sole-only (a TP alone on its side of every orbit, 1666/1651
samples) and co-satellite (sharing an orbit-side with a massive body,
8334/8349 samples) — valid, map-ineligible, and a byte-exact whole-state no-op
under repeated stepping; a deterministically crossing-corrupted arm produces
an invalid tree on 10000/10000 samples; and `eligible(t) ⇒ valid(t)` holds over
every sampled tree. (A classifier split by `m_reduced==0` turned out to be
always-true in this domain, since every `gen_valid_tree` body is a sole
member of its own first-merge orbit; the geometric co-satellite/sole-only
split was substituted instead, since it does exercise both TP shapes.)
The same sweep also promotes the faithful test-particle drift tier to a
named M1.x deferral — a TP has no Jacobi row to drift, a genuine
missing-machinery blocker — closing out that debt-ledger item.

Release 526/526, Debug 522/522.

### Two-band HJS-path golden + the determinism contract

`test_hjs_det05.cpp` extends the det04-style two-band golden pattern to the
full HJS pipeline: `b2g → g2b → one map step`, frozen on two scenarios so both
the coordinate folds and the recursive scheduling-ladder folds sit inside one
trajectory. Scenario 0 runs the existing 9-body `hjs_odea_golden` seed through
one single-level `hjs_map_step` (dt=3600 s, G=6.67430e-11; the seed declares no
periods, so every `n_k==1`) — 54 doubles frozen. Scenario 1 runs the 6-body
Sun/Earth/Moon/Jupiter/Io/Callisto `two_clump_seed` through one
`hjs_nested_step` (τ=864000 s) whose Phase-38 cadence ladder is {1, 8, 128} —
`n_k>1` on the Moon and Io edges, so the DLL98-palindrome recursive scheduling
fold is captured too — 36 doubles frozen.

Same-family lanes (GCC/Clang x86_64) assert byte-exact `to_bits ==` against
the golden; every lane also runs a derived physical band (per-body position
error < 1.0 m), sized from the P1 `C=4N` round-trip family (~8 mm worst case
at the ~7.8e11 m Jupiter orbit scale) with ~125x margin — metre-scale-tight,
not AU-scale slop. A repeat-call probe runs each pipeline twice in-process and
checks every output double byte-identical, independent of the golden itself.
Regenerating the golden requires the hidden `[.][det05_capture]` generator and
independent re-verification.

The contract lives in two places. The enforcement-adjacent half:
comment-only blocks added to `hjs_coords.hpp` and `hjs_map.hpp` naming the
pinned fold order, the Jacobi-not-DHC convention, and the sign-off requirement
for changes — verified comment-only at the object level by hashing the five
Release `.o` files touched by those headers before and after the edit; all
five came back byte-identical. The reviewer-facing half generalizes the
existing same-family-byte-exact/cross-family-physical-band designation
(already established for the flat N-body path) to the full engine, and
cites the external precedent — WHFast (Rein & Tamayo 2015,
arXiv:1506.01084 §4) ships the identical two-band discipline because C99
forbids FP re-ordering.

The M0.7 debt ledger was reconciled in the same pass: the eligibility
item resolved (above); the worktree-embed housekeeping item re-verified
resolved (`git ls-files .worktrees` empty on the milestone branch,
`.gitignore` carries the ignore line); the test-particle deferral
confirmed closed (the named-blocker entry already existed from an
earlier session); one new item opened — `s05_hammer`, a pre-existing
`[.long]` pause/resume concurrency stress test, failed once
intermittently on an earlier baseline and passed on every subsequent
run. Cataloged, not fixed: unrelated to the HJS path, owner before
Phase 43's closing review.

Release 529/529, Debug 525/525 — the phase's exit gate.

## Why it was built this way

- **Calibrate-then-lock, not a priori.** The energy lock's velocity-only
  perturbation and the precession guard's 2000-orbit convergence point
  are both corrections to an
  initial guess that a real run exposed as wrong — a position perturbation
  destabilizing the bound Moon, a 300-orbit smoke undershooting the true
  secular rate. Every locked band traces to a measured value plus a documented
  margin.
- **One production line, proven safe from every angle.** The eligibility
  fix is additive, float-free, ordered after the existing checks, and
  audited at every call site before landing — the strengthening changes
  behavior only for inputs that were already wrong.
- **A deferral needs a named blocker.** The domain sweep promotes the
  test-particle drift gap to a named blocker with the concrete missing
  machinery (no Jacobi row to drift), rather than leaving it open across
  another milestone.
- **The contract lives where the force kernel's already does.** It
  mirrors the locked N-body force kernel's own in-repo precedent —
  enforcement-adjacent header comments plus a reviewer-facing vault
  note — rather than inventing a new documentation shape for the HJS
  path.

## Where it is now (drift since 2026-07-09)

- **2026-07-12, Phase 46**: the precession-guard measurement core
  (`ecc_vector`/`apsidal_angle`/`lsq_slope`/`ApsidalFit`) moved verbatim out of
  `test_hjs_precession_guard.cpp` into a shared
  `tests/unit/test_helpers/apsidal_fit.hpp`, reused by M0.8's 1PN precession
  suite on the Sun-Mercury HJS arm.
- **2026-07-13, Phase 47, a later gate finding**: the determinism contract
  gained five new rows for the M0.8 J2-oblateness and 1PN kernels, each
  landing as additive kicks/drifts after the locked Newtonian path; the
  note's milestone stamp moved from M0.7 to M0.8. (M0.8's own debt ledger
  separately opened a PN/J2 corrector-omission item, unrelated to this
  phase's `hjs_map_eligible` fix.)
- The `hjs_map_eligible` `valid(tree)` conjunct sits unchanged at
  `engine/src/hjs_map.cpp:467` as of engine HEAD — the file has grown around
  it (J2 Step-2b, 1PN Step-4 kicks landed before this check in the call
  order), but the three-line conjunct itself is untouched.
- The two-band HJS-path golden, the two header-comment blocks, and the
  reviewer-facing determinism note all still exist and still describe
  the Phase-40 path unchanged; no drift beyond the M0.8 additive rows
  above.

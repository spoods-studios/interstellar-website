# M0.7 Phase 43 — Findings + Fixes: Technical Deep-Dive

> Retroactive technical devlog. **Closing phase of M0.7
> Hierarchical (Nested) Symplectic Integrator.** Review ran 2026-07-10;
> six fix rounds landed the same day; the milestone closed and merged
> the same day.

## What it found

A review pass ran against the post-Phase-42 tree on 2026-07-10.
**0 Critical, 7 High, 25 Medium, 19 Low** (51 distinct root causes after
semantic dedupe). No Critical: every HJS equation — the Beust eq-12/13/16/17
split, the closed-form `umat`, the Chambers/Wisdom-2006 corrector
constants, the DLL98 nesting — and the determinism posture
(`-ffp-contract=off` reaching all four HJS translation units, no libm/FMA
leakage) verified clean. Both math-correctness passes filed zero findings.

**The headline finding is a High found independently across the pass:**
`build_tree` (`engine/src/hjs_coords.cpp:61`), the HJS
coordinate-core constructor, does no `n_bodies`/`n_orbits`/body-index
bounds check and stack-buffer-overflows on any out-of-range shape —
ASan/UBSan-confirmed across both lanes
(`hjs_coords.cpp:73/82/85/87/95 runtime error: index 33 out of bounds`).
Every sibling on the surface (`valid`, `hjs_map_eligible`, `hjs_map_step`)
guards the same `kHjsMaxBodies` bound; the one function that runs first
omits it. That anchors a broader unchecked-surface cluster:

- **Eligibility gate too narrow** — `hjs_map_eligible` rejects only
  exactly-zero masses, so NaN, +Inf, and negative masses all pass
  eligibility (`NaN==0.0` is false). NaN/Inf are caught downstream by
  the warp finiteness hard-stop; a negative mass stays finite and
  integrates a physically-wrong trajectory with no guard and no alarm.
- **Silent fallback on a bad period** — when a declared edge lacks a
  finite-positive period, `hjs_nested_ladder` returns an invalid ladder.
  `hjs_nested_step` gates on eligibility and byte-exact no-ops, but
  `hjs_map_step_jacobi` silently falls back to single-level stepping —
  so a worker-declared **nested** hierarchy with a bad period runs as
  period-independent single-level HJS, with no log or error. Filed at
  both Medium (an API-symmetry framing) and High (a shipped-path silent
  regime change); adjudicated High — the worker is a shipped consumer,
  and silently defeating the milestone's defining feature outweighs the
  API-symmetry framing.
- **No guard on the Jacobi seam** — `hjs_map_step_jacobi` and three
  sibling seams take a bare `HjsTree` with comment-only preconditions;
  `hjs_map_step_jacobi` has no null/N/eligibility guard at all. A
  reproducer showed the safe `hjs_map_step` wrapper refuses an invalid
  tree (`delta=0`) while the public `hjs_map_step_jacobi` seam
  integrates the same tree into `150818833996.6` m of movement. Filed
  at both Medium (a comment-only-precondition framing) and High (the
  reproduced silent-garbage path); adjudicated High, matching the
  rubric's own example of a public API allowing silent garbage.

The second High cluster is **satellite-channel observability** — the
per-clump internal-energy drift M0.7 exists to protect had no runtime
alarm:

- **Global alarm masks a local collapse** — the global `dE/E` alarm
  (`kEnergyDriftAlarm=1e-2`) is computed from the same per-publish block
  as the per-clump drift, but only the global ratio is ever compared
  against it. Earth-Moon internal energy is ~1.156e-7 of whole-system
  energy, so a *total* Earth-Moon collapse moves the global ratio by
  ~1.16e-7 — 8.6e4× below the alarm threshold. The masking factor was
  confirmed directly from `constants.hpp` masses/GM.
- **Cadence blind spot at max warp** — at the live seed's `step_dt=300`,
  `observability_cadence=8`,
  and `time_scale_max=1048576`, one publish drains ~3 days of sim-time at
  max warp. The refresh/alarm block only evaluates every 8th publish, so a
  structural failure starting immediately after a refresh stays invisible for
  ~21.2 days sim-time — longer than a full Io orbit (1.53e5 s) or Callisto
  orbit (1.44e6 s). A reproducer linked directly against
  `libinterstellar-engine.a` at production settings and confirmed the
  gap; an earlier coverage note had judged the cadence "bounded and
  acceptable" in wall-time, which fails at max warp where sim-time races
  far ahead of wall-time — adjudicated High on the live-settings
  reproduction.

The remaining two Highs are **provenance/doc-integrity**: the
committed "ODEA golden" (`tests/unit/physics/data/hjs_odea_golden.hpp`) was
a C++ self-capture, explicitly labeled "PENDING ONE-TIME FORTRAN
CROSS-CHECK... NOT yet verified against ODEA" — yet the load-bearing
determinism-contract block (`hjs_coords.hpp:44-46`) asserted as flat fact that
the fold order "replicates ODEA's `coord_b2g.f`/`coord_g2b.f` summation
order bit-for-bit." A systematic-but-self-consistent convention error would
have survived every existing test (round-trip and KE-diagonalization are
sign-insensitive), because the independent oracle that would catch it
didn't exist yet. Filed at both Medium (the missing-oracle facet) and
High (the doc-overclaim itself). This one had been the milestone's
single DEFER candidate (the ODEA Fortran toolchain isn't normally on
this machine) — the disposition below is why it isn't.

## The ODEA cross-check — the one genuinely unusual artifact

Every prior review closed its findings with code fixes, doc corrections,
or named deferrals. This finding got something else: an actual
independent-oracle run, executed inside the fix window rather than
deferred.

A dedicated fix commit clones [LaRodet/ODEA](https://github.com/LaRodet/ODEA),
builds its real `coord_b2g.f`/`coord_g2b.f`/
`io_init_pl_hjs.f` under `gfortran 16.1.1`
(`-O2 -fno-unsafe-math-optimizations -ffp-contract=off -std=legacy`), and
diffs it against the engine's C++ `b2g` on the same 9-body seed — fed to
Fortran as `%.17g` so gfortran's list-directed read parses the identical
IEEE-754 bit pattern the C++ side consumed. Result, measured 2026-07-10:
**every real Jacobi orbit (k=2..9, both position and velocity — 16
components) is byte-identical, max deviation 0 ULP.** The one difference is
by design, not error: ODEA's `coord_b2g.f:38` hard-zeros the k=1 dummy COM
row (it operates in the system COM frame), while the engine's `b2g`
computes the true mass-weighted COM at that row so `g2b` stays a general
inverse valid for any input frame — pre-documented at `hjs_coords.cpp:350`.
A follow-up commit then rewrites the determinism-contract text from the
unperformed "bit-for-bit" claim to the measured result. Object code is
untouched: Release `.text`/`.rodata` byte-identical for every touched TU;
Debug differs only in the `-g` line table.

The full driver, seed, and raw hex outputs from this cross-check were
preserved with a re-run recipe, so the 0-ULP claim doesn't have to be
taken on faith next time someone touches the fold order.

## The fixes

All 7 Highs were fixed in-milestone. Three gray areas resolved toward the
harder option: build ODEA and run the real cross-check now instead of
deferring; land the O(N³) kick rewrite bit-identity gated — stop
and defer to M1.0 instead of re-pinning if any golden moves; add
the deep-ladder DE441 anchor now, keep per-edge corrector masking as the
already-named handoff-corrector deferral. All 25 Mediums and 19 Lows
folded in alongside.

### Hardening the unchecked HJS public surface

One fix adds an entry bounds guard at the top of `build_tree`: any
oversized N, out-of-range `n_orbits`, or out-of-range spec count/index
returns a zeroed tree (`valid()==false`) before any scatter loop runs, plus
a loud worker-ctor `HjsOrbitSpec` preflight. Another makes
`hjs_map_eligible` require every gravitating mass and real-orbit reduced
mass finite and strictly positive via a branch-only `finite_positive` (no
libm added). A third gives `hjs_map_step_jacobi` the same null/N/
eligibility no-op guard its siblings already had — an invalid tree now
degrades to a byte-exact whole-state no-op instead of 1.5e11 m of silent
motion. A fourth makes the worker require a valid cadence ladder for a
declared hierarchy, throwing `std::invalid_argument` instead of silently
downgrading to single-level; direct callers of `hjs_map_step` keep
period-independent single-level operation. Every well-formed shape in the
shipped seed and existing tests is byte-unaffected; a later fix in this
phase adds a library-level regression pinning the exact map-vs-nested
divergence the silent-fallback finding described, so the failure mode is
now a guard, not a silent branch.

### Satellite-channel observability

One fix evaluates each declared bound clump against its own tight
envelope — one decade above the bound already locked for each clump
(Earth-Moon 2.5e-1, Jovian 2.0e-4) — emitting a value-bearing,
per-clump-throttled alarm line, observability-only. The empirical masking
proof: a full 9-body seed driven into warp with a COM-conserving
Earth-Moon internal collapse yields global `dE/E = -1.94e-7` (silent,
5.1e4× below the global alarm) while the clump alarm fires at
`dE/E = -0.838`. A second fix adds a sim-time freshness bound alongside
the publish-count cadence: force a refresh + alarm evaluation once
sim-time advances `min(declared period)/2` since the last refresh, so a
structural failure can't hide past half an Io period regardless of warp
scale. Flat seeds with no clumps and `observability_cadence=1` stay
byte-identical.

### ODEA provenance

Covered above. The same fix also commits
`scratchpad/capture_hjs_golden.cpp`, closing the recipe gap (the
regeneration recipe had referenced an uncommitted file).

### Performance, bit-identity gated

One fix hoists the per-body barycentric acceleration `a_bary[i]` out of
the interaction kick's Jacobi-orbit loop — computed once per body instead
of recomputed per orbit row — cutting the kick from O(N³) to O(N²). The
per-body ascending-j fold and the ascending-i forward fold (with its
`c==0.0` skip) are byte-for-byte the pre-fix loops, so **zero bits moved**:
the N=9 full-seed 100-step Jacobi hexfloat dump matches pre/post
(`sha256 e5e7af9a…`), and this was redundant-work removal, not
reassociation — no determinism-golden re-pin needed. Measured trivial-step
speedup on a chain hierarchy: N=32 ~4.7× (87.0→18.4 µs), N=16 ~2.15×,
N=9 ~1.4×, growing with N as O(N³)→O(N²) predicts. A companion fix stores
the ctor-derived nested ladder as worker state instead of re-deriving it
every step (it's a pure function of `(tree, step_dt)`, both ctor-fixed),
verified value-identical via `memcmp` and a 16-step trajectory-equivalence
test between the self-deriving and ladder-taking overloads.

### Test-depth additions

Additive-only, no production numeric change beyond one already-covered
doc comment: one addition adds a deep-ladder DE441 position anchor at
warp-scale tau (n_max=128 @ 10 d, n_max=512 @ 30 d) — turning the deep
ladders' previously energy-only check into a position-anchored gate, since
energy conservation alone is necessary but not sufficient (the project's
own M0.5 frozen-Sun lesson). Moon geocentric residual lands at 38.9/21.2 km
at 10/30 days; the Galilean residuals track the same Jupiter-J2 model
floor the tau=86400 gate already measured. Another pins the real
DE441-seed Ganymede/Callisto power-of-two ceil straddles exactly (raw
2.796→n_sub 4, raw 1.200→n_sub 2), closing a gap where every existing
pinned value sat away from the straddle point a ceil→floor mutation would
flip. A third extends the determinism golden with a third scenario
routing the corrector/warp-enter/warp-export lane, which the prior two
scenarios never touched. Four more round out coincident-kick propagation,
the real ~2.7e7 Sun/Moon mass-ratio domain, non-finite-dt poisoning, and
nested-ladder defensive branches. Full suite green after this phase:
Release 552/552, Debug 548/548.

### Doc/trivial bundle + terminal disposition of every remaining M/L

Four commits round out the bundle. One corrects HJS contract doc-drift (the
"does NOT drift" COM-orbit comment, the "bit-clean" round-trip claim, the
"THE ONLY path out" handoff header, the dt/G-confusable-params hazard) and
documents the interaction-kick cancellation bound and the power-of-two
cadence waste bound — all comment-only, Release object-code
byte-identical. Another adds `assert(parked_.load(acquire))` to the three
tests-only warp accessors that read non-atomic cross-thread state under
an unenforced parked contract, mirroring the guard `tick()` already had,
plus a central `static_assert(std::numeric_limits<double>::is_iec559)`
making the `build_tree` zero-init's all-bits-zero assumption an enforced
compile-time contract instead of an implicit one. A third is the phase's
one genuine behavior change: hoists a `get_origin()` seqlock read out of
the worker's own odd-generation write window, and enriches the HJS warp
finiteness guard's throw message with sim_time and the offending xj/vj
vectors — both verified behavior-preserving (published origin
bit-identical). The last fixes stale provenance comments, UAT-checklist
line citations and stale suite counts, and documents the Catch2
shuffle-seed pin's CTest-only scope.

The closing commit closes the review's own bookkeeping: every one of the
51 findings now carries a terminal disposition. **33 RESOLVED, 12 DEFERRED
(named blocker/owner — six of them fixes that turned out to need a
production numeric/output change or non-trivial test-harness design beyond
the doc/assert charter), 6 ACCEPTED (documented, correct by design). Zero
PENDING.** Suite green after the final fix round: Release 552/552,
Debug 548/548 — identical to the baseline before it, no test added or
lost on this phase.

## Why it was disposed this way

- **All 7 Highs fixed in-milestone, the one DEFER candidate un-deferred.**
  The ODEA-provenance finding arrived flagged as the single legitimate
  deferral (no Fortran toolchain on the machine) — the disposition
  reversed that: stand up gfortran and run the real cross-check rather
  than ship a corrected caveat around an unperformed test. The other
  twelve named deferrals (the n_max cost ceiling, the HUD/telemetry
  surface, several test-harness-depth items, `G==0` defensive
  hardening, status-writer ownership, per-edge corrector masking,
  runtime re-hierarchization, the 32-body cap, warp peek cadence) each
  name a concrete blocker — an algorithm change needing its own study, a
  production behavior change outside a trivial-bundle scope, or an
  M1.0-scope machinery gap — satisfying the bar for a legal defer.
- **Severity disagreements resolved by reproduction, not headcount.**
  The silent-fallback, ODEA-provenance, cadence-blind-spot, and
  no-guard-on-the-Jacobi-seam findings above all split Medium/High
  across review; each was adjudicated by re-running the stronger
  reproducer against the live tree rather than by which framing had
  more support.
- **The perf fix was bit-identity gated going in, not audited after
  the fact.** The disposition itself carried the stop condition: land the
  O(N²) kick only if every determinism/math-lock golden stayed
  byte-green, defer to M1.0 otherwise. It landed clean — the rewrite
  turned out to be pure redundant-work removal, not reassociation, so no
  golden needed a re-pin.

## Close

Gate closed 2026-07-10. A post-completion audit caught 6 new
`-Wdeprecated-declarations` from a Fedora `vulkan-headers` 1.4.341
upgrade (device-level layer fields ignored since Vulkan 1.1, now
deprecated) — fixed before merge rather than deferred, baseline
refreshed. Merged and tagged the same day.

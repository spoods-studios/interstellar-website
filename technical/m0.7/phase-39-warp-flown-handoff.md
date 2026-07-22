# M0.7 Phase 39 — Warp↔Flown Handoff: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on
> 2026-07-09**; the drift section traces `hjs_handoff.{hpp,cpp}` and the
> worker's warp session through M0.8 and M1.1.

## Starting point

Phases 36–38 built the nested Hierarchical Jacobi Symplectic (HJS) map —
coordinate transforms, the per-orbit Kepler drift, and the SyMBA-style
recursive sub-stepping — as a validated seat, not a consumed one: every
prior phase's math-lock suite exercised the map directly, never through
the live `PhysicsWorker`. M0.6 had already deferred exactly this wiring.
Phase 39 is where the nested map goes live as the worker's warp
tier: a declared hierarchy auto-selects it, a two-octave hysteresis band
on `time_scale` drives entry and exit, and a symplectic corrector pair
absorbs the KDK boundary error at each crossing. The flown tier (adaptive
Yoshida4/IAS15) does not change.

## The synchronize requirement's REBOUND parenthetical doesn't apply literally

The requirement for a synchronized export reads "re-inject pending
half-Kepler + corrector, Jacobi→barycentric at post-drift end-of-step" —
language lifted from REBOUND's WHFast `synchronize()`. WHFast runs DKD (drift-kick-drift) with `safe_mode=0`,
which merges adjacent half-drifts across steps, so its interior genuinely
carries a *pending* trailing half-Kepler drift between calls; `synchronize()`
re-injects that pending half-step before inverting the corrector. This
engine's map is KDK with **unmerged full steps** — nothing is pending
between calls by construction, because Phase 38's ladder executor
deliberately keeps every half-kick explicit rather than folding adjacent
ones together (the same design choice that keeps the palindrome bit-exact
for the reversibility lock established in Phase 38). The corresponding
"synchronize" operation
is therefore three steps: finish the in-flight outer step (there is
nothing pending after it), apply C⁻¹, then `g2b`. The operative
invariant — never export a mid-sequence or mapping-coordinate state as
real — holds either way, and the unmerged form is cheaper: no
operator-merging bookkeeping, one `O(N²)` kick per step at N≈9.

## The corrector: right coefficients, and a direction that had to be proven

The corrector chosen pins the Chambers (1999) / Wisdom (2006, eq. 35)
third-order two-stage KDK form, not REBOUND's own default set — REBOUND's `alpha = sqrt(7/40)`
belongs to its DKD map and does not transfer to this engine's KDK
composition. The five literals (`gamma = sqrt(10)`, `a1 = 0.3*gamma`,
`b1 = -gamma/72`, `a2 = gamma/5`, `b2 = gamma/24`) are pinned as constexpr
25-significant-figure header literals, cross-checked against a runtime
`std::sqrt(10)` at test time to ≤1 ULP — the same "literal in production,
computed in test" split `integrator.hpp`'s Yoshida weights already use.

Composition order was not settled by derivation alone: it was left as an
open assumption, arbitrated by the effectiveness fixture — if the
corrected arc came out worse than uncorrected, the composition order was
the first suspect. It didn't: the
literal eq. 26/27 reading (`C = Z(a1,b1)∘Z(a2,b2)`, `C⁻¹ = Z(a2,-b2)∘Z(a1,-b1)`)
measured a **484× improvement** in boundary `|ΔE/E|` on the single-level map
(6.66e-9 → 1.37e-11), which settles the direction — a swapped C/C⁻¹ would
have amplified the offset instead. The k=1 COM row is deliberately excluded
from the corrector's drift stage: the ±a drift pair on that row would cancel
exactly in exact arithmetic anyway (the kick never touches k=1), so excluding
it keeps the cancellation bit-exact instead of injecting pure roundoff.

## The finding that forced a same-session amendment: the corrector hurts the nested map

The 484× number above is measured at `n_max=1` — the single-level map the
corrector's derivation targets. Run at `n_max=8` (Moon sub-stepped 8× inside
one Sun/Earth-Moon outer step, the actual regime a hierarchical warp seed
exercises at coarse dt), the same corrector **degrades** boundary `|ΔE/E|`
by ~31× (5.54e-9 → 1.71e-7). This is not a sign or scale bug — it was
confirmed by ladder-cadence probing across two seed geometries: the
corrector's A operator drifts every real orbit at the *outer* dt
(a1·dt ≈ 9.5 days, about a third of the Moon's period), which
re-introduces the single-level-sized mapping offset that Phase-38's
Moon-at-dt/8 sub-cadence had already cancelled. Genuine physics, not a
defect — but a hierarchical warp seed at coarse dt is the milestone's
headline case, and applying the corrector there unconditionally would have
shipped a regression disguised as a feature.

The 2026-07-09 amendment gates the corrector on
the ladder itself: `warp_corrector_at_boundary_ = !ladder.valid ||
ladder.n_max == 1` — trivial ladder (fine `step_dt`, every `n_k == 1`)
enters/exports through `hjs_warp_enter`/`hjs_warp_export` (corrector on);
an active nested ladder enters/exports through bare `b2g`/`g2b` (corrector
off, mapping coordinates equal real coordinates at those boundaries because
nothing corrects them away from it). Both sides are pinned bit-for-bit by
peek-identity fixtures against their respective standalone references.
Formal characterization of the interaction was named as
Phase 40's job; this phase ships the corrector correct, safe, and
conditionally applied — not silently assumed to always help.

## `hjs_warp_export`: one function serves both the real exit and the display peek

The synchronized export and the keep-unsynchronized peek are the
same operation on a copy: copy live `(xj, vj)` into scratch, invert the
corrector on the *copy*, `g2b` from the copy. `hjs_warp_export` takes the
live session pointers as `const Vec3f64*` — the compiler enforces that
export can never mutate the buffers integration resumes from. That single
signature makes two of the research note's named pitfalls unrepresentable
rather than merely tested-for: a mapping-coordinate leak (there is no path
that hands mapping coordinates to a caller labeled as real) and a
resume-from-the-wrong-state bug (there is no path back into the live
session except the saved pre-corrector Jacobi state). The worker's
`publish_snapshot()` calls this same function at the existing
triple-buffer publish point during warp — no new cross-thread API, no
change to publish cadence. The bit-identity fixture that proves the peek is
non-perturbing: a worker publishing every warp step (K peeks) and a worker
publishing once (0 peeks) export identical final state, `==`, not
approximately — a tolerance here would hide a leaked C⁻¹ behind an epsilon
narrow enough to pass.

## The hysteresis band, and why it's safe where the Phase-25 pattern says it shouldn't be

The two-octave band (`warp_in_scale = 2048.0`, `warp_out_scale = 512.0`)
follows the same calibrate-then-lock precedent used elsewhere, but the
anchors are also provisional by design — 2^11 is a placeholder for "flown-tier cost per wall
second exceeds budget," a number that needs measurement this phase didn't
do. The band width matters more than the exact anchors right now: at
octave-quantized user input, any band narrower than two octaves lets a
single-octave toggle land exactly on an edge and thrash — and every
crossing costs a corrector pair. Phase 25 established, for a different
system, that hysteresis bands built on *physical* state inject secular
energy at the changeover (Hernandez-Dehnen 2023) and replaced them with a
stateless predicate. This band is safe under the same rule specifically
because `time_scale` is exogenous user input read from an atomic, never
physical state cloned onto a decision boundary — the per-body WH↔Yoshida4
eligibility hysteresis that *would* violate that rule stays the named M1.x
deferral it already was.

## Proving the composed system, not each mechanism alone

Each mechanism was built and unit-tested standalone; the fixtures below
are the ones that only fail when two mechanisms interact wrong. Five
worker-level acceptance fixtures closed the phase:

| Fixture | What it catches | Measured |
|---|---|---|
| Round trip (warp→flown→warp) | a pre/post-corrector state mixup at either seam | max `\|ΔE/E\|` 8.60e-15 vs derived bound 3.2e-13 |
| Band thrash (6 cycles) | unbounded degradation under repeated crossings | 12 transitions exactly, `\|ΔE/E\|` 2.17e-14 vs 1.12e-12 bound |
| Peek bit-identity | a leaked C⁻¹ hiding inside a tolerance | `==` at both the warp-frame publish and the post-exit export |
| Boosted-frame COM (v_com ≠ 0) | a frozen k=1 row (the corrector's own carve-out, unverified) | position residual 3.05e-5 m vs a frozen-COM miss of ~1e5 m — roughly eight orders of margin |
| Queued mid-warp mutation | the maneuver flag patching the live session in place | matched a standalone export→mutate→re-enter reference bit-for-bit |

All five ran green against that code on the first correct assertion —
test-only work that stayed test-only. The COM fixture is
worth dwelling on because energy checks are translation-invariant and would
never have caught a frozen COM row: only a position assertion can, which is
why it's a position check and not an energy check.

## Determinism and test counts

`nbody_force.cpp` stayed byte-unchanged across the phase; the new
`hjs_handoff.cpp` translation unit is libm-free by construction — its only
undefined symbols are `kepler_step`, `hjs_map_kick`, `b2g`, and `g2b`, no
`std::sqrt`/`pow`/`cbrt` anywhere, checked by a comment-stripped grep gate.
Test counts grew in three steps across the phase: 499/499 → 511/511 →
516/516 (Release); 495/495 → 507/507 → 512/512 (Debug). A fresh
full-suite run the same day reached Release 537/537, Debug 533/533. The
`[hjs_handoff]` family alone: 21 cases / 181 assertions, green in both
configs.

## Where it is now (drift since 2026-07-09)

- **2026-07-10, a gate finding:** a comment-only correction to
  `hjs_handoff.hpp`'s header — the "THE ONLY path out" / "no OTHER path"
  wording was an absolute claim the same-day corrector-gating amendment
  had already made partially untrue (the nested-ladder path exits via
  bare `g2b`, not through the corrector-wrapped function at all).
  Restated as scoped to the corrector-wrapped, trivial-ladder path
  specifically. Zero object-code change (verified by section-hash
  comparison).
- **M0.8 gate fix (2026-07-13):** `warp_synchronize_peek()`
  was exporting ST94 pseudo-velocities as true velocities to render/telemetry
  whenever post-Newtonian correction was enabled during warp (positions
  unaffected; velocity relative error ~1.6e-8, ~0.004 m/s). Fixed by
  extracting a shared `export_warp_session(out, convert_pn)` that converts
  pseudo→true on a scratch copy before the same `hjs_warp_export`/`g2b` call
  this phase built — the const-export discipline Phase 39 established is
  exactly what made the fix a copy-and-convert rather than a live-session
  patch.
- **M1.1 Phase 51 (2026-07-20, craft warp):** the ctor guard that rejected
  every test-particle-bearing hierarchical seed — the deferral this phase
  logged — was narrowed to admit exactly one `FeelOnly` craft test
  particle riding
  the hierarchy; `warp_enter_session`/`warp_exit_session`/`export_warp_session`
  had their loops re-bound from "every slot" to `hjs_tree_.n_bodies`
  specifically so the craft's own conic-drift row at `n_active` is never
  clobbered by the tree-only write-back on exit.
- **M1.1 Phase 52 (2026-07-21):** the WARP arm gained an
  attitude sub-path (FRB rigid-body precompute at session entry, `O(1)`
  step) that runs alongside the position conic when a craft has attitude
  control; the hold-to-exit input path reuses `warp_exit_session` verbatim
  — zero new call sites, the counter Phase 39 built is the only trigger a
  new consumer needed.
- As of 2026-07-21, `hjs_handoff.{hpp,cpp}` themselves are unchanged since
  the comment-only doc fix noted above — every subsequent touch has landed in
  `physics_worker_thread.cpp`'s warp session, which this phase's boundary
  functions still gate.

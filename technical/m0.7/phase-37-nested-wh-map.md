# M0.7 Phase 37 — Nested WH Map: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on
> 2026-07-01**; the drift section traces the map through Phases 38–40,
> the M0.8 J2/1PN additions, and Phase 51's craft-warp narrowing.

## Starting point

M0.6 shipped `wh_perturbation_eligible` (Phase 31), a gate that correctly
*rejects* the flat heliocentric Wisdom-Holman map for the shipped
Sun/Earth/Moon/Mars/Jupiter seed: the Earth-Moon pair measures η ≈ 0.40,
almost 40× past the η² = 1.0e-4 ceiling, because a heliocentric split has
no way to represent a body bound to something other than the Sun. Phase 36
built the machinery the flat map can't have — a hierarchical-Jacobi tree
(`HjsTree`) with `b2g`/`g2b` transforms that diagonalize kinetic energy
per orbit — but that phase shipped no integrator: the tree round-trips
state, it doesn't advance it.

Phase 37 turns the tree into a map, locking the shape before any code: a
standalone `hjs_map` translation unit (mirroring Phase 36's precedent of
landing coordinate machinery before any live wiring); a fresh,
self-contained interaction-kick kernel rather than reusing
`nbody_force.cpp` (H_B is the all-pairs force *minus* the per-orbit
self-term the drift already carries, so reusing the locked kernel would
double-count it); a plain 2nd-order KDK composition with no symplectic
corrector (the corrector is Phase 39's job, at the warp↔flown handoff
boundary, not inside the bare map); and two metrics left to engineering
judgment — a loose energy-bound demonstration over a few Moon periods and
a derived (not bit-exact) reversibility tolerance, with the formal
Brouwer-√t property suite deferred to Phase 40.

## What was built

### The KDK map + structural probes

`hjs_map.hpp`/`hjs_map.cpp` split the HJS Hamiltonian per Beust (2003) A&A
400, 1129 eqs. 16–17. `H_A` (the drift) is one independent Kepler problem
per real orbit `k`, exactly solved by the M0.5 `kepler_step` reused
verbatim at `G·M_k = G·(η_k + μ_k)`:

```cpp
for (int k = 2; k <= N; ++k) {   // real orbits only (k=1 done above).
    const double gm_k = G * (tree.eta[k] + tree.mu[k]);
    const KeplerState ks = kepler_step(xj_scratch[k], vj_scratch[k], dt, gm_k);
    xj_scratch[k] = ks.x;
    vj_scratch[k] = ks.v;
}
```

The COM orbit (`k=1`) gets no Kepler drift — it free-translates,
`xj[1] += vj[1]·dt` — because it carries no gravitational parameter of its
own.

`H_B` (the kick) is the all-pairs barycentric Newtonian potential minus the
per-orbit self-term H_A already integrates. It reconstructs barycentric
positions from the Jacobi state via the `umat` forward fold (the same
closed-form inverse `g2b` uses), accumulates each body's acceleration in
ascending-index left-fold order (mirroring the same summation-order lock
from Phase 36), maps that acceleration forward into each orbit's Jacobi
row with the same `mat` fold the position transform uses (accelerations
transform like positions — Beust eq. 12 is linear with constant-mass
coefficients), then subtracts the self-term:

```cpp
// Step 4: subtract the self-term Kepler acceleration the drift carries:
//   a'_self,k = −G·(η_k+μ_k)·r'_k/|r'_k|³.
const Vec3f64 rk = xj[k];
const double rk2 = rk.dot(rk);
Vec3f64 a_self{0.0, 0.0, 0.0};
if (rk2 > 0.0) {
    const double inv_rk3 = 1.0 / (rk2 * det_sqrt(rk2));
    const double gmk = G * (tree.eta[k] + tree.mu[k]);
    a_self = (-gmk * inv_rk3) * rk;
}
const Vec3f64 a_kick = a_orbit - a_self;
vj[k] = vj[k] + a_kick * dt;
```

For a single real orbit (an all-massive two-body config) the only pair
force *is* the orbit's own self-term, so `a_orbit == a_self` and the kick
is identically zero. `hjs_map_step` is **KDK**, not DKD, specifically so
this collapses cleanly: `kick(0)·kepler_step(dt)·kick(0)` reduces to one
`kepler_step(dt)` call, giving the same cheap structural probe the flat
`wh_step` uses (Phase 24) — a wrong Hamiltonian split shows up as a
single-step mismatch, not a multi-period energy hunt. The lone distance
root (`1/r³ = 1/(r²·√r²)`) routes through the canonical `det_sqrt`, never
`std::sqrt` — the whole TU is `+,−,×,÷` only, no libm.

The two-body collapse probe and the eq-17-kick-is-zero probe pin exactly
this; a third probe drifts two distinct real orbits with different `η+μ`
and confirms each advances by its own `kepler_step` call, bit-for-bit,
while the COM orbit stays untouched.

### The bound-Moon seed + correctness probes

`hjs_map_seed.hpp` builds the headline validation config: Sun (1kg-scale
mass 1.989e30), Earth (5.972e24), Moon (7.342e22), with the Moon bound to
Earth at 3.84e8 m and ~1 km/s *relative* velocity — the inverse geometry of
the M0.6 rejection. The declared tree is two real orbits: `orbit2`
(Earth-Moon) and `orbit3` (Sun-EMB). A circular relative Earth-Moon speed
and a circular EMB heliocentric speed derive the initial conditions from
the masses, so an edit to a mass re-derives the geometry instead of
drifting out of sync with a hardcoded velocity.

Four correctness probes ran on this seed:

- **Bound-Moon headline** (the inverse of the M0.6 rejection): over 3 Moon
  periods (600 steps at 200 steps/period, ≈1.8° of lunar phase per step)
  the Earth-Moon separation stays inside a 0.75–1.25× band around the seed
  radius — neither collapsing into Earth nor escaping to heliocentric
  distance — while the EMB's heliocentric radius stays within 5% of its
  seed value and its angular position sweeps more than 10% of `a_EMB` away
  from where it started. The Moon stays bound; the EMB visibly orbits the
  Sun.
- **Energy demonstration:** barycentric total energy (the same
  oracle every N-body lock uses, run on the `g2b` output — not an
  HJS-frame energy) stayed bounded at max `|ΔE/E| = 6.7e-11`, four orders
  below the 1e-4 demonstration ceiling, with a near-zero least-squares
  slope against step index — bounded oscillation, not a ramp.
- **Reversibility:** forward `N` steps then backward `N` (`dt → −dt`)
  returns within `N·1e-10` — the same per-step reversal floor the M0.5
  `test_trigger_reversibility` lock established for the fixed-iteration
  universal-variable Kepler corrector, which is not bit-reversible. The
  measured residual sits an order inside that floor (~1e-12/step),
  clearing a derived tolerance rather than an arbitrary one.
- **TP consistency**: a massless test-particle orbit sources no kick and
  stays finite (guarded so a `1/m'_k` division never fires on a massless
  orbit).

467/467 Release ctest green, `nbody_force.cpp` diff-clean, no libm symbol
in the compiled `hjs_map.cpp.o` beyond the TU's own
`kepler_step`/`b2g`/`g2b`/`det_sqrt`.

### Seven findings, fixed in-phase

A review finding closes in the phase that surfaced it, not the next
one — seven landed here:

- **COM row frozen, not free-translating** (High). The drift
  loop started at `k=2` and never advanced the `k=1` COM row, so any system
  with nonzero net momentum had its center of mass pinned in place —
  bit-exact in the barycentric COM frame (where `xj[1]=vj[1]=0`), but
  wrong under a boosted input frame, which is exactly the frame the
  Phase-39 warp↔flown handoff needs. Fixed by advancing `xj[1] += vj[1]·dt`
  before the per-orbit loop; a new boosted-frame probe asserts the COM
  moves by `V_com·dt`.
- **Degenerate massless orbits Kepler-drifted anyway** (High).
  A companion bug: the drift advanced every real orbit including ones with
  `m'_k == 0`, whose Jacobi row the Phase-36 transform never faithfully
  encodes (`mat[k][sat]` is guarded to 0 when `μ_k == 0`). Fixed by
  skipping the drift on a degenerate orbit, mirroring the kick's existing
  no-kick guard so drift and kick treat degeneracy identically.
- **Missing scratch-precondition asserts** (Medium). The header
  promised the caller-owned scratch buffers were checked under
  `INTERSTELLAR_TESTING` — non-null, correctly sized, non-aliasing — but
  the implementation asserted none of it. Added the promised asserts plus
  a release-mode null-guard that degrades to a no-op instead of a null
  deref.
- **Massless body lost across the `b2g`→`g2b` round-trip** (High). A test
  particle is absent from every Jacobi coordinate, so `g2b`
  had nothing to reconstruct it from and collapsed it to the origin —
  silent corruption even though the drift already skipped its degenerate
  orbit. Fixed by snapshotting every massless body's barycentric state
  before the transform and restoring it after `g2b`.
- **Two independent oversized-N OOB paths** (both High). `hjs_map_step`
  checked `N <= kHjsMaxBodies` only under
  `INTERSTELLAR_TESTING`; a release build with a malformed oversized tree
  indexed the fixed-capacity `xb_massless[33]`/`umat[33][33]` arrays out of
  bounds. `valid()` itself had the same gap in its own bitmask arrays —
  the exact predicate a caller uses to gate the step. Both got an
  unconditional `N > kHjsMaxBodies` reject, purely additive (no valid
  tree, `N <= 32`, changes verdict).
- **Non-finite separations silently swallowed** (High). The kick
  guarded `if (!(r2 > 0.0)) continue`, collapsing a genuinely singular
  coincident pair (`r2 == 0`) and an already-corrupt NaN separation into
  the same spurious zero-force outcome — finite-but-wrong, with nothing
  downstream able to see the corruption. Removed the guard so both cases
  propagate (`det_sqrt` mirrors `std::sqrt`'s specials: `±0→±0`,
  `NaN→NaN`, `+Inf→+Inf`), matching the special-value stance already
  locked in `nbody_force.cpp` verbatim.
- **TP contract finalized as an explicit predicate** (High). The interim
  fix for the massless-body-lost finding
  refused a TP tree with a bare early `return` — but `valid()` still
  admitted it and the header still promised a massless-TP collapse to
  `kepler_step` that never happened: a silent, unqueryable contradiction.
  Landed as `hjs_map_eligible(tree)`, mirroring the M0.6
  `wh_perturbation_eligible` precedent — false for any massless body,
  degenerate massless orbit, or out-of-range size; true for all-massive.
  `hjs_map_step` gates on it explicitly; both sides are pinned (Probe 1
  `REQUIRE(eligible)`, Probes 7/7b `REQUIRE_FALSE`).

A separate housekeeping commit untracked the branch's background
worktrees, which had been accidentally staged as embedded gitlinks, and
added a `.worktrees/` ignore rule.

## Why it was built this way

- **KDK over DKD, again.** The same reasoning Phase 24 used for the flat
  map applies here: KDK makes the full drift a single `kepler_step(dt)`
  call, so the two-body case collapses to it exactly — a bit-exact
  structural probe that DKD's independently-rounded half-drifts can't
  give you.
- **A fresh kick kernel, not `nbody_force.cpp` reuse.** H_B is the
  all-pairs force *minus* the self-term the drift carries — not a plain
  N-body force — so calling the locked kernel would double-count the
  self-term. Writing a dedicated kernel keeps `nbody_force.cpp`'s diff
  empty and makes the subtraction auditable term-by-term against Beust
  eq. 17.
- **Refuse, don't silently freeze.** Every TP-handling attempt before the
  final one either silently skipped the drift or silently restored the
  barycentric state — both leave a caller believing the step ran when it
  didn't. `hjs_map_eligible` makes the refusal a queryable contract
  instead of a trap.
- **Loose bound now, formal suite later.** The energy-bound demonstration
  and the derived-tolerance reversibility check stand in for the formal
  Brouwer-√t property suite Phase 40 delivers — enough to catch a leaking
  split now, without duplicating Phase 40's scope.

## Where it is now (drift since 2026-07-01)

- **2026-07-01, same day:** the massless-TP deferral was promoted
  from an in-code comment to a named blocker ("HJS map TP handling
  finalized") — the concrete missing machinery (the Phase-36
  TP-coordinate/drift tier is unbuilt) that a legal deferral requires.
- **2026-07-09, Phase 38:** the flat inline half-kick/drift/half-kick
  sequence this phase shipped became one level of a recursive DLL98
  cadence ladder (`execute_ladder`); each real edge carries a declared
  static period, and with all cadences at 1 the nested path is
  bit-identical to this phase's step.
- **2026-07-09, Phase 39:** the Jacobi interior was extracted into
  `hjs_map_step_jacobi` for the warp session, and `hjs_map_kick` — this
  phase's `INTERSTELLAR_TESTING`-only probe seam — was promoted to the
  production ABI as the Phase-39 handoff corrector's B operator. The
  module stopped being the standalone translation unit this phase
  shipped: it is now wired into the worker's live warp tier.
- **2026-07-09, Phase 40:** `hjs_map_eligible` gained a `valid(tree)`
  conjunct, closing a gap this phase's predicate left open — a
  hand-built, structurally invalid tree could still be all-massive and
  pass eligibility, integrating garbage silently.
- **2026-07-13, M0.8 Phases 44/45:** the kick gained a J2 oblateness term
  and the drift gained ST94 1PN γ/α operations, both threaded through
  optional parameters (`OblatenessTable`, `PnParams`) that default to
  empty/disabled — every all-massive Phase-37 seed config stays
  byte-identical.
- **2026-07-20, Phase 51:** the TP-in-warp deferral this phase logged
  was narrowed and closed for the single-craft coasting case — a lone
  test-particle craft rides the warp tier via a per-step re-keyed Kepler
  drift about its dominant body, not the HJS map itself. The general
  multi-TP tier this phase deferred remains unbuilt.
- As of 2026-07-21 the KDK composition, the eq-17 kick fold order, and the
  barycentric in/out boundary contract from this phase are unchanged;
  `hjs_map.cpp` has grown from the 295 lines this phase shipped to over
  750, carrying the ladder executor, the J2 kick term, and the 1PN
  drift/kick terms on top of the core built here.

# M0.7 Phase 36 — HJS Coordinate Core: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on
> 2026-07-01**; the drift section traces `hjs_coords.{hpp,cpp}` through
> today's stack.

## Starting point

M0.6's perturbation-ratio gate (Phase 31) found the full Sun/Earth/Moon/
Mars/Jupiter seed fails heliocentric Wisdom-Holman at η≈0.40 — the
Earth-Moon pair is a bound satellite, and heliocentric WH's small-
interaction premise doesn't hold for it. M0.7 answers that with a nested
integrator: detect the bound subsystems, build a hierarchy tree, and solve
each piece exactly at its own scale (Moon→Earth, Galileans→Jupiter,
clumps→Sun). Phase 36 is the coordinate layer everything else in the
milestone runs on — the hierarchical-Jacobi (HJS, Beust 2003 A&A 400, 1129
§2.3) tree representation and the barycentric↔Jacobi transforms. No
Kepler drift, no KDK map, no handoff: the phase is correct iff coordinates
round-trip bit-clean and the kinetic energy diagonalizes.

## The tree is declared, not hand-built

`HjsOrbitSpec` is a per-orbit centers/satellites set of body indices; the
caller fills one per real Jacobi orbit and `build_tree` compiles the set
into the `oloc(orbit k, body i) ∈ {+1 sat, −1 ctr, 0}` matrix
(`engine/include/interstellar/physics/hjs_coords.hpp`):

```cpp
struct HjsOrbitSpec {
    int centers   [kHjsMaxBodies];
    int n_centers;
    int satellites[kHjsMaxBodies];
    int n_satellites;
};
```

The seed's tree is one data literal — inner orbits `{C={Earth},S={Moon}}`
and `{C={Jupiter},S={Io,Europa,Ganymede,Callisto}}`, outer orbits grouping
the EMB-clump, Jupiter-clump, and Mars around `{C={Sun}}` — exactly N−1
real orbits plus the dummy COM orbit at k=1. `HjsTree` stores `oloc` dense
at `[kHjsMaxBodies+1][kHjsMaxBodies+1]` — an O(N) tree-walk was the
broader research note's first suggestion, but a dense N×N matrix is both
simpler and the bit-exact-against-ODEA choice at the seed's small N.

## Forward matrix, closed-form inverse

`build_tree` computes mass aggregates in ascending index order — η_k
(center-set mass), μ_k (satellite-set mass), and the reduced mass
`m'_k = η_k·μ_k/(η_k+μ_k)` — then the forward matrix per Beust eq. 13:

```cpp
for (int i = 1; i <= N; ++i) {
    if (t.mtot != 0.0) t.mat[1][i] = t.m[i] / t.mtot;
    for (int k = 2; k <= N; ++k) {
        if (t.oloc[k][i] == +1) {
            t.mat[k][i] = (t.mu[k] != 0.0) ? (+t.m[i] / t.mu[k]) : 0.0;
        } else if (t.oloc[k][i] == -1) {
            t.mat[k][i] = (t.eta[k] != 0.0) ? (-t.m[i] / t.eta[k]) : 0.0;
        }
    }
}
```

The inverse `umat` is never a numerical inversion of `mat` — it's built in
closed form, `vsat = η_k/(μ_k+η_k)`, `vcen = −μ_k/(μ_k+η_k)`:

```cpp
const double vsat =  t.eta[k] / sum;
const double vcen = -t.mu[k]  / sum;
if      (t.oloc[k][i] == +1) t.umat[i][k] = vsat;
else if (t.oloc[k][i] == -1) t.umat[i][k] = vcen;
```

This is what makes `g2b(b2g(x))==x` bit-clean instead of accumulating
inversion rounding error into every downstream phase.

## Velocity uses the same matrix — the porting trap

Beust eq. 12 is linear with constant-mass coefficients, so `b2g`/`g2b`
apply `mat`/`umat` identically to position and velocity. The paper's
`(M⁻¹)ᵀ` in eq. 13 is for conjugate *momenta* `p = m·v` — a different
vector — and building a transposed-inverse matrix for velocity is the
canonical way an HJS port goes wrong. `g2b` also generalizes to fold
`k=1..N` rather than ODEA's `k=2..N`:

```cpp
for (int k = 1; k <= N; ++k) {             // ascending k=1..N (D-05)
    const double c = tree.umat[i][k];
    if (c != 0.0) {                         // sparsity skip (bit-identical)
        xacc = xacc + xj[k] * c;
```

ODEA's `coord_g2b.f` starts at `j=2` because its caller always works in a
COM frame where `x'_1=0`; including the k=1 term makes `g2b` a general
inverse that round-trips correctly for arbitrary input frames, needed for
the property suite's arbitrary-frame sweep.

Every mass-weighted accumulation folds in ascending body index —
IEEE-754 addition isn't associative, and replicating ODEA's exact order is
the cross-language bit-identity contract the golden diff later verifies.
The `!= 0.0` sparsity skip used throughout is a no-op in bits (`x+0.0==x`
for finite x), so it changes fold cost, never fold result.

## The tree invariant is combinatorial, not numerical

`valid()` never touches a float. For each real orbit k, body set
`B_k = C_k ∪ S_k` as a bitmask; the predicate requires every real-orbit
pair to be exactly one of foreign (`B_k ∩ B_l = ∅`), inner k→l
(`B_k ⊆ C_l` or `B_k ⊆ S_l`), or inner l→k:

```cpp
const bool foreign_kl    = (b_set[k] & b_set[l]) == 0u;
const bool inner_k_to_l  = ((b_set[k] & c_set[l]) == b_set[k]) ||
                           ((b_set[k] & s_set[l]) == b_set[k]);
const bool inner_l_to_k  = ((b_set[l] & c_set[k]) == b_set[l]) ||
                           ((b_set[l] & s_set[k]) == b_set[l]);
```

plus `#real orbits == N−1`, every `C_k`/`S_k` non-empty and disjoint, and
the root orbit's `B` covering all N bodies. An invalid tree is rejected
here, never silently mis-integrated downstream.

## Test particles fall out of the same formula

The engine already carries a massless test-particle tier from M0.5; HJS
coordinates have to stay consistent with it. A TP's mass is 0, so it
contributes nothing to any orbit's η/μ — the real orbit's denominator
stays positive as long as its massive members do. No TP branch is needed
on the hot path; the `!= 0.0` sparsity skip already handles the zero
column. The guard that exists is defensive, for the degenerate case
where an *entire* center or satellite set is massless (which `valid()`
should have already rejected):

```cpp
const double denom = eta_acc + mu_acc;
if (denom != 0.0) {
    t.m_reduced[k] = (eta_acc * mu_acc) / denom;
} else {
    t.m_reduced[k] = 0.0;
}
```

## Analytic identities plus a golden that wasn't real yet

The primary math-lock is four analytic properties over ~10,000
constructed-valid random trees (fixed seed, changed only with independent
re-verification): P1 round-trip within a derived ULP bound `C=4N`; P2
KE-diagonalization `K = M·diag(1/m)·Mᵀ` with off-diagonals bounded and
`K_kk=1/m'_k`; P3 the load-bearing iff — `valid()` and "K is diagonal"
agree on every sampled tree; P4 a 3-body crossing-chain negative control
where both correctly disagree with a well-formed tree. Alongside those, a
one-time ODEA golden (`hjs_odea_golden.hpp`) was committed diffing `b2g`'s
forward output bit-for-bit — but as landed, that golden was a
**self-consistency pin**: numbers captured from the C++ implementation
itself, with the real Fortran cross-check documented as a not-yet-run
recipe. The round-trip property (P1) is what carried correctness
confidence at this point; the golden test proved the implementation was
stable against itself, not yet against an independent oracle. The
independent Fortran cross-check followed nine days later (see the drift
section).

## Where it is now (drift since 2026-07-01)

- **Phase 38 (2026-07-09):** `HjsOrbitSpec` gained a declared per-edge
  `period` field, and `HjsTree` gained a parallel `period[]` array plus a
  `sep[i][j]` table (the unique separating orbit for each body pair,
  compiled from `oloc` alone) — both consumed only by the nested-stepping
  ladder; `valid()` stays mass/period-independent.
- **Phase 40 (2026-07-09):** the determinism contract landed as a header
  block on `hjs_coords.hpp`, formally pinning the ascending fold order,
  same-matrix-for-velocity, closed-form umat, and the Jacobi-not-DHC
  convention — mirroring the equivalent contract block already on
  `nbody_force.cpp`.
- **A later gate finding (2026-07-10):** the independent-oracle check
  promised earlier finally ran — LaRodet/ODEA `coord_b2g.f` +
  `io_init_pl_hjs.f` built under gfortran 16.1.1, diffed against the C++
  `b2g` output on the exact 9-body seed. Measured: every real Jacobi orbit
  (k=2..9, position and velocity) is byte-identical to ODEA, **0 ULP**
  deviation; the only difference is the k=1 dummy-COM row, where ODEA
  forces `xj(1)=0` in its COM-frame caller and this implementation computes
  the true COM so `g2b` stays a general inverse — a documented convention
  choice, not a fold-order mismatch. The full diff recipe and raw hex
  captures were preserved for anyone wanting to rerun the comparison.
- **A second gate finding (2026-07-10):** `build_tree` scattered into
  its fixed `[kHjsMaxBodies+1]` arrays using the raw `n_bodies`, per-spec
  `k=r+2`, and raw 1-based body indices with no range check — an
  oversized or out-of-range shape wrote out of bounds (ASan/UBSan
  stack-buffer-overflow) *before* `valid()` ever ran. An entry bounds guard
  now returns a zeroed (`valid()==false`) tree for any such shape;
  well-formed trees are byte-identical.
- **A third gate finding (2026-07-10):** a
  `static_assert(std::numeric_limits<double>::is_iec559)` was added,
  turning the all-bits-zero `memset` zero-init `build_tree` relies on from
  a silent representation assumption into an enforced compile-time
  contract.
- As of 2026-07-21, `hjs_coords.{hpp,cpp}` is unchanged since gate close —
  the coordinate core every later M0.7 phase (map, nesting, handoff) and
  the shipped nested seed run on is this phase's tree/transform pair, plus
  the bounds guard and IEC-559 assert.

# M0.8 Phase 45 — 1PN Post-Newtonian Corrections: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-12**; a
> drift section at the end traces the kernel through its post-close fix
> round and Phase 46/46.1's production flip.

## Starting point

Phase 44 landed J2 oblateness the same milestone — a per-body catalog
term threaded through the WH flat kick, the HJS nested kick, and the
worker's direct-force callback, off-path bit-identical by construction.
Phase 45 owes the other perturbation-fidelity promise: general
relativity's first-order correction to Newtonian gravity, without which
Mercury's perihelion advances at the wrong rate and DE441 comparisons
carry a systematic bias no milestone had closed.

"Add 1PN" is not one design: REBOUNDx alone ships three incompatible
tiers (`gr_potential`, `gr`, `gr_full`) with different
accuracy/cost/determinism trade-offs, and the engine's WH/HJS kick sites
are position-only by construction (`hjs_map.hpp:38`), while 1PN is
inherently velocity-dependent. A fidelity bar was locked before any
formulation was picked: both mean motion and precession must land right,
rejecting the cheap precession-only `gr_potential` class as a shipped
mode. The candidate comparison below had to be ratified before
implementation began. Six plans, all landing 2026-07-12 (the 1000-yr
Mercury harness is Phase 46's job).

## The formulation: an exact rearrangement, not an approximation

Four candidates were compared against that fidelity bar using primary
sources — the ST94 paper, orbitN 1.0.1 source, REBOUNDx `gr.c`, Moyer's
DESCANSO EIH reference, NIST CODATA — recommending the **Saha & Tremaine
1994 §5 explicit three-term split** of the dominant-mass 1PN Hamiltonian,
the same scheme orbitN ships. Ratified 2026-07-12, rejecting full
pairwise EIH (`O(N²)` cost for `≲1e-3×` gain on a `1e-8` effect) and
`gr_potential` (mean-motion bias by construction).

The split works because `H_PN` factors into three independently
integrable pieces:

```
H_PN = α·H²_Kep + β/r² + γ·p⁴,   α = 3/(2mc²), β = −μ²m/c², γ = −1/(2m³c²)
```

Per unit mass, with `ṽ` the pseudo-velocity (`ṽ = p/m`):

1. `β/r²` → a position-only radial **kick**: `a_β = −2μ²/(c²r⁴)·x` (zero
   new roots — `r⁴ = (r²)²`).
2. `γ·p⁴` → a position-only "gamma" **drift** shift, applied as two half
   operations bracketing the Kepler drift: `Δx = −(h/c²)(ṽ·ṽ)ṽ` per half.
3. `α·H²_Kep` → a **rescale of the drift's own dt**:
   `dt_pn = dt·(1 − 3μ/(2c²a))`, where `μ/a = 2μ/r − ṽ²` is the
   (conserved) vis-viva factor, so evaluating it pre-drift is exact.

The α-term is the mean-motion fix — exactly the term `gr_potential`
omits, which is why that class biases mean motion by `O(GM/ac²)`. Because
the ST94 split integrates the Kepler-Hamiltonian piece through the
drift's own exact solution rather than approximating it, there is no
mean-motion error to begin with; that's what "exact rearrangement, not
approximation" means concretely. IAS15 and the other non-symplectic
direct tiers don't need any of this rebracketing — they evaluate forces
at predictor nodes natively, so they use the equivalent
Anderson-1975/Schwarzschild direct EOM instead:
`a_1PN = (μ/(c²r³))·[(4μ/r − v²)x + 4(x·v)v]`.

Determinism (explicit-only preferred) rules out REBOUNDx's `gr`-style
implicit velocity solve, whose epsilon-exit convergence loop has a
data-dependent trip count. The one iterative piece that remains —
converting a true velocity into ST94's pseudo-velocity — gets the same
treatment Phase 23's Kepler solver already established: a **pinned fixed
count**, not an epsilon exit.

## What was built

### The kernel

`pn_force.hpp`/`pn_force.cpp` is the single canonical 1PN arithmetic
definition every tier links against — no per-tier hand copies, mirroring
the `det_sqrt` single-definition contract from M0.5. Six primitives,
transcribed from the published ST94 equations 26/27/29/30/31 and the
Anderson PPN form — never from orbitN or REBOUNDx source, both GPL
(clean-room provenance):

```cpp
coords::Vec3f64 pn_beta_kick_accel(coords::Vec3f64 x, double mu, double c2) noexcept {
    const double r2 = x.dot(x);
    const double inv_r4 = 1.0 / (r2 * r2);
    const double coef = -2.0 * mu * mu * inv_r4 / c2;   // −2μ²/(c²r⁴)
    return coef * x;
}

coords::Vec3f64 pn_gamma_half_shift(coords::Vec3f64 v_tilde, double h, double c2) noexcept {
    const double v2 = v_tilde.dot(v_tilde);
    const double fac = -(h / c2) * v2;
    return fac * v_tilde;
}

double pn_drift_dt(coords::Vec3f64 x, coords::Vec3f64 v_tilde, double mu,
                   double dt, double c2) noexcept {
    const double r = det_sqrt(x.dot(x));
    const double beta = 2.0 * mu / r - v_tilde.dot(v_tilde);   // μ/a by vis-viva
    return dt * (1.0 - 1.5 * beta / c2);
}
```

The true→pseudo conversion (ST94 eq. 31) is the one place with a loop,
and it's the same pinned-iteration idiom verbatim — `kPnPseudoVelIterations
= 8`, no epsilon exit, each sweep rescaling the *original* `v` (not the
running iterate) by a freshly recomputed factor:

```cpp
coords::Vec3f64 pn_true_to_pseudo(coords::Vec3f64 v, coords::Vec3f64 x,
                                  double mu, double c2) noexcept {
    const double r = det_sqrt(x.dot(x));
    const double tmp = 3.0 * mu / r;
    coords::Vec3f64 v_tilde = v;
    for (int i = 0; i < kPnPseudoVelIterations; ++i) {
        const double f = 1.0 / (1.0 - (0.5 * v_tilde.dot(v_tilde) + tmp) / c2);
        v_tilde = v * f;
    }
    return v_tilde;
}
```

The contraction factor is `~v²/c² ≈ 2.6e-8` for Mercury, so 8 sweeps sit
bit-stationary with room to spare. The reverse direction (pseudo→true) is
closed-form — zero iteration. Every primitive is libm-free but for a
single `det_sqrt` where a distance root is unavoidable (`nm -u -C`
verified no other libm symbol in the compiled TU). `PnParams{bool
enabled=false; double c2=C2_LIGHT}` is the config POD, `C_LIGHT` /
`C2_LIGHT` are CODATA-2022 (`299792458.0` m/s), and `enabled=false` is a
structural skip everywhere it's read — the same idiom Phase 44's J2
table used. Full suite green at 591/591 Release; `nbody_force.cpp` diff
empty.

### WH flat-tier entry

The β kick lands as a *separate* additive pass immediately after
`interaction_kick` and `oblateness_kick` at both half-kick sites — pinned
order Newtonian → J2 → 1PN, ascending slot — exempting the dominant body
(it anchors the democratic-heliocentric frame and never itself drifts):

```cpp
void pn_beta_kick(std::span<State> helio, std::size_t dom, double mu_dom,
                  double half, double c2) noexcept {
    for (std::size_t i = 0; i < helio.size(); ++i) {
        if (i == dom) continue;  // dominant slot exempt (frame anchor, no drift).
        helio[i].v = helio[i].v + pn_beta_kick_accel(helio[i].r, mu_dom, c2) * half;
    }
}
```

γ and α live in the *drift slot*, bracketing each non-dominant body's
`kepler_step` — `gamma_half → kepler_step(dt_pn) → gamma_half`, the same
species of operation as WH's existing `H_jump` — under `enabled==false`
skipping the whole bracket. This threading shape (a trailing defaulted
`PnParams pn = {}` on the existing 8-argument `wh_step` overload, not a
new overload) means every pre-Phase-45 call site is untouched and
byte-identical by construction; downstream plans mirror it verbatim.
Measured on a Sun+Mercury 2-body WH tier, `dt = period/4000`, 12 orbits,
osculating-element apsidal fit: the PN-on advance matches the Einstein
closed form `6πμ/(c²a(1−e²))` to the displayed 6 significant figures
(`5.01859e-07` rad/orbit both ways), against a PN-off floor of
`~6.66e-16` rad/orbit — pure Kepler-solver noise. Full suite 595/595.

### HJS nested-tier entry

Structurally different from J2's placement. J2's oblateness term rides
the inertial-frame Step-2b site; the 1PN β kick rides the **Step-4
self-term site** instead — a per-orbit correction on the orbit's own
Jacobi vector, gated by the identical `edge_selected(edge_mask, k)`
cadence the self-term itself uses (the DLL98 partition invariant: β has
to fire at the same V_k cadence as the orbit it corrects, or the split
Hamiltonian silently changes):

```cpp
// Step 6 (M0.8 / Phase 45): the per-orbit 1PN β radial kick, applied AFTER
// the Newtonian a_kick + J2 (Step-2b) fold — pinned order N → J2 → 1PN.
if (pn.enabled && edge_selected(edge_mask, k) && rk2 > 0.0) {
    const double gmk_pn = G * (tree.eta[k] + tree.mu[k]);
    vj[k] = vj[k] + dt * pn_beta_kick_accel(rk, gmk_pn, pn.c2);
}
```

The mass convention here is per-orbit *enclosed* mass, `G·(η_k+μ_k)` —
the same sum the drift and self-term already use for that Jacobi orbit —
not the single global dominant-μ the WH/direct tiers use. That
divergence is a deliberate, documented design point revisited below.
γ/α bracket `drift_all_orbits`'s per-orbit `kepler_step` the same
way as the WH tier, exempting the COM orbit (k=1, which carries no
gravitational parameter). Measured cross-tier: HJS gives
`5.0186e-07` rad/orbit against the WH tier's `5.01859e-07` — the same
dominant-mass dynamics reached through different coordinates. Full suite
601/601.

### Worker enablement + boundary transforms

`PhysicsWorker::Config.pn` (default OFF, ctor-validates `c2`) wires the
direct Anderson EOM into the shared `accel_fn_` that serves IAS15 and
every `step<M>` direct tier uniformly — the same "satisfied-plus" append
pattern Phase 44 used for J2's force term. The harder problem is the
ST94 pseudo-velocity bookkeeping: the WH/HJS tiers *carry* pseudo-
velocity internally between the true↔pseudo boundary conversions, but
`states_` — the buffer every snapshot/telemetry/detector/handoff reader
touches — must stay TRUE velocities at every read.

The transform's placement (per-step vs. per-session) had been left open.
Per-session storage would have made `states_` carry pseudo-velocities
between conversions, which contradicts the snapshot/detector/handoff
readers that all expect true velocities — an internal inconsistency that
didn't surface until the actual reader surface was checked. The
resolution: the WH tier
converts **per-step** around `wh_step` (true→pseudo before, pseudo→true
after); the HJS warp tier converts **per-session** at
`warp_enter_session`/`warp_exit_session`, since the warp session is
itself the natural session boundary. `states_` stays true everywhere —
no `O(v²/c²)` pseudo delta ever reaches a reader. The formulation itself
is unchanged; only this placement sub-decision moved. Full suite
607/607, dominant-selection scan (`select_dominant`) proven PN-invariant
(same `selected_method_index` PN-on vs. off).

### Determinism goldens + structure probes

Four PN-on lanes frozen as hexfloat goldens — WH flat, HJS single-level,
HJS nested, worker direct-EOM — the determinism evidence that a fixed
seed stepped a pinned count always lands on the same bytes. The nested
lane's first capture went all-NaN: hand-set Jacobi initial conditions for
a bound Moon orbit are geometrically inconsistent with the tree hierarchy
(the Moon's Jacobi coordinate sits at roughly Sun-distance, not
Earth-Moon-distance), so the orbit went hyperbolic — exactly the same
trap Phase 44 hit at its own nested seed. Fixed by seeding physical
barycentric initial conditions and `b2g`-transforming to consistent
Jacobi state, the established precedent. Structure probes proved the
η-gate and eligibility predicates take no PN input (PN-on and PN-off
select the identical integrator), and that nested trace event
kinds/cadence are unchanged — 1PN adds no new event kind, γ/α ride inside
the existing drift event and β inside the existing kick event. Full
suite 615/615.

### Math-locks + phase exit gate

The physics evidence that closes the phase: the one-orbit Einstein probe
(calibrate-then-locked at ±15% of the closed form, measured ratio
`1.0000`, with a wrong-gauge tripwire excluding `1/2`, `1/3`, `1/6` of
the closed form — the classic McDonald sign-convention mistakes); the
`1/c²` Newtonian-recovery scaling (deviation shrinks `~4×` per `c²`
quadrupling, banded `[3,5]`); a bounded non-secular `dE/E` lock on the
ST94 PN-Hamiltonian energy (measured max `~9e-14` on WH, `<1e-6` on HJS,
against a `1e-6` ceiling — the Tamayo splitting-health red flag never
trips); and a cross-tier consistency lock between the ST94-WH scheme and
the direct-Anderson EOM (measured `<1e-4` relative on the Sun+Mercury
relative trajectory — the two are the same physics, different schemes).
No 1000-year/arcsec-per-century harness here — that's explicitly Phase
46's job. Phase exit gate green: Release 620/620, the locked kernel
untouched across the whole phase, `ias15_integrator.cpp`/`main.cpp`
diff-empty (no production flip this phase — the ON-flip is Phase 46.1's
job).

## Why it was built this way

- **A rearrangement, not a model swap.** The whole point of ST94 over
  `gr_potential` is that it's algebraically *exact* — the Kepler drift
  already solves the `α·H²_Kep` piece exactly, so there's no mean-motion
  approximation to correct for later. Picking a formulation that folds
  into the existing exact-Kepler machinery, rather than adding a new
  approximate force term, is what makes the fidelity bar achievable
  at all without full EIH's `O(N²)` cost.
- **Kick position-only, always.** `hjs_map.hpp:38`'s kick structure
  predates this phase; ST94 was picked specifically because none of its
  three pieces needs the kick to become velocity-dependent — the β kick
  is position-only, γ/α ride the drift slot instead. A formulation that
  forced a velocity-dependent kick would have been new machinery, not an
  extension.
- **Pinned iteration over epsilon exit, again.** The `kKeplerIterations=8`
  precedent generalizes cleanly here: a data-dependent convergence loop
  (REBOUNDx's `gr.c` epsilon exit) is not bit-reproducible across
  platforms even when it converges to the same physical answer, so the
  fixed-count sweep is the only determinism-compatible shape for a
  velocity-dependent iterative step.
- **states_ stays true, no exceptions.** The per-step/per-session
  boundary placement was a real design fork, but the invariant driving
  the choice wasn't negotiable: every existing consumer of worker state
  (snapshot, telemetry energy, the close-encounter detector, the
  warp/flown handoff) was built assuming true velocities. Carrying
  pseudo-velocity anywhere in that shared buffer, even briefly, risks a
  silent `O(v²/c²)` error leaking into code that has no idea PN exists.

## Where it is now (drift since 2026-07-12)

- **2026-07-13, Phase 46/46.1:** the 1000-year, 2-day-step Mercury
  harness confirmed `42.9807″/cy ± 0.30` on the WH tier built here, and
  Phase 46.1-06 flipped the shipped production seed to
  `PnParams{true, C2_LIGHT}` — Phase 45 itself never changed
  `main.cpp` (the production-ON call landed one phase later, by
  design).
- **A Critical finding (2026-07-13):**
  `warp_synchronize_peek()` exported the live HJS warp session without
  running the pseudo→true conversion this phase's plan-04 established at
  `warp_exit_session` — so a PN-on config publishing a snapshot *while
  still warping* shipped pseudo-velocities to render/telemetry as if they
  were true (positions unaffected; velocity relative error `~1.6e-8`,
  `~0.004 m/s`). Fixed by routing the peek through the same
  `export_warp_session(out, convert_pn)` helper the session-exit path
  uses, never mutating the live session.
- **A High finding (2026-07-13):** the shipped
  direct-tier force law this phase built exempted the dominant body from
  any PN back-reaction, while the DE441 SSB validation harness added a
  momentum-conserving Sun reaction and claimed to validate the shipped
  path — a real discrepancy (`~657 m` Sun-Earth barycenter drift over 50
  years from the production convention's net PN force). Resolved by
  giving production the same back-reaction via one new shared function,
  `apply_pn_dominant_accelerations`, that both the worker and the harness
  now call — no more reimplementation.
- **Another finding (Medium→High severity, 2026-07-13):** named and
  documented, rather than fixed, since it isn't a bug — the HJS tier's
  per-orbit enclosed-mass convention (`G·(η_k+μ_k)`, this phase's Plan
  03) genuinely differs from the WH/direct tiers' single dominant-μ, and
  the gap is now quantified: `0.00134` relative (max, Neptune's orbit) on
  the shipped 14-body seed's Sun-anchored planetary orbits, locked at
  `2e-3` in `test_pn_properties`. Also corrected a misattributed "Zeebe
  convention" code comment (orbitN's own citation uses solar GM, not
  enclosed mass).
- As of 2026-07-21 the six ST94 primitives and the WH/HJS kick-and-drift
  placement built here are unchanged; `pn_force.cpp` has grown from the
  125 lines the kernel shipped with to 178, and `pn_force.hpp` from
  137 to 196 — `apply_pn_dominant_accelerations`, `pn_true_to_pseudo_checked`,
  and the `kPnRoundTripMaxUlp` boundary guard account for the difference.

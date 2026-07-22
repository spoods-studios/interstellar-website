# M0.5 Phase 25 — Predictive Periapsis Estimator: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-15**; the
> drift section traces the trigger through M0.6/M0.7.

## Starting point

M0.4's `detect_regime` (Phase 20) switches to the IAS15 encounter fallback
on a reactive test: is a pair's mutual separation inside `k·R_Hill` *right
now*, sampled once per step endpoint. That test has two structural gaps
this phase closes. First, a fast flyby can plunge to periapsis and exit
again entirely between the step-start and step-end samples — the encounter
never registers. Second, "have we crossed the radius" is not
time-reversible: Hernandez & Dehnen (2023) show a naive reactive switch
disagrees with itself between a forward pass and a flipped-velocity
backward pass over the same trajectory, injecting secular energy error at
every crossing. Phase 25 replaces the predicate — not the seam — with a
step-boundary estimate of closest approach over the *upcoming* step, frozen
at step start, provably symmetric under `v → −v`.

The design locked: the estimator is a closed-form two-body conic periapsis,
not a ballistic line or a kepler-step sample (the phase's correctness
crux); the new predicate (`detect_regime_predictive`) is stateless — no
`prior`, no history, a fixed pad the sole anti-chatter margin, since a
historyful band is exactly the reversibility hazard the paper names; the
M0.4 reactive `detect_regime` stays untouched as the negative control. All
of it landed 2026-06-15.

## What was built

### The closed-form periapsis estimator

`predicted_periapsis(r, v, mu)` computes the conic periapsis `q = p/(1+e)`
from step-start relative state, using only the conserved two-body scalars:

```cpp
const double r2 = r.dot(r);
const double v2 = v.dot(v);
const double rv = r.dot(v);
const double r1 = peri_det_sqrt(r2);
// h² via the Lagrange identity — rv enters ONLY as rv*rv, so q is EXACTLY
// invariant under v → −v (the reversibility primitive the trigger depends on).
const double h2 = r2 * v2 - rv * rv;
const double eps = 0.5 * v2 - mu / r1;
const double p = h2 / mu;
double e2 = 1.0 + 2.0 * eps * h2 / (mu * mu);
if (e2 < 0.0) { e2 = 0.0; }               // near-circular round-off clamp
const double e = peri_det_sqrt(e2);
return p / (1.0 + e);                     // finite for every conic, 1+e ≥ 1
```

`q = p/(1+e)` is finite for every eccentricity — circular through
hyperbolic — with no `a → ∞` blowup at the parabolic seam, because the
semi-latus-rectum form never divides by `1 − e`. `predicted_apoapsis` shares
the same algebra and returns `+Inf` for any unbound orbit (`e ≥ 1`, which
also traps NaN since `NaN < 1.0` is false). Both roots — `|r|` and `e` —
route through a file-local `peri_det_sqrt`, the same bit-seed-plus-Heron
recipe as `kepler_universal`'s `det_sqrt`, never `std::sqrt`, keeping the
whole decision path libm-free.

The estimator was confirmed against two independent oracles: the analytic
conic periapsis to 1e-9 relative across near-circular, moderate-e,
near-parabolic (e = 1±1e-7), and hyperbolic (e up to 5) constructed orbits,
and an independent `kepler_step`-propagated relative orbit's minimum `|x|`
(periapsis located by the radial-velocity zero, grid-independent) to
propagator-oracle precision. `v → −v` invariance held bit-exact — `==` on
raw doubles, not `Approx` — because `rv` only ever appears squared.

### The stateless predictive predicate

`detect_regime_predictive` reuses the M0.4 dominant-body scan, `hill_radius`,
and the bound-pair exemption verbatim — no new Hill math, `detect_regime`
untouched. Per non-dominant pair in canonical slot order it computes the
mutual relative state and `mu = G*(m_i + m_j)`, gates on a `v → −v`-symmetric
horizon (`t* = −(r·v)/v²`; `|t*|` is invariant since `r·v` flips but `v²`
doesn't), and switches IN on a squared comparison:

```cpp
const double t_star = -rv / v2;
const bool within_horizon = (abs_t <= pred_horizon_n * step_dt);
if (!within_horizon) { continue; }
const double q = predicted_periapsis(r_rel, v_rel, mu);
const double q2 = q * q;
const double thresh = pred_k * pred_k * r_hill * r_hill * pred_pad;
if (q2 < thresh) { return Regime::ENCOUNTER; }
```

There is no `prior` parameter and no next-state lookahead — `pred_pad` is
the sole anti-chatter margin, a deliberate departure from M0.4's
`k_in`/`k_out` hysteresis band. A boundary, corrupt-mass, or degenerate
table falls through to `REGULAR` (the conservative default with no history
to fall back on); a NaN `q²` makes the `<` comparison false, so it never
spuriously fires.

### Worker seam swap + reversibility locks

`run_due_steps()` swaps its one call from `detect_regime` to
`detect_regime_predictive`; `regime_` becomes observe-only, retained for
logging and `FrameMeta` but no longer fed back as history. The diff is the
predicate call plus a comment — `integrate_window`, `step<M>`, cadence, and
publish are byte-unchanged. One in-phase fix: a pair-only predicate
would have silently dropped M0.4's lone-sun-grazer protection (a grazer
with no pair partner triggers nothing), so a stateless, velocity-free
dominant-timescale switch-in carries over as a new `pred_n_min` knob,
reusing the existing switch-in arm verbatim.

The primary bad-switch detector drove forward-N / flip-v /
back-N / flip-v through the predictive seam across a genuine
REGULAR↔ENCOUNTER crossing (at least two transitions, non-vacuous) and
returned to the initial state within `N·1e-10` — residuals measured
~1e-12 to ~1e-20. The anti-thrash check found a band-edge pair making at
most 4 transitions over 2000 steps, confirming `pred_pad` alone holds the
line with no escalation to a redo-step scheme. A separate negative-control
test constructed a sub-sample straddle — both step endpoints outside
`k·R_Hill`, periapsis inside — where `detect_regime_predictive` returns
`ENCOUNTER` and the unmodified `detect_regime` returns `REGULAR` on the
identical state, the case the reactive gap was named for. Two same-binary
predictive runs stayed byte-identical for both REGULAR and
encounter-crossing paths.

### Calibrate-then-lock the trigger constants

A grid sweep over `(pred_k, pred_pad, pred_horizon_n)` —
`{2.5,3.0,3.5} × {1.0,1.21,1.5} × {1,2,4}` — pinned the calibrated knee at
**(3.0, 1.21, 2.0)**, seeded from MERCURIUS's `r_crit=3` and its 1.21
squared-distance pad. The knee is the smallest band that simultaneously
catches the flyby straddle case with a 113× margin, produces zero thrash over
1500 steps, keeps the round-trip residual bounded (~8.9e-13), and
leaves the Earth-Moon bound pair in `REGULAR`. The `Config` defaults were
already the knee value; the lock only asserts they equal it, so silent
drift fails CI without moving any trajectory.

## Why it was built this way

- **Closed-form conic, not ballistic or sampled.** A straight-line estimate
  is too loose near periapsis; repeated `kepler_step` sampling is both
  costly and adds its own reversibility surface. The conic form is exact
  two-body physics and a single evaluation.
- **Stateless over historyful hysteresis.** A `k_in`/`k_out` band carries
  memory across steps — exactly the asymmetry Hernandez-Dehnen identify as
  the reversibility hazard. A fixed pad is the only anti-chatter margin
  that cannot disagree with its own time-reversal.
- **Predicate swap, not seam rewrite.** Everything downstream of the one
  `detect_regime` call — WH, IAS15, the snapshot, `system_energy` — stays
  untouched, keeping the change additive against every prior lock.
- **Calibrate-then-lock.** The trigger constants come from a grid sweep
  against four simultaneous pass conditions, not an a-priori guess.

## Where it is now (drift since 2026-06-15)

- The predictive trigger and its stateless pad-only hysteresis are
  unchanged through M0.6 and M0.7 — neither milestone touched
  `detect_regime_predictive`'s shape. M0.6 routes the trigger into the
  WH-valid heliocentric warp config (Sun/EMB/Mars/Jupiter) as well as the
  legacy Yoshida4 path; the Moon-containing full seed still runs the same
  predicate on its Yoshida4 REGULAR tier.
- **M0.7:** the WH↔IAS15 handoff this trigger gates into is now the nested
  HJS map rather than the flat WH map from Phase 24 — the periapsis algebra
  and horizon gate are unaffected, since they operate on mutual pair state,
  not on which symplectic tier is running underneath.
- As of 2026-07-21 the calibrated knee `(3.0, 1.21, 2.0)` from the
  trigger-constant sweep is still the production default, and the
  time-reversal round-trip remains the standing regression
  guard for any future change to the switch predicate.

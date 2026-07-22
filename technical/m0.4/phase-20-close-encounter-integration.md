# M0.4 Phase 20 — Close-Encounter Integration: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-08**; the
> drift section traces the detector and IAS15 through today's stack.

## Starting point

Phase 19 shipped the N-body direct-force module and promoted the worker's
state to a `std::span<State>` vector with a whole-vector `bound_accel_fn`
callback. The integrator stack was still fixed-step-only, and a fixed step
through a close approach bleeds energy — the fast dynamics at pericenter are
undersampled and the symplectic error bound no longer holds. That was named
a deferred blocker: shipping detection-free multi-body ships a known
failure mode.

The shape locked 2026-06-05: on encounter detection the **whole system**
switches from fixed-step Yoshida4 to an adaptive IAS15-class Gauss-Radau
integrator for the window, then back — a hard stop was rejected, and the
per-pair MERCURIUS hybrid was deferred to M0.5 as a perf upgrade reusing
this phase's core. Two more locks: the trigger is a mutual-Hill-radius
geometric test, and energy-error is a test assertion, never the trigger —
a trigger keyed on the symptom is reactive and circular.

One decision preceded any code: both reference IAS15 implementations
(REBOUND's `integrator_ias15.c`, GRSS) are GPLv3 — porting would relicense
the planned Apache-2.0/MIT engine. The call (2026-06-08): **clean-room from
the paper** — Rein & Spiegel 2015 (arXiv:1409.4779) — with no GPL source
opened at any point. Five stages, all completing 2026-06-08.

## What was built

### The Gauss-Radau core

`ias15_integrator.hpp/.cpp`: the 8 Gauss-Radau node fractions pinned to 25
significant figures, the g→b conversion matrix c and its inverse d, and
`predict_correct_window` — one fixed-window predictor-corrector sweep over
the force series `F(h) = a₀ + Σ b_k·h^(k+1)` (eq.4): predict r/v at the 8
nodes from the b-series, re-evaluate acceleration through the Phase 19
`bound_accel_fn` (no force reimplementation), run the eq.(5)
divided-difference recurrence for g, convert g→b, repeat until δb₆ < 1e-16
(hard cap 12), Kahan-compensated final update.

Two transcription bugs, both caught by tests the same day. The first `d`
matrix assumed the b→g inverse shared magnitudes with c (an all-positive
reflection); the I-3 g→b→g round-trip returned 2.0039 instead of 2.0 — d is
the genuine triangular inverse c⁻¹, recomputed offline by back-substitution
at 60-digit precision. The first predictor used `b_k·h^(k+2)/((k+1)(k+2))`
for the position term — the wrong power for a series whose k-th term is
h^(k+1); the linear-field anchor missed its closed form by ~1.6e-3 until the
double integral was re-derived (`b_k·h^(k+3)/((k+2)(k+3))`). Both
closed-form anchors — constant and linear-in-h acceleration — then hit the
analytic result to ~1e-13, the linear one via an N=2 harness with a
zero-acceleration clock body (a self-forced body's curvature feeds back into
a position-derived h, polluting the closed form at ~1e-6).

### The adaptive step controller, validated standalone

The step controller is `dt_required = dt_trial·(ε_b/b̃₆)^(1/7)` (eq.11),
with `b̃₆ = max_i|b₆,i| / max_i|y″,i|` (eq.9) as a component-max proxy —
no `sqrt` for a norm. The seventh root is hand-rolled on `+,−,×,÷` only,
per the IAS15 determinism recipe (arXiv:1701.07423 — the integrator computes
its own roots so the controller is bit-reproducible):

```cpp
// Seed: memcpy the double's bits, halve the unbiased IEEE-754 exponent
// toward 2^(e/7) (pure integer ops) — then Newton on y⁷ = a:
for (int it = 0; it < 20; ++it) {
    const double y6 = (y * y * y) * (y * y * y);
    y = (6.0 * y + a / y6) / 7.0;
}
```

20 fixed iterations, not 8: the `⌊e/7⌋` seed can sit an octave off the true
root, and probe points at x≈10 and x≈1e-6 needed the extra budget to reach
the float64 floor (final: 0–3.6e-16 relative against `std::pow`). The count
is data-independent, keeping control flow deterministic.

`integrate_window` wraps the sweep in an accept/reject loop whose accepted
substeps sum to the window boundary to the last bit. The controller's one
real bug lived here: the accept condition included `dt_trial >= remaining`
as a progress guard, which force-accepted the first trial (where
`dt_trial == window_dt == remaining`) — the controller was bypassed for the
largest, least accurate step, producing 9% energy drift over 50 periods
while a single sweep sat at machine floor. The fix accepts only on
`dt_trial <= dt_required || dt_trial <= min_sub`; the top-of-loop
`remaining` clamp preserves the boundary contract.

The integrator was required to be proven **standalone** before any wiring —
a broken adaptive integrator inside a switch is undebuggable. The gate
(`test_ias15_window.cpp`): Kepler at e=0.3 over 50 periods, position error
7.98e-13, |ΔE/E| 6.36e-15; a convergence anchor — err(h)/err(h/2) measured
2^13.93 inside the a-priori [2^13, 2^17] band, which rejects a
degraded-order transcription a calibrated tolerance would absorb; e=0.9,
IAS15 |ΔE/E| 2.88e-14 where Yoshida4 at T/2000 bleeds 1.49e-4 — a 5.17e9×
gap; same-binary bit-determinism (`==`, not Approx).

### The Hill-radius detector and hysteresis band

`encounter_detector.hpp/.cpp`: `hill_radius(m_i, m_j, dominant_mass,
mean_orbital_radius)` computes `R_Hill = a·((m_i+m_j)/(3M))^(1/3)`
(Hamilton & Burns 1992; changeover use per Rein et al. 2019, MERCURIUS).
The plan left `a` to discretion, and the first attempt — the pair's mutual
separation — is geometrically degenerate: `sep < k·R_Hill` reduces to
`1 < k·cbrt((m_i+m_j)/(3M))`, a separation-independent constant that fires
at every distance (the `enc_detect_quiet_outside` fixture could never be
made "outside"). The fix is the genuine MERCURIUS geometry: a dominant
central mass (most-massive active body, excluded from the pair loop),
`a` = the pair's mean heliocentric distance, mutual separation for the
comparison.

`detect_regime` is a pure function of (states, masses, k_in, k_out, prior):
switch IN when any non-dominant pair's separation < `k_in·R_Hill`, OUT only
when all pairs exceed `k_out·R_Hill`, otherwise hold — the band is the
anti-chatter zone. `k_in = 3.0` / `k_out = 3.6` are config-exposed; pairs
iterate i<j in canonical id order via short-circuit loops in fixed order.
No energy parameter exists in the signature, and a grep gate asserts no
energy term, wall-clock, or atomic load in any code path.

The deep-plunge straddle: a body can cross the Hill radius AND reach
pericenter within one 60 s step, which a once-per-step boundary check
straddles. The mitigation is the conservative k itself, proven by a
CONTRAST test at a pinned `step_dt = 60.0 s`: bare-Hill k=1.0 misses a
0.5·R_Hill mid-step plunge (asserted — the anti-vacuous arm); k_in=3.0
flips ENCOUNTER at the prior boundary. A substepped detection variant is
wired as defense-in-depth; only the full periapsis-prediction trigger was
deferred.

### The regime-switch seam

IAS15 is **not** a third `IntegratorMethod` case — it consumes a window with
internal variable dt, which breaks the fixed-dt `step<M>` contract. Instead
a selector sits at the top of both worker step loops:

```cpp
regime_ = detect_regime(std::span<const State>{&state_, active},
                        BodyTable{...}, config_.k_in, config_.k_out, regime_);
if (regime_ == Regime::ENCOUNTER) {
    integrate_window(std::span<State>{&state_, active},
                     accel_fn_, step_dt, ias15_scratch_, origin, ias15_cfg_);
} else {
    std::visit(/* unchanged step<M> dispatch */, config_.method);
}
```

The window integrates exactly one `step_dt`, so the accumulator, sim-clock,
and publish cadence are untouched. The selector is mirrored verbatim in
`accumulator_iteration` and the `tick()` twin (keeping both step paths in
lockstep); `ias15_scratch_` is ctor-sized to `body_capacity` — no hot-path
allocation. The load-bearing gate is worker-driven no-encounter
bit-identity: a production-config N=1 worker against a forced-REGULAR
baseline (`k_in = k_out = 0`, so `sep < 0` is structurally impossible), 80
published frames compared `==` bit-for-bit. The M0.3 10⁵-step energy gate
alone proves only that `step<M>` itself is unchanged — it never routes
through the seam; the worker-driven compare is what proves the seam.

### Bounded-energy regression + exit gate

`test_encounter_energy.cpp` drives a self-consistent N=3 impact-parameter
flyby through the real selector (a bound high-e orbit between planet-mass
bodies has a ~7.7-million-step infall — intractable for a unit test).
Measured max |ΔE/E|: 4.58e-15 through a 0.5·R_Hill pericenter, 8.27e-15
through the 60 s deep-plunge straddle — the detector's mitigation controls
energy as well as detection. The bound is locked at 1e-9, the ε_b target,
~5 orders above the measured floor: IAS15's error is a Brouwer's-law √n
random walk, and tightening to the floor would re-key the lock to this
scenario's length. Bounded-not-monotone is asserted directly — the
step-over-step decreasing fraction measured 0.33 (a monotone ramp decreases
on ~0% of steps). Phase gate: 207/207 green in Debug, Release, and TSan,
with `test_energy_conservation.cpp` unmodified.

## Why it was built this way

- **Whole-system fallback, not per-pair.** One integrator regime at a time
  in M0.4; the per-pair MERCURIUS hybrid is an M0.5 perf refinement over the
  same core and detector, not a rewrite.
- **Geometric trigger, energy as assertion.** Triggering on energy error
  reacts after the damage and is circular — the quantity being protected
  cannot gate the protection. The Hill crossing fires before the fast
  dynamics corrupt a fixed step.
- **Clean-room, not port.** Every recurrence carries an `arXiv:1409.4779
  eq.(N)` comment pointing at the paper, never at code; constants re-derived
  offline and cross-checked (Newton form ≡ power form to 60 digits).
- **Standalone before wired.** Both the Gauss-Radau transcription bugs and
  the step-controller bypass were isolated in minutes because nothing else
  was attached yet.
- **Calibrate-then-lock.** k_in/k_out and the energy bound are locked from
  measured behavior with documented margins — the M0.3 playbook measured
  a-priori bounds running 4–5 orders optimistic.

## Where it is now (drift since 2026-06-08)

- **2026-06-10:** an Earth-Moon-class bound pair sits inside k·R_Hill
  forever and locked the detector in ENCOUNTER; `pair_is_bound()` (ε<0,
  e<0.9, r_apo<k_out·R_Hill) exempts permanent satellites while an unbound
  flyby at the same separation still triggers.
- **2026-06-10:** `compute_accelerations` gained a per-side gravitating
  gate and short-circuits pairs where neither body gravitates before any
  distance math.
- **2026-06-11:** detector cost — `pair_predicate` skips zero-mass pairs,
  removing O(N²) overhead from craft-tier bodies.
- **2026-06-15, M0.5:** Phase 25 replaced the instantaneous-radius test
  with `detect_regime_predictive` — predicted two-body periapsis on
  `+,−,×,÷` only; Phase 24 wired the WH↔IAS15 round-trip with
  dominant-mass auto-select — the hybrid handoff this phase had deferred,
  on this phase's core and detector unchanged.
- As of 2026-07-21 IAS15 is the close-encounter tier of the four-tier stack
  (Leapfrog, Yoshida4, WH/HJS, IAS15); the seam shape — selector above an
  untouched fixed-step branch — survived M0.5–M0.8 intact.

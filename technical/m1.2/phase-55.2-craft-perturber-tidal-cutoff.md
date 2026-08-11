# M1.2 Phase 55.2 — Craft Perturber Tidal-Relevance Cutoff: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-31**. M1.2's
> gate-fix chain later touched this exact code — the drift section at the end
> covers what changed and why.

## Starting point

The shipped 14-body demo's craft hard-stopped in its first coarse window:

```
PhysicsWorker::run_due_steps: craft substep produced a non-finite state at
t=0 (substep 9672/16384) v_rel=(-nan,-nan,-nan) ... 13 perturbers
```

Mercury sits roughly 2.1e11 m from Earth, moving about 50 km/s relative to
it — around six decades into the free-streaming corner of the
universal-variable Kepler formulation. `kepler_step`'s fixed-iteration
solver leaves its convergence domain there and returns NaN, which then
poisons the craft's tidal sum. The finiteness hard-stop that catches this is
doing exactly its job; the bug is upstream of it. Every perturber in the
shipped 14-body table entered the craft substep window regardless of
whether it moved the craft by anything a player, or the milestone's own
accuracy budget, would ever notice.

## The relevance metric

The measure is the tidal acceleration a perturber exerts on the craft,
in the leading term of the direct-minus-indirect expansion for `d_j >> r`:

```
a_j = 2 * mu_j * r / d_j^3        [m/s^2]
```

with `r = |craft - dominant|` and `d_j = |perturber_j - dominant|`, both at
window-start geometry. This form was picked over the gradient form
`mu_j/d^3` (units s⁻²) for three reasons: multiplied by `T²/2` it is
directly the coherent per-orbit displacement the milestone's accuracy
ladder is written in; it self-adapts to orbit radius, since `r` sits in the
numerator, so a higher orbit correctly retains more bodies; and it
self-corrects on approach, since an approaching body's `d_j` collapses
toward `r`-scale and `a_j` blows far above any floor long before the body
actually matters. The caveat, stated once in the source: this is a
relevance metric, not the force model — every retained body still goes
through the kernel's exact direct-minus-indirect pair form.

## The calibration

Measured 2026-07-31 on the shipped 14-body table with the craft at 400 km
circular LEO about Earth (`r = 6.778137e+06 m`, osculating `T = 5553.6243 s`):

| body | slot | a [m/s²] | δ [m/orbit] | class |
|------|-----:|---------:|------------:|-------|
| Sun | 0 | 5.651813e-07 | 8.715871e+00 | RETAINED |
| Moon | 2 | 1.002631e-06 | 1.546194e+01 | RETAINED |
| Jupiter | 3 | 5.146027e-12 | 7.935879e-05 | dropped |
| Mercury | 9 | 3.162959e-14 | 4.877716e-07 | dropped |
| … 9 more bodies, 5.15e-12 down to 1.30e-16 m/s² | | | | dropped |

Min retained acceleration 5.651813e-07 m/s², max dropped 5.146027e-12
m/s² — a gap of **5.04 decades**, with the nearest body to the line
(Jupiter) sitting 1.89 decades clear of it. The floor is the geometric
midpoint of that gap, rounded to one significant figure:

```
sqrt(5.146027e-12 * 5.651813e-07) = 1.7053e-09 -> 2e-09 m/s^2
```

giving margins of 2.451 decades below the smallest retained scale and
2.590 above the largest dropped one. Summed over all eleven dropped bodies,
worst case (every perturbation adding in phase for a whole orbit), the
model-fidelity cost is 9.815779e-05 m per craft orbit — 1.80 decades under
the milestone's 6.2e-3 m per-orbit accuracy anchor.

## The one membership predicate

```cpp
constexpr bool craft_perturber_tidally_relevant(double mu_j, double r2_m2,
                                                double d2_m2) noexcept {
    const double lhs = 4.0 * mu_j * mu_j * r2_m2;
    const double rhs = kCraftPerturberTidalFloorMps2 * kCraftPerturberTidalFloorMps2
                       * d2_m2 * d2_m2 * d2_m2;
    return !(lhs < rhs);
}
```

`a_j >= floor` is equivalent to `(2*mu_j*r)^2 >= floor^2 * (d^2)^3`, and
every factor on both sides is non-negative, so squaring is
order-preserving — the predicate stays free of `sqrt`/libm and legal in the
deterministic worker translation unit. The comparison is written as
`NOT(below)` rather than `(at-or-above)` on purpose: every degenerate input
falls through to *retain*. A NaN operand makes `<` false, so the body
survives and the existing craft finiteness hard-stop fires downstream on
the real poison instead of a silent drop. A coincident perturber
(`d2 == 0`) retains too, preserving the unsoftened-propagation path into
that same guard. An overflowing right-hand side drops a hyper-far body (the
correct direction); an overflowing left-hand side retains. The one input
that actually drops everything is `r2 == 0` with `d2 > 0` — the craft
sitting exactly at its dominant's centre, where tides vanish by
construction.

## The window-entry filter

`craft_open_window` already walked the whole perturber table once per
coarse window to build the substep context; the filter is a skip inside
that same ascending-slot-order loop, so nothing about the fill's op order
changes for the rows that survive:

```cpp
const coords::Vec3f64 craft_rel_r0 = states_[craft_slot_].r - dom_r;
const double craft_r2 = craft_rel_r0.dot(craft_rel_r0);
...
for (std::size_t j = 0; j < n_active_; ++j) {
    if (j == dom) continue;
    const double mu_j = body_props_[j].mu;
    if (mu_j == 0.0) continue;
    const coords::Vec3f64 r0 = states_[j].r - dom_r;
    const double d2 = r0.dot(r0);
    if (!craft_perturber_tidally_relevant(mu_j, craft_r2, d2)) {
        ++dropped_n;
        if (dropped_logged < kCraftDropLogMax) {
            dropped_slot[dropped_logged] = j;
            dropped_d2[dropped_logged] = d2;
            ++dropped_logged;
        }
        continue;
    }
    craft_perturbers_.push_back(CraftPerturber{
        r0, states_[j].v - dom_v, mu_j, mu_j + mu_dom});
}
```

Membership is decided once per window, at entry, as a pure function of
window-start geometry, not once per substep. Both the fine substep window and
the degraded (single-substep) window route through this one site, so there
is no second code path to keep in sync. Membership can legitimately change
from one window to the next as a body approaches; the metric self-corrects
long before that approach matters, and window-entry determinism makes any
boundary flicker benign, which is why no distance-hysteresis was built
around it.

Dropping is never silent. Whenever `dropped_n != 0`, one throttled message
names every excluded slot, the scale that excluded it, and the floor:

```cpp
if (dropped_n != 0) {
    char msg[512];
    int n = std::snprintf(msg, sizeof(msg),
        "[physics-worker] craft-substep TIDAL CUTOFF at t=%.6e: %zu of %zu "
        "perturbers excluded below kCraftPerturberTidalFloorMps2=%.3e m/s^2 "
        "(dominant slot=%zu) —",
        sim_clock_.sim_time(), dropped_n, dropped_n + craft_perturbers_.size(),
        kCraftPerturberTidalFloorMps2, craft_dom_slot_);
    const double craft_r = det_sqrt(craft_r2);
    for (std::size_t k = 0; k < dropped_logged /* ... */; ++k) {
        const double d = det_sqrt(dropped_d2[k]);
        const double a_j = 2.0 * body_props_[dropped_slot[k]].mu * craft_r
                           / (dropped_d2[k] * d);
        n += std::snprintf(msg + n, sizeof(msg) - n, " slot=%zu a=%.3e;",
                           dropped_slot[k], a_j);
    }
    log_throttled("craft-perturber-cutoff", msg);
}
```

The fill loop itself stays root-free; the two `det_sqrt` calls needed to
recover a human-readable acceleration for the log live inside the
`dropped_n != 0` branch, off the flown numeric path entirely.
`kCraftDropLogMax = 12` sizes the message to name the shipped table's
entire dropped set (eleven bodies) individually before collapsing the rest
into a "+N more" tail — a formatting bound, not a limit on how many bodies
the filter may exclude. Run against the shipped binary, the line reads:

```
[physics-worker] craft-substep TIDAL CUTOFF at t=0.000000e+00: 11 of 13
perturbers excluded below kCraftPerturberTidalFloorMps2=2.000e-09 m/s^2
(dominant slot=1) — slot=3 a=5.146e-12; slot=4 a=2.425e-16; ...
```

## The tests that pin it

A calibration harness measures all thirteen shipped perturbers and asserts
the honesty conditions before trusting the pinned constant: the gap is wide
(no HALT clause fires unless it collapses toward zero decades), both
classes are non-empty, Mercury specifically measures dropped and the Sun
specifically retained, and the closest body to the line sits outside a
±0.5-decade ambiguity band. A companion lock re-derives the geometric
midpoint from the *live* seed at test run time and asserts it equals the
pinned `2e-09` literal — so a seed change that moves the measured gap goes
red instead of silently drifting the flown constant out of its derivation.
A classification-equivalence lock checks the squared predicate agrees with
the linear `a_j >= floor` form on every body in the shipped table.

On the worker side, a synthetic fixture places a Mercury-class perturber
(2e11 m, 50 km/s relative) in the *middle* of a five-slot table, with a
Moon-class control sitting at the same slot in a paired fixture — so the
same position both excludes and retains, proving the filter discriminates
on tidal scale rather than table position. Every surviving row is compared
byte-for-byte against hand-computed window-start values in ascending slot
order, turning "the filter is a pure skip" into an assertion instead of a
claim. The regression that actually proves the P0 is fixed drives the
shipped 14-body config with a seeded 400 km LEO craft through at least four
consecutive coarse windows and asserts two things together: the state stays
finite, *and* the retained span is strictly smaller than thirteen with
Mercury's `mu` specifically absent from it — a fixture that merely dodged
the poison by accident would pass the first assertion and fail the second.

Both lanes closed clean: Release 1081/1081, Debug 1077/1077, zero
pre-existing test files modified, zero locks regenerated. A diff of
`engine/src/nbody_force.cpp` against its pre-phase state came back empty,
and an `nm -u -C` symbol-set diff of the changed translation unit against
its pre-change build was byte-identical — no new libm import.

## Why it was built this way

- **One mechanism for two problems.** The same calibrated cutoff that fixes
  the live crash also collapses the trajectory predictor's perturber count
  from thirteen to the same two bodies the flown path keeps, so a single
  measurement session pays for both.
- **Calibrate, then lock.** The floor is read off a measured 5.04-decade
  gap, not hand-picked — the test harness that produced the table is the
  same one that locks the constant against it.
- **Fail-open on every degenerate input.** A NaN, an overflow, or a
  coincident perturber all retain rather than drop, so the existing
  finiteness hard-stop stays the backstop for real poison; the one input
  that drops everything (the craft sitting at its dominant's own centre) is
  a documented physical degenerate, not a new failure mode.
- **One membership spelling.** `craft_perturber_tidally_relevant` lives in
  the leaf physics constants header specifically so the render-tier
  trajectory predictor can alias it without linking the worker at all — the
  same pattern the craft HUD's reference-slot constant already established.
- **Filtering never touches a retained row's bits.** The skip sits inside
  the pre-existing fill loop rather than a second pass over the table, so
  the kernel's locked summation order over the rows that survive is
  preserved by construction.

## Where it is now

The acceleration floor's every claim — the 5.04-decade gap, the "not
delicate" margin, the 9.8e-5 m dropped-set bound — was true at exactly the
one radius it was measured at: 400 km LEO, T = 5553.6 s. A later hardening
pass this milestone found that at a fixed acceleration the coherent
per-orbit displacement scales as `T²`, i.e. as `r³` by Kepler's third law,
while the bare acceleration compare carries no `T` at all. The same
thirteen-body table evaluated at GEO — 15.5× the LEO period, so 241× more
coherent displacement for the same `a_j` — drops bodies worth
1.469774e-01 m per orbit against the 6.2e-3 m anchor: 23.7× *over* the bound
the LEO margins claimed.

The predicate was re-expressed in the currency its own accuracy contract
was already written in. A new constant, `kCraftPerturberPerOrbitFloorM =
6.2e-3` (the same 6.2e-3 m the acceleration floor was originally derived
from — not a new calibration), is now the compared quantity directly, and
the predicate takes a fourth argument, `t4_s4`, the craft's osculating
period to the fourth power:

```cpp
constexpr bool craft_perturber_tidally_relevant(double mu_j, double r2_m2,
                                                double d2_m2, double t4_s4) noexcept {
    const double lhs = mu_j * mu_j * r2_m2 * t4_s4;
    const double rhs = kCraftPerturberPerOrbitFloorM * kCraftPerturberPerOrbitFloorM
                       * d2_m2 * d2_m2 * d2_m2;
    return !(lhs < rhs);
}
```

The acceleration form's leading `4` (from squaring `2*mu_j*r`) cancels
exactly against the quarter that squaring `a_j*T²/2` contributes, so the
left side carries no leading coefficient at all — a naive `4.0 *`
transcription of the old body would misclassify every body by a factor of
two, silently, and a dedicated straddler fixture exists specifically to
catch that. `T⁴` comes from a new helper, `craft_osculating_t4`, a
vis-viva semi-major-axis derivation with a single `det_sqrt` (never
`extract_kepler_elements`, which reaches real libm through `Vec3f64::length()`);
an unbound or parabolic local orbit returns `+Infinity`, which retains
every perturber rather than classifying against a period that does not
exist. Both `craft_open_window` and the render tier's predictor
context-build now hoist the craft's relative velocity and call this one
helper once per window, so the two tiers cannot drift apart on what "the
craft's period" means. The shipped 14-body LEO classification is asserted
bit-identical before and after the change; the acceleration floor and its
measured table stay in the header as the historical calibration record,
just no longer the compared quantity.

A few smaller changes followed on the observability side: the throttled
cutoff message gained `window=`/`cutoff=` counters so a run of suppressed
log lines is recoverable by subtraction rather than lost to the throttle;
an unconditional per-window heartbeat line now reports the retained and
declared perturber counts even in the steady state where nothing drops;
and both craft finiteness hard-stops gained a per-row probe that names the
culprit slot directly, rather than only a perturber count, closing the gap
that originally took a separate analysis pass to identify Mercury as the
cause. `craft_perturber_tidally_relevant` is marked `[[nodiscard]]`. None
of these touch the classification arithmetic above; the predicate's
`constexpr` body and its fail-open degenerate posture are unchanged.

# M1.2 Phase 55 — Craft-Orbital Subcycling Closure: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-31**. M1.2 has
> since closed; the drift section at the end covers what touched this code
> between then and the milestone gate.

## Starting point

The craft's translational state rode the shared 300 s planetary step —
`states_[craft_slot_]` sat in the same span every gravitating body advanced
through, as a `FeelOnly` test-particle row that never sourced force back into
the n-body solve. One 400 km LEO orbit at that cadence accumulated 546 km of
position error and a spurious eccentricity of 6.07e-4. That number blocked
two things directly: launching at 1× real time (the orbit visibly decayed
under the player's eyes) and fine interactive throttle (a command could only
land at a 300 s boundary). The ephemeris step itself was not wrong — Earth,
the Moon and the Sun integrate fine at 300 s — the craft simply needed a
finer step than the planets did, without moving the planets' step to get it.

## The derivation — not a new numerical method

The engine already has a Wisdom-Holman KDK split for n-body integration:
kick, drift, kick, with the drift closed-form through `kepler_step`. That
split already proves two things for a massless test-particle row — the
Kepler/interaction split is symplectic in general, and with zero mass the
kick vanishes and the map collapses to a bare `kepler_step` bit-for-bit. The
craft substep is that same split, narrowed to one row, run at its own finer
cadence inside the 300 s window:

```
half-KICK(craft_dt/2) → DRIFT(craft_dt) via kepler_step → half-KICK(craft_dt/2)
```

Composition of symplectic maps stays symplectic, and the near-integrable
`O(ε·τ²)` scaling survives the nesting (Rein 2020, MNRAS 492:5413). The craft
does feel the non-dominant bodies' pull, its dominant's J2, and 1PN, so its
kick is not always zero — but with zero perturbers, no J2 and PN off, the
substep is still exactly `kepler_step(r, v, craft_dt, mu_dom)` in bits, and
the kernel's nine ground-truth locks pin that reduction across four conic
regimes and five step counts.

## The kick: tidal, then oblate, then relativistic

`craft_kick_accel` (`engine/src/physics_craft_integrator.cpp`) accumulates
three terms in a pinned order — Newtonian, J2, 1PN — each skipped by control
flow rather than by a zero-valued arithmetic op, so an absent term commits no
floating-point instruction at all:

```cpp
for (std::size_t j = 0; j < ctx.perturbers.size(); ++j) {
    const double mu_j = ctx.perturbers[j].mu;
    if (mu_j == 0.0) {
        continue;  // not a gravity source — structural skip, zero FP ops
    }
    const coords::Vec3f64 d = use_cache
        ? cache->pos[j]
        : craft_perturber_position(ctx, j, boundary_index);
    const coords::Vec3f64 direct = craft_substep_pair_accel(mu_j, r - d);
    const coords::Vec3f64 indirect = craft_substep_pair_accel(mu_j, -d);
    out.a = out.a + (direct - indirect);
    out.any = true;
}
```

The Newtonian term is the *tidal* residual, direct minus indirect: the
dominant body sits at the frame origin, but it is itself pulled by every
perturber, and in the dominant-relative frame that reaction subtracts.
Dropping the indirect half applies the perturber's full pull instead of its
tidal residual — for the Sun on a 400 km LEO craft that is 5.93e-3 m/s²
instead of the correct 5.37e-7 m/s², a factor of roughly 1.1e4 that no
convergence sweep would forgive. `craft_substep_pair_accel` is the one
inverse-square closure in the translation unit — `inv_r3 = 1/(r²·det_sqrt(r²))`,
the same op tree `evaluate_force` uses, with `det_sqrt` standing in for
`std::sqrt` because the trajectory path stays libm-free — and a dedicated
lock pins it against `evaluate_force` to within 1 ULP over thirty geometries
so a second, silently drifting closure can't exist unnoticed.

J2 is evaluated at the craft's own substep position and never folded into
the drift's `mu_dom`, keeping the drift a pure two-body problem so
`kepler_step` stays exact. 1PN reuses the same ST94 position-only β term the
n-body Wisdom-Holman tier applies, with the γ half-shifts and the α
time-rescale living in the drift slot exactly as they do there.

## Resolving how perturbers move mid-window

Between coarse 300 s boundaries the craft substeps sixteen thousand times,
and every one of those needs each perturber's dominant-relative position at
the substep boundary — but the perturbers themselves only get updated by the
n-body solver once per 300 s window. Three candidate answers to "where is
Earth's Moon at substep 9,672 of this window" all shipped in the kernel
behind one `PerturberMode` enum, so a convergence sweep could measure them
against each other before any one was picked: hold the perturber fixed for
the whole window, Kepler-drift it from its window-start state about the
craft's dominant, or accept an exact externally-supplied position (the
sweep's own truth-injection mode).

The sweep's ground truth had to be the perturbers' actual mutual N-body
trajectory, not a Kepler orbit about the dominant — seeding truth from a
Kepler orbit would have made the Kepler-drift candidate reproduce it exactly
by construction, and the sweep would have measured nothing while looking
clean. Three fixtures ran the grid: a quiet two-body 400 km LEO, a
Moon-perturbed 20,000 km MEO, and a J2-dominant 300 km/87° LEO. Only the
Moon-perturbed fixture can discriminate the two real candidates — Sun+Earth
is a genuine two-body system whose relative motion *is* Keplerian, so a
Kepler-drift perturber reproduces truth exactly there regardless of which
extrapolation is correct in general.

On that discriminating fixture the hold-fixed candidate's extrapolation
error was a flat plateau — it moved by only 1.03× across a 2048-fold change
in substep count, sitting at 1.0921e-2 m against a 3.1e-2 m accuracy budget:
2.8× under, but flat, so past roughly N = 4096 it becomes the *dominant*
error term rather than shrinking with more substeps. The Kepler-drift
candidate measured 3.0805e-6 m on the same fixture — 4.0 decades under the
budget, and 3,437× better than holding the perturber still. That is also
what Wisdom (2017) reports every surveyed test-particle N-body code does
(RMVS3, SyMBA, MERCURY all drift perturbers rather than hold or interpolate
them), and what Saha & Tremaine's (1994) step-consistency argument implies.
The literature prior and the measurement agreed, and the measurement is what
bound the choice: `PerturberMode::KeplerDrift` is what ships.

## Choosing the substep count

Two independent requirements set the substep count, and the pin took
whichever was larger. The accuracy floor came off the J2-realistic 300 km
fixture, since a pure two-body fixture flatters the sub-map: 512 substeps
per window measured 1.364e-2 m of one-window error against the 6.2e-3 m
target (fails); 1,024 substeps cleared it at 3.482e-3 m. The liveness floor
came from control latency — `craft_dt` is literally the interval at which
the craft's translational state advances, and the engine already commits to
an 18.31 ms worst-case control-latency budget on the attitude channel. To
hold interactive throttle to that same budget, `craft_dt` has to stay at or
under 18.31 ms, which needs at least 16,384 substeps per 300 s window. At
8,192 substeps (36.6 ms per substep) the craft would rotate smoothly under
reaction-control input while translating in visibly discrete steps during a
1× launch — exactly the failure the requirement exists to rule out.

```cpp
inline constexpr int kCraftSubstepN = 16384;  // 2^14
inline constexpr double kCraftDt = 75.0 * 0x1p-12;  // 300/16384 s = 18.310546875 ms

static_assert(kCraftDt * static_cast<double>(kCraftSubstepN) == 300.0, ...);
```

`75 * 2^-12` needs seven mantissa bits, so the quotient is an exact binary64
dyadic with 45 bits of headroom — every substep-accumulator subtraction is
exact, and the sixteen thousand substeps telescope binary-exactly back to
one 300 s step, which is what keeps the craft from ever drifting out of
phase with the ephemeris. That value happens to equal the engine's existing
attitude sub-tick width, `kAttDt`, but the two constants are deliberately
independent — one answers a translational control-latency requirement, the
other a rotational one, and they land on the same number only because both
are quantizing the same 300 s window to a 1× human-in-the-loop cadence.

## Thrust at substep cadence

M1.1's thrust seam obeyed one rule — "mass leads, velocity splits": the
Tsiolkovsky kernel commits the new mass once, before any velocity write, and
the resulting Δv splits into two exact halves that bracket whatever gravity
integration happens between them. Moving that seam from once per 300 s
window to once per 18.31 ms substep keeps the same order, just at the new
cadence, with the halves bracketing this substep's own gravity kick-drift-kick
instead of the coarse tier dispatch:

```cpp
double thrust_half = 0.0;
if (thrust.enabled) {
    const ThrustStep ts = thrust_step(thrust.props, m_kg, thrust.throttle, h);
    out.m_kg = ts.m_new_kg;
    out.dv_mps = ts.dv_mps;
    out.burned_out = ts.burned_out;
    thrust_half = 0.5 * ts.dv_mps;
}
if (out.dv_mps != 0.0) {
    vel = vel + thrust.dir * thrust_half;
    ++out.seam_calls;
}
// ... gravity half-KICK, DRIFT, gravity half-KICK ...
if (out.dv_mps != 0.0) {
    const double second = out.dv_mps - thrust_half;
    vel = vel + thrust.dir * second;
    ++out.seam_calls;
}
```

Moving from one telescoping term per outer step to 16,384 was flagged as a
risk worth measuring rather than assuming: the Phase 49 Tsiolkovsky kernel's
banner claims its log-kick telescopes to closed-form Δv exactly, which is
true in exact arithmetic but says nothing about round-off across 16,384×
more terms. The first measurement came back bit-identical — 0 ULP — which
looked clean but turned out to be a coincidence of the fixture's mass-flow
rate landing on a dyadic fraction, not a general property; a second,
deliberately non-dyadic fixture measured 8.34e-10 kg (about 4 ULP) over
16,384 substeps against a 7.45e-9 kg derivation-true bound. The Δv
telescoping check ran 81,920 terms and measured 4.68e-11 m/s (103 ULP)
against 3000·ln(2), against a random-walk prediction of roughly 286 ULP —
better than the model, not worse. No band needed loosening.

## Worker integration: the craft leaves the shared span

The craft's row leaves the span handed to the planetary integrator entirely.
It never sourced force into that call, so the planets integrate exactly as
before. In its place, `run_due_steps()` runs a
nested substep loop structurally sibling to the existing attitude subcycle:
per coarse window, snapshot every perturber's dominant-relative state at the
window's start, carry the craft through `kCraftSubstepN` substeps in that
relative frame, then recompose the craft's absolute row against the
*post-step* dominant:

```cpp
void PhysicsWorker::craft_recompose_and_close() {
    const std::size_t dom = craft_dom_slot_;
    coords::Vec3f64 v_out = craft_rel_v_;
    if (pn_params_.enabled && craft_ctx_.mu_dom != 0.0) {
        v_out = pn_pseudo_to_true(v_out, craft_rel_r_, craft_ctx_.mu_dom, pn_params_.c2);
    }
    states_[craft_slot_].r = states_[dom].r + craft_rel_r_;
    states_[craft_slot_].v = states_[dom].v + v_out;
    craft_window_open_ = false;
    // ... finiteness hard-stop on the recomposed row ...
}
```

Recomposing against the dominant's post-step position rather than its
window-start position is what makes the close correct: the relative-frame
equations of motion already carry the dominant's own acceleration through
each kick's indirect (tidal) term, so the only residual is the bounded
within-window frame error the convergence sweep measured directly.

Because the perturber-sourcing sweep picked `KeplerDrift`, and consecutive
substeps share a boundary, every interior boundary was being Kepler-solved
twice — once as the outgoing substep's right kick and again as the next
substep's left kick. A single-slot memo (`CraftBoundaryCache`) that caches
the most recently computed boundary's perturber positions turns that into
once, since `craft_perturber_position` is a pure function of its inputs and
a cached value is therefore the identical bits a recompute would produce.
Measured end to end, the memo cut one window's cost from 58.09 ms to 35.03
ms in Release (113.81 ms to 71.97 ms in Debug), and that cache is what made
`kCraftFineScaleCap = 2048` — the highest time-scale multiplier at which the
craft still substeps at full accuracy rather than degrading to a single
coarse step — land where two independent derivations wanted it: a Debug
wall-clock budget and the product's existing warp-entry threshold both
picked 2,048 on their own. Above that cap the craft runs the exact same
kernel with `n_sub = 1`, never returning to the shared planetary span, so
accuracy degrades to no worse than the pre-phase quality at time scales
where a 92-minute orbit already completes in under six wall-seconds.

## Closing the blocker

The regression that replaces the 546 km blocker figure had to avoid two
traps a naive version would fall into. First, a purely two-body fixture
would make `craft_substep` collapse to `kepler_step` in bits, so the test
would measure round-off and report it as the sub-map's accuracy — the
fixture keeps Earth's J2, a roughly 0.11% perturbation at 400 km, which is
the same term the convergence sweep used to measure the sub-map's second
order. Second, a J2-perturbed LEO's osculating eccentricity genuinely
oscillates by about 2.5e-4 over one orbit — that's physics, not integrator
error — so the assertion differences the run against a reference rather than
bounding `|e|` directly. The reference is a second worker running the exact
same production code path at four times the substep count, so every
non-integrator difference between the two runs cancels and what's left is
the sub-map's own truncation error.

At the same 300 s ephemeris step, 546,000 m of one-orbit position error
became 7.363e-5 m (locked at 4.0e-4 m), and the spurious eccentricity of
6.07e-4 became 6.54e-15 (locked at 1.0e-13). A companion case bounds ten
orbits of osculating-element drift rather than one:

| case | measured | locked |
|---|---:|---:|
| 10-orbit semi-major-axis drift band | 32.64 m | 2.0e2 m |
| 10-orbit eccentricity drift band | 1.958e-3 | 1.0e-2 |
| secular slope as a fraction of the drift band | 0.114 / 0.112 | ≤ 0.5 |

That drift-band lock exists because the craft is a driven test particle in a
time-varying field — there is no energy-conservation claim to make — so
"bounded, not secular" is asserted as a slope-to-band ratio rather than an
absolute tolerance. A separate chunking-exactness case delivers the same
1,200 simulated seconds to the worker as whole steps, half steps, and a
ragged mix, and checks that the craft's position, velocity and mass land
bit-identical regardless — the substep loop can only be left open mid-window
across calls when an active reaction-control surface keeps the fine attitude
drain alive, so that's the configuration the case exercises.

## Tests that pin the behavior

The kernel carries nine locks on its own — the two-body bit-reduction across
four conic regimes, the μ→0 linear-drift limit, an independent oracle for
the tidal residual, the 1-ULP agreement with `evaluate_force`, a bitwise J2
check, a PN structural-no-op check, fresh-position/fresh-time kicks, all
three perturber modes, and cross-run determinism. The sweep adds a
convergence-order lock (measured 4.000 per halving on the J2 fixture, banded
[3.2, 4.8]) and an extrapolation lock that keeps asserting the rejected
hold-fixed candidate still fails, so a future change couldn't accidentally
make it look acceptable without the lock noticing. The thrust seam adds
seven cases covering the mass/Δv telescoping measurements, statement order,
coasting structural no-ops, a full five-window burn to `m_dry`, and
mid-window throttle changes. The worker integration carries a fine-scale-cap
benchmark plus regenerated golden trajectory bits for a fixture that
necessarily changed — the whole point of the phase was to move the craft's
trajectory. Full suite at close: Release 1003/1003, Debug 999/999.

## Where it is now

Two follow-on phases inside the same milestone touched this code directly,
plus one correction to the substep-count reasoning itself.

**Substep-cadence publish.** The craft's state only updated the published
snapshot at the coarse 300 s boundary, which meant a display or predictor
reading that snapshot at 1× real time could go most of a second between
updates. A follow-on phase made the craft row publish at its own substep
cadence — measured 54.4982 Hz at time scale 1 — while planetary rows kept
the coarse publish, composing the craft's absolute position against its
dominant at the *same* substep boundary rather than the window's start. A
second pass found that the naive publish-retention window (twice the
minimum publish interval) still let a 60 Hz reader miss a boundary-consistent
frame roughly one time in four, because publish decisions themselves land on
a substep-width lattice; the fix widened the retention window until the
*observable* margin — retention minus one lattice cell — cleared a 60 Hz
sample period, and armed that wider hold from the published frame's own
boundary-consistency rather than from the call site that published it.

**A perturber tidal-relevance cutoff.** The shipped fourteen-body
configuration crashed the craft in its first coarse window: Mercury, tens of
thousands of kilometers away and moving at roughly 50 km/s relative to
Earth, sits deep enough into the free-streaming corner of the
universal-variable Kepler solver that `kepler_step`'s fixed-iteration
extrapolation returned non-finite values, which then poisoned the craft's
tidal sum. The fix left the finiteness hard-stop in place as the backstop
for genuine poison and instead removed the poison input: at each coarse
window's open, every perturber's coherent per-orbit displacement of the
craft is compared against a calibrated floor, and anything below it is
excluded from that window's perturber table with a throttled log naming
which body and by how much it missed. Measuring all thirteen shipped
perturbers on the 400 km LEO fixture found a five-decade gap between the
retained set (Sun, Moon) and everything else, with the closest excluded body
still 1.8 decades clear of the line — the floor sits at the gap's geometric
midpoint rather than at a hand-picked value.

**A correction to the substep-count reasoning.** The original banner
justifying `kCraftSubstepN = 16384` claimed a larger substep count never
degrades accuracy. That claim turned out to be false: `kepler_step`'s own
position-velocity update commits a small systematic bias per call, so more
substeps over the same span means more calls and a growing absolute error —
measured on a bare two-body window, 16 substeps landed 1.3e-9 m from an
analytic reference and 65,536 substeps landed 3.3e-6 m away, with the
pinned 16,384 measuring 2.426e-4 m off the analytic reference over a full
orbit. The original convergence sweep never saw this because it always
differenced two same-mode substep chains against each other, which cancels
a bias shared by both. The pin itself didn't move — 16,384 substeps is still
set by the control-latency floor, a hard requirement independent of this
finding, and the measured accuracy cost sits roughly 25× under the one-orbit
bound this phase locked — but the banner's reasoning was corrected, and that
lock was re-derived once, later in the milestone, against the honestly
measured number.

# M1.1 Phase 52 — Rotational Integration & Input Command Channel: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-21**;
> verification passed the next morning (2026-07-22, 847/847, no fixes
> required).

## Starting point

Phase 51 gave a craft position, velocity, mass, and a static attitude
quaternion read straight from config. The Phase 48 rigid-body kernel existed,
but nothing stepped it in the worker. Burns ran off a scripted
`{t_start, t_end, throttle}` schedule rather than a human's hands. Phase 52 is
the phase where a player flies it: the Phase 48 kernel steps live,
rotation input reaches it through the Phase 50 RCS mixer, six-direction
translation drives the same mixer, kill-rot exists, and warp no longer freezes
attitude. No HUD (Phase 53), no vector-lock SAS, no gamepad.

Two things made this phase harder than "wire the kernel to a keyboard." First,
the orbital step is 300 s and a spacecraft's attitude needs to respond in tens
of milliseconds. One rate has to nest inside the other without breaking the
orbital math-lock suite's bit-identity. Second, player input arriving on wall-clock
render time had never touched this engine's physics loop before; every existing
source of state change was internal and deterministic, and a keypress is
neither.

## The subcycling rate: nested integer divisor, N = 16384

The open question carried from Phase 51 was what rate attitude integrates
at relative to the 300 s orbital step. Pinned 2026-07-21: a
`has_craft_control_`-gated subcycle drain inside the existing
`while (accumulator_ >= quantum)` loop in `run_due_steps`, with
`quantum = kAttDt = step_dt / N` and `N = kAttTicksPerStep = 16384` (2¹⁴).
There is no second accumulator — the same drain accumulator that has always
governed the orbital step now subtracts `kAttDt` per fine tick. The
orbital step body (warp-arm dispatch, thrust half-kicks, `sim_clock_.advance()`)
runs only on every 16384th tick.

The rate itself falls out of an input-latency budget rather than a numerical
stability requirement — measurement pinned 10–20 ms of input response at
`time_scale 1`:

```
N = 2^14 = 16384 → dt_att = 300/16384 = 0.018310546875 s ≈ 18.31 ms  (in budget)
N = 2^15 = 32768 → dt_att ≈ 9.16 ms  (below budget, 2x the per-step cost, no gain without a rate controller)
```

`N = 16384` is the cheaper of the two candidates that both clear the budget.
There's no rate-hold controller in this phase — direct torque command
only — so resolving attitude finer than the budget buys nothing yet.

The reason this can be a plain integer divisor instead of a second independent
clock is a dyadic-exactness argument, not an approximation: `step_dt = 300 s =
75·2²`, so `kAttDt = 300/16384 = 75·2⁻¹²` is an exact binary64 value —
`18.310546875 ms`, no rounding. Every value the drain accumulator takes stays
bounded under `2¹⁸`, so its ULP is at least `2⁻³⁴`, which divides `75·2⁻¹²`
exactly. That means every `accumulator_ -= kAttDt` is exact, and 16384 of them
telescope to precisely one `step_dt` subtraction — the orbital step count and
trigger times for any given `wall_dt` sequence come out bit-identical to the
pre-52 loop. A craft-absent run, or a Phase 51 thrust-only craft
(`rcs.count == 0`, so `has_craft_control_` is false), takes `quantum == step_dt`
and skips the fine block entirely — the loop for those cases is untouched, not
merely unaffected.

```cpp
const bool fine = has_craft_control_ && tier_ != WarpTier::Warp;
const double quantum = fine ? kAttDt : step_dt;
while (accumulator_ >= quantum) {
    if (fine) {
        attitude_tick(kAttDt);
        ++att_tick_;
        if (att_tick_ % kAttTicksPerStep != 0) { accumulator_ -= quantum; continue; }
    }
    // ... orbital body: warp-arm dispatch, thrust half-kicks, tier dispatch, sim_clock_.advance()
    accumulator_ -= quantum;
}
```

`test_craft_attitude_input.cpp`'s `att_subcycle_exactness` proves the nesting
rather than assuming it: a controlled craft's fine-drained accumulator is
bit-constant across orbital steps (the fine drain removes exactly `step_dt`),
its `sim_clock_` time is bit-identical to a craft-absent worker's at every
step, and `att_tick_ == steps × 16384`. The orbital math-lock suite — Yoshida4,
IAS15, HJS nested WH, everything from M0.2 through M0.8 — is unaffected; it
never sees the craft slot at all.

## Attitude-before-body ordering and the RCS Δv seam

No physical reason favors running the boundary tick's attitude work
before or after that tick's orbital body — an impulse either way, at the
accuracy the thrust seam already documents. This phase pins
attitude-before-body and reuses the existing Phase 51 thrust kick seam
rather than adding a second orbital-state write site. RCS translation
accumulates a `Vec3f64` delta-v in the craft sidecar every fine tick
(`rcs_dv_accum_`, per-component `!= 0.0`-gated so a coasting craft stays a
structural no-op). It injects at the two existing Phase 51 half-kick sites,
in order:

1. At the first site, the thrust half applies, then half the RCS accumulator.
2. At the second site, the thrust second half applies, then the remainder of
   the RCS accumulator (`accum - half`, so the two halves sum binary-exactly).
   The accumulator resets to exact zero only after this write.

One seam still owns every orbital-state write, so the Phase 51
`craft_seam_calls_` audit — asserting exactly two seam calls per outer step
under both Leapfrog and Yoshida4 — holds unmodified.

`rcs_boundary_tick_ordering` locks the ordering itself with a negative
control: the boundary tick's injection has to include the sum over all 16384
ticks, and a 16383-tick partial sum is asserted distinct from it — proof the
attitude work runs before the orbital body on that tick, not after.

## The input channel: tick-stamped, not wall-clock-sampled

The requirement here is that replaying the same input trace at a different
frame rate reproduces the identical trajectory bit-for-bit. Sampling a
relaxed atomic on the worker side was rejected outright — the mapping
from wall-clock writes to attitude ticks depends on frame timing, which is
exactly the non-determinism this requirement exists to close out. Instead, the main
thread stamps every command with the attitude tick it should take effect at
and pushes it onto a bounded single-producer/single-consumer ring
(`InputRing`, power-of-two capacity, the rigtorp acquire/release memory-order
recipe — relaxed load of the writer's own index, acquire load of the reader's,
release store on publish). The worker drains the ring up to the current
`att_tick_` inside `consume_input_upto`, keeping a one-entry future stash so a
command stamped slightly ahead isn't dropped on a missed frame.

Each `AxisCommand` (72 bytes, trivially copyable) carries the full desired
control state — pitch/yaw/roll, six-direction RCS, throttle, and an event-flag
byte for kill-rot press / precision hold / throttle full / throttle cut — not
a delta. That makes the channel idempotent: a dropped or duplicated entry
can't desync the craft's state, since every entry re-states everything.
Overflow policy is drop-newest at the producer boundary; the producer also
rejects non-finite values before any index moves, so a NaN keypress can never
enter the ring at all.

`test_craft_input_replay.cpp` drives the same canonical trace through three
different tick chunkings at `time_scale 1200` — `0.25 s`/tick, `0.125 s`/tick,
and a pathological alternating `0.25 s` / `2⁻⁹ s` chunking — all summing to
65536 fine ticks (4 orbital steps), and byte-compares every published field
(position, velocity, quaternion, ω, `att_tick`, mass, throttle,
`kill_rot_active`). Bit-identity holds by construction: because `kAttDt`
exactly divides `step_dt`, any chunking whose per-call sim increment is an
exact multiple of `kAttDt` walks through the identical fine-tick sequence with
inputs landing on the identical ticks, regardless of how the wall clock chose
to slice it.

## A gate the initial design was missing: `has_craft_control_`

The initial design read `fine = has_craft_ && tier != Warp` — any craft
subcycles. Running the Phase 51 craft locks against that gate broke every one
of them. Phase 51's fuel/warp/seam fixtures construct thrust-only crafts with
no inertia or RCS tensor at all. Subcycling those through `rcs_mix` and
`rigid_body_step` on an empty config produces NaNs, on top of failing
construction outright once the new inertia/RCS validation gates on the same
condition. The fix adds `has_craft_control_`, set at construction time iff
`rcs.count > 0`. The fine drain, `attitude_tick`, and the mandatory
inertia/RCS validation all key off it instead of the bare craft-presence flag;
a thrust-only craft leaves it false and keeps riding the exact pre-52 coarse
loop, byte-for-byte, with zero edits to any Phase 51 test file. It's the
literal reading of "a craft with a rotational-control surface subcycles" — a
craft without RCS has nothing to subcycle.

The same distinction reopened a separate Phase 51 guard: crafts with
`rcs.count == 0` still reject a nonzero `attitude.omega` at construction (the
same swap-point guard stays closed for them), while a controlled craft's
constructor now accepts one — needed for this phase's warp-arm tumble
fixtures, and not a behavior any Phase 51 lock ever asserted against a
controlled craft.

## `attitude_tick`: the chain, in the order it runs

1. `consume_input_upto(att_tick_)` — last-wins level state plus edge events
   (throttle full/cut snaps `craft_state_.throttle` directly; a kill-rot press
   toggles the latch).
2. Ramp each rotation/RCS axis toward its raw target at `kInputRampPerTick =
   2⁻⁴` (16 ticks, ~293 ms, to full deflection — a docking-relevant
   ~0.25 s intent, expressed as an exact dyadic); throttle ramps separately at
   `kThrottleRampPerTick = 2⁻⁶` (64 ticks, ~1.17 s idle-to-full).
3. Build the wrench: force rows from the ramped RCS axes, torque rows from
   pitch→X/yaw→Y/roll→Z, each scaled by the per-axis max envelope
   (`w_max`, computed once at construction by probing the locked `rcs_mix`
   with six unit wrenches — axis 1.0 means "the most torque this thruster
   geometry can produce," never an arbitrary tuning constant) and by
   `kInputPrecisionScale = 2⁻³` when the precision modifier is held.
4. `rcs_mix(craft_rcs_alloc_, wr)` — the Phase 50 kernel, unmodified.
5. `craft_state_.att = rigid_body_step(craft_state_.att, inertia,
   achieved.torque_nm, dt_att)` — the Phase 48 kernel, live for the first time.
6. Accumulate `achieved.force_n * (dt_att / m_kg)` into `rcs_dv_accum_`,
   per-component gated.

`ramp_toward` is a dyadic add/subtract with an exact clamp at the target —
releasing a key decays the axis to a literal `+0.0`, not an epsilon-away
value. The test suites replicate it bit-for-bit as their reference
oracle rather than re-deriving it independently.

RCS consumes no propellant this milestone. The point-mass fuel model stays
main-engine-only; per-thruster mass flow needs a per-part mass/center-of-mass
model the mixer doesn't have yet (its origin-at-CoM contract assumes one fixed
CoM for all of M1.1). RCS fuel accounting reopens with part-based craft.

## Kill-rot: a guarded snap to literal zero, not an approximation of one

Kill-rot needs to be testable as literal `ω == 0.0`, and the naive approach —
one tick of `τ = -I·ω/dt` clamped to the mixer envelope — doesn't get there.
The reason is structural: the Phase 48 kernel's KDK order is half-kick →
free-rotor drift → half-kick, and the drift rotates ω on the polhode *between*
the two half-kicks. So `τ = -I·ω/dt` computed from the pre-step ω leaves
`ω_final = D(ω₀/2) - ω₀/2`, not zero — an O(dt²) residual that's physically
meaningless on the final tick but not bit-zero.

The fix is a guarded commit, not a silent one. The exact law only fires the
guarded path when it was unclamped on every rotation axis *and* `rcs_mix`
reports `scale_factor == 1.0` — the "mixer-honest" predicate, because a
request that fits the envelope on its own can still get uniformly scaled down
by a shared-jet saturation coming from the live translation force rows. Once
both conditions hold, the worker Debug-asserts the post-step residual is under
`kKillRotResidualBound` (loud failure if a broken law were ever committed
silently) and only then snaps `ω := (0, 0, 0)`. Measured residual across the
suite's tumble fixture (ω {0.4, -0.3, 0.2}, moments {1000, 1200, 1500}):
`6.776e-21 rad/s`. The bound is pinned at `5.0e-20`, about 7x the measurement —
roughly sixteen orders of magnitude below the ~1e-3 physical envelope the
bang-bang max-decel phase drives every axis into before the mixer-honest
predicate can fit them all simultaneously. The compare is squared (`res² <=
bound²`), keeping the worker translation unit's libm surface exactly `{cos,
sqrt}` — no new `sqrt` call for a residual check.

Kill-rot is engage-until-done: one press latches, it runs to the exact
zero and auto-disengages, a second press cancels early into a coasting free
rotor. Pilot wins: any nonzero raw rotation input clears the latch that
tick and applies the manual command instead. The two authorities never
superpose. Rotation ramps freeze while latched, so a released kill-rot
doesn't inherit a stale ramp value. `killrot_cancel_early`'s own fixture caught
a wrong invariant during development: an asymmetric free rotor conserves `|L|`
and energy, not `|ω|` magnitude, which genuinely drifts along the polhode
(measured 4e-4 over 40 ticks) — the test was asserting the wrong physical
quantity, not the engine.

## Warp attitude: exact, not clamped, and loud when it can't be

The requirement going into this phase was explicit: a spacecraft
tumbling out of control must not become quietly stable merely by entering
warp. This delivers that as an exact free-rigid-body propagator rather
than an approximation — warp is torque-free by the existing
zero-thrust invariant, so warp attitude is closed-form torque-free rigid-body
motion, evaluated once per warp step at O(1) cost regardless of warp depth,
the same shape as the Phase 51 position conic.

The propagator (`frb_precompute` / `frb_step`, `frb_propagator.{hpp,cpp}`)
uses the van Zon–Schofield theta-function formulation over the alternative
Celledoni–Fasso–Safstrom–Zanna Pi-based form specifically because of where
each one puts its expensive transcendentals: the Pi form needs an incomplete
third-kind elliptic integral on every warp step, while the theta form confines
all of that — Jacobi K/K′, `det_exp`, `det_atan2` — to a one-time per-tumble
cold precompute, leaving the hot per-step path to theta-quotient sn/cn/dn
built from `det_sin_cos`/`det_sqrt`/`det_atan2` only. Both formulations were
cross-validated before implementation against long-double RK4 ground truth, an
AGM-descent Jacobi oracle, and the Celledoni Pi form itself, before any of it
reached the propagator's own code. Measured against RK4: ~5e-14 over one 300 s
warp step, ~9e-13 over 6000 s.

Near the separatrix — where the tumble's energy and angular momentum sit at
the exact ratio that makes the polhode degenerate — no fixed theta-term count
converges, and the propagator does not pretend otherwise. It dispatches five
explicit branches (Identity, PureSpin, SymmetricTop, the generic Elliptic
case, and Guarded). A tumble whose nome exceeds `kFrbQMax = 0.5` returns
Guarded with a NaN-poisoned `frb_finite_probe`. The worker reads that probe at
warp-session entry and hard-stops with a `runtime_error` naming the guard and
the offending ω — never a silent NaN-poisoned craft. This isn't a corner case
that only shows up in synthetic fixtures: the exact Dzhanibekov intermediate-
axis IC from Phase 48's Dzhanibekov fixture (`ω = {1e-4, 1, 1e-4}`) precomputes to
`q = 0.618`, above the guard, and is correctly Guarded. Phase 52's own flip
demonstration through warp instead uses a within-window perturbation
(`ε = 0.01`, `q = 0.417`) cross-checked against the flown kernel for the same
initial condition.

Warp input is physically inert: a command entering the ring during
warp drains normally (its level state carries forward so control resumes the
instant warp ends) but applies no ramp, no mixer call, no torque, no Δv, and
no kill-rot toggle — only a throttled `warp-blocked-input` stderr line. A
sustained ~1 s hold (`kWarpExitHoldTicks = 7 × kAttTicksPerStep` warp-arm
visits) is read as declared intent to exit, and reuses the existing Phase 51
mid-warp latch verbatim. The hold counter is a new *trigger condition* added
to that latch's `if`, not a second exit path, so `warp_exit_session()`'s call
count doesn't change. A blocking edge case surfaced wiring this: `fine`/
`quantum` were originally computed before the tier-switch prologue, so a
controlled craft's warp *entry* — which fires inside that prologue — would
read a stale Flown-tier value and run the attitude subcycle during warp,
violating the zero-torque-in-warp invariant. No Phase 51 fixture had ever
driven a controlled craft into warp, so the bug was latent until this phase's
own test exercised it; moving the read to after the prologue fixed it in the
same commit.

## Determinism and test counts

Full suite: **847/847 Release**, confirmed again the next morning with no
fixes needed. `nbody_force.cpp` — the locked deterministic kernel — stayed
byte-untouched across the whole phase; the locked Phase 48 kernel and
Phase 50 mixer files (`rigid_body.cpp`, `rcs_mixer.cpp`) are wired live but
never modified. The worker translation unit's libm baseline holds at
exactly `{cos, sqrt}` — the kill-rot residual check, the new subcycle loop,
and the RCS seam injection add no new libm symbols; `frb_propagator` and
`det_math` are libm-free TUs in their own right (`nm -u -C`, filtered for
`det_` prefixes, comes back empty). A TSan lane run against the `InputRing`
target came back with zero data-race reports across the SPSC
producer/consumer pair.

Manual/visual verification of the three behavioral criteria — visible
rotation, kill-rot damping, balanced translation — is explicitly deferred:
there's no renderable craft model yet, so verification accepted the
code-level coverage (deterministic, bitwise-locked, not smoke-level) and
carried the visual pass forward to whichever phase first puts a craft on
screen.

## Where it is now

Phase 52 is engine HEAD as of this writing (2026-07-22) — Phase 53 (telemetry
and a debug HUD) is next and hasn't touched any of this surface yet. There is
no drift to report. The near-separatrix guard-only policy (the theta form's
branch (iii), sech/tanh, deliberately not implemented) and the new
free-rigid-body/elliptic math surface are both named, standing items for
Phase 54's review rather than open debt — flagged explicitly rather than
treated as resolved.

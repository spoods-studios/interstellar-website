# M1.1 Phase 51 — n-Body Integration Hookup: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-20**; the
> drift section traces the thrust seam and the warp-arm craft branch
> through Phase 52.

## Starting point

Phase 48 built the rigid-body attitude kernel. Phase 49 built the
Tsiolkovsky thrust kernel — both validated as standalone math, exercised
only by their own test suites, never through the live `PhysicsWorker`.
Phase 50 added the
RCS mixer the same way. Phase 51 is where all three get a body. A craft
occupies the existing M0.5 `FeelOnly` test-particle slot. Thrust threads
into the n-body core through the kick seams already in `run_due_steps`. The
M0.7 warp tier — which had no code path for advancing a test particle
at all — gains one. `nbody_force.cpp` — the locked deterministic kernel —
does not move; every addition sits beside it, not inside it.

## The fuel-depletion order was the phase's flagged design pass

This phase needed one committed answer to a question with no clear
default: when a burn spans an outer step, does the impulse land at the
start, the end, or split — and does the mass update before or after the
velocity write? Four options existed: full impulse at first kick, full
impulse at second kick, symmetric split, or punting to implementation.
The symmetric split won because it's the only one that
matches the KDK shape the rest of the integrator already uses: `half =
0.5*dv` applied before the tier's dispatch, `second = dv - half` after.
Computing the halves that way rather than as two independent `0.5*dv` calls
means they sum back to `dv` binary-exactly, so Phase 49's telescoping
guarantee survives the seam intact.

Mass commits at the first half-kick. One `thrust_step` call per outer step
produces `{dv, m_new}` as an atomic pair. `m_new` is stored before
either velocity write. The one-line summary that ended up in the code
comment is "mass leads, velocity splits." The seam attaches at the
**outermost** fixed-step boundary, never inside `accel_fn_`. That function
is where the continuous J2/1PN perturbations live and get re-evaluated at
every inner KDK kick, so a thrust term placed there would get multiplied by
however many inner Yoshida4 stages the active tier happens to use —
otherwise a trajectory that "looks burned" while carrying 2x or 4x too
much delta-v. Attaching at the tier-agnostic outer boundary means the inner
Yoshida4 stage count and the WH Kepler-drift-plus-kick structure never see
thrust internally. No symplectic claim is made for the coupling — 2nd-
order accuracy is the documented contract, not an accident.

The lock stack is four cases, not one: an in-orbit full-burn regression
against closed-form Tsiolkovsky, a same-binary golden `==` mid-burn
checkpoint, an explicit bitwise order tripwire (`v` after the first
half-kick equals `v0 + dv/2` with mass already `m_new`), and a determinism
check. The Tsiolkovsky band is locked at 16 ULP against a measured 2.95 ULP
result (GCC, `-ffp-contract=off`) — about 5.4x margin, matching the house
convention from the Dzhanibekov lock in Phase 48. `craft_scheduled_throttle`
reads the burn schedule's `{t_start, t_end, throttle}` windows under exact
comparisons (`t >= t_start_s && t < t_end_s`), so ignition snaps to the
first step boundary at or after `t_start_s` and cutoff to the first at or
after `t_end_s`. The only fractional case left is Phase 49's own
partial-burnout substep.

## One new function, tested with the worker nowhere in sight

The phase's single piece of genuinely new math is `rotate_body_to_inertial`
— the expanded quaternion sandwich that turns a body-frame vector into an
inertial one without a quaternion multiply or a call into `<cmath>`:

```cpp
const coords::Vec3f64 u{s.qx, s.qy, s.qz};
const coords::Vec3f64 t = u.cross(v_body);
return v_body + (t * (2.0 * s.qw)) + (u.cross(t) * 2.0);
```

Paired with it is `kBodyThrustAxis`, pinned to `{1, 0, 0}` — the main
engine thrusts along +X body, nose-forward, chosen over a launch-stack
−Z convention. Both are tested in complete isolation:
`[craft_frame]` never touches `PhysicsWorker`, only fixed known
orientations (identity, 90-degree axis cases, an arbitrary unit quaternion
checked against an independent Hamilton-product reference to 8 ULP). That
isolation is a requirement, not a style choice — the seam has to
be provably correct on its own before anything downstream calls it. The
identity and 180-degree cases locked bit-exact on the first GREEN run, with
no signed-zero flip and no tolerance relaxation needed.

The attitude this seam reads is a **static** quaternion this phase — the
Phase 48 kernel is not stepped yet. `CraftState`'s sidecar holds a constant
orientation set at seed time, with angular velocity required to be exactly
zero. That's what let the frame-conversion seam be tested completely
independent of the attitude dynamics. Phase 52 swaps in the live rigid-body
kernel without touching the seam itself.

## The craft is declared, not attached

`CraftConfig` is an optional field on `PhysicsWorker::Config` — empty means
the feature doesn't exist for that worker, no craft code is reachable, no
new control-channel surface this phase. It's the same declared-config idiom
the oblateness and PN corrections already use: fully deterministic from
step 0, no runtime attach path to reason about. Position and velocity ride
the existing `FeelOnly` TP slot unchanged (gravity comes free from the
Phase 26 TP partition). Mass, fuel, throttle, and attitude live in a
`CraftState` sidecar keyed to that slot.

Craft-absent runs staying byte-identical to the prior milestone's shipped
behavior is proven two ways, not one. Every existing golden lock stays
green with craft code compiled in but `CraftConfig` empty. A
`craft_seam_calls_` counter proves the craft-absent worker takes the
*structurally* identical path — the counter never increments if
`has_craft_` is false — a stronger claim than numeric equality alone. A
coasting craft with `dv == 0.0` is likewise a structural no-op at the kick
sites — the `!= 0.0` gate means the seam doesn't even write to the
velocity when there's nothing to add.

## Closing last milestone's warp deferral — for one craft

M0.7 Phase 39's HJS warp tier rejected every test-particle-bearing
hierarchical seed outright — a named deferral. That collided with this
phase's own scope head-on: "burn starts mid-warp" is not testable if warp
refuses to run with a craft present in the first place — a spec
contradiction surfaced and fixed in the same phase, not re-deferred again.

The fix is narrow, not a reversal: the ctor guard now admits exactly one
`FeelOnly` craft test particle riding a hierarchy, at slot `n_active`.
Every other TP-bearing hierarchical seed still throws. A coasting craft
drifts each warp step on a Kepler-universal conic about its mass-dominant
body, selected by the same `select_dominant` scan the WH tier already uses
— one source of truth, not a second dominance heuristic. The branch is
built from three already-locked kernels (`select_dominant`, `g2b`,
`kepler_step`) with zero new math derived. That's also why the worker
translation unit's libm symbol gate stays at exactly `{cos, sqrt}` through
the whole phase. Dominance re-keys every warp step so the conic re-anchors
through SOI crossings — interplanetary transfers stay warpable rather than
forcing an exit on every dominance change.

Perturbations (J2, 1PN, third-body) are ignored during the warp drift. The
accuracy cost of that is measured, not assumed. Three calibrate-then-lock
divergence fixtures compare the warp conic against the full flown n-body
truth over an identical 7200-second span:

| Fixture | measured \|dr\| | locked \|dr\| | margin |
|---|---|---|---|
| quiet-heliocentric (3 AU, away from planets) | 10.3744 m | 50 m | ~4.8x |
| SOI-transfer (1.3x Earth v, crossing) | 419.965 m | 2100 m | ~5.0x |
| moon-perturbed (co-moving near Earth-Moon) | 2606.21 m | 13000 m | ~5.0x |

The ordering is honest rather than anticipated: the SOI transfer was
expected to be the worst case. Instead, the moon-perturbed craft lingers in
the Earth-Moon well for the whole span and accumulates the largest ignored
third-body pull. The transfer craft, by contrast, crosses through quickly.
The warp session's staging, write-back, and export loops were also
re-bound from "every slot" to `hjs_tree_.n_bodies` specifically. A craft
riding a hierarchy sits outside the tree. An unbounded loop would clobber
its conic-fresh state on exit.

## Burn/warp exclusion: latch, export, then ignite

Zero thrust is ever applied inside a warp step — that's a named hard
invariant, not an emergent property of the code. It's enforced three
separate ways: structurally (both kick sites sit after the WARP arm's early
`continue`, so they're unreachable during warp, not merely untriggered),
with a Debug-mode assert at each site, and with bitwise mass and
seam-counter tripwires in the acceptance suite that would catch a half-kick
sneaking through even if the structural placement were somehow bypassed.

Two gates realize the invariant against a live burn. Entry: while the
shared `burn_active` predicate from Phase 49 (the same one used everywhere
else that "is the craft burning" needs an answer) is true, `time_scale`
clamps below `warp_in_scale` and a throttled `warp-blocked-burn`
stderr line fires on its own log key — no cooldown once the burn ends.
Mid-warp: if a scripted burn comes due while the tier is already `Warp`,
the session **latches**. `warp_exit_session()` closes it at the next
warp-step boundary through the existing export path. Thrust ignites
from the first regular step in the same loop iteration, so exactly one
step's worth of simulation time advances. Both gate sites call the same
`burn_active` predicate deliberately: a second, independently-written
burning check at only one of the two gates is exactly the kind of drift
that would let a burn slip through the other one.

## Telemetry landed a phase early

Phase 53 needs the HUD to read craft state, so the publish snapshot's
flight block — present flag, wet mass, derived fuel, throttle, burn-active,
and the attitude quaternion — was extended now rather than touching the
worker a second time later. It fills unconditionally on every publish
(never gated behind the existing observability-cadence refresh, so a
burn-active flip is visible the instant it happens, not on the next
cadence tick). It sits under the same value-bearing finiteness guard that
already hard-stops on a non-finite body: a non-finite craft mass, throttle,
or quaternion component is treated exactly like a poisoned body, not a
silent NaN in the snapshot.

## Determinism and test counts

`nbody_force.cpp` stayed byte-unchanged across the phase (verified against
the M0.8 gate baseline). The worker translation unit's libm gate never
moved past its pre-existing `{cos, sqrt}` pair — none of the five plans
introduced a new transcendental call, because the conic branch, the
frame-conversion seam, and the thrust seam are all built from det-based or
pure `+-*` primitives. Full-suite growth across the five plans: 731/731 →
737/737 → 745/745 → 753/753 → 760/760 (Release). The Debug lane closed at
756/756 (four fewer than Release — the release-only zero-alloc lanes stay
excluded in Debug, unchanged from prior phases). Phase verification passed
the same day the phase closed.

## Where it is now (drift since 2026-07-20)

Phase 52 (2026-07-21, rotational input and the attitude subcycle) touched
every seam this phase built, without changing what any of them locked:

- **The thrust half-kick's throttle source is superseded, not replaced.**
  `craft_scheduled_throttle` still exists and still drives the engine for
  any craft that never receives a live command — byte-unchanged from this
  phase. Once a live command has arrived, the ramped `craft_state_.throttle`
  (integrated in Phase 52's attitude subcycle) takes over via a
  `live_input_seen_` branch added immediately above the Phase 51 comment
  block. The mass-leads/velocity-splits body of the seam is untouched.
- **RCS delta-v injects at the same seam site, after the thrust half.**
  Phase 52's RCS pipeline accumulates translation delta-v and adds its own
  first half immediately after this phase's thrust half-kick, per-component
  gated the same way thrust already was. There's no new `craft_seam_calls_`
  increment site, so the craft-absent audit still counts exactly two calls
  per outer step.
- **The mid-warp latch condition Phase 51 built got a second trigger, not
  a second mechanism.** Phase 52's hold-to-exit (holding a rotation input
  through warp until it accumulates enough ticks) reuses
  `warp_exit_session()` verbatim. The call-count delta from adding it is
  zero, because the counter this phase built was the only trigger a new
  consumer needed.
- **`warp_exit_session()` picked up a second teardown responsibility.**
  Alongside this phase's tier/transition-count bookkeeping, it now also
  invalidates Phase 52's FRB attitude session and resets the hold-to-exit
  counter when a controlled craft is present. That gives one auditable exit
  site covering every exit route (the prologue exit, the mid-warp latch, and
  Phase 52's hold-to-exit) rather than a duplicate reset at each call site.
- The zero-thrust-in-warp invariant this phase pinned three ways gained a
  sibling: Phase 52 added a zero-*torque*-in-warp invariant for attitude,
  enforced the same way (structural placement, Debug assert, bitwise
  tripwire) at the analogous point in the warp arm.

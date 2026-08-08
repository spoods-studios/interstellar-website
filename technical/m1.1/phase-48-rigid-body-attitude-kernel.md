# M1.1 Phase 48 — Rigid-Body Attitude Kernel: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-14**.
> A drift section traces `rigid_body.{hpp,cpp}` and `det_math.{hpp,cpp}`
> through engine HEAD (Phase 53, M1.1 still open).

## Starting point

M1.1 is the engine's first Phase 1 milestone — the point where a
player-controlled spacecraft exists at all. Phase 48 is the first phase of
it: a standalone 6DOF rigid-body attitude kernel — float64 quaternion
attitude, body-frame angular velocity, principal-moment inertia tensor —
integrated deterministically on a fixed step, with zero `PhysicsWorker` or
render dependency. No thrust (Phase 49), no RCS (Phase 50), no worker wiring
(Phase 51/52) — only the kernel and a Dzhanibekov intermediate-axis flip
fixture proving it holds up under the hardest free-rotor trajectory there
is.

## Exact rotations, not semi-implicit Euler

The obvious integrator for `(quaternion, ω)` is semi-implicit Euler: advance
ω from torque, advance the quaternion from ω, renormalize to fix the drift.
This was rejected: renormalization there is a correction for accumulated
error, not hygiene, and the scheme isn't exactly time-reversible. The kernel instead splits the free-rigid-body Hamiltonian
`H = G₁²/2I₁ + G₂²/2I₂ + G₃²/2I₃` into three pieces. Each piece has an
**exact** closed-form flow: a rigid rotation about the corresponding
principal axis by angle `θᵢ = Gᵢ·τ/Iᵢ` (Laskar & Vaillant 2019, eq. 3-6;
Dullweber, Leimkuhler & McLachlan 1997 is the original derivation, the
DLM/NO_SQUISH family). Composing the three exact flows symmetrically —
`R3(dt/2)·R2(dt/2)·R1(dt)·R2(dt/2)·R3(dt/2)` (Laskar & Vaillant's
`S_ABCBA2`) — gives a 2nd-order, time-reversible integrator for the full
non-integrable triaxial free rigid body without ever evaluating an elliptic
function.

Each single-axis stage is genuinely exact, not a linearization, so unlike
semi-implicit Euler this scheme has no small-angle requirement for
correctness at the single-stage level. What *does* still degrade at large
per-stage angles is the 2nd-order **composition** error — how well five
exact single-axis flows approximate the one true coupled flow. That is
exactly why calibrating flip timing empirically, rather than deriving it
from first principles, is required below.

```cpp
void free_rotor_drift(RigidBodyState& s, const RigidBodyProps& props,
                      double dt) noexcept {
    double L[3] = {props.i1 * s.omega.x, props.i2 * s.omega.y,
                   props.i3 * s.omega.z};
    rotate_axis(s, L, props.i3, 2, dt * 0.5);
    rotate_axis(s, L, props.i2, 1, dt * 0.5);
    rotate_axis(s, L, props.i1, 0, dt);
    rotate_axis(s, L, props.i2, 1, dt * 0.5);
    rotate_axis(s, L, props.i3, 2, dt * 0.5);
    s.omega.x = L[0] / props.i1;
    s.omega.y = L[1] / props.i2;
    s.omega.z = L[2] / props.i3;
}
```

The inertia tensor is diagonal by construction — `RigidBodyProps`
carries three principal moments `i1/i2/i3`, the body frame *is* the
principal frame, and there is no runtime diagonalization. A future
part-based craft that needs a general 3×3 tensor diagonalizes it offline;
that's a tooling problem, not this kernel's. `I_body` is fixed for all of
M1.1 — fuel depletion (Phase 49/51) changes mass, never the inertia
tensor, consistent with the point-mass fuel model locked 2026-07-13.

## det_sin_cos: the "not small angle" primitive

The engine bans libm on the hot path, so every stage rotation needs its
sin/cos from a hand-rolled primitive. The natural assumption is that a
physics substep's rotation angle is small enough for a plain Taylor series.
Measurement showed that assumption is wrong. At the engine's
only currently-defined fixed step (`step_dt = 300 s`, `main.cpp:380`), even
a slowly tumbling craft (`ω ~ 0.01–0.1 rad/s`) produces per-stage angles of
several to tens of radians — several full turns, not a fraction of one.

`det_sin_cos` is a bounded-domain halving + double-angle-reconstruction
primitive, the same shape as `det_stumpff`'s quartering
(`kepler_universal.hpp:52-59`):

1. Halve `theta` a fixed number of times (exact under IEEE-754, since
   multiplying by 0.5 never rounds).
2. Evaluate a 5-term Horner sin/cos series at the tiny reduced angle.
3. Reconstruct via `sin(2x) = 2·sin(x)·cos(x)` and
   `cos(2x) = 1 - 2·sin²(x)` the same number of times.

The domain bound is `kDetTrigMaxAngle = 64·π` — generous over the
fixture's measured O(0.1) rad per-stage angles and any plausible Phase 52
subcycle. Anything outside it, or non-finite, produces NaN in both
outputs rather than a silently-wrong value:

```cpp
void det_sin_cos(double theta, double& s, double& c) noexcept {
    if (!(is_finite_check) || !(abs(theta) <= kDetTrigMaxAngle)) {
        s = c = std::numeric_limits<double>::quiet_NaN();
        return;
    }
    // halve theta n times (n <= 12 over this domain), Horner series,
    // then n double-angle reconstructions
}
```

Calibration measured the achieved accuracy against a long-double
(`std::sinl`/`std::cosl`) oracle over a 12,001-point sweep spanning the
whole domain: max absolute error 1.457e-13 (sin) / 2.743e-13 (cos), locked
at 1.5e-12 (~5-10x margin). Pythagorean defect `|s² + c² - 1|` measured
5.966e-13, locked at 3.0e-12. That per-call defect is the number Phase
48-03's `|L|` conservation bound has to inherit — five rotations per
substep, each one a `det_sin_cos` call pair, each contributing that much
drift.

## The torque seam is structural, not compute-then-add-zero

`rigid_body_step` takes body-frame torque as a parameter even though no
caller supplies real torque until Phase 52. The KDK shape wraps the
free-rotor drift in two half torque-kicks — half kick, drift, half kick,
renormalize — mirroring the orbital leapfrog KDK. A zero torque vector has
to reduce *exactly* to the pure free rotor. The kernel gets that from
control flow rather than arithmetic: a `has_torque` presence flag (the same
idiom as `OblatenessProps::has_j2`) gates both half-kick calls, so a
torque-free craft never executes the kick's `+`/`*` at all:

```cpp
RigidBodyState rigid_body_step(const RigidBodyState& s0,
                               const RigidBodyProps& props,
                               coords::Vec3f64 torque_body,
                               double dt) noexcept {
    RigidBodyState s = s0;
    const bool has_torque = (torque_body != coords::Vec3f64{0.0, 0.0, 0.0});
    if (has_torque) apply_torque_half_kick(s, props, torque_body, dt * 0.5);
    free_rotor_drift(s, props, dt);
    if (has_torque) apply_torque_half_kick(s, props, torque_body, dt * 0.5);
    renormalize(s);
    return s;
}
```

## A sign convention that conserves everything and is still wrong

Every rotation in the splitting conserves `|L|` and rotational energy
exactly — rotations always do — so a sign error in the in-plane rotation
`L_j' = c·L_j + s·L_k`, `L_k' = -s·L_j + c·L_k` would pass a
conservation-only test while precessing in the wrong direction. Two
equally-plausible sign conventions exist in the literature (active vs.
passive rotation, which index leads). An early code sketch carried one
of them — the *other* one, it turned out, once checked against the
right-multiply quaternion convention this kernel uses.

The RK4 reference is `rigid_body_rk4_reference`: an independent RK4 integration of
Euler's equations plus quaternion kinematics, built without touching the
splitting kernel's own code path. The recommended sign (consistent with the
body-frame derivation `dL/dt|body = -ω × L`) diverged from the RK4 reference
by a measured 1.36e-7 (ω) / 7.03e-8 (attitude) over a 2 s horizon. The
flipped sign — the one the early sketch carried — diverged by 9.60e-1 /
1.05e0: seven orders of magnitude worse, while still conserving `|L|` and
energy exactly the whole time. The recommended sign passed on the first
implementation attempt, so the flip was never exercised in this phase.
But the divergence gap is what makes the arbitration meaningful: a
conservation check alone could not have caught the wrong sign — only a
trajectory comparison against a genuinely independent integration could.

The whole pinned sequence — stage order, in-plane sign, kick placement, the
two-`det_sin_cos`-calls-per-stage grouping — is a locked extension of the
engine's determinism contract: changing any of it requires re-verification
against the lock.

## Dzhanibekov: the headline proof

The fixture is the UC Berkeley tumbling T-handle setup — spin
dominantly about the intermediate axis, `ω(t₀) = ε·ê₁ + Ω·ê₂ + ε·ê₃` with
`ε ≪ Ω`, distinct principal moments. The Berkeley source gives the
qualitative shape only, not concrete numbers, so the fixture was pinned and
calibrated in-phase: `I = {1.0, 2.0, 3.0} kg·m²` (well-separated triaxial,
axis 2 unambiguously intermediate), `ω₀ = {1e-4, 1.0, 1e-4} rad/s`
(`ε/Ω = 1e-4`), `dt = 0.1 s`, horizon 600 s. The separatrix growth rate
`Ω·√((I2-I1)(I3-I2)/(I1·I3)) ≈ 0.58/s` predicted a first flip on the
tens-of-seconds scale. Measurement matched on the first run — 17
intermediate-axis sign changes over the horizon, first flip at 18.9 s.

Conservation alone is not the proof — a badly-composed trajectory can
conserve `|L|` and energy (both structural properties of the splitting)
while completely failing to reproduce the qualitative flip behavior, or
producing spurious extra flips. So the fixture locks four independent
things at once:

- **(a) Occurrence** — `ω.y` changes sign at least twice; measured 17.
- **(b) Conservation** — `|L|` relative drift ≤ 3.0e-13 (a Casimir, tight to
  round-off; measured 6.11e-14), rotational energy relative drift ≤ 5.0e-3
  (a bounded 2nd-order oscillation, not a Casimir; measured 9.01e-4).
- **(c) Same-binary golden** — full state (`qw,qx,qy,qz,omega`) at
  checkpoints {1000, 3000, 6000} steps matches frozen `to_bits` literals.
- **(d) Time-reversal** — forward 6000 steps, negate ω, forward 6000 more,
  negate ω again, compare to the initial state: measured residual 1.36e-9
  (ω) / 7.22e-10 (attitude), locked at 7.0e-9 / 4.0e-9.

A fifth lock covers what the other four don't: the first-flip time
itself, banded at ±20% around the measured 18.9 s (`[15.12, 22.68]`). The
golden pins the exact bits. The band pins the physics — a
conservation-preserving change that distorts how the trajectory approaches
the separatrix would move the flip timing far outside a 20% window while
leaving (a), (b), and (d) all still green.

The `|L|` bound's margin traces directly to `det_sin_cos`'s calibrated
per-call defect: over 5 stages × 6000 substeps = 30,000 rotations, a
random-walk ceiling from the 5.97e-13 measured Pythagorean defect sits
around 1.0e-10 — the observed 6.11e-14 is roughly 300x under that ceiling.

## Where it is now (drift since 2026-07-14)

- **Phase 51 (2026-07-20):** `rigid_body.cpp` gained
  `rotate_body_to_inertial` — the `R(q)·v_body` frame conversion expanded as
  `v' = v + 2·qw·(u×v) + 2·(u×(u×v))` to avoid a full quaternion multiply.
  It's an addition to the same file, not a change to `rigid_body_step` or
  the pinned rotation sequence. Phase 51 calls it to convert the
  main-engine thrust vector from body frame to inertial before it enters
  the n-body kick seam.
- **Phase 52 (2026-07-21):** the worker's attitude subcycle calls
  `rigid_body_step` live for the first time — `craft_state_.att =
  rigid_body_step(craft_state_.att, config_.craft->inertia,
  mix.achieved.torque_nm, dt_att)` in `physics_worker_thread.cpp` — with the
  RCS mixer's achieved torque (Phase 50) as the real, non-zero
  `torque_body` the seam was built for.
- **Phase 52 (2026-07-21):** a second, separate kernel —
  `frb_propagator.{hpp,cpp}` — landed as a closed-form warp-attitude
  propagator (van Zon & Schofield's theta-function exact free rotor,
  O(1) per warp step). It consumes and produces the same `RigidBodyState`/
  `RigidBodyProps` structs this phase defined, so the warp-exit handoff
  seeds the Phase 48 kernel unchanged. But it is new additive code, not a
  modification of `rigid_body_step` itself.
- As of 2026-07-22, `rigid_body_step`'s own body — the pinned rotation
  sequence, the sign convention, the torque gating — is unchanged since the
  phase closed. The one addition to `rigid_body.cpp` is the frame-conversion
  helper above. `det_sin_cos` and `kDetTrigMaxAngle` are also unchanged.
  Both are now load-bearing for every later M1.1 phase: Phase 49's thrust
  frame, Phase 50's RCS torque, Phase 51's worker integration, and Phase
  52's live attitude tick and warp propagator all run on top of this
  kernel as built.

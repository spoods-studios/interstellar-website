# M1.1 Phase 49 — Tsiolkovsky Thrust & Fuel Kernel: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-14**.
> M1.1 is still executing (currently Phase 53) — no gate has closed yet,
> so this note has no close-side citation. The drift section traces the
> kernel through Phase 51's n-body hookup.

## Starting point

Phase 48 landed the rigid-body attitude kernel the same milestone —
`rigid_body.{hpp,cpp}`, a standalone 6DOF kernel validated against the
Dzhanibekov flip with zero worker wiring. Phase 49 owes M1.1's other
foundational kernel: thrust that depletes fuel the way the rocket
equation says it must, closed-form-checkable, before any of it touches
the n-body integrator (Phase 51), player input (Phase 52), or a HUD
(Phase 53).

The MIT L14 momentum-balance derivation gives the correct variable-mass
equation of motion, `m(dv/dt) = F + (v′−v)(dm/dt)`, with thrust
`T = −u·(dm/dt)`. The phase boundary is drawn tight around that equation
and nothing past it: pin the mass-depletion convention at the kernel
level, lock the two closed-form regressions below, and leave *where* the
resulting Δv gets applied inside the n-body kick-drift-kick loop to Phase
51. The core risk: a per-substep Tsiolkovsky calculation can be exactly
right in isolation while the *integrated* full burn still diverges from
the closed form, because the mass-sampling convention for the kick
magnitude quietly uses a different clock than the drift acceleration. The
only test that reliably catches that class of bug is a full-burn-vs-closed-
form regression, not per-substep spot checks.

## The formulation: telescoping instead of discretizing

The kernel picks the **analytic log kick** over the more common
midpoint- or endpoint-mass force-kick discretization:

```
dm = u · mdot_max · dt
m1 = m0 − dm
dv = v_e · ln(m0 / m1)
```

Sum that over every substep of a burn and the logs telescope:
`Σ ln(mᵢ/mᵢ₊₁) = ln(m0/m_final)` exactly, regardless of step count or step
size. The mass-sampling-clock risk is dead by construction rather than by
tolerance — there is no mass-sampling clock to mismatch because the kernel
never discretizes the force at all; it discretizes the *closed-form* Δv
directly. The only residual error left is IEEE-754 rounding in the log
evaluation and the running sum, which is bounded and measured rather
than tuned.

That formulation needs a natural log inside the hot path, and the
engine's determinism rule bans libm transcendentals there. The phase
adds `det_log` to `det_math.{hpp,cpp}` alongside the existing `det_sqrt`/
`det_sin_cos` primitives — an IEEE-754 bit-seed exponent split plus a
sqrt(2)-centered atanh series, the same reduction family as `det_sqrt`/
`det_cbrt`, not `det_sin_cos`'s halving loop:

```cpp
double det_log(double x) noexcept {
    if (x != x) { return x; }                       // NaN -> NaN
    if (!(x >= kDetLogMinInput && x <= kDetLogMaxInput)) {
        return std::numeric_limits<double>::quiet_NaN();
    }
    if (x == 1.0) { return 0.0; }                   // exact fixed point

    const std::uint64_t bits = std::bit_cast<std::uint64_t>(x);
    std::int64_t e = static_cast<std::int64_t>((bits >> 52) & 0x7FF) - 1023;
    const std::uint64_t mantissa_bits =
        (bits & 0x000FFFFFFFFFFFFFULL) | (static_cast<std::uint64_t>(1023) << 52);
    double m = std::bit_cast<double>(mantissa_bits);   // m in [1, 2)

    if (m > kSqrt2) { m *= 0.5; e += 1; }             // sqrt(2)-centering

    const double z = (m - 1.0) / (m + 1.0);            // Sterbenz-exact numerator
    const double u = z * z;                             // |z| <= 0.17157
    double p = kC9;                                     // 10-term Horner, through u^9
    p = kC8 + u * p; p = kC7 + u * p; /* ... */ p = kC0 + u * p;
    const double ln_m = 2.0 * z * p;
    return static_cast<double>(e) * kLn2 + ln_m;
}
```

`kDetLogMinInput`/`kDetLogMaxInput` are `[2^-7, 2^7]` — a **defense-in-
depth plausibility bound**, not an accuracy bound. The
bit-seed algorithm is accurate over the whole positive-finite-double
range. The window exists to loudly reject corrupted or nonsensical
mass ratios rather than silently return something wrong. Sqrt(2)-
centering bounds `|z| ≤ 0.1716` for *any* input in the window, which is
what lets one fixed 10-term series cover the whole domain instead of
Cephes's usual near-1/far-from-1 dual branch. The 10-term count is a
derived minimum, not a round number: `ln(m)` tops out at `ln(√2) ≈
0.3466`, so 0.5 ULP is `2⁻⁵⁴ ≈ 2.78e-17`; the first omitted term at 10
terms contributes `≈8.0e-18` (under budget), while 9 terms leaves
`≈3.0e-16` (over budget). Measured max absolute error: **8.882e-16**
(~1 ULP), tolerances locked at `5.0e-15` (~5.6× headroom). `det_log(1.0)`
returns bit-exact `+0.0` by an explicit branch, not series composition —
that's the already-empty-tank fixed point (`m0 == m_dry` ⇒
`dv = 0`) landing exactly, not approximately.

## What was built

### The `det_log` primitive

The primitive above, plus `test_det_log.cpp`: exact fixed point, dense
ULP-oracle sweeps against a long-double libm reference, six frozen golden
bit patterns, loud-NaN specials, the two-sided window guard, and a
determinism check. `nm -u -C` on `det_math.cpp.o` shows nothing outside
the `det_*` whitelist. Full suite **685/685**.

### The `thrust_step` kernel

`thrust_force.{hpp,cpp}` — the minimal 3-parameter surface:

```cpp
struct ThrustProps { double v_e_mps; double thrust_max_n; double m_dry_kg; };
struct ThrustStep  { double dv_mps; double m_new_kg; bool burned_out; double burn_frac; };
```

`mdot_max_kg_s = thrust_max_n / v_e_mps` is a **derived accessor**, never
a stored member — the momentum-balance identity `T = v_e·ṁ` holds by
construction, so an inconsistent `(T, ṁ, Isp)` triple is unrepresentable.
`isp_seconds = v_e_mps / G0_STANDARD` reuses the engine's existing
`G0_STANDARD` constant rather than duplicating it — standard gravity, not
local `g`.

`burn_active(props, m_kg, throttle)` is `(throttle > 0) && (m_kg −
m_dry_kg > 0)` — one function, reused as `thrust_step`'s own structural
gate and the same predicate Phase 51's warp-tier exclusion gate and Phase
53's HUD will read. `thrust_step` itself is a three-branch ladder: a
structural no-op (`dt <= 0` or not burning — never touches `det_log`), an
exact-partial-burn branch (`dm_requested >= m_kg − m_dry_kg`: mass
assigned exactly to `m_dry_kg`, `burn_frac =
(m_kg−m_dry_kg)/dm_requested`), and the normal analytic-log-kick
branch. The public output is the Δv **impulse** — `ThrustStep`,
not an `a = F/m` acceleration surface — because Phase 51 applies it
directly as a velocity increment at the kick boundary. It is a scalar
kernel with no vector types or frame assumption, since direction
ownership belongs at Phase 51's `R(q)·F_body → F_inertial` conversion
seam, not here.

**Calibrate-then-lock tolerances** (Release, `-O3 -ffp-contract=off`):
full-burn `|Σdv − v_e·ln(m0/m_dry)|` measured **1.819e-12 @ N=960** and
**1.910e-11 @ N=3840** (per-step ≈5e-15), locked as an N-scaling formula
`kFullBurnTol(N) = 2.5e-14·N` rather than a fixed epsilon — a fixed
tolerance would either fail at high N or mask a bug at low N. Full suite
**696/696**.

### AA284a gravity-loss regression

The second closed-form anchor: Stanford AA284a Lecture 7b's finite-burn
gravity loss, `v = v_e·ln(Mᵢ/M) − g·t_burn`. This stays entirely test-side
— a small vertical-ascent loop in
`test_thrust_gravity_loss.cpp` drives the *real* `thrust_step` kernel
(kick up, then subtract `g·dt`) and compares the result against an
independent long-double libm oracle, so the kernel is never tested
against itself. It has zero production surface, mirroring the WH/IAS15
validation-harness precedent. Fixture: `v_e=3000, thrust_max_n=50000,
m_dry_kg=2000`, `m0=10000` (wet/dry ratio 5), `dt=0.25`, `g=G0_STANDARD` (a
fixture constant-*g* choice, not a claim that local g equals standard
gravity). Measured residual **9.91918e-12** at **N=1921** executed
substeps, locked `kGravityLossTol = 5.0e-11` (~5× headroom) — the
telescoping property kills discretization error, so this residual is
pure float rounding. A large residual here would itself be the bug
signal.

The same commit records the analytic-log-kick-plus-exact-partial-burn
design, naming both regressions as its validating evidence and explicitly
deferring the impulse-at-kick KDK placement question to Phase 51 —
staying strictly in the kernel lane.
Phase-end two-lane gate: Release **698/698**, Debug **694/694**. Both
`det_math.cpp.o` and `thrust_force.cpp.o` libm-clean. `nbody_force.cpp`
byte-untouched across the whole phase.

## The review round: a window bound with a blind spot

The code review rebuilt and ran the live suite, independently
re-derived all six `det_log` goldens in Python against `math.log`, and
verified the libm scan itself rather than trusting the prior claim.
It found one Critical issue. `det_log`'s `[2^-7, 2^7]` window is sized
and documented against the *total* wet/dry ratio, i.e. the burnout
call `det_log(m0/m_dry)`. But the normal branch calls `det_log(m_kg
/ m1)` on the **per-substep** ratio instead. Nothing bounded that
ratio. A single oversized substep — a large `dt` against a
high-mass-ratio craft, exactly the shape Phase 51's warp-tier kick-seam
was documented to drive — could push the per-substep ratio past 128 and
return NaN, while `m_new_kg` stayed finite, `burned_out` read false, and
`burn_frac` read exactly `1.0`: every visible field except `dv_mps`
itself looked like a perfectly healthy step. It was reproduced with a
plausible, non-adversarial fixture (`v_e=3000, thrust_max_n=50000,
m_dry_kg=500, m0=100000`, wet/dry ratio 200, one substep at 99.8% of the
burn duration): `m0/m1 ratio=143.06 → dv=nan, burned_out=0,
burn_frac=1`.

The fix is a file-local `dv_from_mass_ratio` helper that
peels exact factors of 128 off the high mass before the ratio ever
reaches `det_log`, reconstructing `ln(m_hi/m_lo) = k·ln(128) +
ln(residual)` with `kLn128` a hex-float-literal correctly-rounded
`7·ln(2)`:

```cpp
double dv_from_mass_ratio(double v_e, double m_hi, double m_lo) noexcept {
    double m = m_hi;
    double dv = 0.0;
    while (m_lo * kDetLogMaxInput < m) {   // ratio would exceed the window
        dv += v_e * kLn128;                 // peel one factor of 128
        m *= 0x1p-7;                         // exact power-of-two down-scale
    }
    dv += v_e * det_log(m / m_lo);          // in-window residual
    return dv;
}
```

The `2^-7` multiply is exact (power-of-two, rounding-free). The loop
is bounded and deterministic — for any ratio already inside the window
the loop body never runs, so every prior in-window call stays bit-
identical. Both call sites route through this helper now.

Two more findings followed the same shape. First: `dt = +Inf` isn't
excluded by the `dt <= 0.0` guard, so it lands on the exact-partial-burn branch with
`burn_frac = margin/Inf = 0.0` — outside the documented `(0,1]` range and
reading as "almost none of the burn happened" when the opposite was
true. Second: `throttle`'s NaN behavior was explicitly documented and
tested, but `dt`'s wasn't — `dt=NaN` degraded loudly (both outputs NaN)
while `dt=+Inf` degraded silently into the first finding's bogus fraction,
an inconsistent contract between the two inputs. The fix makes
the structural no-op guard symmetric — `!(dt > 0.0) || !is_finite(dt) ||
!is_finite(throttle) || !is_finite(m_kg)` all take the same no-op
passthrough now, so a non-finite input rides through as an unchanged
`m_new_kg` (loud for a mass-checking caller) rather than producing a
finite-looking but wrong `burn_frac` or a silent NaN three systems
downstream.

## Why it was built this way

- **Telescoping kills the actual risk.** The mass-sampling clock
  mismatch is a real, previously-documented failure mode for naive
  force-kick discretization. Choosing the analytic form specifically
  because it telescopes — rather than adding more test coverage around a
  discretized form — removes the bug class instead of guarding against
  it.
- **The output is an impulse, not an acceleration.** The Δv-per-
  substep surface exists because Phase 51 needs to apply it as a
  velocity increment at an existing kick boundary. An `a = F/m` surface
  would have needed its own integration inside the kernel or a second
  API shape at the seam. One surface, one placement decision, made once
  at the phase that owns it.
- **A window sized for one call site doesn't protect another.** The
  window-bound finding is the clearest example in this phase of a domain
  guard being correct for the use case it was designed against (the total
  wet/dry ratio) and silently wrong for a second use case that shares the
  same function (the per-substep ratio) — exactly the kind of gap a
  build-and-run review with independently-reproduced fixtures catches and
  a paper read-through would not.
- **`burn_frac` needed the same non-finite discipline `throttle`
  already had.** The two `+Inf`/NaN findings weren't new bugs so much as
  an inconsistency between how thoroughly two structurally similar inputs
  were guarded — closing it made the contract symmetric rather than
  adding a one-off patch for `+Inf` alone.

## Where it is now (drift since 2026-07-14)

`thrust_force.{hpp,cpp}` and `det_math.cpp`'s `det_log` body are
byte-identical to how this phase left them — no diff against current
`HEAD` in either file. Two things moved around this kernel without
touching it:

- **2026-07-20, Phase 51:** this phase deliberately pinned the
  mass-depletion *formulation* while deferring the mass-depletion
  *step-order inside the n-body kick-drift-kick loop* to Phase 51's own
  design record. Phase 51 resolved
  that: a symmetric outer-kick-seam split — "mass leads, velocity
  splits" — with `ThrustStep`'s impulse applied as `half = 0.5·dv_mps`
  at the first half-kick and the remainder at the second, mass updated
  first. The "fuel-mass depletion
  order" question is tracked resolved 2026-07-20 (Phase 51 shipped),
  distinct from this phase's own resolved "mass-depletion formulation"
  question — two different questions, two different phases, on purpose.
- **2026-07-21, Phase 52:** `det_math.hpp` grew four new cold-path
  primitives (`det_agm_k`, `det_ellf`, `det_exp`, `det_atan2`) for the
  free-rigid-body warp propagator, appended after `det_log`'s
  declaration in the same file. Purely additive — `det_log` itself is
  untouched. The new primitives target Phase 52's attitude-warp
  math, not thrust.

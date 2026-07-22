# M0.3 Phase 13 — Integrator Core: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on
> 2026-05-21**; the drift section traces the step family
> through today's four-tier integrator stack.

## Starting point

Phase 12 shipped `evaluate_force(mu, r_relative)` — inverse-square gravity in
float64, acceleration out. Phase 13 is what calls it: the fixed-step
symplectic integrators that advance (position, velocity) state. The bar
downstream is Phase 15's energy-conservation gate — `|ΔE/E| < 1e-9` over 10⁵
steps of a canonical Earth orbit — a number a non-symplectic integrator cannot
reach at any dt, because its leading error term drifts secularly instead of
oscillating in a bounded band.

The phase also owned a named M0.2 carry-over: a silent
origin-collapse when a NaN reaches `to_absolute`; the M0.2 review demanded
a per-substep — not per-step — NaN/Inf filter via `try_to_absolute`.

## What was built

### The header

`engine/include/interstellar/physics/integrator.hpp`: a POD `State
{ Vec3f64 r; Vec3f64 v; }`, empty tag structs `Leapfrog{}` / `Yoshida4{}`
behind a C++20 concept, and one declaration:

```cpp
template <IntegratorMethod M>
void step(std::span<State> states,
          double dt,
          bound_force_fn f,
          coords::Vec3i64 origin);
```

A free-function template — no v-table, full inlining, one explicit
instantiation per method in its own translation unit. The
concept exists for diagnostics: `step<int>` fails at the constraint, not ten
levels into instantiation. `bound_force_fn` is a plain function pointer
`Vec3f64 (*)(Vec3f64)` with μ pre-bound by the caller — not `std::function`,
which costs heap allocation plus ~21 cycles of construction against the
pointer's ~5-cycle indirect call. The span signature is the deliberate
M0.4 scaffold: M0.3 always passes size 1; an N-body caller passes
size N without touching the kernel. The Yoshida coefficients live here as
`inline constexpr double` pinned to 25 significant figures — `std::cbrt` is
not constexpr in C++20 on the targeted libstdc++/libc++ releases, so the
literals are hard-pinned and the identity tests are the runtime backstop.

### Coefficient identity tests Y-1..Y-6

Yoshida's 1990 construction composes a symmetric 2nd-order base integrator
S₂ at widths (w₁, w₀, w₁), with the coefficients uniquely determined by two
constraints: consistency `2·w₁ + w₀ = 1`, and cancellation of the leading
O(dt³) Baker-Campbell-Hausdorff error term, `2·w₁³ + w₀³ = 0`. Solving gives
`w₁ = 1/(2 − 2^(1/3)) ≈ 1.351` and `w₀ = −2^(1/3)/(2 − 2^(1/3)) ≈ −1.702`.

`test_yoshida_coefficients.cpp` pins six identities. Y-3 is the load-bearing
one:

```cpp
// Y-3: 2·w₁³ + w₀³ = 0 — the BCH 4th-order condition.
const double order_condition =
    2.0 * std::pow(yoshida_w1, 3) + std::pow(yoshida_w0, 3);
REQUIRE_THAT(order_condition, WithinAbs(0.0, 1e-14));
```

The research walked the sign-flip failure mode exactly: with w₀ transcribed
positive, Y-1's sum evaluates to ≈ 4.05 instead of 1.0 and Y-3 to ≈ 9.86
instead of 0 — both catch it at unit-test time. Without them, a sign-flipped
w₀ reverts the composition to 2nd order with secular energy drift: invisible
at 10³ steps, visible at 10⁴, gate-blowing at 10⁵. Y-2 pins `w₀ < 0`
directly, Y-4/Y-5 pin both values against `std::cbrt(2.0)` at runtime, Y-6
pins the (w₁, w₀, w₁) palindrome. Tolerances are derived: Y-1's operands
share the (2 − 2^(1/3)) denominator so cancellation is within 1–2 ULP and
1e-15 is comfortable; Y-3 sums cubes at unshared scales, so 1e-14.

### KDK Leapfrog kernel + per-substep filter

`engine/src/physics_integrator_detail.hpp` declares the shared primitive —
an internal header next to the .cpps, never installed under
`engine/include/`. `physics_integrator_leapfrog.cpp` implements it:

```cpp
void leapfrog_kdk_substep(State& s, double dt, bound_force_fn f,
                          coords::Vec3i64 origin, const char* method_name) {
    // KDK form per D-07: v += a(r)·dt/2 ; r += v·dt ; v += a(r)·dt/2
    const double half_dt = dt * 0.5;

    const coords::Vec3f64 a0 = f(s.r);
    s.v = s.v + a0 * half_dt;
    check_finite_or_throw(s.r, origin, method_name, "0 (post half-kick 1)");

    s.r = s.r + s.v * dt;
    check_finite_or_throw(s.r, origin, method_name, "1 (post drift)");

    const coords::Vec3f64 a1 = f(s.r);
    s.v = s.v + a1 * half_dt;
    check_finite_or_throw(s.r, origin, method_name, "2 (post half-kick 2)");
}
```

Kick-drift-kick keeps (x, v) synchronized at integer step boundaries, so an
energy probe `½‖v‖² − μ/‖r‖` sampled there is unbiased — the staggered
leapfrog form, where v lives at half-integer times, produces an
O(dt²)-biased energy curve that masquerades as drift. `check_finite_or_throw`
wraps `coords::try_to_absolute`: NaN/Inf yields an empty optional, and the
integrator throws `std::runtime_error` naming the method and substep. The
float64 state is never quantized between substeps — the conversion is invoked
purely for its validation contract, because a mid-substep int64
round-trip would inject quantization noise into the BCH cancellation.
Filter cost: one isfinite triple plus magnitude check,
~6–10 cycles per boundary. `test_leapfrog_step.cpp` pins a single KDK step
bit-exactly (5-ULP margin) against a hand-derived harmonic-oscillator
expected at dt = 0.01, plus a one-period closure at 1e-3 — Leapfrog is
2nd-order, so that bar is deliberately loose.

### Yoshida composition + convergence proof

`physics_integrator_yoshida.cpp` is 47 lines: `step<Yoshida4>` computes
`dt0 = yoshida_w1 * dt`, `dt1 = yoshida_w0 * dt`, `dt2 = yoshida_w1 * dt`
and calls `detail::leapfrog_kdk_substep` three times per state, tagging each
call "Yoshida4 substep 0/1/2" for the throw diagnostics. The middle substep
runs backward in time by ~1.7·dt while the net composed step advances by
exactly dt — not a quirk to engineer away: no positive-coefficient 4th-order
composition of a symmetric 2nd-order method exists (Yoshida 1990). This is
Form A — composition over S₂ — rather than the expanded 7-coefficient c/d
table; two constants instead of seven is less transcription surface, and the
redundant adjacent half-kicks at internal boundaries cost ~2 FMA per step,
the price of kernel reuse. The filter fires at every internal substep
boundary, nine per Yoshida step.

`test_yoshida_step.cpp` pins integrated 4th-order behavior, complementing
Y-3's algebraic pin: a harmonic-oscillator one-period closure at dt ≈ 1e-3
within **1e-10** — seven orders tighter than the Leapfrog bar at the same dt,
which is what dt⁴ scaling buys over dt² — and a convergence-ratio test at
dt ∈ {0.01, 0.005, 0.0025} requiring error to fall ~16× per halving, band
[8, 32]. The defenses are independent: Y-3 catches a wrong literal before any
integration runs; the convergence ratio catches a composition typo — dropped
substep, doubled width — when the literals are correct.

### NaN/Inf filter structural closure

`test_nan_propagation.cpp`, five TEST_CASEs: NaN in r, NaN in v, +Inf in r
under Leapfrog; NaN in r and in v under Yoshida4. Each requires the
`std::runtime_error` throw with method name and substep marker, AND that
M0.2's `g_to_absolute_release_violation_logged` atomic_flag stays un-set
after the throw — the upstream filter caught the NaN before the M0.2
cerr-once backstop could fire. The flag is process-wide, so every TEST_CASE
clears it first. Green in Debug and Release both: the cerr-once branch only
exists under NDEBUG, so a Debug-only test could pass without exercising the
contract it was meant to close.

### SimClock and wiring

`engine/include/interstellar/physics/sim_clock.hpp`, header-only: `sim_time_`
plus `const double step_dt_` — dt immutability enforced at the type level,
since the symplecticity guarantee rests on fixed-step composition.
`advance()` adds `step_dt_`; the Phase 14 worker decides when to call it, and
the time-scale UI changes how many advances happen per wall-clock second,
never the step size (the Fiedler fixed-timestep pattern). Non-copyable,
non-movable — a copied clock is an observably divergent time base. Its own
header so the worker and the HUD read `sim_time()` without dragging
integrator headers. Four TEST_CASEs include a 10⁵-step bit-exact
accumulation check at dt = 0.5 and a bounded-drift check at the
non-representable dt = 0.1. A verification commit confirmed the full wiring:
97/97 green Debug and Release — M0.2's 73, Phase 12's 7, and 20 new (6
identity + 3 Leapfrog + 2 Yoshida + 5 NaN + 4 SimClock).

## Why it was built this way

- **Symplectic because the gate demands it.** A symplectic map preserves
  phase-space volume exactly (Jacobian determinant 1), so it conserves a
  modified Hamiltonian close to the true one — energy error oscillates in a
  bounded band instead of drifting. Forward Euler's determinant is 1 + h²;
  RK4's truncation error accumulates secularly. The energy-conservation
  gate's bar selects the integrator family before any implementation choice.
- **KDK over DKD** is not a correctness call — both synchronize (x, v) at
  step boundaries under fixed dt. KDK reads as "force is the discretized
  thing" (the drift `x += v·dt` is exact), matches the Form A narrative, and
  is what REBOUND, GADGET, and ChaNGa ship. Because a stealth KDK→DKD
  refactor would pass the energy gate, the bit-exact single-step test is what
  pins the operator order.
- **Fixed dt is a contract, not a limitation.** Naive `Δt(|a|)` adaptivity
  destroys the modified-Hamiltonian guarantee through parametric resonance.
  The `const` member on SimClock makes the contract structural.
- **Energy probes sample full-step boundaries only** — inside a Yoshida
  step the state is mid-backward-substep and physically nonsensical.
- **Throw as the failure contract**: the alternative — returning
  `std::optional` per substep — puts a branch in every caller; a NaN state
  is unrecoverable anyway, and the Phase 14 worker catches the exception
  and posts a hard stop instead of dying silently.

## Where it is now (drift since 2026-05-21)

- **2026-06-04**: the filter validated
  only position, so a non-finite velocity written by the final half-kick
  escaped `step<M>()`; `check_finite_or_throw` now validates r and v at
  every boundary, and the throw names the offending channel and component
  values. A later fix replaced SimClock's `sim_time_ += dt`
  accumulation with `initial + step_count · step_dt` over an integer count —
  the exact swap the header comment had reserved. M0.3 merged 2026-06-05.
- **2026-06-08, M0.4 Phases 19–20**: the per-body
  `bound_force_fn` pointer became a whole-vector `bound_accel_fn` callback
  fired at both kick boundaries, the primitive operating over the full span
  with caller-owned acceleration scratch, the filter naming the offending
  body slot — bit-identical for N=1. IAS15, a clean-room Gauss-Radau
  predictor-corrector with adaptive step, joined as the close-encounter tier.
- **2026-06-15, M0.5 Phase 24**: Wisdom-Holman wired into the
  worker as `variant<Leapfrog, Yoshida4, Wh>` with dominant-mass
  auto-select; Wh has its own `wh_step` rather than plugging into `step<M>`.
- **2026-06-25**: the concept split — `KdkMethod`
  now constrains `step<M>` to Leapfrog/Yoshida4 exactly, so `step<Wh>`
  fails at the concept boundary. M0.6 shipped heliocentric WH for the
  planetary regime (merged 2026-06-25); M0.7 added HJS nested-WH for
  satellite systems (merged 2026-07-10).
- As of 2026-07-21 the stack is four tiers — Leapfrog, Yoshida4, WH/HJS,
  IAS15 — and the Phase 13 KDK substep primitive is still the base of the
  first two. The per-substep filter remains the same NaN/Inf mechanism, now
  N-aware and velocity-inclusive.

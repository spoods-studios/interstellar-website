# M0.5 Phase 24 — Wisdom-Holman Map: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-15**; the
> drift section traces the map through the same-day Phase 27/27.5
> correction and the M0.6/M0.7 milestones.

## Starting point

M0.4 closed with Yoshida4 as the only REGULAR-tier integrator and IAS15 as
the close-encounter fallback (Phase 20) — neither symplectic in a way that
tolerates a large configured `step_dt`. Phase 23 landed `kepler_step`, a
deterministic universal-variable two-body propagator, libm-free and
fixed-iteration. Phase 24 turns that primitive into a drift operator for a
Wisdom-Holman map: split the Hamiltonian into an exactly-solvable Kepler
piece per body (about a dominant central mass) and a small mutual-
perturbation kick, so a star-dominated table can take a much bigger
regular-regime step without secular energy drift.

The design locked the shape before any code: `Wh` joins `IntegratorMethod`
as an added tag, not a Yoshida4 replacement (deleting Yoshida4 trips the
M0.3/M0.4 bit-identity locks and leaves no fallback for non-dominated
tables); the frame transform lives inside the step only, so barycentric
Cartesian state crosses every other seam unchanged; symplectic correctors
(Wisdom 2006) are deferred; the WH↔IAS15 handoff reuses the existing
Cartesian seam verbatim. All of it landed 2026-06-15.

## What was built

### The DKD-map primitive, corrected to KDK

`wisdom_holman.hpp`/`physics_integrator_wh.cpp`: `to_democratic_heliocentric`
converts barycentric state to positions heliocentric relative to the
dominant body and barycentric-unchanged velocities; the dominant slot
stores its own absolute position, so `from_democratic_heliocentric` is a
single-forward-pass exact reconstruction — no barycenter divide, no
accumulating bias (measured worst relative error 1.6e-13 over 200k round-trip
samples).

The interaction kick is the heliocentric mutual perturbation among
non-dominant bodies only:

```cpp
// dr = Qⱼ − Qᵢ (heliocentric separation)
const coords::Vec3f64 dr = helio[j].r - helio[i].r;
const double r2 = dr.dot(dr);
const double inv_r3 = 1.0 / (r2 * det_sqrt(r2));
const double prefact = G * inv_r3 * dt;
helio[i].v = helio[i].v + (prefact * props.mass(j)) * dr;
helio[j].v = helio[j].v - (prefact * props.mass(i)) * dr;
```

It excludes the dominant-body attraction — that term is integrated exactly
by the Kepler drift, and including it in the kick double-counts and injects
secular drift. The dr sign, the `G·mass·inv_r3` prefactor form, and the
ascending-`i`/`j=i+1` pair-visit order with the dominant slot skipped are
pinned as the new WH-kick summation lock; the jump term's
momentum-sum order is part of the same lock. The one square root routes
through a hand-rolled `det_sqrt` (bit-seed + fixed 8-iteration Heron), never
`std::sqrt` — the whole WH path is `+,−,×,÷` only.

The democratic-heliocentric "jump" term is momentum-only — `H_jump =
|ΣPᵢ|²/(2M₀)` depends on no positions, so it is a pure position translation
applied in the drift, not the kick, and vanishes for a single massless test
particle.

The original design called for DKD (half-Drift → Kick → half-Drift). Under
floating point a DKD step propagates the two-body case as `kepler_step(dt/2)
∘ kepler_step(dt/2)`, analytically — but not bit-for-bit — equal to one
`kepler_step(dt)`, because each half-step rounds independently. The
split-correctness probe requires {dominant + massless test particle} to
collapse to `kepler_step(dt)` under exact `==`, unreachable with DKD.
**KDK** (Kick(dt/2) → Drift(dt) → Kick(dt/2)) makes the full drift a single
`kepler_step(dt)` call, so the massless case collapses to it exactly (kick
and jump both zero) — an equally valid second-order, time-symmetric
symplectic WH map, the standard half-a-kick-out-of-phase alternative, with
every determinism and energy lock (below) holding under it. That probe
confirmed bit-exact match across circular, eccentric, tilted, and
hyperbolic states.

### Worker wiring + WH↔IAS15 handoff

`Wh` joins the `IntegratorMethod` concept via a forward declaration (breaks
the `wisdom_holman`↔`integrator` include cycle) but does not plug into
`step<M>` — it dispatches separately. `Config.method` becomes
`std::variant<Leapfrog, Yoshida4, Wh>`; the ctor auto-select runs
`select_dominant` (the canonical-slot mass scan above) when `Wh` is
requested: star-dominated (top mass ≥ `kDominantMassRatio` × next) keeps WH,
anything else downgrades to `Yoshida4` — never throws — logged once via
`KeyedLogThrottle`. The REGULAR arm visits the resolved `method_`, not the
requested `config_.method`, so the auto-select is honored:

```cpp
if constexpr (std::same_as<M, Wh>) {
    wh_step(states_, props, dom_slot_, mu_dom_, dt, G);
} else {
    step<M>(states_, accel_fn_, dt, force_override, origin);
}
```

The ENCOUNTER arm (`integrate_window`) is byte-unchanged — the WH↔IAS15
handoff carries the same barycentric Cartesian `states_` bytes since the
frame transform lives *inside* `wh_step`, so the detector and IAS15
never see a democratic-heliocentric coordinate. A scripted
round-trip confirms finite, continuous state across REGULAR→ENCOUNTER→
REGULAR.

### Determinism + energy locks

Same-binary byte-identity: identical run sequences reproduce
bit-for-bit at both the `wh_step` primitive and the worker seam. The
time-reversal round-trip (forward-N / flip-v / back-N / flip-v) is the
primary bad-split probe — it returned to the initial state with residual
scaling **linearly with N** (~N·6.5e-11, a round-off random walk, not a
secular bias) across 2-body and 3-planet fixtures, confirming the KDK split
is genuinely time-symmetric beyond the single-step check above.

The symplecticity floor was measured over ~634 years (N=200k steps,
dt=1e5 s): energy error bounded and non-secular — two-body log-log slope
≈ −0.024, max |ΔE/E| ≈ 3.6e-9; Sun+3-planet slope ≈ −0.019, max |ΔE/E| ≈
3.4e-5. Both stronger than the √t Brouwer floor the assertion allows
(slope < 0.6). A further sweep tested step fraction against the shortest
orbital period at a fixed ~316-year horizon, from 0.001× (dt=31 558 s, max
|ΔE/E|=9.86e-7, slope −0.053) up to 0.03× (dt=946 728 s, still bounded,
slope < 0.6) — bounded and non-secular up to ~3% of the shortest period.
That value locks `kDominantMassRatio = 100.0` (Sun/Jupiter ≈ 1047:1, far
above it) and sets the stable warp-step bound the production seed draws
from.

### Production seed + frozen golden vectors

`main.cpp` flips the seed to `Wh{}` with `step_dt = 21600.0` (6 h, ≈0.9% of
the Moon's ~27.3-day period — the binding shortest period in the shipped
table — 72× the prior 300 s Yoshida4 step). The Sun-dominated table
auto-selects WH at the ctor (Sun/Jupiter ≈ 1047:1 ≫ 100); `time_scale` still
only scales steps-per-iteration, never `step_dt` itself. A frozen WH
golden-vector table (`test_wh_determinism.cpp`) reconstructs
five representative cases — star+1, star+2, near-resonant 2:1, small-dt,
large-dt — from exact IEEE-754 bit patterns (no libm on the golden-vector
generation path) and asserts the output bit-exact `==` on both CI lanes,
the real cross-platform guard.

## Why it was built this way

- **KDK over DKD.** The bit-exact split-correctness probe is a hard
  constraint, not a tolerance to loosen; KDK is the composition that
  satisfies it while staying an equally valid symplectic map.
- **Frame transform confined to the step boundary.** Every other seam —
  detector, IAS15, snapshot, `system_energy` — stays byte-unchanged, which
  keeps the WH surface additive against every prior lock.
- **Correctors deferred, not skipped.** Plain KDK already meets the
  symplecticity bound; a corrector tightens the constant, not the slope,
  and would add transform surface for no requirement this phase names.
- **Calibrate-then-lock.** `kDominantMassRatio` and the stable-step bound are
  locked from measurement, not an a-priori guess.

## Where it is now (drift since 2026-06-15)

- **2026-06-15, Phase 27:** the shipped map froze the dominant
  body — its barycentric position and velocity never updated across a
  step, because the back-transform anchored to the dominant slot verbatim
  instead of the barycenter, dropping its reflex motion and letting the
  barycenter itself drift. Production reverted to Yoshida4 at 300 s
  pending a fix.
- **2026-06-15, Phase 27.5:** the fix runs WH in the
  COM rest frame — the dominant body's position reconstructs from the
  barycenter and its velocity from total momentum. The symplecticity floor
  test was hardened to eccentric/inclined initial conditions plus a
  barycenter/momentum no-drift lock; the golden vectors were re-frozen
  against the corrected map (expected — the table is a determinism guard,
  not a physics oracle). With WH corrected, Phase 27 closed honest: it does
  not beat Yoshida4 at the shipped 5-body config, so Yoshida4 ships — WH's
  genuine win is aggressive time-warp (large step), not body count, banked
  for future milestones.
- **2026-06-24, M0.6:** the shipped 5-body seed fails the perturbation-ratio
  gate for the Moon (η ≈ 0.40) — heliocentric WH mis-models a bound
  satellite by construction. M0.6 narrows WH's shipped warp config to
  Sun/EMB/Mars/Jupiter (Earth-Moon collapsed to their barycenter);
  satellites route to a new M0.7.
- **M0.7:** Phase 37 nests a second WH map (`hjs_map_step`) inside the
  outer one — an inner map over each bound clump's internals (Moon around
  Earth) atop the outer map over clump barycenters around the Sun — so
  both planetary and lunar orbits get exact per-scale Kepler drifts.
- As of 2026-07-21 the KDK composition and WH-kick summation lock from
  this phase are unchanged; the frame anchor is COM-relative, and the
  nested HJS map is the production warp tier for satellite-bearing
  systems.

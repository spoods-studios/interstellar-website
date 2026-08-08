# M1.1 Phase 54 — Findings + Fixes: Technical Deep-Dive

> Retroactive technical devlog. **Closing gate of M1.1 Spacecraft Control.** The
> review ran 2026-07-28 against the post-Phase-53.3 tree; eleven fix phases
> (54.1–54.11) landed across 2026-07-28/29 and the gate closed 2026-07-29.

## The review pass

The gate dispatched 28 independent review runs — two independent frontier
models, each attacking from fourteen angles, every run read-only. All 28
returned. Baseline at dispatch: 903/903 Release, 899/899 Debug.

## What it found

**7 Critical, 17 High, 83 Medium, 39 Low.** The propulsion mathematics — the
priority surface, since thrust and fuel are what M1.1 added — came back clean.
Both reviewers independently re-derived Tsiolkovsky, the Isp/g₀ convention and
the thrust–mass-flow relation and found them correct; `g₀ = 9.80665` was
checked exact against NIST CODATA 2022 and the Earth GM against JPL's ephemeris
values, both fetched live. The attitude kick composition reproduces an
independent long-double RK4 of Euler's equations to |Δq| = 3.6e-6 with a clean
4.00 convergence ratio; the van Zon–Schofield elliptic branch agrees with the
same RK4 to 1.8e-10 over 200 s; the thrust seam converges at exactly 2nd order
over six step halvings. The locked deterministic force kernel
`engine/src/nbody_force.cpp` is sha256-identical to the previous release,
`engine/src/det_math.cpp` compiles to an object with zero undefined symbols and
zero mutable data, and `-ffp-contract=off` is genuinely load-bearing — O0, O2,
O3 and O3+`-march=native` all bit-identical. A thread-sanitizer run over the
live input/snapshot seam saw 1.65M snapshot reads against 1.61M input pushes
with zero races outside the one documented seqlock reader, and the worker
performed zero allocations across 147,456 attitude ticks.

Every blocker that did land sits at a contract seam the spacecraft work cut
through, not in an equation: which throttle a gate reads, what state survives a
tier transition, what a guard's bound actually permits, what an oracle is
allowed to know about the harness it grades. All 24 Critical/High blockers were
dispositioned in one pass on 2026-07-28 — 23 approved for in-milestone fixes,
one deferral re-scoped — and the fixes ran serially over the next two days.

### One throttle, four readers

The warp tier and the main engine disagreed about whether the craft was
burning. The burn↔warp exclusion — no engine burn inside the symplectic warp
tier, where a 300 s Kepler step would swallow the thrust — is enforced at three
sites in `engine/src/physics_worker_thread.cpp`: the warp-entry clamp, its
blocked-burn diagnostic, and the mid-warp latch. All three derived "is the
craft burning" from the scripted burn schedule. The thrust seam burns on the
live throttle once any live command has been seen. The shipped demo craft has
an empty schedule, so from the first keypress the two sides read different
numbers: the exclusion read 0.0 while the engine burned at full throttle.

The consequence was measured in both directions:

1. A player-throttled burn enters warp and applies zero Δv for the whole
   session. One reproduction froze the craft's mass at 600.000000 kg across 16
   warp steps at throttle 1.000; another measured ~1763 m/s of commanded Δv
   lost in two ticks. The HUD kept publishing THR 100% throughout.
2. With a schedule present and a live cut, warp is denied indefinitely while
   the diagnostic prints `throttle=1.000 (burn active)`.

Ten of the 28 review runs found this independently — the most-agreed finding
of the gate. It shipped because all four warp-gate tests drive scripted
schedules; none drives a live throttle.

The fix is one accessor, the single definition of the commanded throttle:

```cpp
// engine/src/physics_worker_thread.cpp
double PhysicsWorker::craft_commanded_throttle(double sim_time_s) const noexcept {
    return live_input_seen_ ? craft_state_.throttle : craft_scheduled_throttle(sim_time_s);
}
```

All four divergent call sites now go through it. Until the first live command
arrives it is the scheduled throttle by construction, so every scripted-only
fixture — the original warp-gate cases, the fuel-depletion locks — stays
bit-identical. A live-throttle regression sits beside the scripted lane and
reproduces both failure directions against the pre-fix code. Release 905/905.

### Five domain guards, one wrong diagnosis

The warp tier propagates a torque-free tumble with the closed-form free
rigid body (FRB) solution — Jacobi elliptic functions driven by deterministic
kernels in `engine/src/det_math.cpp`. The gate found five distinct defects on
that surface, and all five terminated in the same abort message blaming "the
near-separatrix regime". That shared mis-diagnosis is why Phase 52's
verification caught none of them: every failure looked like the one regime the
code had already documented as excluded.

The first: the phase constant τ₀ is built from `det_atan2` of the polhode
components, which lands anywhere in (−π, π] — but `det_ellf`, the incomplete
elliptic integral it feeds, only accepts |φ| ≤ π/2. Its banner said the caller
owns the reduction into that window. No reduction was ever written. For roughly
half of all tumbles the integral answered a quiet NaN, the finiteness probe
(computed upstream of τ₀) stayed finite, and the worker hard-stopped blaming
the separatrix. Measured on the shipped craft: 51.0% of warp entries after one
second of pitch+yaw input produced a NaN attitude. The fix is eight lines of
K-periodicity:

```cpp
// engine/src/frb_propagator.cpp — F is odd, and F(pi - phi | m) = 2K(m) - F(phi | m)
double ellf_reduced(double phi, double m) noexcept {
    if (phi > kDetEllfMaxPhi)  { return 2.0 * det_agm_k(m) - det_ellf(kPi - phi, m); }
    if (phi < -kDetEllfMaxPhi) { return det_ellf(kPi + phi, m) - 2.0 * det_agm_k(m); }
    return det_ellf(phi, m);
}
```

The reduced value agrees with a 2M-node long-double quadrature to 4e-16 at
points where the unreduced call returns NaN.

The second: `det_agm_k`'s domain window rejects `m < 9.5367e-7` — which
rejects the complementary integral K(1−m) for every near-axisymmetric tumble.
Pure-spin dispatch required exactly-zero off-axis rotation, but the RCS mixer
leaves ~1e-17 residuals, so a pilot-commanded pure rotation fell into the
elliptic branch with m→0 and NaN'd — in the *most* convergent regime the
mathematics has, while the abort named the least.

The third: the theta coefficients are combined exponents, q^((n+1/2)²), with
the multiplier reaching (7.5)² = 56.25 — so a nome as ordinary as q = 1.7e-6
asks `det_exp` for exp(−746), one step past its lower window, and gets a quiet
NaN. Reachable at pitch 0.01 rad/s plus yaw 1e-4 rad/s. Below the window the
mathematically correct value of the underflowed series term is exactly zero, so
the fix flushes to zero at the call site rather than widening the locked
kernel's domain.

The fourth: the craft validator never enforced the strict moment ordering
I₁ < I₂ < I₃ that the FRB precompute requires. An unsorted-inertia craft passed
validation, flew normally, then hard-stopped at its first warp entry — with,
again, the separatrix message.

The fifth defect was the diagnostic itself, which now names the regime that
actually triggered.

The measure that carried the whole bundle: on a 40³ tumble grid over the
shipped demo inertia, silent-NaN attitudes went from 50.00% to 0.00%; a
near-axis residual sweep went from 4.94% to 0.00%; every remaining guarded case
carries m = 1.0, the genuine separatrix. Every FRB fixture predating the gate
used all-positive angular velocity — mixed-sign, small-m and unsorted-inertia
fixtures now exist. Release 922/922, kernels still libm-free.

### What survives a tier transition

The drain loop computes its `fine`/`quantum` step selector once, before
draining the accumulator. The in-loop mid-warp latch can exit the warp session
*after* that, and every remaining due step in the same call then runs on the
stale selector. Identical time scale (2400×), identical input trace, identical
3600 s of simulated time, three different wall-clock chunkings: attitude tick
counts of 180224 / 163840 / 180224 against an expected 196608, with the craft
velocity bit-differing (`0x401bd2a6aba72e6c` vs `0x401bd2a6e910b3ee`).
Cross-frame-rate replay determinism — a stated milestone guarantee — was
broken. The replay lock never saw it because its fixture ran at 1200×, below
the 2048× warp threshold, so it never entered the tier it needed to cover.

Recomputing the selector after any in-loop tier change fixed the tick count —
196608 on all three chunkings, matching the reviewer's expected figure exactly
— and left the bytes still differing. The residual had a second root: the tier
prologue is evaluated once per `tick()` call, and a controlled craft's fine
drain empties the accumulator every call, so warp *re-entry* after a
hold-to-exit tracked the frame clock rather than sim time. Closed by inhibiting
re-entry while the declaring input is still held — which also completes the
hold-to-exit feature's own intent, since a player holding the exit key has
asked to leave warp, and re-entering one step later defeats that. A new lock,
`warpatt_replay_across_warp_exit`, pins byte-identity across three chunkings
including a non-exact multiple. Release 906/906.

The same investigation opened a sibling defect: at 2400×, a chunking that
injects less than one 300 s step per call never enters warp at all — the fine
drain empties the accumulator below the prologue's threshold every call, so
warp *availability* was frame-rate dependent too. That folded into the
drain-bounding work below.

### A guard bound eight orders too strict

Kill-rot damps a tumble and then commits the angular velocity to exactly zero
— guarded by an assert that the last tick's residual is below a bound before
snapping, so a broken control law can never be silently absorbed. The bound was
an absolute constant: 5.0e-20 rad/s. The residual is O(asymmetry·dt·|ω|²) — a
function of the rate the tick started from — and the retired constant had been
fitted at a seed where the deceleration had already driven |ω| to ~1e-10. It
was satisfiable only below ~7.6e-9 rad/s. At |ω| = 1e-4, an ordinary rate for
the shipped craft, the actual residual is 8.533e-12 — 1.7e8 times the bound.
An assert-enabled build aborted on an ordinary `T` keypress; every `-DNDEBUG`
build performed exactly the silent snap the guard exists to prevent. The
existing kill-rot suite passed with asserts on because it never operated in the
band where the assert could fire.

The bound is now derived, not constant:

```cpp
// engine/src/physics_worker_thread.cpp — factor·asymmetry·dt·|omega_before|²
const double bound = kKillRotResidualFactor * killrot_asymmetry * dt_att * w0_2;
assert(res2 <= bound * bound
       && "kill-rot exact-tick residual exceeded the derived bound");
```

The factor was calibrated over 7 inertia tensors × 4 timesteps × 7 tumble
directions in the regime the assert can fire; the worst measured ratio was
0.1245, and the factor is pinned at 1.0 — roughly 8× headroom. A companion
finding closed in the same phase: deleting the `mix.scale_factor == 1.0` term
from the commit predicate escaped the entire suite, with the mutant still
committing ω := 0 while 1.714e-3 rad/s of genuine rotation remained. That
escape is now constructed explicitly and pinned. Release 925/925, with the
assert live on the Debug lane.

### Tests that could not fail

The most uncomfortable family. The gravity-loss benchmark — the gate benchmark
for the thrust-and-fuel stack, checked against the AA284a closed form — had a
self-referential oracle: it recomputed the gravity term from the harness's own
substep count, so the two sides of the comparison could never disagree. The
lock passed at 9.9e-12 against a 5.0e-11 tolerance while the physical answer
was off by 2.451662 m/s — 2.02% of the final velocity. The tolerance itself was
dominated by the harness's own naive g·dt accumulation (5.28e-11), not by the
production thrust kernel (5.46e-12). The rebuilt oracle derives the burn time
independently from the propellant budget, the harness charges gravity only for
the fraction of the step actually burned, and the tolerance is split into
kernel, burn-time and closed-form parts, each justified. Post-fix residual:
1.313e-11 — now measured against an answer the harness didn't write.

Second: the project's standing rule that every math surface carries
property-based suites alongside representative-point tests had zero coverage
on the M1.1 surface — all 27 property suites in the tree belonged to earlier
milestones. `tests/unit/physics/test_property_m11_kernels.cpp` now runs
**364,636 assertions across 9 cases** over all three M1.1 kernels, with every
tolerance band measured by probe rather than guessed. The calibration produced
two characterizations worth keeping: energy conservation of the attitude step
is governed by the polhode phase advanced per step, A·|ω|·dt — the shipped
craft sits at 0.0092, and dE/E reaches 8.3e-5 only at 0.1 — and non-finite
divergence appears only above A·|ω|·dt ≈ 343. |L|² and the quaternion norm
hold to machine precision unconditionally.

Third: the replay and subcycle fixtures systematically avoided production
regimes — exact-multiple frame chunks only, time scales below the warp
threshold, and every controlled-craft fixture phase-locked to an attitude tick
divisible by 16384 while the shipped demo runs at 6917. The fixtures now cover
non-boundary tick phases (1, 4097, 6917, 12289, 16383), non-exact-multiple
chunkings, and scales above the threshold. Release 936/936, with zero
production numeric change — this family touched only tests.

### The input channel

Two defects, both on the path between a keypress and the physics. Input
commands are stamped with the worker's attitude tick so the consume side can
schedule them a fixed lead ahead. The stamp was read from a channel that
refreshed only on orbital-step boundaries — up to 13,981 attitude ticks stale,
which is 256 s of simulated time at the shipped 128×. The lead-tick scheduling
the input path was designed around never engaged. The fix publishes the
attitude tick live: an atomic `att_tick_pub_` release-stored per fine tick and
per warp-arm advance. Measured staleness after: zero, with the scheduling
branch demonstrably engaging at 128×.

The second defect: the input ring dropped the *newest* command on overflow.
For a level-state channel — key held, key released — the dropped message can
be the release edge, and last-wins semantics mean nothing behind it corrects
the record. Measured: ring saturated, release edge dropped, craft stranded at
|ω_x| = 9.577734 rad/s and still accelerating with no key held. The ring now
coalesces on full — the newest command overwrites the tail, with edge-flag
merge and newest-wins throttle disambiguation, so a release edge can never
vanish. The reproducer's stranded spin becomes bit-zero. One measurement was
handed forward: the two-tick input lead costs 0.286102294921875 ms of wall
clock at 128×, a number the wall-time work below consumes. Release 968/968.

### Bounding the fine drain

Attitude subcycle work was O(time_scale) with no bound. At the 2²⁰ scale
ceiling, one `tick(0.25)` cost 1.972 s of wall time — 7.9× slower than real
time and non-recovering, since the next frame injects more than the last one
drained. Break-even sat near 1.25e5.

The reviewer proposed a per-call iteration cap. That was rejected: a per-call
cap partitions fine and coarse work by how the wall clock happened to chunk the
injection — precisely the frame-rate variance the replay lock exists to forbid.
The landed bound is a scale threshold on the drain selector:

```cpp
// engine/include/interstellar/physics/worker_thread.hpp
inline constexpr double kAttFineScaleCap = 0x1p13;  // 8192 — largest dyadic draining
                                                    // one clamped injection in <= 0.125 s
```

Calibrate-then-lock: the largest power-of-two scale whose Debug-lane drain of
one clamped injection completes in ≤ 0.125 s (measured 0.096 s; 16384 fails at
0.193 s). At or above the cap, a controlled flown craft degrades to an FRB
torque-free coast per coarse step — stateless, thrust intact through the
existing kick seams, Δv within 2.95 ulp of the closed form — announced through
a rate-limited `attitude-degraded-coarse` log key. The per-call cap survives
only as a Debug tripwire that is unreachable through 2²⁰. After: 1.972 s →
0.000381 s Release (17.55 s → 0.00137 s Debug), every rung recovering.

The folded warp-availability defect closed at the same boundary: fine draining
now suspends and accumulates to the step boundary when warp entry is possible,
behind one shared predicate:

```cpp
// engine/src/physics_worker_thread.cpp — the ONE definition of warp-entry eligibility
bool PhysicsWorker::warp_entry_eligible(double scale, bool craft_burning) const noexcept {
    return has_hierarchy_ && tier_ == WarpTier::Flown && scale >= warp_in_scale_
        && !craft_burning && !warp_hold_exit_latch_;
}
```

Sub-step delivery's zero warp transitions became one, at the same boundary as
whole-step delivery, locked by `warpatt_entry_chunking_equivalence`. Release
974/974.

### Control constants in wall time

The command ramps — the shaping that turns a key tap into a gradual authority
rise — advance once per attitude tick, and a fine tick's wall period is
dt_att/scale. So the ramp durations were true only at 1×, a scale the product
cannot run at: with a 300 s orbital step, 1× is a frozen simulation, which is
why the demo boots at 128×. At 128× the axis ramp saturated in 2.29 ms of wall
time and the throttle ramp in 9.16 ms — indistinguishable from a step input —
and one held wall-second of full pitch commanded 366.7 deg/s. The shaping
mechanism was dead code in practice.

The fix divides each ramp increment by the live scale at the consume boundary:

```cpp
// engine/src/physics_worker_thread.cpp
const double axis_rate = kInputRampPerTick / scale;
const double throttle_rate = kThrottleRampPerTick / scale;
```

Ramp-to-full now costs 16·kAttDt = 0.29296875 s (axis) and 64·kAttDt =
1.171875 s (throttle) of wall time at every scale. The constants' values are
unchanged — they always encoded the wall-time intent, and the division is what
delivers it away from scale 1. `scale` is the same deterministic per-call read
the drain selector already uses, never a wall-clock sample, so a fixed-scale
replay stays bitwise identical; every scale on the shipped ladder is a power of
two, so every compensated increment is an exact dyadic; at scale 1 the division
is an identity, proven byte-unchanged. The compensation deliberately stops at
the ramps: command shaping is wall-time, but raw torque authority is physical —
dividing the kill-rot law or the precision modifier by the scale would make
commanded physics depend on how fast the sim runs. So 366.7 deg/s per held
wall-second at 128× stands as correct dynamics, and fine control at extreme
warp remains next-milestone machinery. Wall-invariance is locked across ten
scale rungs spanning the fine-scale cap into the degraded branch. Release
977/977.

### RCS: dead axes, sign inversions, and a fuel bill

Re-verification before fixing found the RCS allocation contract weaker than
the gate had reported. Over 500,000 random accepted geometries: 4.58% carried a
dead control axis silently written as a zero envelope; 60.51% could deliver a
sign-inverted axis — a commanded +1 executed as far as −727.894 in the worst
trial, against the single +1 N·m → −189 N·m case the review measured. Every
degradation flag the mixer raised was read by nobody. A NaN allocation built
from finite, accepted props was returned without complaint. And
`conic_samples` returned a full 256-vertex count while writing NaN into every
vertex.

After the fix, `build_rcs_allocation` throws for a genuinely dead axis — one
where every contributing thruster needs negative duty and has no opposing
partner to redirect through — and for any non-finite allocation. Sign
inversion is deliberately *not* rejected at build time. The checked-in locked
asymmetric fixture is itself an instance of it (a unit +1 N force command in Z
delivers −6.899363e-3 N), and measurement showed only a zero tolerance
eliminates the still-accepted-and-inverting population — a tolerance that
would reject that locked fixture; at the most sparing nonzero tolerance,
1.157% still invert. An unbalanced geometry that cannot achieve a pure-axis
command with non-negative duties is an actuation-authority limit of the
hardware, not a configuration error. What was unacceptable is that it happened
silently — so the milestone's success criterion was restated from "the
inversion is unreachable" to "the inversion cannot occur silently". `rcs_mix`
now raises a per-axis inversion bitmask, one exported policy function consumes
all three degradation flags — fatal on non-finite output, rate-limited
value-bearing log lines naming axis, commanded and delivered values otherwise
— and `conic_samples` reports zero vertices for a non-finite conic.

The bigger reversal: RCS had been propellant-free by a recorded 2026-07-21
decision, and the gate overturned it. Free RCS translation at 0.2 m/s² on dry
mass is 720 m/s of Δv per simulated hour — 26% of the entire main-engine
budget, reachable in about 28 wall-seconds at 128×. The decision's stated
blocker, "needs a part-based mass/CoM model", does not hold: the accepted main
engine already burns 60% of wet mass with a fixed center of mass. RCS now
draws propellant once per attitude tick from the achieved duty, through the
unmodified locked thrust kernel:

```cpp
// engine/src/physics_worker_thread.cpp — effective-throttle reduction makes the
// locked Phase 49 kernel compute dm = Sigma(u_i*T_i)/v_e * dt exactly
const ThrustStep draw = thrust_step(rcs_engine, craft_state_.m_kg,
                                    duty_thrust_n / craft_rcs_thrust_sum_n_,
                                    dt_att);
craft_state_.m_kg = draw.m_new_kg;
```

Only the mass is taken — the kernel's returned Δv is discarded, because the
RCS Δv already rides the achieved force into the accumulator, and applying
both would be a second impulse with no physical justification. An empty tank
zeroes the RCS wrench with no kill-rot exemption: nulling a tumble with
propellant the craft does not have would be the same defect readmitted. The
numbers after: mass flow 0.0363636 kg/s, 16,500 s of authority on a 600 kg
craft, and a total RCS budget of 2015.840 m/s against the main engine's
2748.872 m/s. A zero-command tick burns exactly the mass it burned before, so
craft-idle byte-identity holds. Release 959/959.

### Two weeks of red CI

Both declared CI lanes had been red for every M1.1 commit since 2026-07-14,
with the local branch 33 commits ahead of any remote run. Four defects:

1. A hard Linux build failure: `std::sinl`/`cosl`/`logl` are not guaranteed in
   `namespace std` — libstdc++ gates the l-suffixed names behind a
   configuration macro. All 8 call sites moved to the standard long-double
   overloads.
2. MSVC maps `long double` to `double`, losing 11 mantissa bits — one
   symmetric-top oracle failed outright on Windows and four ULP locks passed
   vacuously there. A precision header plus 17 explicit, reasoned skips
   replaced both failure modes, verified by simulating the MSVC condition with
   GCC `-mlong-double-64`: 23 failures → 936/936 with the skips, and the
   native lane unchanged at 936/936 with zero skips.
3. The fast-math configure guard matched only `-ffast-math`/`-Ofast`.
   `-funsafe-math-optimizations`, `-fassociative-math`, `-freciprocal-math`
   and clang's `-ffp-model=fast` all passed configure and measurably break
   bit-identity — the repo's own elliptic-kernel golden-bits lock fails under
   the first. The guard now covers the whole reassociation family across
   GCC/clang/MSVC spellings and names the offending flag.
4. Neither prepared local build directory had assertions enabled — both were
   Release — so the entire debug-invariant stratum was unexercised by the
   green runs the gate initially rested on. A genuine Debug build lane was
   stood up mid-gate (899/899), and a Linux Debug CI job was added with an
   anti-vacuity check that reads the compile database and asserts the debug
   flags are actually present.

Both lanes confirmed green on 2026-07-28 — cross-toolchain identity verified
at HEAD for the first time in two weeks.

## The deferral that changed its reason

One Critical was accepted rather than fixed, and the interesting part is what
it did to the paperwork. The craft is integrated on the same fixed 300 s step
as the planetary ephemeris — 18.5 steps per LEO orbit. Craft-orbital
subcycling had already been deferred to M1.2, with burn-trajectory
discretization recorded as the blocker. Both practitioner reviewers,
independently, measured the dominant error somewhere else: on the **coast**. A
craft coasting one LEO orbit on the 300 s step accumulates 546 km of position
error and a spurious eccentricity of 6.07e-4 — 4.96e-3 by ten orbits — while
the burn-trajectory error is 6.8–28.4 km, an order of magnitude smaller. The
measurement harness is confirmed by clean h⁴ convergence: at step_dt/64 the
error falls to 3.1 cm.

The project's deferral rule permits pushing work forward only against a
concrete, named missing-machinery blocker — and a deferral naming the wrong
failure mode does not satisfy it. The deferral was re-written to name the
coast error as the blocker, with the closure work staged at deferral time: the
craft gets its own integration step, decoupled from the ephemeris, following
the Principia precedent of a fixed-step ephemeris with vessels on separate
finer-step integration. It was not pulled into M1.1 because it is a
milestone-scale change, and this milestone's committed bar is demonstrable
thrust-changes-orbit, not real-time flight. The coast is the regime the craft
spends nearly all its time in, which is why this is recorded as inaccuracy
rather than coarseness.

## Close

Closed 2026-07-29 — Release 977/977, Debug 973/973, 2,093,627 math-lock
assertions green, the locked force kernel `engine/src/nbody_force.cpp`
sha256-identical to the previous release, and zero math-locks moved or
weakened across all eleven fix phases. Every fix that touched a locked surface
was additive: new locks, new fixtures, new asserts. The 83 Medium and 39 Low
findings were recorded with 18 cross-run duplicate pairs merged; the
documentation cluster — three status files disagreeing on the phase count, a
wrong comment claiming a readback reorder would re-trigger a lock (provably a
no-op: verified bit-identical over 20,000 random commands), a research note
describing a world-frame hazard the body-frame design does not have — landed
with the final fix phase. A mutation campaign from the review remains the
honest outstanding signal: 38 mutations, 20 caught, 4 provably equivalent, 14
genuine escapes, concentrated in tuned RCS tolerances.

The gate's own coverage gaps, stated for the record: no AArch64 or weak-memory
testing, and the non-atomic seqlock payload grew from 13 to 54 fields this
milestone — exactly the construct whose x86-only ordering argument does not
transfer; one compiler family locally (GCC 16.1.1), with MSVC covered only
through CI after the portability fixes and no Clang anywhere; no review run
flew the live Vulkan build, so render-side findings are static or
harness-level; and the panel ran two vendors, not three, per the standing
review policy. M1.1 exits with a craft that burns, tumbles, damps, warps and
pays for its propellant — and with the first playable milestone's physics
pinned behind the same lock discipline as the n-body core beneath it.

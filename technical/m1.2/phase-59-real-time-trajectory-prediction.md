# M1.2 Phase 59 — Real-Time Trajectory Prediction: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-31**; M1.2 is
> still open, and a later hardening pass this milestone touched this code —
> the closing section covers what changed and why.

## Starting point

Phase 57 extracted the shared craft-substep kernel both the flown worker and any
future replay would call, and locked its calling contract. Phase 58 gave a
maneuver node a data model: an epoch, three handle scalars in the node's own
TNB frame, and a burn derived from them. Neither reached the screen. Phase 59
owes the thing a maneuver-planning tool actually needs: a predicted trajectory
that redraws as a player drags a node handle, computed by the same physics the
worker flies rather than a second, cheaper approximation of it.

The constraint that shapes the whole phase is stated once and holds
everywhere downstream: the predictor may only call `physics::craft_substep`,
the exact function the worker calls every tick. A parallel conic
re-implementation would be faster to write and impossible to trust — a
mismatched force term or a different perturber model would show a player a
line their burn does not fly. The predictor is instead the kernel's second
caller, replaying it over a copied `physics::SnapshotView` on the main thread,
never touching worker state directly.

## Two segments, one kernel window

`render::TrajectoryPredictor` hands out two float64 polylines: Segment A runs
from the craft's current state to the node's epoch, Segment B from the node
past a horizon, with the node's burn injected as a throttle-command profile —
per the kernel's own contract, never a Δv schedule applied directly to
velocity. A coasting substep still sets thrust `enabled = true` at zero
throttle, matching the worker's own unconditional branch rather than taking a
different structural path outside a burn window.

Both segments come out of **one** kernel window sized to the whole horizon,
not a chain of the worker's 300 s windows. The shared perturber provider's
`KeplerDrift` mode evaluates each perturber's position from a single
window-start anchor, so opening one window over the full replay is what makes
that provider rule apply continuously across the segment boundary. The
consequence is stated at the design's own boundary: predicted and flown
trajectories agree bit-for-bit only where the worker's window-reopening
cadence and the predictor's single-window extrapolation happen to coincide —
not by construction over an arbitrary span.

## The frame-budget wall

The first measurement ran the kernel at the worker's own locked fine rate —
16,384 substeps per 300 s window, `craft_dt = 18.3105 ms` — and swept horizon
against wall time on two fixtures: a quiet 400 km circular orbit, and an
eccentric (e = 0.15) Moon-perturbed orbit.

| horizon (orbits) | wall (ms), eccentric fixture | × 16.6 ms frame budget |
|---:|---:|---:|
| 0.5 | 410.59 | 24.7× |
| 1.0 | 814.44 | 49.1× |
| 2.0 | 1622.04 | 97.7× |
| 5.0 | 4044.16 | 243.6× |
| 10.0 | 8067.63 | 486.0× |

Cost is flat at 2086.7 ns/substep to within 1.2% across a 20-fold horizon
change — no knee, no natural cliff to design around. Applying a
calibrate-then-lock decision rule to the worse fixture:

```
2086.7 ns / substep,  18.3105 ms of sim time per substep
  16.6 ms frame budget  ->  7,955 substeps  ->  145.7 s of horizon
  at a house ~5x calibrate-then-lock margin  ->  1,591 substeps  ->  29.1 s
```

Against a smallest-meaningful horizon of one full orbit (7,085 s for that
fixture), 145.7 s is 49× over the raw budget and 29.1 s is 245× over the
margined one. A handle-drag frame has to redraw Segment B from scratch by
construction — that is what "the line redraws live" means — so the shortfall
could not be amortized away; a 0.5-orbit drag frame at the flown rate cost
411 ms, about 2.4 fps.

A second, independent problem surfaced in the same measurement pass. Run
against a full nine-body seed, the shared perturber provider's `KeplerDrift`
extrapolation went non-finite for five of eight bodies inside a single
prediction horizon — Mars' position ratio against its own window-start anchor
reached 2.961e+11. None of the eight lost finiteness inside the worker's own
300 s window; the provider's within-window extrapolation was being asked to
hold over a horizon it was never calibrated for. A distant body's motion
relative to the craft's own dominant is essentially free-streaming at that
span — the near-rectilinear corner where the fixed-iteration Kepler solver
leaves its convergence domain.

Both findings were written up with the measured tables and no constant was
pinned against them — pinning a horizon or a stride that the data already
refuted would have meant improvising a fix the measurement was specifically
built to catch.

## Per-dominant anchoring

The perturber-extrapolation fix changes what each body extrapolates *about*.
Instead of every perturber Kepler-drifting relative to the craft's own
dominant, each one now drifts relative to **its own** dominant — Io about
Jupiter, Mars about the Sun, the Moon about Earth — and the resulting legs
compose into the craft's frame, child-to-root, in a fixed floating-point
summation order. Every leg is then a genuine two-body relative motion, inside
the solver's convergence domain by construction rather than by luck of
geometry.

The anchor table encodes the hierarchy with one structural rule: a
perturber's declared parent must be an earlier row in the same list, or a
sentinel meaning "the craft's dominant." That single constraint makes a cycle
unrepresentable — no visited-set, no recursion, no depth cap, because the
encoding cannot express a loop. On the render side, `PredictorPerturber`
carries a `parent_slot` that is **declared**, never scanned from mass, and
`set_source` validates it against exactly that rule before arming anything.

Under the repair, the same nine-body fixture that produced Mars' 2.961e+11
ratio and non-finite results for five of eight bodies now measures every
perturber bounded to within 1.004× of its own anchor across the full probe
ladder:

| perturber | max \|r\|/\|r0\|, legacy | max \|r\|/\|r0\|, per-dominant |
|---|---:|---:|
| Europa | **1.740e+08**, non-finite at 3600 s | 1.003 |
| Mars | **2.961e+11**, non-finite at 3600 s | 1.002 |
| Ganymede | 1.831, non-finite at 3600 s | 1.004 |

That the two modes share exactly one Kepler-leg helper in the provider is
what makes a single-anchor row byte-identical between the old and new modes
at every probed boundary — a property later locks depend on directly.

## Fitting the frame budget: a coarser tier, then amortization

The frame-budget fix has two parts. The first is a fidelity tier: prediction
runs the same kernel at **N = 1024** substeps per 300 s window rather than the
worker's 16,384 — sixteen times cheaper — inheriting its accuracy bound
directly from an existing convergence sweep rather than a fresh one: N = 1024
measured 3.482e-3 m of divergence per orbit against a 6.2e-3 m target on a
realistic LEO fixture. The rationale is stated where the tier constant lives:
the worker's 16,384 was chosen for control-latency reasons a drawn line
doesn't have; prediction has no closed-loop-control requirement, so it runs at
the accuracy floor instead.

The second part closes over what the perturber-provider fix couldn't: cost.
Rerunning the frame-budget measurement against the shipped 13-perturber demo
table under the N = 1024 tier still priced the full unfiltered table at
21,104 ns/substep — still over budget at any gameplay-meaningful horizon. The
fix is a shared tidal-relevance predicate applied at window entry, the same
one the flown worker applies to its own perturber table: a body whose tidal
scale (`mu·2r/d³`-class term) falls under a calibrated floor is excluded
before the kernel ever sees it, filtered through one predicate consumed by
both tiers so neither can silently diverge from the other's notion of "which
bodies matter here." On the shipped configuration that filters 13 declared
perturbers down to 2 retained (Sun and Moon) and drops the cost to 2,161
ns/substep — a 9.76× cut that tracks the leg-count reduction almost exactly,
confirming the speedup is the filter removing real work rather than the
harness measuring less of it.

With both fixes in place, the same decision rule that had failed by 245×
now closes comfortably:

```
worst measured ns/substep, filtered table ........ 2206.0
closed-trajectory horizon cap = 1 osculating orbit = 19,160 substeps (400 km LEO, T = 5554 s)
  => ONE full Segment B recompute = 42.27 ms

prediction's slice of the 16.6 ms frame .......... 25%  = 4.15 ms
at the house ~5x calibrate-then-lock margin ...... 0.83 ms of measured work/frame

  => kPredictionChunkSubsteps        = 0.83e6 / 2206.0     =   376 substeps
  => chunks to complete the cap      = 19,160 / 376         =    51 frames (0.85 s @ 60 fps)
  => kPredictionDragPreviewHorizonS  = 376 x 0.29296875 s   =   110.16 s -> 110.0
```

A full-cap recompute is split into 376-substep chunks: one chunk lands per
call, the previous polyline keeps drawing while the next one is in flight, and
a single swap publishes the new points together with their derived terminal
state so a caller can never read a horizon time that belongs to a different
line than the one on screen. Dragging a handle runs a **synchronous**
recompute out to a shorter 110-second preview horizon at the same fidelity, so
the line still redraws every frame during the drag itself; releasing the
handle queues the full-cap amortized recompute and the preview keeps drawing
until it lands. A Δv change mid-recompute drops the in-flight chunk sequence
and restarts rather than splicing — a spliced line would be part one burn and
part another, which no maneuver produces.

The open (hyperbolic) trajectory horizon cap, `kPredictionOpenHorizonS =
7200.0`, was derived from cost parity with the closed cap rather than fixed
arbitrarily. Emission cadence, `kPredictionEmitStride = 4`, was derived from
memory pressure: at a per-substep emission rate the guard against runaway
sample counts started binding above roughly a 21-hour orbital period; at
stride 4 it doesn't bind until three decades past the horizon cap. Decimating
the emission meant the pre-node segment's drawn line could stop short of the
actual node position between stride-aligned samples, so each segment's
terminal point is emitted **unconditionally** regardless of where the stride
lands — the rule collapses to ordinary per-substep emission at stride 1, so
every byte-identity assertion written before the stride existed still holds.

## The tolerance locks

The milestone's headline claim needed two different kinds of evidence, because
they measure different things.

**Bitwise.** Where the predictor and the flown worker consume genuinely
identical inputs — no perturbers, so the provider's window-reopening cadence
never enters the comparison — a grid-aligned scheduled burn produces
bit-identical state on both lanes at every coarse-window boundary, position,
velocity and mass, with no epsilon anywhere in that comparison. The fixture is
deliberately oriented so the arithmetic is exact rather than merely close: the
craft's velocity sits exactly on the body's thrust axis and the commanded
delta-v is a power of two, so the burn direction both lanes consume is the
identical bit pattern rather than two values that happen to agree to fifteen
digits.

**Runtime bands.** For the shipped configuration — the N = 1024 tier, the
filtered perturber table, a node epoch deliberately off the fine substep grid
— predicted and flown trajectories diverge by a small, measured, decomposed
amount rather than by zero. Four orbit families were calibrated and locked at
roughly 5× the measured value:

| family | max position divergence, measured | locked | terminal velocity divergence, measured | locked |
|---|---:|---:|---:|---:|
| LEO coast | 1.585e-04 m | 8.0e-4 m | 1.749e-07 m/s | 8.8e-7 m/s |
| eccentric mid-orbit burn | 1.276e+03 m | 6400 m | 1.480 m/s | 7.5 m/s |
| hyperbolic escape burn | 1.899e+02 m | 950 m | 1.825e-02 m/s | 9.2e-2 m/s |
| eccentric burn at periapsis | 4.640e+03 m | 23000 m | 5.152 m/s | 26.0 m/s |

The divergence decomposes into four named terms, printed alongside every
locked total rather than left as an unexplained number: the substep-count
truncation between the two tiers; perturber drift accumulated from the
predictor's single window-start anchor against the worker's per-window
re-anchoring; an ignition-timing skew of exactly one prediction substep
(0.2929688 s), which is the dominant term on every burning family; and a
scripted-burn cutoff tail specific to how a `BurnSpec` rounds its stop time to
the worker's own coarse boundary — a term that does not apply to a
hand-flown burn, since live throttle resolves every substep rather than every
window. The coast family sits four orders of magnitude below the burning
families because it is missing the timing terms entirely — one thing to
measure, not four.

Two regenerable CSVs — the shipped N = 1024 predicted polyline and the real
worker's flown trail, same frame, same burn — are emitted on demand from this
runtime tier rather than the zero-tolerance bitwise one, on the reasoning that
a plot of the configuration the feature actually ships at is the honest
picture; a plot of the exact-equality fixture would be a picture of a test,
not of the game.

## Drawing it in the demo

The demo scenario declares a dominant slot, its gravitational parameter, an
oblateness term, relativistic correction parameters and the full
perturber hierarchy once, at startup — the same fields the worker's own craft
window already reads, so the two configurations cannot drift apart. Every
recompute-policy value is left at its measured default, so the demo ships
the exact locked policy: the N = 1024 tier, a one-orbit closed cap, a
7,200-second open cap, stride 4, 376-substep chunks, a 110-second drag
preview.

The two segments draw as line strips in the existing craft-geometry vertex
family: a dim pre-node line for context, a bright amber post-node line
answering "what does this burn do," both distinct from the existing orange
trail, cyan craft trail, magenta unburned-conic and RGB attitude triad. A
scripted node re-arms once its epoch passes, so a session that runs longer
than one orbit never leaves a stale, unreachable node with nothing drawn past
it.

A periodic stderr line rides the same per-frame counter the existing
telemetry lines use, on its own cadence divisor:

```
[prediction] node=1 valid=1 perturbers=2/13 seg_a_recomputes=9 seg_b_recomputes=9
             landings=9 chunks=459 in_flight=0 substeps_last=0 seg_a_pts=79 seg_b_pts=4740
```

`perturbers=2/13` is the tidal-relevance cutoff firing live; two identical
consecutive lines with `substeps_last=0` are the idle no-op measured in the
frame-budget arithmetic above, running in the actual binary rather than only
in a test.

## Where it is now

A later hardening pass this milestone touched the predictor in four ways,
none of which moved a locked number.

**Producer-boundary hardening.** `TrajectoryPredictor` became explicitly
non-copyable and non-movable — its internal context and cache carry
`std::span`s into its own member vectors, so a compiler-generated copy would
deep-copy the vectors but shallow-copy the spans, silently binding the copy's
kernel calls to the original's storage:

```cpp
TrajectoryPredictor(const TrajectoryPredictor&) = delete;
TrajectoryPredictor& operator=(const TrajectoryPredictor&) = delete;
TrajectoryPredictor(TrajectoryPredictor&&) = delete;
TrajectoryPredictor& operator=(TrajectoryPredictor&&) = delete;
```

Every field on a declared `PredictorSource` — fifteen leaf doubles, including
ones previously validated only when their owning feature flag was set — is
now checked for finiteness unconditionally before the predictor trusts it, and
the declared perturber hierarchy is rejected outright, not silently
resorted, if a parent index isn't the sentinel, the dominant, or an earlier
row. Segment B's per-substep finiteness gate was moved to sit inside the
integration loop and strictly before the point is pushed onto the published
polyline, so a non-finite substep result can never reach the drawn line even
transiently — it drops the whole in-flight segment, clears validity, and
counts the drop instead.

**Numeric reason codes.** `TrajectoryPredictor::update` now names which of
nine outcomes fired on its most recent call, through a fixed-width enum
rather than a string, so the demo's telemetry line stays greppable:

```cpp
enum class PredictorReason : std::uint8_t {
    kProductive = 0,
    kIdle = 1,
    kSourceNotSet = 2,
    kNonFiniteNode = 3,
    kCraftUnavailable = 4,
    kPerturberSlotOutOfRange = 5,
    kSegmentAInvalid = 6,
    kSegmentBFault = 7,
    kSeedDeferred = 8,
};
```

`last_reason()` is non-latching — it reports the outcome of the call that just
ran, not a sticky fault from three frames ago — and every one of the nine
codes is exercised by a headless fixture that drives `update()` into exactly
that exit. The `[prediction]` line grew a `reason=` field alongside a
`deferrals=` count and a `mid=` flag reporting whether the last evaluated call
held for a boundary-consistent frame.

**Adaptive emit stride.** The fixed stride of 4 is now a floor rather than a
constant: for very long horizons, a per-recompute decimation factor derives
from the render tier's actual vertex-buffer capacity, always rounded to a
whole multiple of the base stride. That rounding is what keeps a decimated
run a **bitwise subset** of the stride-4 run — point `k` of a stride-16 line
is byte-identical to point `4k` of the stride-4 line, rather than a resample
on a different grid — while still bounding stored samples by the screen's
draw range instead of by orbital period. A 16-orbit horizon that previously
stored 75,826 points now stores 5,056; a `reserve()` sized once per recompute
dropped one full recompute's allocation count from 22 to 2, and doubling the
horizon no longer grows that count at all. At the shipped one-orbit LEO
configuration the derived stride is still exactly 4 and the stored count is
unchanged — the adaptive branch is provably inert at production settings and
only engages once a horizon genuinely exceeds what the draw range can hold.

**A wall floor on recompute cadence.** The Segment A staleness trigger was
originally a pure sim-time threshold — 60 seconds of simulated time since the
last refresh. At high time-scale, sim seconds compress: a 60-second sim
threshold can arrive every couple of real frames, which is a much tighter
recompute cadence than the constant's derivation ever priced. A wall-clock
floor now sits beside it:

```cpp
inline constexpr double kPredictionRefreshMinWallDt = 6.0;
```

six real seconds must also have elapsed before a staleness-triggered refresh
fires, regardless of how much sim time that represents. The first-ever
compute and a case where the sim clock has moved backward both stay
ungated, since neither is the runaway-cadence case the floor exists to catch.

# M1.2 Phase 61 — Findings and Fixes: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as it exists now**. Phases 55-60
> built craft-orbital subcycling, maneuver-node placement and real-time
> trajectory prediction; Phase 61 is eighteen fix passes across that stack,
> landing between 2026-08-05 and 2026-08-10.

## Starting point

A maneuver node is a point on a predicted trajectory carrying a Δv in three
handle axes; the predictor replays the craft's own propagation kernel forward
from the current state to draw where that Δv sends it. Phases 55-60 built the
propagation, the node data model, and the live redraw. Phase 61 is where that
machinery got run hard enough to find where it disagreed with itself — a burn
that resolves throttle on two different clocks, a planner reading its own
two-body approximation instead of the predictor's answer, an input path
racing its own coalesce branch, and a substep count that had never been
checked against an independent time base. Eighteen sub-phases, one fix each,
closing with every divergence tolerance in the M1.2 suite re-measured from
scratch.

## The falsified fix

The craft's own translational substep — `kepler_step` called
`kCraftSubstepN = 16384` times per 300 s window — drifts against a single
analytic call over the same span. Over one full orbit (19 windows, bare
two-body, no perturbers, no J2, PN off): **2.425928e-04 m**. The chain's
selection rule had claimed a larger N never degrades accuracy; that clause is
false, and the first attempt at a fix took the claim at face value.

The obvious diagnosis is round-off in the state carry: `craft_substep` takes
`kepler_step`'s returned position and velocity and hands them straight to the
next call —

```cpp
// engine/src/physics_craft_integrator.cpp
const KeplerState ks = kepler_step(x, vel, h, ctx.mu_dom);
x = ks.x;
vel = ks.v;
```

— so 16,384 carries per window is 16,384 chances to lose a bit. Compensated
summation is the standard fix for exactly this shape: fold the update as a
delta against a running compensation term instead of overwriting outright,
so the discarded low bits get carried forward instead of vanishing. The
fold-back form was implemented completely — an additional `double comp{}`
threaded through the worker's carried craft state, the predictor's segments,
and the isolation harness, applied as:

```cpp
// Kahan (1965) streaming compensated add
double kahan_fold_add(double acc, double delta, double& comp) noexcept {
    const double y = delta - comp;
    const double t = acc + y;
    comp = (t - acc) - y;
    return t;
}
```

Measured before and after: **bit-identical**, `2.425928e-04 m` both times.
Not close — the same seventeen digits. A probe walked every compensation
term the fold produced across a full run: 311,296 substep commits times six
components each, **zero nonzero residuals across 1,867,776 component
commits**. The delta `ks.x - x` is a displacement of roughly 140 m against a
radius of about 6.78e6 m — small enough, against Sterbenz's lemma, that the
subtraction `delta = ks.x - x` returns an exact result in binary64, with no
rounding for a compensation term to recover. `comp` came out identically
zero on every single call. The fix was implemented correctly and did
provably nothing, because there was no round-off in the carry to compensate.
It was reverted rather than kept as a fix-in-name-only.

The real mechanism sits one level lower, inside `kepler_step` itself, in the
Lagrange f/g update it commits every call:

```cpp
// engine/src/kepler_universal.cpp
const double f = 1.0 - chi2 * inv_r0 * c2;
const double g = dt - chi2 * chi * inv_smu * c3;
const coords::Vec3f64 x{
    f * x0.x + g * v0.x,
    f * x0.y + g * v0.y,
    f * x0.z + g * v0.z,
};
```

`f` is a near-1 quantity, and the near-1 multiplication `f * x0` is where a
systematic bias is committed on every call. Tracking specific energy across a
run shows it growing linearly rather than random-walking: `dE/E =
-3.645042e-13` after one window, `-7.306555e-12` after nineteen. Ninety-eight
percent of the resulting position error is along-track, which is what a mean-
motion bias produces: `δa/a` grows linearly, the accumulated mean-anomaly
error integrates to about `3.5e-11` rad, and `r · δM` at LEO radius closes
analytically on the measured 2.4e-4 m. Two other candidates were checked and
excluded: the solver's Newton-iteration count (2 through 12 iterations
returns the same result to the bit), and rewriting the increment as
`(f-1)*x0 + g*v0` to avoid the near-1 multiply (measured **worse**,
2.494450e-04 m).

`kepler_step` is a locked surface shared with the planetary integration
tier, so reformulating its f/g commit is out of scope for this fix — it is
recorded as open, named work: the f/g identity `f·gdot − fdot·g == 1` is
presently only observed to hold, not enforced by construction, and enforcing
it (or reshaping the commit to avoid the near-1 multiply) is the candidate
fix for a dedicated pass. The count of 16384 substeps itself is not an
accuracy choice at all — it is a **liveness** floor: it is set so a
translational command answers within the same 18.31 ms worst-case budget the
attitude channel already committed to, independent of accuracy considerations,
which sit roughly 25x under this milestone's own tolerance at that count. The
selection rule's banner now states the trade honestly: a larger N buys
nothing and the pinned N carries a known, bounded, and accepted cost, rather
than claiming the cost doesn't exist. The lock that pins it —
`craft_substep_absolute_roundoff_lock` in
`tests/unit/physics/test_craft_substep_convergence.cpp` — grades the chain
against one single analytic `kepler_step` call over the same span rather than
against another same-mode chain, since two chains built the same way share
the same bias and cancel it out of the comparison, which is exactly how the
original claim survived its own test suite. The bound sits at `1.2e-3 m`,
4.947x above the measured figure. A mechanical rounding rule would have
produced `1.3e-3` — declined, since the number to round from hadn't moved by
a single digit.

## The torn tail

The input ring's coalesce-on-full path merges a new axis command into the
already-queued tail slot when the ring is saturated. The merge write was a
plain, non-atomic struct assignment with no synchronizing store of its own —
a data race under the C++ memory model regardless of what x86's ordering
happens to permit in practice. The at-risk entry is always the newest
command, which can carry a key-release edge.

A saturating fixture — an unpaced producer against a bursty, draining
consumer, periodically stalled after a coalesce event to widen the window —
reproduced it 10 times out of 10 runs under ThreadSanitizer:

```
WARNING: ThreadSanitizer: data race
  Read of size 8 by thread T2:
    InputRing::pop(...) worker_thread.hpp:990
  Previous write of size 8 by thread T1:
    InputRing::push(...) worker_thread.hpp:967
```

The first fix added a post-write acquire recheck: after merging, reload the
consumer's read index, and if the consumer had already closed onto the tail
during the write, discard the merge and fall back to a plain, correctly
published append instead. That closes a real gap — a merge landing after the
slot had already been consumed — but it is a narrower fix than it looks. It
narrows the race window; it does not order the bytes inside it. `pop`'s
acquire load pairs with whatever release it happens to observe, and the
append that originally filled the slot precedes the merge in program order,
not the other way round. Same fixture, same 10 runs, same two lines: still
racing.

The fix that closed it treats the tail the same way the engine's own
snapshot triple-buffer already does — an odd/even sequence counter, verified
before and after the copy:

```cpp
// engine/include/interstellar/physics/worker_thread.hpp — writer side
const std::uint64_t seq0 = coalesce_seq_.load(std::memory_order_relaxed);
coalesce_seq_.store(seq0 + 1, std::memory_order_relaxed);   // ODD: merge in flight
std::atomic_thread_fence(std::memory_order_release);
tail = c;
tail.flags = merged;
coalesce_seq_.store(seq0 + 2, std::memory_order_release);   // EVEN: merge complete
```

```cpp
// reader side
if (r == w - 1) {
    for (std::size_t attempt = 0;; ++attempt) {
        const std::uint64_t s1 = coalesce_seq_.load(std::memory_order_acquire);
        if ((s1 & 1ULL) == 0ULL) {
            AxisCommand tmp = slots_[r & (kInputQueueCapacity - 1)];
            std::atomic_thread_fence(std::memory_order_acquire);
            if (coalesce_seq_.load(std::memory_order_relaxed) == s1) {
                out = tmp;
                read_.store(r + 1, std::memory_order_release);
                return true;
            }
        }
        ++seq_retries_;
        if (attempt >= kMaxTailSeqRetries) { ++seq_giveups_; return false; }
    }
}
```

A give-up defers rather than drops — `read_` has not advanced, so the same
entry is still there for the next `pop`. Before landing this shape, a forced-
preemption probe modeled a scheduler interruption during the merge under both
the old (single release-bump) form and the new form: the old form tore on
**every single merge that hit the window** — 13 of 13, 22 of 22, 18 of 18
across three runs. The new form, with the window forced roughly 30,000x
wider than a real preemption would produce, recorded zero torn reads across
541K, 1.4M, and 906K retries. `InputRing::push`'s merge branch gained exactly
the odd store, the release fence, and the even store; nothing about what gets
merged, when a command is dropped, or how a saturation event is logged moved.

## The burn lattice

The trajectory predictor and the flown engine both resolve throttle for a
scripted burn window as a binary in/out test against the window boundary —
no partial credit for a burn that starts or ends mid-window. A burn placed
off the 300 s grid could see its throttle drop to zero for the fraction of a
window it didn't fully occupy, or read as fully off for windows it barely
touched at all: one reproduction found a node's predicted burn delivering
**+75.833%** too much Δv against the flown result.

The fix is an overlap-weighted throttle, written the same way at both tiers:

```cpp
// engine/src/trajectory_prediction.cpp
const double t_next = t + pending_.dt;
double throttle = 0.0;
if (t_next <= burn_.t_start_s || t >= burn_.t_end_s) {
    throttle = 0.0;                                     // no overlap
} else if (t >= burn_.t_start_s && t_next <= burn_.t_end_s) {
    throttle = burn_.throttle;                          // wholly interior
} else {
    const double lo = t > burn_.t_start_s ? t : burn_.t_start_s;
    const double hi = t_next < burn_.t_end_s ? t_next : burn_.t_end_s;
    throttle = burn_.throttle * ((hi - lo) / pending_.dt);
}
```

```cpp
// engine/src/physics_worker_thread.cpp — the flown tier, summed rather than first-match
double PhysicsWorker::craft_scheduled_throttle(double sim_time_s) const noexcept {
    const double window_dt = config_.step_dt;
    const double window_end = sim_time_s + window_dt;
    double total = 0.0;
    for (const BurnSpec& b : config_.craft->schedule) {
        if (b.t_start_s >= window_end) break;
        if (b.t_end_s <= sim_time_s) continue;
        if (sim_time_s >= b.t_start_s && window_end <= b.t_end_s) {
            total += b.throttle;
        } else {
            const double lo = sim_time_s > b.t_start_s ? sim_time_s : b.t_start_s;
            const double hi = window_end < b.t_end_s ? window_end : b.t_end_s;
            total += b.throttle * ((hi - lo) / window_dt);
        }
    }
    return total > 1.0 ? 1.0 : total;
}
```

The wholly-interior branch assigns the throttle literally rather than
computing `(e - s) / dt`, which is not guaranteed to equal exactly 1.0 in
binary64 for a large absolute time against a small window — every grid-
aligned fixture in the tree needed to stay bit-identical, and this is why it
does. Across the divergence bands sized to catch an off-grid burn, the worst
position error tightened by exactly 2.7x (1/0.37, the fixture's own off-grid
placement fraction): 1.275660e+03 m to 4.720048e+02 m on the largest of the
three.

The second half closes what the throttle fix leaves standing: even with
overlap correctly weighted, a burn placed at an arbitrary instant still
starts and ends at a fractional offset into its first and last window, which
the two tiers can round differently. Snapping the node's epoch onto the
prediction grid at placement removes the mismatch instead of correcting for
it:

```cpp
// engine/src/maneuver_planner.cpp
const double quanta = dt_s / prediction_quantum_s_;
constexpr double kMaxQuanta = 9.0e15;
if (!(quanta >= 0.0 && quanta < kMaxQuanta)) {
    return false;
}
const double snapped_s =
    sim_time_s_
    + static_cast<double>(static_cast<long long>(quanta)) * prediction_quantum_s_;
```

An out-of-range lead is refused outright rather than clamped. The truncation
mirrors the predictor's own grid reconstruction exactly — `kCraftSubstepN`
is 16 times `kPredictionSubstepN`, so a point on the prediction grid is also
a point on the flown grid, and one snapped epoch is exact on both. On an
on-grid twin of the same fixture, ignition-instant skew — previously one
whole substep width, 2.929688e-01 s — goes to **0.000000e+00 s exactly**,
and the worst position error against the same burn drops from 4.720048e+02 m
to 1.716948e-02 m.

## Two prediction bases, one predictor

The maneuver-node planner draws six handle glyphs and a Δv readout at the
node's position. Building that display needs the predicted state at the node
epoch, and the planner had its own way of getting one: a bare two-body
`kepler_step` call against the craft's live relative state, independent of
the trajectory predictor that was already replaying the same craft forward
through the full force model to draw the line the handles sit on. Two
different answers to the same question, on the same screen, diverging by
about 1.3e-3 rad of frame rotation at a 1200 s lead — small enough to be
invisible on the handle glyphs, present in every number the readout printed.

The fix deletes the planner's own propagation outright and routes the
predictor's own node-entry state through the one place both objects are
legitimately visible to each other — the object that owns both:

```cpp
// engine/include/interstellar/render/orbit_demo.hpp
NodeReadout map_node_readout() const {
    if (!prediction_enabled_ || !predictor_.valid()) {
        return NodeReadout{};
    }
    return planner_.readout(predictor_.node_entry_state(),
                            predictor_.node_entry_mass_kg());
}
```

`ManeuverPlanner::readout` takes the predicted state and mass as arguments
now, rather than deriving them itself; the planner keeps no reference to the
predictor by design, so this composition root is where the two connect.

The handle basis carries the same class of bug in miniature: a TNB frame
built from a predicted state is only meaningful at the instant that state was
predicted for, and nothing previously stopped a stale frame from being reused
against a node whose epoch had since moved. The fix binds a basis to the
epoch it was built for and checks that binding on every use:

```cpp
// engine/include/interstellar/physics/maneuver_node.hpp
struct NodeFrame {
    TnbBasis basis{};
    double epoch_s{0.0};
    bool valid{false};
};
```

```cpp
// engine/src/physics_maneuver_node.cpp
NodeFrame node_frame_at_epoch(const ManeuverNode& node,
                              const State& predicted_at_time_s) noexcept {
    NodeFrame out{};
    out.epoch_s = node.time_s;
    const TnbBasis basis = tnb_frame_basis(predicted_at_time_s);
    if (!basis.valid) return out;
    out.basis = basis;
    out.valid = true;
    return out;
}

coords::Vec3f64 node_delta_v(const ManeuverNode& node, const NodeFrame& frame) noexcept {
    if (!frame.valid || frame.epoch_s != node.time_s) {
        return coords::Vec3f64{};
    }
    return node_delta_v(node, frame.basis);
}
```

The epoch comparison is exact, never a tolerance: a frame built for one node
epoch composes to a Δv of precisely zero against a node whose epoch has since
moved, rather than a small, silently wrong number. Three separate hand-rolled
basis constructions in the planner, the composition root, and the predictor
itself all became call sites of this one function; a search across the
engine source for the pattern this fix replaced returns nothing left.

## Re-locking every band

With the numeric fixes landed, every divergence tolerance and round-off bound
in the M1.2 suite was re-measured against the finished tree in one pass, each
number's derivation written down beside it rather than carried forward from
whichever phase happened to have touched it last. Eleven closure rows across
ten surfaces: three prediction-divergence bounds tightened by exactly 0.37x —
the same 2.7x factor the burn-lattice fix produced, since the two are the
same measurement — two new bounds added for cases that previously had none,
one promoted to a byte-exact lock backed by a frozen golden table, and zero
loosened.

Re-deriving the terms behind the tightened bounds turned up an inverted
result worth keeping: the working assumption going in was that the
predictor's fixed substep count would dominate the total divergence budget,
with round-off a smaller contributor underneath it. Measured, it runs the
other way — the substep truncation error is 0.69x the size of the round-off
floor, not larger, because the drift leg of the craft's sub-map is an exact
`kepler_step` call with no truncation term of its own to contribute, while
the round-off floor is the same systematic per-call bias described above,
which does not cancel over a longer span the way a random-walk error would.

Two rounding proposals were declined for the same reason. House convention
rounds a bound up to the smallest clean two-significant-figure value at least
five times the measured figure; applied mechanically to the round-off bound
above, `5 x 2.425928e-04` rounds to `1.3e-3` — an 8% loosening of the
existing `1.2e-3` bound on a measurement that had not moved by a single
digit. Applied to one of the tightened prediction bands, the same rule
rounds a `2.75 m/s` velocity bound up to `2.8`, an 1.8% loosening on an
equally unmoved figure. Both were kept at their measured-derived values
instead: the rounding convention exists to produce a clean number from a
measurement, and a measurement that hasn't changed is not itself grounds to
widen anything.

One case was deliberately left as a bound rather than closed further: past a
fixed scale threshold, the craft's translational substepping is designed to
degrade to a coarser mode, and prediction diverges sharply across that
boundary — a factor of roughly 730x against the finest-tier bound, reachable
by raising time scale enough. The behavior is correct — the coarse mode
trades resolution for cost by design — so the fix is a dedicated bound for
that regime rather than a change to when it engages.

## Close

Both lanes: **Release 1278/1278, Debug 1273/1273**. The locked deterministic
force kernel, `engine/src/nbody_force.cpp`, is byte-untouched across all
eighteen sub-phases — checked at every phase boundary, not assumed. The
remaining thirteen sub-phases closed narrower gaps across the same stack:
`atan2`-based angle recovery in place of an `acos` legs that lost sign
information near the poles; a boundary-consistent craft frame moved from a
sampled quantity to one produced directly at the publish edge; a predictor
that now fails closed on a non-finite substep instead of silently continuing
to report a stale state as valid; a hard-stop diagnostic that names the
specific perturber responsible instead of a generic message; and a full
`-Wall -Wextra` pass across the tree with the warnings actually read. None of
it touched the propagation math itself — the craft chain, the burn lattice,
and the seqlock above account for the numbers that moved.

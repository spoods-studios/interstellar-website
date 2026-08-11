# M1.2 Phase 55.1 — Substep-Cadence Craft Publish: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-31**; M1.2
> closed on 2026-08-10, and a hardening pass later in the same milestone
> touched this path twice more. The drift section at the end covers both
> changes.

## Starting point

Phase 55 gave the craft its own KDK sub-map: within a 300 s coarse window the
craft integrates on `kCraftSubstepN = 16384` substeps of `kCraftDt =
75·2⁻¹² s ≈ 18.31 ms`, dominant-relative, while every planetary row still
steps once per window. That made the craft's *physics* live at real time. It
did not make the craft's *published* state live: the worker's publish call
was still gated on `stepped == true` — one publish per completed coarse
step — so at `time_scale = 1` a fresh craft row reached the HUD once every
300 wall-seconds, and the renderer held a static row while the craft
coasted, thrust-fired and crossed a full orbit underneath it. `main.cpp`
carried a workaround for exactly this: the demo booted at 128× time scale,
above the point where the craft completes enough coarse steps per second to
look continuous, and below the warp threshold. Phase 55.1 closes the gap at
its mechanism — the craft row publishes at substep cadence, planets keep
the coarse cadence — and retires that workaround so the demo boots at 1×
outright.

## The cadence law

The publish epilogue used to live inline at the tail of
`accumulator_iteration`, reachable only from the production hot loop. Phase
55.1 pulled it out as `PhysicsWorker::accumulator_drain(wall_dt, scale)` —
one implementation called by both production and a test hook
(`accumulator_drain_for_test`) that bypasses only the paused gate, the same
parked-instead-of-paused contract `tick()` already documents. The split
point is the paused gate and nothing else, so production statement order is
unchanged:

```cpp
bool PhysicsWorker::accumulator_drain(double wall_dt, double scale) {
    if (has_craft_) {
        craft_pub_wall_budget_ += wall_dt;
    }
    accumulator_ += scale * wall_dt;
    const bool stepped = run_due_steps();

    if (stepped) {
        if (!craft_boundary_crossed_this_call_) {
            publish_snapshot();
        }
        craft_pub_wall_budget_ = 0.0;
        return stepped;
    }

    const double publish_budget =
        craft_boundary_hold_ ? kCraftBoundaryHoldWallDt : kCraftPublishMinWallDt;
    if (has_craft_ && craft_substeps_this_call_ > 0
        && craft_pub_wall_budget_ >= publish_budget) {
        publish_snapshot(/*boundary_publish=*/false);
        craft_pub_wall_budget_ = 0.0;
    }
    ...
}
```

(`craft_boundary_crossed_this_call_` and `craft_boundary_hold_`'s larger
budget are the two later additions covered under "Where it is now" — at
initial landing the mid-window branch used `kCraftPublishMinWallDt`
unconditionally.)

The budget accumulates the same Fiedler-clamped `wall_dt` already flowing
into the function — no new clock read on the payload path — and resets on
every publish, boundary or mid. `kCraftPublishMinWallDt` is the exact dyadic
half of `kCraftDt`:

```cpp
inline constexpr double kCraftPublishMinWallDt = kCraftDt * 0.5;
// 75·2⁻¹³ s = 9.1552734375 ms (~109.2 Hz cap)

static_assert(kCraftPublishMinWallDt * 2.0 == kCraftDt,
              "kCraftPublishMinWallDt must be the EXACT dyadic half of kCraftDt");
```

Half a substep quantum, for two reasons. At `time_scale = 1` substeps arrive
one per `kCraftDt` of wall time, so a half-quantum budget admits every
substep despite scheduler jitter rather than every other one. And the
implied ceiling, `1/kCraftPublishMinWallDt ≈ 109.2 Hz`, holds at *any*
scale — above `kCraftFineScaleCap` the craft window opens and closes inside
the same boundary iteration, so `craft_substeps_this_call_` is only ever
nonzero on a stepped call there, and mid publishes are structurally
impossible rather than merely throttled. Publish rate is therefore bounded
in `[stepped-rate, ~109 Hz]` at every time scale — never
16384-publishes-per-frame at `S = 2²⁰`.

Publish *timing* stays wall-driven, exactly as it was at HEAD (one publish
per stepped call is already a function of wall chunking). Publish *payload*
is a pure function of physics state at the publish instant, and the publish
path writes no physics state: the mid-window composition below lands in
locals only.

## The dominant's mid-window position

Between coarse boundaries the craft's state is dominant-relative (Phase 55),
so `states_[craft_slot_]` still holds the window-start row while the craft
has moved. Composing the published row against that stale dominant position
is wrong by the dominant's own drift over the partial window — about 8,900
km per 300 s for a heliocentric Earth-dominant craft, against a 6,778 km LEO
radius: a plausible-looking, wrong orbit.

At `craft_open_window`, a `CraftDomAnchor` captures the dominant's own
parent-relative state once per window, from the same window-start ephemeris
the perturber rows come from. `craft_dominant_mid(t)` then evaluates the
dominant's absolute state at any intra-window offset:

```cpp
PhysicsWorker::CraftDomMid PhysicsWorker::craft_dominant_mid(double t) const noexcept {
    const CraftDomAnchor& a = craft_dom_anchor_;
    const coords::Vec3f64 parent_r{a.parent_r0.x + a.parent_v0.x * t,
                                   a.parent_r0.y + a.parent_v0.y * t,
                                   a.parent_r0.z + a.parent_v0.z * t};
    if (!a.has_parent || a.mu_rel == 0.0) {
        return CraftDomMid{parent_r, a.parent_v0};
    }
    const KeplerState leg = kepler_step(a.rel_r0, a.rel_v0, t, a.mu_rel);
    return CraftDomMid{parent_r + leg.x, a.parent_v0 + leg.v};
}
```

Parent linear drift first, the dominant's own two-body leg added on top with
a plain `+` — floating-point addition does not commute across magnitudes, so
the order is pinned and a test mirrors it bit-for-bit. `mu_rel == 0.0` (and
the no-parent case) is the explicit linear-drift limit, the same guard the
window-close recompose already carries. One `kepler_step` call per
mid-window publish — the same locked, libm-free kernel the warp arm already
calls, never a second n-body solve. The dominant's parent is read once from
the existing global dominance scan; the mechanism never introduces a second
heuristic for "who is dominant."

At publish time the mid-window flag and row are derived from state, not
threaded from the caller — a window open with `craft_sub_index_ > 0` is
exactly when the craft row is ahead of `states_`:

```cpp
if (craft_window_open_ && craft_sub_index_ > 0) {
    craft_mid_window = true;
    craft_window_t_off_s = static_cast<double>(craft_sub_index_) * craft_ctx_.craft_dt;
    const CraftDomMid dom_mid = craft_dominant_mid(craft_window_t_off_s);
    craft_mid_r = dom_mid.r + craft_rel_r_;
    craft_mid_v = dom_mid.v + v_rel_true;   // v_rel_true: the pseudo-to-true PN transform, mirrored
    ...
}
```

Every value here is a local. `craft_rel_*`, `states_`, and the boundary cache
are never touched from the publish path — a mid-window publish composes a
row and discards the composition once the seqlock write finishes.

## What refreshes on a mid publish, and what does not

A published frame carries fields at three different natural cadences:
per-substep (the new craft row), per-coarse-step (planetary rows, `sim_time`,
the burn-boundary shadow latches), and per-refresh (energy, angular-momentum
deficit, clump diagnostics — O(N²)-ish work). The observability refresh
block and the `publish_seq_` counter run on boundary publishes only; a mid
publish copies the cached values bit-for-bit. Recomputing them on every mid
publish would run O(N²) work up to ~109 times a second for numbers that
have not changed, and would make the observability cadence a function of
wall chunking rather than of simulated time.

The burn-boundary shadow latches (Phase 53) get one real rule change: a
latch may only advance with an *instant-consistent* pair. On a mid publish
where the composed dominant slot equals the HUD's reference slot — the
shipped scenario — both shadow halves advance from the same composed
instant, so the latches gain full substep resolution. When the reference is
not the dominant, neither half advances and no edge is evaluated that call;
the edge waits for the next consistent publish, since `src[kCraftHudReferenceSlot]`
is still the window-start row on a mid frame and pairing it with a
mid-window craft row would reproduce the same ~8,900 km skew the
dominant-mid composition exists to avoid. A latch is a rare event, and one
coarse window of extra latency is exactly HEAD's latency, while a skewed
pair would be silently wrong forever.

## The reader-side rule

Every consumer that differences the craft row against a reference body —
the HUD, the orbit demo's trail, element extraction, the camera focus, the
maneuver planner — used to read `states_[craft_slot_]` directly. From
55.1 that slot can carry a mid-window row while every other row on the same
snapshot is coarse. `craft_scene_state()` is the one place that
composition happens:

```cpp
if (!snap.craft_mid_window || snap.craft_dom_slot >= snap.count) {
    s.rel_r = craft_r - s.ref_r;
    s.rel_v = craft_v - s.ref_v;
    s.scene_r = craft_r;
    s.scene_v = craft_v;
    return s;
}
const coords::Vec3f64 rel_dom_r = craft_r - dom_mid_r;
const coords::Vec3f64 rel_dom_v = craft_v - dom_mid_v;
s.scene_r = snap.pos_at(snap.craft_dom_slot) + rel_dom_r;
s.scene_v = snap.vel_at(snap.craft_dom_slot) + rel_dom_v;
if (snap.craft_dom_slot == kCraftHudReferenceSlot) {
    s.rel_r = rel_dom_r;   // exact — no round trip through 1.5e11 m magnitudes
    s.rel_v = rel_dom_v;
} else {
    s.rel_r = s.scene_r - s.ref_r;   // two rows of the SAME coarse instant
    s.rel_v = s.scene_v - s.ref_v;
}
```

On a boundary frame this is bit-identical to the row-differencing it
replaced. On a mid frame it re-anchors the craft into the coarse-drawn
scene — planet discs, trail store, conic, camera all still live in the
per-300 s frame — before differencing against the reference. A dominant
slot past the published count is treated as a clear flag rather than
indexed on, a defence against a torn index the seqlock recheck did not
catch.

The maneuver planner could not be routed through a call site, because
`ManeuverPlanner::refresh` derives its relative state internally from
`snap.pos_at(craft_slot_)` against the reference row. `refresh` now calls
the helper itself, so its signature stays unchanged and there is still
exactly one implementation of the rule. That matters because
`relative_state_` seeds the planning conic, the node epoch, and the
nearest-sample math — a skewed pair there silently mis-plans a burn rather
than just looking wrong for one frame.

The Phase 59 trajectory predictor gets a gate rather than a route: its
Segment A seed is `craft_row − dominant_row`, computed once per recompute
rather than every frame, so `recompute_segment_a` is gated on
`craft_mid_window` being clear:

```cpp
const bool boundary_frame = !snap.craft_mid_window;
const bool want_refresh_a = (epoch_moved || clock_moved) && (!drag_active || !have_a_);
const bool refresh_a = want_refresh_a && boundary_frame;
const bool seed_deferred = want_refresh_a && !boundary_frame;
```

`sim_time` staying per-coarse-step is not sufficient protection on its own:
mid frames of the *next* window already carry the advanced `sim_time`, and
at up to ~109 Hz publish against ~60 Hz reads a reader routinely misses the
boundary frame, so `clock_moved` can first go true on a mid frame. The
deferral holds the pending trigger rather than swallowing it — `cached_node_`
is written only on a non-deferred path — so the reseed fires at the next
boundary-consistent frame and produces byte-identically the Segment A a
twin that never saw the mid frame would produce.

## The demo boots at 1×, and the measured cadence

With the publish side live, the 128× workaround in `main.cpp` was retired
and `time_scale_init` set to `1.0`. A headless 30 s scan of the shipped
binary at 1× logged 911 `[craft]` stderr lines, `t_off` advancing from
0.0549 s to 29.44 s inside a single 300 s coarse window — 29.44 s of craft
freshness inside a run that, at HEAD, would have shown its first
craft-present line only after 300 s. `elem_valid = 1` on every line, zero
throttled diagnostic channels, zero fatal or non-finite lines. The cadence
law is a predicted rate; a live worker measures it against the predicted
bands:

| quantity | predicted | measured |
|---|---:|---:|
| publish rate, `time_scale` 1 | 54.61 Hz | 54.4982 Hz |
| publish rate, `time_scale` 64 | ≤ 109.23 Hz | 106.997 Hz |
| craft-absent publishes, 12 production drain calls | 6 | 6, exactly |
| craft-present publishes, same 12 calls | 12 | 12 |

The 64× number bounds the DoS case: without the wall budget, publish rate
would track the substep rate, `O(time_scale)` — at 64× the worker drains 64
substeps per substep-of-wall, so an ungated publish-per-substep design
would run near 3.5 kHz there and near 900 kHz at `kCraftFineScaleCap`. The
budget holds the ceiling at ~109 Hz at every scale, landing 2% under it.

A dedicated soak drove the seqlock writer protocol at a sustained ~100 µs
period for 1.5 s — nearly two decades past the ~109 Hz the production
throttle admits, with a production worker parked and one dedicated test
writer so the writer-count invariant (`pub_` has exactly one writer) held
throughout. Zero torn frames.

## The dark line at 1×, and the boundary-frame hold

The reader-side gate above has a failure mode a code-level lock cannot
catch: the *interval* a boundary-consistent frame stays published. Under
the plain `kCraftPublishMinWallDt` throttle, a boundary frame was the
published frame for as little as 9.16 ms before the next window's first mid
publish replaced it — shorter than a 60 Hz reader's 16.67 ms sampling
interval. Measured on the shipped demo at 1×: the predicted trajectory never
seeded at all, `[prediction]` reading `valid=0` on every line for the whole
30 s scan.

The obvious fix — hold the boundary frame published for longer than one
reader interval — turns out to need one more term than the naive version.
The worker decides whether to publish only at drain-call granularity, so
publish decisions land on a lattice whose spacing is bounded by `kCraftDt`.
The retiring publish and a reader sample can fall in the *same* lattice
cell, and the reader sees whichever frame that cell ended with — so the
*observable* window is the hold minus one publish-decision cell, not the
hold itself. Measured directly: a 2× hold (18.31 ms) gives an observable
window of 16.02 ms against a 16.67 ms reader period, and the pigeonhole
failed on 1 of 4 boundaries in a scripted `S = 8` reader case.

| candidate | value | observable window | verdict |
|---|---:|---:|---|
| 1× `kCraftPublishMinWallDt` | 9.1552734375 ms | −9.2 ms | the original defect |
| 2× | 18.310546875 ms | 0.0 ms | measured insufficient |
| **4×** | **36.62109375 ms** | **18.31 ms** | pinned (= 2 × `kCraftDt`) |

`kCraftBoundaryHoldWallDt = 4 · kCraftPublishMinWallDt = 2 · kCraftDt` is the
smallest dyadic multiple that clears `hold − kCraftDt > 1/60 s`. It carries
a 1.0986× margin over the 60 Hz interval and, incidentally, exceeds *two*
reader intervals, so a reader that drops a single frame still observes the
boundary. The mechanism: after any publish whose *payload* is
boundary-consistent, the next mid-window publish must clear this larger
budget instead of the plain one. Armed from the payload rather than the
call site — boundary-consistency is a property of the frame, not of which
site produced it — and armed by default, so the constructor-seeded first
page inherits the same protection.

Cost: exactly three mid-window publish opportunities foregone per coarse
window, and up to 36.62 ms of extra craft-row staleness once per 300 s
window — 0.012% of the window, immediately after a boundary, where the row
is freshest by construction. Because the hold binds only where substeps
arrive faster than a reader samples, the discriminating regression cases
run at `S = 8` rather than `S = 1` — at `S = 1` publishes are already 18.31
ms apart and a hold-deleted case would pass vacuously. Disabling the hold
fails both discriminating locks directly:

```
lifetime lock : 0.0091552734 >= 0.0354766846   FAILED  (9.16 ms against a required 35.48 ms)
reader   lock : 3 >= 4                         FAILED  (3 of 4 boundaries observed)
```

A 340 s headless re-scan (past the first 300 s coarse boundary) confirmed
the fix end to end: the predictor goes `valid=1 perturbers=2/13
seg_a_recomputes=1` at the first coarse boundary and stays valid for the
remaining 278 `[prediction]` lines of the run, drawing a 337+4734-point
polyline. The re-measured cadence bands moved 0.9% (`S=1`) and 1.4%
(`S=64`) from the pre-hold numbers — both shifts land far inside their
existing bands, and at `S=64` the shift moves *away* from the ceiling.

## Why it was built this way

**Publish site and publish payload are separate notions.**
`boundary_publish` names the call site — the stepped publish, `tick()`'s
unconditional publish, and the constructor's seed publish are all boundary
sites. `craft_mid_window` is derived inside the publish function from
`craft_window_open_ && craft_sub_index_ > 0` — a property of the state, not
of the caller. Collapsing the two would force a choice between `tick()`
never showing a mid-window row (untestable without a live worker) or
`tick()` shifting the observability cadence (moving pre-existing
expectations). Keeping them distinct costs one `bool`.

**`accumulator_drain` is a split, not a mirror.** The mid-publish site lives
in the production hot loop, which no test can drive directly — `tick()`
bypasses the paused gate entirely. Rather than hand-mirror the epilogue into
a separate test path — exactly the divergence an earlier phase had already
extracted `run_due_steps` to prevent — the body below the paused gate
became its own function, called by both production and a test hook that
bypasses only the gate itself.

## Verification

Full suite at phase close: 1117/1117 Release, 1113/1113 Debug (1093/1089 at
phase start, +24 across four plans). The deterministic force kernel diffed
byte-identical against the prior release throughout; the undefined-symbol
set on the worker translation unit carried no new libm import — `kepler_step`
is an engine symbol, not a `<cmath>` call. The craft-absent seam battery
ran unmodified across the whole phase, a zero-line diff from the phase's
starting commit. No pre-existing test file's expectations moved beyond one
restatement: two byte-exact `[craft]`-line format pins gained a `t_off=`
field, with the fixture's populated case strengthened to carry a nonzero
offset so the pin proves the field is carried rather than merely present.

## Where it is now

M1.2 closed on 2026-08-10. A hardening pass later in the milestone touched
this publish path twice, on top of what landed above — both additive,
neither moving a locked cadence number.

**A boundary-crossing latch.** The window-close recompose can land inside
`run_due_steps` on a call that also completes a coarse step. At that
instant the craft row and every window flag are boundary-consistent — but
at HEAD's original shape, that call's own epilogue publish still ran
*later*, after the next fine tick had already reopened the window and
advanced a substep. So a call that closed a window published the
*reopened* window's mid-window payload instead of the boundary-consistent
frame that had existed moments earlier the same call, starving the exact
guarantee the reader-side gate depends on. The fix latches the crossing
(`craft_boundary_crossed_this_call_`) and publishes once, immediately, at
the instant the window closes; the call's own epilogue publish then stands
down so it cannot overwrite that frame with the reopened window's state.
The loop's continuation is unchanged — an extra publish, never an early
return — so a fixed-length run's total time advance stays independent of
how a caller chunks its wall-time input.

**A dedicated last-boundary craft slot.** The boundary-frame hold's
guarantee is stated honestly at its constant: a reader at or above 60 Hz
observes every boundary-consistent frame; a slower reader's guarantee stays
probabilistic — a display's refresh rate, load-bearing inside a physics
publish policy. The later pass closes that gap structurally instead of by
raising the hold further: three fields (`craft_boundary_valid`,
`craft_boundary_pub_tick`, and the boundary row itself) are written only
when the current payload is boundary-consistent, then ride every
subsequent published frame — mid-window or not — unchanged until the next
boundary replaces them. Since planetary rows and `sim_time` already only
change at coarse boundaries, a mid-window frame carrying the last
boundary's craft row is a complete boundary-consistent state, independent
of when the reader samples; the identity field lets a reader tell which
boundary it is holding. The hold itself — same value, same three foregone
publishes per window — is unchanged; what closed is the guarantee a slow
reader gets, not the cost the fast path already pays.

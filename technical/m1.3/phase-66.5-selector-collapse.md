# M1.3 Phase 66.5 — A False Positive in the Collapse Detector: Technical Deep-Dive

## Starting point

Phase 66.4 re-sized the terrain cache against a live flight and eliminated
capacity as the cause of the renderer's whole-view detail collapse. At the
re-locked cap of 1,024 tiles that flight still printed ten `COLLAPSE-START`
lines with ground in frame, against a flight verdict of no collapse seen on
screen. Both readings went into the record unreconciled. This phase reconciles
them: the events are real firings of the detector, and the detector was wrong
about what it was looking at.

## What the detector compares

`terrain_drawn_collapse` is a relative two-frame predicate over the terrain
selector's ledger. Its AREA arm fires when drawn area falls below a retention
floor of one half; its RESOLUTION arm fires when the drawn set's area-weighted
mean level falls more than 500 millilevels. Both compare one frame against the
frame before it, and both assume the two frames describe the same ground.

## One node, both arms

At a near-nadir pose in the 404–476 km band, a single level-3 node — 4,096 area
units, exactly `terrain_node_area_units(3)` — is 54.7% of the 7,488 units the
frame draws. Crossing `select()`'s own drawn↔prefetch visibility boundary, that
one node reaches both arms of the predicate, and which arm it reaches depends
only on the direction the camera crossed it.

| | drawn units | prefetch units | prefetch moment | arm |
|---|---|---|---|---|
| descent at 447,500 m | 7,488 → 3,392 (45.3% retention, floor 50%) | 344,768 → 348,864 (+4,096) | 1,265,280 → 1,277,568 (+12,288) | AREA |
| ascent at 476,844 m | 3,392 → 7,488 (area grew; mean drawn level fell 1.940 levels) | 377,536 → 373,440 (−4,096) | 1,391,744 → 1,379,456 (−12,288) | RESOLUTION |

12,288 / 4,096 = 3 on both rows: one node, one level, in both quantities and
both directions. The two firing altitudes sit 29 km apart because the LOD
hysteresis band places the crossing differently going up than coming down.

Nothing was lost on either frame. Per-frame conservation held on all 889 frames
of each rung, the drawn-set hold promoted nothing, residency gated nothing
anywhere — zero blocked splits, zero evictions, peak occupancy 814 of 1,024 —
and the departing node went on being prefetched. The detector was comparing two
frames that did not draw the same ground.

The two directions do not even leave through the same door. The descent departs
through the tight frustum; on the ascent the frustum sub-bucket does not move at
all, because the node arrives out of the horizon-band arm of the same prefetch
bucket. Both are arms of one partition — drawn versus held-but-not-drawn — which
is why the repair is written against `prefetch_units` and not against its
frustum subset. A fix written against the frustum alone closes the descent and
leaves the ascent firing, and that was measured rather than reasoned about: the
first passing attempt did exactly that.

## The netting

The predicate now puts its two frames on a common footing before comparing them.
When the whole change in `drawn_units` is accounted for to the unit by the whole
change in `prefetch_units`, and that crossing is exactly one node of one level,
the crossing is netted out of both sides and the two arms then run unchanged over
the remainder. `TerrainSelectLedger` gains `prefetch_level_moment` — area × level
for the prefetch bucket, accumulated at the two sites `prefetch_units` already is
— so the RESOLUTION arm can be netted the way the AREA arm can.

No locked constant moves. `kTerrainDrawnCollapseRetentionNum` (1),
`kTerrainDrawnCollapseRetentionDen` (2), `kTerrainDrawnMeanLevelDropMilliBound`
(500), `kTerrainHoldPromotionUnitBound` (0) and `kTerrainResidentTileCap` (1024)
are byte-identical across the fix, and the exemption introduces no numeric
threshold of its own. There is no quantity here to be tolerant of, so the bound
is structural instead: `detail::terrain_one_node_crossing` requires
`moment == units × L` for an integer level in range **and**
`units == terrain_node_area_units(L)`. The second clause is what rejects four
level-4 nodes carrying a level-3 node's 4,096 units, whose moment is 16,384
rather than 12,288. Both clauses are proven load-bearing by controls that fire,
not by assertion.

The alternatives all traded the false positive for something worse. Loosening
either retention constant, or fitting a new altitude-aware bound at 450 km, buys
silence on two rungs at the cost of a false negative on the one instrument this
whole line of work depends on. Moving `walk_drawn`'s frustum/horizon partition so
the node stops crossing would trade a classification bug for a real one — the
node genuinely left the view. Gating the detector below some drawn-set size fails
on its own numbers: drawn area spans 18 to 262,144 units across the ten logged
events precisely because the predicate is relative.

## The off-control

`terrain_drawn_collapse`'s new `net_visibility_boundary_flux` parameter defaults
to the shipped state, so the render path's call site is unchanged, and driving it
false reaches the pre-fix predicate. On the identical rungs it restores one event
at 476,844 m through the RESOLUTION arm and one at 447,500 m through the AREA
arm, with the same before/after pair and the same arm each time — required equal
to the recorded values and required non-zero, so a control that stopped
controlling anything fails instead of passing quietly.

Correspondence to the flight is stated rather than rounded off. The flight's ten
events are two at a parked pose, six in the band, and two at cold start. The
off-control restores two, not six or eight: the band's six are three traversals
of the window at two altitudes each, and this harness drives one traversal per
direction. The parked two restore zero, measured on both sides of the knob — a
pinned-pose drive freezes eye, pitch and yaw, so a two-frame predicate has no
transition to classify. That false negative stays open and is not covered by this
lock.

## What the netting may not do

Netting that can cancel a firing can also cancel a real one. The shipped shape
keeps the two arms in a helper and returns the union of two evaluations, so the
exemption may quiet a level-consistent crossing and may still re-base into a
firing, but can never silence one. A level-consistency conjunct gates the
silencing half only. Before that conjunct, an exhaustive enumeration found 17
frames where a counter-flux crossing suppressed a firing the arms should have
kept; after it, zero, with the 17-frame family driven as a rung that calls the
shipped predicate directly rather than re-spelling it.

The magnitude gate that both guard sites share now has one spelling,
`detail::terrain_netting_magnitude_ok`, called by both rather than copied into
each. Extracting it was proven arithmetic-identical over 19,034,698 differential
calls with zero mismatches, and the drift band the two copies had opened — 142 to
299 permille — closes to a single value pinned by edge assertions that call the
helper itself. The gate stands at 250 permille for a crossing that clears both
structural identities, against the general 500-permille floor, and it is recorded
as chosen with its 1.39× margin stated where the constant is defined.

## The direction that had no threshold

The originally adopted fix direction was different: gate the detector on a
completeness invariant built from a walk-measured denominator — the area the
frustum admitted — and fire when the drawn set falls too far below it. That
direction was measured before it was built, and it has no usable bound anywhere.

The AREA half is a structural identity at this tree. The numerator's field and
the denominator's field are incremented by adjacent lines under the same
condition, at both of the walk's drawn-side terminations, so
`frustum_admitted_units == walk_drawn_units` is a property of the source. It
reads 1000..1000 permille on every frame of every rung. The RESOLUTION half had
never been instrumented in the currency the direction specifies — a gap
in level units, not a moment ratio — and measured there it is identically zero on
every frame of all seven rungs, so it cannot fire at any bound at all.

The sweep is exhaustive rather than sampled, because a per-mille integer ratio is
bracketed by its own minimum and maximum: 2,000 candidate area floors against
each of six unperturbed controls, plus 9,001 candidate gap bounds against the same
six, is 66,006 verdict comparisons. Discriminating bounds: zero. The existence
question the invariant has to pass — a bound at which a provably perturbed
selection fires while all six unperturbed rungs stay quiet — has no answer over
2,001 area floors, 9,001 gap bounds, or the 2,001 floors of the one alternative
denominator the record named. The alternative fails in the opposite direction: at
every floor that fires on the perturbed rung, all six unperturbed rungs fire with
it.

The perturbation is real, which is what gives the null its force. A one-frame
stale cull volume moves `peak_drawn_nodes` from 126 to 127 and
`peak_stream_demand` from 540 to 541, so the two drives genuinely select
different nodes — and every field the specified invariant reads is bit-identical
between them. What shipped from that measurement is a probe that turns red the
day a successor moves where the walk credits area. No production code.

## The criterion, sharpened

The acceptance criterion was a bare zero: no ground-in-frame `COLLAPSE-START`
events. A bare zero is satisfiable by a detector that has stopped working, so it
was replaced before the re-flight with a per-hit obligation. Sky-pointing frames
are a pre-filter, never a class: a frame is sky-pointing when its pitch exceeds
`fov_y/2 − acos(R / (R + h))` — the tight frustum's lowest ray misses the limb,
no ground is in view, and zero drawn units is the correct answer. Every remaining
event must be dispositioned against one of three named legal transitions, each
carrying its own required ledger evidence:

1. A drawn↔prefetch re-classification, requiring the rejected channel to be
   quiet across the crossing and the conservation identity
   `drawn + prefetch + rejected == 1572864` to hold on both frames.
2. Horizon-band flux under eye translation, requiring the rejected channel to
   move and conservation to hold on both frames.
3. A cold-cache or camera-mode transition, requiring a mode-transition marker on
   the log or occupancy below the cap carrying the cold-fill signature.

No fourth class may be minted at scan time, and every row carries a flag saying
whether its evidence was read off the hit line itself or bounded from the
surrounding print window — the instrument prints event starts plus a 1-in-120
cadence, so for most events the frame the predicate compared against is
not on the log, and a window difference bounds the move rather than measuring the
operand. The detector's own positive controls ride the same evidence chain: a
pitch-off-planet drive at both edges of the measured live slew rate, and the
stale-volume injector, both driven as named rungs, both firing.

## The re-flight

Six segments in one continuous run at the shipped cap: spawn, scripted descent to
the surface, fast ascent to 2,755 km, fast descent to 56 km, then a slow ascent
and hover to 1,812 km with a look-around. Nothing seen on screen.

The log carries 27 `COLLAPSE-START` events. Seventeen are sky-pointing and drop
out before the table starts. All ten ground-in-frame events classify: six
re-classifications, one horizon-band flux under a 495 km descent-ascent, three
cold-cache or mode transitions, zero unclassified. Netting engaged three times.
Peak demand reads 566 tiles against the 1,024 cap — 1.809× headroom — with zero
refusals flight-long and 385 evictions over the whole run.

The comparison series, same six-segment card each time: at a forced 512-tile cap
with the pre-fix detector, 2,878 events; at 768, 21 events with 13 ground in
frame; at 1,024 pre-fix, 10 and 10; at 1,024 with the netting but before the
sharpening, 33 with 20 ground in frame, all 20 classifiable in retrospect; and
this run, 27 with 10. The eye and the instrument agree for the first time in this
line of work: nothing appeared on screen, and every logged transition carries a
named class.

## What's next

Aerial perspective on terrain, drawn from the Phase 66 scattering tables.

*Built solo by Spoods Studios.*

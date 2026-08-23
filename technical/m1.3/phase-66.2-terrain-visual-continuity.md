# M1.3 Phase 66.2 — Terrain Visual Continuity: Technical Deep-Dive

## Starting point

Two defects survived the terrain renderer's first flights. The first is
node-granularity squares — patch-sized tiles of ground that brighten or shift
as the camera moves, near and far, in a ring that travels with you. The second
is worse: the whole ground blinks. For a frame or two the planet's surface
drops to a handful of coarse patches, then comes back. Every invariant the
terrain selector carried passed while both were happening.

Phase 66.2 closes the first defect completely and closes the mechanism behind
the second, leaving one measured, named edge open.

## The morph band: anchored to the wrong ring

Continuous level-of-detail terrain hides the transition between detail levels
by morphing: as a patch approaches the distance where it will be replaced by
its coarser parent, its vertices slide toward the positions they will occupy
on the parent's grid. Arrive at the swap with the morph complete and the swap
is invisible, because the two surfaces are already identical.

The engine's morph parameter runs 0 to 1 per patch, and the swap frames were
measured directly across the frame boundary — 431 merges driven on a scripted
zoom-out, at three speeds. The morph reads exactly 1.0 at every single flip,
on every rung. That is the arriving patch already fully collapsed onto its
parent's grid — the desired state — and the merge still steps the visible
surface by a full detail level, because what the frame actually exchanges is
parent-grid relief for *grandparent*-grid relief.

The patches sit clamped at 1.0 for 603 to 10,192 frames before their swap
fires, which is 10 to 170 seconds of flight. At least one patch per merge
never renders a single frame inside its own morph band. The band was placed so
early in the approach that it finished long before the geometry needed it.

## Per-draw alpha: neighbors disagreeing across a shared edge

The second measurement is the one that names the squares. Over 181 descent
frames carrying 726 to 1,314 patches and no substitutions at all, **87.4% of
drawn patches render at morph 1.0**.

Because the morph value was computed once per patch and handed to the shader
as a single number, two patches meeting at a shared edge could carry different
values while interpolating from the same pair of vertex attributes. The edge
then separates by the difference in morph times the difference between the
coarse and fine surfaces — tens to hundreds of metres at coarse levels.
Measured: **78,470 of 726,618 same-level adjacencies, 10.8%, worst frame 492**,
with disagreements running to the full 1.0. Of the adjacencies one level apart,
**48,442 of 73,884, or 65.6%, step a full effective level**, because the
coarser side is saturated too.

The band is 30% of one level's arc wide while adjacent patches differ by about
one full patch arc. The band is narrower than a patch, so every level carries a
one-patch-wide ring of full-amplitude disagreement that travels with the
camera. That ring is the squares.

## The fix: one continuous field, measured anchors

Both findings are the same field seen from two directions, so they are fixed
together.

Morph alpha is now computed **per vertex** in `terrain.vert`, from that
vertex's own distance to the eye against its level's band, then composed with a
per-draw floor through `max()`. Two patches sharing an edge now agree at that
edge by arithmetic — the vertices are at the same position and the same level,
so they evaluate the same function to the same value. The selector no longer has
to arrange that agreement patch by patch.

The band anchor was chosen by measurement, and the measurement falsified the
analytically derived candidate. Driving 431 terminal merges gives a worst band
start of 5.1861 × arc(L−1), which the derived `[5.10, 6.00] × arc(L)` violates
on the geometry it claims to cover. The shipped anchor is
**`[5.30, 6.00] × arc(L)`**. Ending the band at the parent's subdivide ring
makes the no-step property fall out of the geometry rather than out of a
safety margin: a coarser patch is never subdivided, so its whole extent
already lies at least that far out. Against the 4.2 × arc(L) span between
detail levels, that band is 16.7% wide, inside the 15–30% envelope the CDLOD
literature cites.

The shader needs each vertex's level to evaluate its band, so the signed level
is now always packed into `sun_dir_and_flags.w` and decoded in lockstep by
`terrain.frag`. It had been a debug-only tint channel.

## The half the band could not reach

A re-anchored band closes every boundary the distance rings create. It cannot
close a boundary created by *streaming*: when a patch wants to split but its
tiles have not arrived, the selector holds it coarse, and that blocked patch
sits inside its own subdivide ring at any distance down to zero. No band
placement reaches it.

That class closes at the selector instead. A drawn patch edge-adjacent to a
residency-blocked leaf takes morph floor 1.0 outright, collapsing it onto the
surface the blocked leaf is already drawing. The blocked set is derived from
output the walk already produces, and membership is asked of the final drawn
set, because the drawn-set hold may have coarsened a blocked leaf's region away
after the walk requested it. Unsaturated boundaries of this class go
**5,174 → 0**, with a control that strips the floors and reproduces 5,174
exactly, pinned rather than merely required non-zero.

The measurement also corrected its own expectation: under the pre-fix band the
floor alone closes the finer side, 2,051 → 0, and 1,669 boundaries still step,
because the blocked leaf carries a coarse-side alpha no finer-side floor can
cancel. The exact zero needs the re-anchored band and the floor together.

## The blink: node count as the wrong currency

The whole-ground blink resisted three rounds of headless reproduction. The
measurement was what failed.

The selector's completeness invariant quantified over *drawn nodes*. A frame
that went from 122 patches to 3 satisfied it vacuously — the invariant asked
whether the drawn nodes were consistent, and three consistent nodes are
consistent. Meanwhile the screen was blank.

The selector now carries a per-frame **area** ledger in exact integers. One
unit is one level-9 node; the whole sphere is 6 × 4⁹ = **1,572,864** units.
Area accumulates at the walk's three partition sites and is checked as an
unsigned 64-bit equality every frame. Completeness is stated in area and in
area-weighted resolution together, so a 3-patch frame covering the same ground
at the same mean level is not a collapse, and a 3-patch frame covering 3% of it
is.

The instrument was proven able to fire before its silence was read as evidence.
A positive control that pitches the camera off the planet reports drawn
retention 0 per mille against visited retention 1000, and names the frustum as
the bucket that absorbed 4,096 units, with conservation intact.

Then it stayed quiet. **24,481 driven frames across six trajectories at three
speeds report zero collapse events.** The leading hypothesis — that the
collapse is rate-dependent, driven by stale camera or geometry state — dies
with a number: one frame of injected staleness moves the worst descent frame
from 893 to 877 per mille and fires nothing, and it takes 128 frames, 2.1
seconds, on an ascent only, to reach even 473.

## The mechanism: a resident set that could not go backwards

The re-flight is what broke it open. Running the real binary with the
instrument compiled in, the collapse fired **189 times**, and the log line
carried the camera state at the firing frame: the camera was **not moving**.

That is the discriminator the headless harness could not produce, and the
reason is structural. The harness's residency model was **insert-only** across
the whole drive. A tile, once resident, stayed resident. Under that model a
residency verdict going backwards is unrepresentable. The shipped cache evicts.

Rebuilding the harness with an evicting model isolates it in three sides:

| residency model | capacity | collapse events | evictions |
|---|---|---|---|
| insert-only | saturated | 0 | — |
| evicting | shipped cap, 768 | 0 | 0 |
| evicting | saturated | 27 | 2,740 |

The saturated capacity is derived from the insert-only rung's own peak stream
demand, not chosen. With that, the collapse reproduces headlessly for the first
time, at a camera that is not moving: **27 events in 600 frames**, worst drawn
retention 9 per mille, 74 adjacent frames stepping by exactly one node's area,
worst step 262,144 units — one whole cube face — absorbed by the rejected
bucket, with the visit count rising by 20, meaning the parent was descended
into and its children thrown away.

## The fix: recency on consulted tiles

`terrain_node_resident` asked the cache `contains`. It now asks `lookup`,
which refreshes the tile's recency.

The distinction decides which tiles a full cache evicts first. At 52 km
altitude the level-1 and level-2 tiles are consulted on every frame — the
selector reads them to decide whether to descend — and drawn on no frame at
all. Under `contains` they were the least-recently-*used* tiles in the cache by
definition, so they were the first evicted, and losing one collapses the frame
by eight detail levels in a single step.

Residency verdict flips go **114 → 18**, a factor of 6.3, and reverting the
call brings all 114 back.

A second defect closes alongside it. The drawn-set hold could coarsen a patch
into an ancestor covering ground the walk had sent to the prefetch and rejected
buckets, promoting non-drawn area into the emitted set — measured at +119,104
units on one frame from 3 km up, one cube face plus two level-1 nodes. A
coarsening is now admissible only when the walk drew the target's region in
full, which is area-preserving by construction, so the promotion bound is an
exact zero with a control that brings back exactly 16,383 units.

One reported mode turned out to be correct behavior. Ten logged frames with an
empty drawn set all sit above the analytic admission angle
`fov_y/2 − acos(R/(R+h)) = −0.1845 rad`, worst margin +155,605 microradians:
the camera is pointed at space, and an empty drawn set is the right answer.
Nine emit exactly empty; the tenth draws one level-3 node covering 0.26% of the
sphere, which is bounding-sphere over-inclusion in the direction the culling
lock already requires.

## The honest edge

Flown on real hardware against the real dataset — six segments, including a
full minute parked at 52 km with the controls released — the ground no longer
blinks. Visually the flight is clean.

The instrument still fires. Thirteen times with the ground in frame, and every
one of them reads the resident tile cache at **768 of 768**, with evictions
climbing to 701 over the flight.

That is capacity, and it is the residual the fix does not close. The cap of 768
tiles was locked against a horizon-bounded working set measured at 467 tiles
peak. The saturating frames sit at 26.7 km and 52.4 km, where that model
predicts roughly 313 to 330 tiles — the live demand is more than double the
model across every altitude that fired.

The likeliest reason is the fix itself. Making a consulted tile refresh its
recency was correct, and it necessarily enlarges the working set the cache has
to hold, because tiles that are never drawn now compete to stay resident. The
cap was measured before that behavior existed. Raising the number without
re-deriving the model would be guessing: at 512 KiB of samples per tile, 768
tiles is a 384 MiB ceiling, and spending another 128 MiB on a working set that
might be 1,400 tiles buys nothing.

So the model gets re-derived with consulted tiles counted, and then the cap
gets re-locked against it. That work is scheduled inside M1.3.

## What's next

One seam remains open in the terrain surface: a boundary two detail levels
apart, which the drawn-set hold cannot repair. That is the next phase.

*Built solo by Spoods Studios.*

# M1.3 Phase 66.3 — LOD Boundary Crack Closure: Technical Deep-Dive

## Starting point

One seam survived the terrain renderer's continuity work: a boundary where two
adjacent drawn patches sit two or more detail levels apart. The finer patch's
edge and the coarser patch's edge are then different polylines through the same
ground, and the gap between them is a crack — a strip of sky visible through the
planet.

A deep read of the selector proved that the machinery which repairs every other
boundary structurally cannot repair this one. Lowering a seam's level difference
to 1 requires a *drawn* node one level below the coarse neighbour, covering the
fine side's seam column. A drawn quadtree leaf renders its whole region. So that
region's culled and not-yet-streamed parts necessarily become drawn too, and the
amount promoted is exactly the target's area minus what the walk drew — which is
the promotion the previous phase locked at zero. Repairing the
seam and holding that lock are unsatisfiable together.

The measurements bound the exception rather than dissolving it. Across every
shipped configuration — 34,923 frames — the worst neighbour difference is 1. At a
forced resident-tile cap of 512 it is not: the parked pose reads difference 4 on
52 of 601 frames, a fourfold-speed radial descent reads 5 on 467 of 976, and a
culled descent with prefetch removed reads 3 on 4,307 of 10,801.

The obvious repair was implemented and measured dead. A walk that coarsens to the
shallowest admissible ancestor leaves the worst difference at 4, unmoved:
coarsening preserves area exactly, so it cannot change which ancestor levels are
fully drawn, and it arrives at the same fixed point. A sweep over per-repair
admission bounds — 0, 64, 1,024, 4,096, 16,384 — holds the worst difference at 4
for every bound below 16,384, and the first bound that reaches difference 1 is
also the first that brings back a seven-level drop in the deepest drawn node. That
drop is the whole-view collapse the previous phase existed to close. Difference 1
and the collapse are one event.

## The routes that survive the narrowing

The structural sentence is short: any repair that works by moving nodes trades
level granularity for area granularity and re-enters the same trap. Two families
escape it — add geometry, or add per-vertex morph targets.

Per-vertex morph targets scale linearly with the level difference spanned. The
vertex struct is 32 B carrying one ancestor level; the measured worst difference
is 5, so spanning it costs about 112 B per vertex, on top of the deeper problem
that morph targets are per-node attributes while the thing that needs a target is
a per-edge relationship.

Unconditional skirts on every node — what comparable engines ship — decouple
crack-freedom from the level bound with no conditional path at all, and pay
border geometry on every node every frame. Sizing the tile cache so saturation
stops happening narrows the trigger without removing the mechanism: the crack
returns on any configuration that saturates, which is a larger dataset, less
VRAM, a wider field of view, or the next milestone.

What shipped is conditional added geometry: a per-edge **apron**, fired only on
seams that survive at a difference of 2 or more. At difference 1 the existing
morph closes the seam exactly, so the apron emits nothing there, and that zero is
a test rather than a claim.

## The apron

The converged draw list is scanned through the one adjacency probe the selector
already owns, and every surviving edge gets a downward curtain on **both** sides.
Real terrain crosses a detail boundary in both directions along one span, and each
side's curtain is zero-height wherever its own surface is the lower one.

The scan reads the post-resolver list, never the selector's own output. The
resolver re-runs the drawn-set hold on its own substituted set and can deny a
coarsening of its own, opening seams the selector never produced. A pre-resolver
scan under-counts.

A node cracked on two edges reaches the emitter as two ordinary per-edge seams
rather than through a mitred corner. There is no corner-neighbour concept anywhere
in the terrain subsystem, so a mitre would be the first thing here to need a
diagonal adjacency spelling, and what it buys back is two correct surfaces drawn
over each other.

## The depth derivation

The curtain's depth is derived exactly, per column, from the two nodes' already
resident baked meshes at emit time. Both edge polylines are in the mesh pool
already, so the required depth is their difference along the shared span. No
global constant sized by a worst case that runs to kilometres at coarse level
pairs, no per-level-pair table coupled to the dataset, and no new data
dependency — the read is a plain CPU pointer read into a persistently mapped,
host-coherent pool, with no fence and no readback.

Two corrections came out of measuring it.

The minimum over the four baked corner candidates is not the infimum. Morph
interpolates linearly between a fine position and a coarse one that sit a fraction
of a cell apart in *angle*, so the segment between them passes `R·α²/8` closer to
the planet centre than either endpoint — about 12 m at a level-3 cell. A
corner-only bound leaves exactly that much crack open on every frame whose morph
lands mid-band. A 121-point sweep went from 22 coverage violations to zero once
the derivation used the clamped point-to-segment closest approach.

Then a one-representable-step shortfall survived. The kernel evaluates the segment
radius at the projection parameter and the renderer evaluates it at some other
morph, and two roundings of the same real quantity can land one float32 step
apart. A 501×501 sweep over all 33 columns — 16,566,066 samples, identical at `-O0`
and `-O2` — put the worst shortfall at exactly 0.5 m, one float32 step at planet
radius, and the worst overshoot at zero. The infimum now steps down by one
`std::nextafter` of the emitted type. A second lock pins the other side: the
smallest renderable radius must sit at the emitted bottom or exactly one step
above it, so an apron two steps too deep fails a test.

The coarse side's facing edge is asked for rather than assumed. The natural
spelling — flip the edge index — is right on a same-face seam and silently wrong
across a cube-face one, where the two nodes' surface axes permute. All 24
cube-face edge seams were enumerated before the test fixture was chosen, because
the obvious fixture (a fine node against face 0's `+u` boundary) puts both edges
on the same face coordinate and exercises no permutation at all. The shipped
fixture is the face-0/face-4 `+v` seam, and mutating the kernel to the naive
same-face axis fails that case and only that case.

## The shading path

All curtains pack into one dynamic vertex buffer and go out as exactly one
additional draw call, however many edges crack, with no index buffer and no
per-edge index variants.

The apron has its own vertex shader and its own pipeline, which borrows the
terrain pipeline's layout and descriptor set whole and reuses `terrain.frag`
byte-unmodified. That reuse works because the fragment stage reads exactly two
interpolated values and the apron's vertex stage owns both. It writes the
curtain's real geometry to `gl_Position` and a **real baked surface point** to the
shading output, so the fragment shader's derivative-reconstructed normal belongs
to a surface that exists rather than to a curtain hanging through empty space; and
it holds elevation constant down each column, so the hypsometric ramp has no
gradient to walk downward through colour bands the real ground never has. The
curtain is a vertical extrusion of its edge's own shaded colour. Cull mode is
`eNone` — a curtain is two-sided, and back-face culling would reopen the crack
from half the viewing directions.

## The wrong diagonal

The first implementation shaded off the wrong triangle diagonal, and the test that
was supposed to catch it could not.

`terrain_patch_indices()` splits every quad cell on the `v00`–`v11` diagonal of the
row-major flat index. Which of the apron's two rows — the seam row or the interior
row — holds the low flat index flips with the edge: edges 0 and 2 put the seam row
low, edges 1 and 3 put the interior row low. The emitted shade triples were
genuine rendered triangles on edges 1 and 3 and named the cell's *other* diagonal
on edges 0 and 2. The fixture used edge 1, one of the two already-correct edges,
and rebuilt its expected triangle from the same two index formulas the emitter
uses, so it could only ever report that the kernel agreed with itself.

The fix overrides two shade positions on edges 0 and 2 only; edges 1 and 3 are
byte-identical to before. The oracle was re-derived from the production index
buffer: a map of every triangle `terrain_patch_indices()` emits, keyed by
vertex set, with each emitted shade position resolved back to a mesh vertex by an
exhaustive float32-exact scan, and the loop runs all four edges. Assertions in that
file went from 112 to 116, none removed. Reverting the production change
reproduces exactly the membership failure the new oracle reports.

## The coverage lock

The terminal invariant is exact apron coverage, and it is stated in those terms
rather than as a restored level bound, because the apron never touches the drawn
set. Per frame, every drawn edge at difference 2 or more carries an apron pair
whose depth is the measured discrepancy, and the count of uncovered surviving
edges is an exact zero on all three rungs that pinned the defect open — with the
covered count required non-zero in the same case body, so a scan pointed at the
wrong set fails instead of reporting a plausible zero.

Switching the apron off restores the recorded defect exactly: **72**, **1,475** and
**18,368** open edges on the three rungs, worst per frame 3, 14 and 14, with the
14s agreeing exactly with an independent measurement taken a plan earlier. The
on-run's covered counts are required equal to the off-run's uncovered counts, so
the two runs count one population from opposite sides.

Both invariants are read off one drive and one result tuple: coverage at zero and
the promotion bound at zero together, with the worst neighbour difference asserted
**still 5** on 467 frames in the same case. The seam survives; it no longer has
anything to show through, and the record says which of those two things happened.

## The flights

The crack has never been visually observed, and that is part of the record rather
than a footnote to it.

The first flight was meant to run at the forced cap and did not — the override
missed, and the whole flight ran the shipped configuration. Every telemetry line
reads a capacity of 768, with 767 of them fully saturated, and the worst neighbour
difference reads 0 on 850 of 851 lines. The single line reading 5 is frame 120 at
2 m altitude with the cache cold at 441 of 768 tiles: a startup transient. That
flight is recorded inconclusive for the visual criterion, because its before half
never showed a crack. What it did answer is the question the live instrument was
built for: a fully saturated *shipped* cache produced zero steady-state
difference-2 frames in flight. First live reading, favourable direction.

The second flight took the override. Capacity 512, saturated on 3,488 lines, and
the defect fired — worst difference 2 to 5 on 1,129 lines (178 at 2, 536 at 3, 390
at 4, 25 at 5), up to 29 surviving seams in a frame. It also logged 2,878
collapse-start events with evictions peaking at 289,126 and drawn area falling to
11 units. That is capacity thrash from running a cache far below its own working
set, and it belongs to the cache-cap re-derive, which has its own phase.

The third flight took the before/after at a pose carrying 10 live seams. No visible
crack with the apron off. No visible difference with it on. No curtain read as a
wall or as foreign geometry at any pose, including low grazing flight and the
horizon silhouette — the risk the exact-depth derivation exists to remove. The
verdict was to accept and close.

So the closure is carried by the coverage lock, with the invisibility of the
*before* half stated plainly rather than smoothed into a claim about a visible
fix. A difference-2 seam at this cap is not visually resolvable at these poses on
this display.

## Cost

A frame carrying a surviving seam pays one extra draw call and at most 16,128
vertices. Every other frame pays zero vertices, zero bytes uploaded and zero draw
calls — which is all 34,923 frames of the shipped configuration. VRAM is a fixed
903,168 bytes allocated once at construction and never resized.

The vertex cap is 3.00× its measurement of 5,376. The plan asked for roughly 5×,
and 5× fails the two-sided lock idiom the same plan mandated, whose over-clear
ceiling is 4.0; widening that ceiling to fit would weaken a lock. Worst
terrain-plus-apron frame across all four rungs is 305,940 vertices against the
557,568 bound, or 54.9%, so the frame vertex bound did not have to move. Nothing
was re-locked.

## What's next

The resident tile cap, re-derived against the shipped dataset with consulted tiles
counted, and re-locked against that measurement.

*Built solo by Spoods Studios.*

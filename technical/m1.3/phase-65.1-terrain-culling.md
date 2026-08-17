# M1.3 Phase 65.1 — Terrain Culling: Technical Deep-Dive

## Starting point

The terrain renderer's first flight was unflyable. Peak drawn count: 1,314
patches, every frame, regardless of where the camera pointed. Roughly half of
them were on the far side of the planet — geometry the camera could never
see, drawn anyway. No lever existed to stop it. The terrain selector had no
view frustum test, no back-face rejection, and no concept of the planet's own
curvature blocking the view. Phase 65.1 adds three: back-face culling,
frustum culling, and horizon culling.

## Back-face culling: a bug hiding since the first pass

The terrain index buffer had been emitting its triangles in the wrong order
since the earliest rendering pass. Every quad's two triangles came out
clockwise in the patch grid, so the composed geometric normal pointed into
the planet rather than out of it. Nothing broke, because back-face culling
had never been turned on — `cullMode` sat at `eNone`, hiding the defect
entirely.

The fix is a single index permutation in
`engine/include/interstellar/render/terrain_patch_mesh.hpp`:
`{v00, v01, v11, v00, v11, v10}` becomes `{v00, v11, v01, v00, v10, v11}`, the
same two triangles over the same quad, traversed the other way round. Twice
the signed area of a counter-clockwise unit-quad triangle is exactly +1 in
integer grid coordinates, so the check needs no tolerance — a triangle is
either +1 or −1, with nothing in between for a rounding error to hide in.
`test_terrain_patch_mesh.cpp` checks all six cube-sphere faces at three
levels of detail: 86,016 triangles, zero inward, zero degenerate.

With the winding fixed, `cullMode` moves to `eBack`. At the pre-culling peak
of 1,314 drawn patches, each one 2,048 triangles, that's 2.69 million
triangles a frame. About half of them, 1.35 million, never reach the
rasterizer at all.

## Frustum culling: two frames meeting at one dot product

`PlanetCamera::frustum_planes` had existed since Phase 62, and no terrain
code had ever called it. Phase 65.1 wires it into the terrain selector as a
three-verdict test: a node's bounding sphere is either drawn, kept resident
but not drawn (prefetched, so a camera turn doesn't reveal a gap where
nothing has streamed in yet), or rejected outright, with its whole subtree
skipped.

The wiring has one sharp edge. A terrain node's center is stored planet-local,
in float64, at a magnitude around 6.371 million meters. The frustum planes
are camera-relative float32, because the view matrix carries no translation
by design — folding a multi-million-meter offset into a float32 matrix would
shred precision back to metre-scale garbage. Getting the order of operations
wrong here produces a plausible-looking answer that is quietly incorrect.
The rule: subtract the eye position from the node center in float64 first,
and only then narrow the small camera-relative result to float32. Doing it
the other way around — narrowing the planet-local center before subtracting —
gives a different answer on 879 of 4,096 sampled nodes, 21.5%. 204 of those
disagreements point the wrong way: the sloppy version draws what the correct
one rejects.

The rejection tolerance that keeps a node from being culled inside its own
rounding error is derived, not guessed. Twice Earth's mean radius is
12,742,018 meters, which lands in float32's `[2^23, 2^24)` range — the one
band where a single unit in the last place is exactly 1.0 meter. Four sources
of error accumulate at that scale: narrowing the camera-relative vector
(0.87 m), the plane dot product's five roundings (2.50 m), the plane
normal's own float32 residual (2.28 m), and the final offset and add
(1.00 m). That totals 6.65 m, rounded up to 8.0 m of slack — about 3.5 parts
in ten thousand of the smallest bounding sphere the selector ever produces.

Driven through a full camera turn at 300 m altitude, the frustum test alone
takes the peak drawn-node count from 1,173 to 368 and the number of nodes
the selector even has to visit from 1,562 to 738. The visit count is what
matters for cost: a rejected node's subtree is never walked, so the saving
compounds down the quadtree rather than only trimming the draw list at the
end.

## Horizon culling: proving the shortcut is exact

The frustum test cannot see the planet's own curvature. At 400 km, a
60-degree view cone still covers a large slice of the far side, which is why
roughly half of the original 1,314-patch peak was far-side geometry the
frustum lever could never reach.

Earth's terrain in this engine sits on a true sphere, not an ellipsoid like
WGS84, so the occlusion test can skip the scaled-space machinery an ellipsoid
model needs. What's left is a simple three-circle relationship: given the
eye, the sphere doing the occluding, and the target's own bounding sphere,
work out whether a straight line from the eye can reach past the occluder to
the target. That's the sphere-sphere form of what's called the Distance
Method.

```
|VH| = sqrt(|VO|^2 - R_O^2)                 the eye's tangent length to the occluder
|HY| = sqrt(|OB|^2 - (R_O - R_B)^2)         the target's tangent length to the occluder
|VB|_edge^2 = (|VH| + |HY|)^2 + R_B^2       the edge of visibility
occluded  <=>  |VB|^2 >= |VB|_edge^2
```

The open question was whether this test stays conservative at the coarsest
level of detail, where a patch's bounding sphere is nearly as large as the
planet's own radius — 92% of it, at the coarsest level. It doesn't need a
small-target assumption at all. Working in the plane containing the eye and
the node's center, with the tangent cone's half-angle as θ and the angle
between the eye and the node as φ, the distance from the node's center to the
edge of the shadow is `R_O - |OB| cos(φ - θ)`. The node is fully hidden
exactly when that distance reaches its own bounding radius. Substituting
through gives `cos(γ + θ) ≥ cos(φ)`, which is the same Distance Method
inequality above, term for term, for any target radius smaller than the
occluder. There's no level where the test degrades into an approximation. An
independently built oracle — closest-point-on-segment against the occluder,
run against 5,544 (node, eye) pairs across all ten levels of detail —
reports zero disagreements, with per-level cull rates climbing from 47% at
the coarsest level to 99% at the deepest.

Every node's center on this planet is a normalized direction times Earth's
mean radius, which means the occluder-to-target distance `|OB|` is the same
constant number for every node. That fact collapses the target's
tangent-length term to a pure function of one node's own bounding radius —
nothing else — so it's a pure function of the node's quadtree key. It's
computed once per key and cached beside the node's other geometry:

```cpp
term.tangent_m = physics::det_sqrt(
    (r_eff + kOccluderSinkM) * (2.0 * physics::R_EARTH_MEAN - kOccluderSinkM - r_eff));
```

That's `(R_B + sink)(2|OB| - sink - R_B)`, a factored form of
`sqrt(|OB|^2 - (R_O - R_B)^2)`. The factored form was chosen over the more
obvious difference-of-squares spelling because the unfactored version
subtracts two numbers around 4.0×10^13 from each other and throws away two
decimal digits to cancellation at every deep-level node. Factored, there's no
cancellation to lose.

The occluder itself sits below Earth's mean radius, sunk to the dataset's own
elevation validity floor of −450 m. A larger occluder pulls the horizon
closer and culls more terrain the player can actually see, which is the
direction this test must never take. A smaller occluder only wastes a little
rendering budget on terrain that turns out to be hidden anyway, so the floor
belongs on the occluder rather than the target: real terrain can sit up to
450 m below the mean sphere, and the lowest surface that could plausibly hide
anything is the sunk sphere, not the mean one.

Two square roots exist anywhere on this path, and both are amortized off the
per-node cost. The eye's tangent length depends only on the eye, so it's
computed once per frame. The target's tangent length depends only on the
node's key, so it's computed once per key and memoized. A warm, steady-state
visit pays no square root at all: six multiplies, four adds, two compares.

With both the frustum and horizon levers live, the same 300 m camera turn
that peaked at 1,173 drawn nodes unculled now peaks at 250.

## The hysteresis band: locating the thrash cliff

A pure geometric cutoff flickers. A patch sitting exactly on the horizon
boundary can cross it every frame as floating-point noise nudges the verdict
back and forth — the same patch-flicker-near-a-threshold failure this engine
had already defeated once, in its level-of-detail rings.

The fix is a band: cull only once the node is comfortably past the true
horizon, and un-cull only exactly at the true horizon itself. The gap
between those two thresholds sits entirely on the cull side, rather than
straddling the boundary symmetrically. A band that dipped inside the true
horizon would keep a node culled after it had genuinely come back into view —
the exact visible pop the band exists to prevent.

The band's width was measured on a hover: the eye parked over a fixed point
on the ground, altitude oscillating ±50% around 4 km at 1 Hz. That
trajectory was chosen deliberately — a steady approach or a fixed camera
turn never crosses the horizon boundary often enough to expose a missing
band at all.

| ratio | 1.000 | 1.040 | 1.048 | 1.052 | 1.053 | 1.054 | 1.100 | 1.200 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| thrash events (601 frames) | 486 | 108 | 72 | 36 | 18 | 0 | 0 | 0 |
| drawn nodes | 788 | 795 | 799 | 800 | 800 | 801 | 817 | 855 |

The transition is a cliff, not a slope: 1.053 still re-flips a node inside
the same short window 18 times, and 1.054 never re-flips a node at all
across the whole 601-frame hover. The collapsed band, with no gap at all,
flickers a node on consecutive frames 486 times. That's the exact failure
mode the band exists to remove, and the fix eliminates it entirely rather
than merely pushing it further apart.

The band locks at 1.1, not the wider 1.2 it originally shipped with. 1.054
is the smallest ratio with zero thrash, so 1.1 carries 1.85 times that gap as
headroom. Every notch wider costs drawn nodes for no additional stability —
the drawn count in the table above climbs monotonically with the ratio — so
the extra width in the old 1.2 value was pure cost with nothing measured
behind it.

## Every bound moves down

The mesh pool, the resident tile cap, and the drawn-node bound had all been
locked before any of the three culling levers existed, against a selector
that drew everything. Three levers later, those numbers no longer described
the system in front of them, so each was re-measured against the culled
selector, across both a full scripted descent and a full camera-turn sweep.
Every bound moved down. The check runs two-sided: a bound sitting at more
than four times its own measurement now fails, exactly as one sitting under
1.5 times does. A ceiling with no upper-side check is exactly the kind of
number that can sit stale and unnoticed for phases at a time, and that's
what had happened here.

| quantity | before | after | measured | headroom |
|---|---:|---:|---:|---|
| drawn-node bound | 2,048 | **512** | 290 | 1.77x |
| mesh pool slots | 2,048 | **1,024** | 290 | 2.00x |
| resident tile cap | 1,536 | **512** | 202 | 2.53x |
| retained-sample ceiling | 768 MiB | **256 MiB** | 101 MiB | — |

Halving the mesh pool frees 34 MiB of real VRAM, since the pool is one device
buffer allocated up front rather than a bookkeeping limit. That's only safe
because a separate resolver, `engine/include/interstellar/render/
terrain_draw_fallback.hpp`, now catches every case where a drawn node's mesh
isn't ready: pool exhaustion, a slot still protected from recent use, or the
frame's upload budget already spent. Any of those substitutes the nearest
ancestor that does have a mesh, coarsening the whole subtree at once rather
than drawing a hole. Before this resolver existed, losing that pool headroom
would have been a straightforward regression. With it in place, an
accidentally unculled frame degrades to visibly coarser terrain instead.

The one number that didn't move is the streaming budget of 4 tiles uploaded
per frame. Measured demand on the culled descent averages 0.019 tiles a
frame, 210 times below the budget, so there was nothing to gain by touching
it — and raising it would trade frame-pacing margin for headroom nothing
measured was asking for.

## The budget the culling had to hit

This engine reserves 25% of a 16.6 ms frame for the whole terrain system, and
about an eighth of that, 0.52 ms, for CPU-side node selection specifically —
the rest goes to baking, uploading and drawing. A five-times margin on top of
that leaves roughly 310,000 cycles a frame at 3 GHz for the culling
predicates themselves.

Per node visited, the frustum test costs about 30 cycles: five plane
comparisons, no square root. The horizon test adds one deterministic square
root on a cold cache entry, around 150 cycles, and about 10 cycles once that
entry is warm. Averaged across an all-cold frame, that puts the cycle budget
at roughly 1,700 visited nodes and, since most visited nodes are internal
quadtree nodes rather than drawn leaves, around 1,270 actually-drawn leaves.

The unculled measured peak was 1,314 drawn nodes, already past that ceiling
with no margin left at all. That's why the culling in this phase isn't an
optimization pass on top of a working system — it's what makes the system
fit its own frame budget in the first place. After all three levers and the
re-lock, the measured peak is 290 drawn nodes against the 1,270 ceiling, a
4.38x margin, and 650 visited nodes against the 1,700 ceiling, a 2.62x
margin.

## What flew

A full descent from 400 km down to 300 m, flown afterward, held the
drawn-node count well below the visited-node count throughout: 244 drawn
against 586 visited near the surface, 189 against 502 in orbit. Terrain
stayed visible cleanly out to the horizon, with no pop at the boundary and no
gaps opening behind a turning camera. The suite that pins all of it down
stands at 1,514 tests in the release build and 1,505 in debug, every one
passing.

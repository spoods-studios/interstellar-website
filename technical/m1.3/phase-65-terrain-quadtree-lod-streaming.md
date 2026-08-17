# M1.3 Phase 65 — Terrain Quadtree LOD + Streaming: Technical Deep-Dive

## Starting point

Phase 64 shipped the tile format, the reader and real SRTM elevation validated
against surveyed landmarks. Nothing draws it yet. Phase 63 gave the renderer a
cube-sphere mapping and a jitter-free way to compose a vertex position. Nothing
decides which patch of the planet to draw, at what resolution, or morphs
between resolutions without a visible pop. Nothing streams a 512 KiB tile off
the render thread. Phase 65 builds a quadtree selector, a dedicated streaming
thread, a resident-tile cache and the CPU bake that ties them together, then
wires all four into one frame loop with real Earth relief on screen.

## A distance-ring selector with a memory

Terrain nodes are addressed by `(face, level, x, y)`, the same four fields the
Phase 64 tile format uses. Each level has a subdivide distance and a merge
distance, both scaled from the node's own arc length:

```cpp
inline constexpr double kTerrainSubdivideFactor = 3.0;
inline constexpr double kTerrainMergeFactor = 3.6;
```

A single threshold thrashes. A camera holding still one metre inside the
subdivide distance flips the node every frame the distance crosses it by
floating-point noise alone. Two thresholds fix that: a node subdivides once
the camera closes to 3.0× its arc length, and does not merge back until the
camera retreats past 3.6×. A node that just split has to give up real ground
before it is allowed to un-split. Over the scripted descent used to drive the
selector — 10,801 frames from 400 km to the runway — the smallest gap between
any node's two consecutive flips measures 756 frames, well clear of the
120-frame window the thrash check uses.

The selector's persistent state is the *desired* subdivision set, not the
drawn one. A tile that has not arrived yet still counts as desired; the frame
loop just draws its parent instead. That separation is what keeps the
geometry the same shape run after run, whatever the disk is doing.

## Two positions per vertex, and a blend that finishes exactly on time

Every terrain vertex carries two positions and two elevations:

```cpp
struct TerrainVertex {
    glm::vec3 fine_pos;
    glm::vec3 coarse_pos;
    float fine_elev_m;
    float coarse_elev_m;
};
```

`terrain.vert` blends between them by a morph factor computed per node, per
frame:

```glsl
float morph = clamp(pc.morph_and_params.x, 0.0, 1.0);
vec3 morphed = mix(in_fine_pos, in_coarse_pos, morph);
out_elev_m = mix(in_fine_elev_m, in_coarse_elev_m, morph);
```

The factor is 0 at and below half the node's subdivide-to-merge span, exactly
1 at the merge distance, and strictly increasing between. A node's geometry is
already sitting on its parent's grid the instant the selector decides to merge
it — the transition finishes exactly where the LOD switch fires, so there is
no frame where the mesh jumps. The same descent that measures zero thrash also
measures the largest single-frame morph step: 0.021, against 1.0 for a full
pop with the hysteresis band collapsed to one threshold.

## Snapping to the parent's grid

A crack opens wherever two neighbouring patches disagree about where their
shared edge sits. The obvious fix is to resample the coarser neighbour's
elevation field at the finer patch's exact coordinate — but a field resample
still disagrees with the coarse patch's own rendered edge, which is a straight
line between its own vertices, not the underlying field. The gap that leaves
is second-order in cell size, and at the coarser levels a parent cell spans
tens of kilometres, so second-order was still tens of metres of open crack.

The fix instead snaps the fine vertex's coordinate down onto the parent's own
grid before sampling:

```cpp
// child index i maps to parent index kTerrainPatchGridN/2 * (node.x & 1) + i/2
// so the snap is i & ~1 and nothing else.
```

Because the patch grid is a power of two, that snap is exact. At morph factor
1.0 a child's odd-indexed vertices collapse onto its even ones, and the
child's edge becomes the exact same polyline the parent already draws. Every
one of a patch's 1,089 coarse vertices is
checked bit-for-bit against a vertex the parent's own bake produced, and the
same check catches a one-metre nudge to a single border sample.

## A streaming thread, and why the budget counts tiles

`TileStreamer` is the engine's second background-thread component, mirroring
the physics worker's shape without sharing any of its state: a `std::jthread`
launched last in the constructor, a `std::stop_callback` that wakes a
condition variable on shutdown, the whole thread body inside a try/catch that
stores an `exception_ptr` for the render thread to poll. Requests move across
a bounded, power-of-two queue (64 slots) guarded by a mutex rather than a
lock-free ring — the queue has to support a sleeping consumer, and an
atomics-only ring beside a condition variable reopens a lost-wakeup window a
shared mutex closes for free. A full queue drops the newest request and counts
it; the selector re-asks for anything missing every frame, so a drop heals
itself one frame later.

The render side never blocks on the result:

```cpp
[[nodiscard]] std::vector<TileResultHandle> drain_up_to(std::size_t budget) {
    std::unique_lock lock{results_mutex_, std::try_to_lock};
    if (!lock.owns_lock() || budget == 0) {
        return {};
    }
    ...
}
```

`drain_up_to` takes the results lock with `try_lock`. On contention it returns
an empty drain instead of waiting, so the worst case is one frame of coarser
terrain, never a stall.

The upload budget is a tile *count*, 4 per frame, rather than a millisecond
allowance. Every v1 tile is a fixed 524,288-byte payload, so a tile count
already is a byte budget. The same budget then produces the same behaviour on
a fast machine and a slow one, and that is what a byte count buys that a
wall-clock allowance cannot. Filling the cache from a cold start now takes
well under a second at that budget.

## A cache that remembers what's about to matter

`TerrainTileCache` holds resident tile samples and their baked meshes behind a
fixed-capacity intrusive LRU: a pre-reserved node pool and a pre-reserved
index, so the hot-path `lookup` and `touch` calls neither allocate nor
rehash. Capacity is locked at 512 resident tiles.

Plain LRU has one problem for this workload: the tile a node is about to merge
into is, briefly, the least recently touched thing in the cache, so a plain
LRU picks it as the next eviction. Each frame, the cache is handed the current
hysteresis merge band and marks every resident tile inside it exempt from
eviction:

```cpp
void set_exempt(std::span<const TerrainNodeKey> band) noexcept {
    for (std::uint32_t slot = head_; slot != kNil; slot = entries_[slot].next) {
        entries_[slot].exempt = false;
    }
    ...
}
```

The exemption is cleared and rebuilt every frame, so it always reflects the
current band rather than an earlier one. If every resident tile happens to be
exempt at full capacity, `insert` refuses the request, bumps a counter and
leaves the frame running with the tile still coarse. A non-zero refusal count
is the signal that the cache size and the band width disagree.

## Real elevation, streamed and shaded

The dataset streams from the offline asset pipeline's output
(`setare-assets/data/processed`), resolved through the Phase 64 manifest the
same way the reader validated it in the previous phase. Elevation reaches the
screen through a five-stop hypsometric ramp — dark green at sea level, through
olive uplands and brown highlands, to white above 4,500 m — and ocean gets no
ramp at all:

```glsl
if (in_elev_m == 0.0) {
    // ocean stays flat, shaded by the sphere's own normal
}
```

That is an exact equality test, and the whole chain that produces it stays
exact: the tile format guarantees ocean samples are `int16` 0, a bilinear
blend of zeros is zero at any weights, and `mix(0.0, 0.0, m)` is zero for any
morph factor. A coastline falls straight out of that chain with no separate
shoreline mask. Land relief comes from a screen-space derivative
normal — no extra vertex attribute — lit by the same Sun direction the
renderer already tracks for every other surface, so day and night arrive as a
consequence of the lighting rather than as a separate feature.

The whole loop — select against the cache, exempt the current band, request
what is missing, drain the streamer under budget, bake, draw — runs inside one
function called once per frame. Every number above, the 512 KiB tile, the
512-tile cap, the 4-tile budget, the 1,089-vertex patch, is a count that loop
can assert against every time it runs.

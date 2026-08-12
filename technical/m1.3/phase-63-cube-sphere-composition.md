# M1.3 Phase 63 — Cube-Sphere Math + Coordinate Composition: Technical Deep-Dive

## Starting point

Phase 62 gave the renderer a perspective camera and a depth buffer. Nothing yet puts terrain geometry under that camera. Two pieces of math have to exist before any terrain code gets written, because everything downstream bakes them in: the mapping from flat cube faces onto the round planet (every elevation tile will be authored against it), and the composition function that turns a planet-local vertex into a camera-relative float32 position (every mesh will flow through it). A precision bug in either one, shipped and built upon, corrupts terrain silently. Phase 63 locks both as tested kernels before a single tile or quadtree exists.

## Six flat faces, one round planet

A cube-sphere wraps the planet in six square faces and maps each face's `(u, v)` grid onto the sphere. Normalizing the cube point onto the sphere is the obvious mapping, and it distorts: cells near a face centre come out much larger than cells near a corner. Measured over a 64×64 grid on every face, the largest cell covers 5.03× the solid angle of the smallest. Terrain tiles authored on that grid would carry 5× resolution swings across a face.

The fix is a closed-form correction applied to the embedded cube point before normalization:

```cpp
// x' = x * sqrt(1 - (y^2 + z^2)/2 + y^2 z^2 / 3), applied cyclically
// to all three components (Nowell's approximately-equal-area variant).
```

Same 64×64 measurement, corrected mapping: 1.286×. The battery that pins this uses Van Oosterom–Strackee's solid-angle formula — both its numerator and denominator are well-conditioned dot and cross products. The textbook spherical-excess route subtracts nearly equal half-perimeter terms, and for the small triangles a fine grid produces, the rounding noise lands in exactly the digits under test. The suite also runs the naive normalization through the same instrument and requires it to violate the bound. A dead instrument would pass a flat curve; the negative control proves the battery can tell the two mappings apart.

The bound itself is calibrated at the 64×64 grid and locked with the grid named in the lock, because the measured ratio climbs as cells shrink: 1.187 at 16×16, 1.286 at 64×64, 1.321 at 256×256. Refining the grid measures a different quantity.

Cross-face continuity is structural. All six faces call one shared embedding helper, and the forward mapping is asserted bit-for-bit equal to the correction applied to that one helper. Adjacent faces agree bitwise along all 12 cube edges and at all 8 corners. The tests compare with `==` on the doubles, and a tolerance there would only hide a ULP seam.

## The tie-break that almost never fires

The inverse mapping — direction in, `(face, u, v)` out — picks the dominant axis to choose the chart, with a documented lowest-face-index tie-break for directions exactly on a cube edge. Generating reference values measured how often that rule actually decides anything: 6 times out of 20 seam points.

No seam point survives a trip through decimal degrees intact. Converting degrees to radians and running `sin`/`cos` leaves a residue of about 1e-16 in the direction components, and that residue picks the dominant axis before the tie-break ever runs. 14 of the 20 seam points land on a face the tie-break would not have chosen. The practical rule for any consumer: on a seam, assert the direction, never the face index. The face a seam point reports is toolchain-dependent; the direction is pinned.

## Composing a vertex without losing the planet

Terrain vertices follow the relative-to-center pattern: each patch stores float32 offsets from its own float64 centre, and the composition function assembles the camera-relative position:

```cpp
[[nodiscard]] inline glm::vec3 compose_patch_camera_relative(
    const glm::dvec3& patch_center_planet, const glm::dvec3& camera_planet,
    const glm::vec3& local_offset) noexcept;
```

The subtraction happens in float64 first; only the small difference narrows to float32. Reversing that order at Earth radius (6.37×10⁶ m) leaves float32 with metre-scale quantization, which on screen is vertices crawling as the camera moves.

The signature was supposed to make that mistake a compile error — float64 in, float32 out. It did not. GLM's cross-precision constructor is implicit by default, so a `glm::vec3` argument widens silently to `glm::dvec3` and an already-narrowed call site compiles clean. The header now carries a `requires`-constrained deleted overload that rejects `glm::vec3` in any of the three positions, with static assertions pinning all the mixed cases. Correct callers are untouched.

The jitter proof sweeps the full altitude range from 1 m to orbit and bounds the worst-case screen-space movement below a pixel. The instrument took some care: the view-projection matrix under test is the real float32 matrix the GPU receives, but the multiply and perspective divide run in float64, because the quantity being measured is itself a float32 ULP. The float32 pixel conversion quantizes at about 1.1e-4 px at 1080p — the same scale as the effect — so evaluating in float32 would measure the ruler instead of the jitter. And because a flat curve is also what a broken instrument produces, the suite runs the composition with a float32 intermediate through the same sweep and requires it to blow the budget.

## The reference table catches its first bug

The mapping is a contract with the offline asset pipeline: every SRTM tile gets authored against this exact function. So the phase ships a 36-row reference table — face centres, cube corners, edge midpoints, poles, equatorial cardinals, and four landmarks including Everest and Death Valley — generated from the shipped kernel at full float64 precision and pinned by a golden test, so the published table and the live kernel cannot drift apart.

It paid for itself before the phase closed. The asset pipeline's own face-axis table carried a sign error on the free axis of three faces. The interior landmark rows exposed it: Everest and Sydney came back with `u` complemented (`1 − u`) against the engine's values. The seam rows could never have caught this — a mirrored axis still lands on the same edge directions — which is exactly why the table carries interior landmarks. Three faces' worth of mirrored terrain tiles were regenerated before any of them shipped.

One wart surfaced while generating the table and got fixed at verification. The longitude convention is `(−π, π]`, but the face behind the planet produces `y = −0.0` in its embedding, and `atan2(−0.0, −1.0)` returns exactly `−π` — outside the interval. The fix folds the single exact `−π` case to `+π`; every inexact neighbour was already inside. Three table rows respelled their longitude from −180° to +180°, moving `u` by one ULP.

## Drawing the mapping

The phase ends with the mapping on screen: a bright green cube-sphere grid over the Phase 62 globe, drawn through a new line-list pipeline. Two implementation notes survived contact with the hardware.

Wireframe rasterization (`polygonMode::eLine`) sits behind a device feature this engine never enabled, and enabling features for a debug overlay is backwards. A line-list topology with the ordinary fill mode draws lines with no feature bit at all.

The first version of the grid rendered as dashes. A grid cell edge at this resolution spans about 620 km of arc, and drawn as a single straight chord it sags about 8 km below the sphere — the same scale as the underlying proxy globe's facet sag, so the two surfaces interleave and the proxy eats segments of every line. Each cell edge is now sampled 8× along the sphere and the whole grid rides a 500 m shell above the surface. The lift is 7.8×10⁻⁵ of the planet's radius and is invisible in the frame.

The grid also taught an honest lesson about expectations: a fixed global grid has an altitude floor. At 2 m altitude the nearest grid line is hundreds of kilometres away and below the horizon, so the surface-level camera states legitimately show nothing. From 400 km the visible cap subtends about 19.8° of arc against a face's 90° span, so even in orbit the view never crosses a face boundary. Closing that floor is what the terrain quadtree exists to do.

## State of the renderer

The renderer now owns a locked mapping from cube faces to the planet and a composition function proven jitter-free across the flight envelope, both with production call sites — the wireframe and the Phase 62 stress scene already compose every vertex through them. The asset pipeline holds the same mapping, verified against the reference table to 1e-12. Phase 64 locks the tile format on top of it and reads the first real SRTM elevation into the engine.

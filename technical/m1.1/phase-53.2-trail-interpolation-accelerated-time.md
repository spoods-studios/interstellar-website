# M1.1 Phase 53.2 — Trail Interpolation at Accelerated Time: Technical Deep-Dive

> Retroactive technical devlog. **Inserted fix phase** — not in the original
> M1.1 roadmap. Code shown **as built on 2026-07-23**; a drift section at the
> end tracks what changed since.

## Starting point

Phase 53 put the craft HUD on screen. It draws three things around the
spacecraft: a past-track trail of where the craft has been, a predicted conic
of where it is going, and a body-axes attitude triad. Flying it showed the
trail rendering as a coarse polygon. A circular orbit came out as a ring of
long straight chords with visible corners at every joint, sitting right next to
the predicted conic, which was already a smooth ellipse.

The colours made that polygon dominate the frame. The trail was drawn in
near-white at full alpha, `(0.95, 0.95, 1.00, 1.00)`; the conic in magenta at
`(1.00, 0.40, 0.90, 0.70)`. The brightest line on screen was the jagged one.

Phase 53.2 is the second of three fix phases inserted between Phase 53 and the
Phase 54 gate. Phase 53.1 fixed the demo's control policy and added an attitude
indicator. Phase 53.3 went on to fix the camera snap.

## The cause: a store tuned for a position stream that does not exist

The past-track store is `CraftTrail` in
`engine/include/interstellar/render/craft_geometry.hpp` — a float64 ring of
2000 reference-relative samples. The scene composer offers it one sample per
rendered frame, with no time-scale or warp condition attached:

```cpp
craft_trail_.append(craft_rel);
```

Only the store's own minimum-travel gate is allowed to reject an offer. That
gate is 30 km:

```cpp
inline constexpr double kCraftTrailMinSegmentM = 3.0e4;
```

30 km was chosen against the drawn scale. The orbit-fit camera maps a
half-extent of 8.13e6 m to 1.0 NDC, so a 30 km segment is 0.0037 NDC — about
two pixels at 1080p. A low Earth orbit here has a circumference of roughly
4.26e7 m, so a 30 km gate admits about 1,420 samples per orbit. That is far
finer than the 256-sample conic the trail is drawn against.

The gate never gets near that figure, because the craft's published position
does not move 30 km at a time. It moves 300 s at a time. The orbital step is
`step_dt = 300 s`, and every rendered frame between two orbital steps sees the
identical published position. A LEO period here is 5,554 s. So one orbit
produces about 18 distinct samples, not 1,420 — the store fills at the rate the
integrator publishes, and the gate has nothing to reject. At 128x that is one
new trail point roughly every 140 rendered frames.

Those ~18 points per orbit are all real; the trail is a faithful record of the
published trajectory. Drawing them as a line strip is what turns a faithful
record into a polygon. Each chord cuts a sagitta of `R*(1 - cos(pi/18.5))`
inside the true circle, about 98 km at this orbit radius. Raising the sample
rate would mean changing what the physics worker publishes, and both that store
and `step_dt = 300 s` are locked. So the fix stays entirely on the draw side.

## The change: a centripetal Catmull-Rom spline through the stored samples

The new kernel is `craft_trail_spline` in `engine/src/craft_geometry.cpp`. It
mirrors the two kernels already in that file, `conic_samples` and
`craft_triad_segments` — a span in, a span out, the count written returned,
`noexcept`, and no rendering, snapshot or I/O dependency:

```cpp
[[nodiscard]] std::size_t craft_trail_spline(std::span<const coords::Vec3f32> src,
                                             std::size_t subdivisions,
                                             std::span<coords::Vec3f32> out) noexcept;
```

It subdivides each stored chord into `kCraftTrailSplineSubdiv = 16` sub-points
along a Catmull-Rom spline. Catmull-Rom interpolates its knots, which is the
property that makes it the right family here. Every stored sample stays on the
drawn curve, and only the arc between two stored samples is invented.

The spline is evaluated with the Barry–Goldman pyramidal blend rather than a
basis-matrix form. Given four control points `P0..P3` and four knots `t0..t3`,
the blend is three levels of linear interpolation, each one remapping the
parameter across a different pair of knots:

```cpp
auto remap = [](double ta, double tb, const coords::Vec3f64& pa,
                const coords::Vec3f64& pb, double t) noexcept -> coords::Vec3f64 {
    const double d = tb - ta;
    if (d == 0.0) {
        return pb;
    }
    const double w = (t - ta) / d;
    return pa * (1.0 - w) + pb * w;
};

const coords::Vec3f64 a1 = remap(t0, t1, p0, p1, t);
const coords::Vec3f64 a2 = remap(t1, t2, p1, p2, t);
const coords::Vec3f64 a3 = remap(t2, t3, p2, p3, t);
const coords::Vec3f64 b1 = remap(t0, t2, a1, a2, t);
const coords::Vec3f64 b2 = remap(t1, t3, a2, a3, t);
const coords::Vec3f64 c  = remap(t1, t2, b1, b2, t);
```

### Why centripetal and not uniform

The pyramid takes the knot values directly, which makes the parametrisation a
free choice instead of a rewrite. The knots are spaced by chord length raised
to a power, `t[i+1] - t[i] = |P[i+1] - P[i]|^alpha`. Uniform Catmull-Rom is
`alpha = 0`, which spaces the knots evenly regardless of how far apart the
points actually are. Uniform overshoots when consecutive chords differ sharply
in length, and the overshoot shows up as a cusp or a self-intersection in the
drawn curve. At 300 s spacing the chords are ~2.3e6 m long, so an overshoot is
large enough to be plainly visible. Centripetal is `alpha = 0.5`, the
parametrisation that provably produces no cusps and no self-intersections for
any control polygon. The kernel computes it from the squared length the vector
type already provides, so the half-power becomes a quarter-power on the square:

```cpp
auto knot_delta = [](const coords::Vec3f64& a,
                     const coords::Vec3f64& b) noexcept -> double {
    const double d2 = (b - a).length_squared();
    return d2 > 0.0 ? std::pow(d2, 0.25) : 0.0;
};
```

The zero branch matters. A repeated control point gives a zero knot interval,
and `remap` divides by that interval. The `d == 0.0` guard returns the shared
endpoint instead, so a coincident knot pair collapses rather than producing a NaN.

### The knot layout and the clamped ends

Per segment the kernel builds four control points and four knots, anchoring at
zero:

```cpp
const double t0 = 0.0;
const double t1 = t0 + knot_delta(p0, p1);
const double t2 = t1 + knot_delta(p1, p2);
const double t3 = t2 + knot_delta(p2, p3);
```

Only knot differences enter `remap`, so anchoring at zero costs nothing. The
four control points come from an accessor `pt` that clamps an out-of-range
index to `0` or `n - 1` and widens the float32 sample to float64.

That clamp is what supplies the phantom control points. The first and last
segments have no real neighbour on one side, so they get a duplicate of the
first or last sample — the standard clamped Catmull-Rom treatment. A duplicated
phantom gives a zero knot interval at that end. The `remap` guard then collapses
the first blend level to the shared point, and the end segment relaxes toward
its straight chord. That is a deliberate trade. The two end segments are the
newest and the oldest points on the trail, and neither has the neighbour
information a full spline needs.

### Exact pass-through at each control point

At the start of each segment the kernel emits the stored sample verbatim rather
than evaluating the pyramid at `t = t1`:

```cpp
for (std::size_t m = 0; m < k; ++m) {
    if (m == 0) {
        out[written++] = src[j];
        continue;
    }
    const double t = t1 + (t2 - t1) * static_cast<double>(m)
                            / static_cast<double>(k);
    ...
}
```

The final control point is appended verbatim after the loop. The intermediate
parameters march linearly from `t1` toward `t2` across `k` steps, so sub-point
`m` sits at fraction `m/k` of the segment's knot interval. Evaluating the
pyramid at exactly `t1` would return `P1` mathematically; emitting `src[j]`
returns it in the source's own float32 bits, with no round trip through float64
and back. That is what lets the test assert exact equality rather than a
tolerance.

This is the property that keeps the smoothed trail honest across a burn. A
thrust event changes the orbit between two stored samples. Both of those
samples stay exactly on the drawn curve, so the trail still bends where it
really bent. Only the arc between them is a spline instead of the true
historical conic arc.

### The buffer cap, which is load-bearing

`n` source points produce `(n-1)*k + 1` outputs. With `k = 16` and a full
2000-sample store that is 31,985 vertices, aimed at a region sized for 2000.
The kernel computes how many source points fit and splines only those:

```cpp
const std::size_t fit = (out.size() - 1) / k + 1;
const std::size_t n = std::min(src.size(), fit);
if (n < 2) {
    out[0] = src[0];
    return 1;
}
```

For a 2000-vertex output that keeps 125 source points, producing `124*16 + 1 =
1985` vertices. The source arrives newest-first, because that is the order
`CraftTrail::regenerate` writes it in, so truncating the source span discards
the oldest history and keeps the recent history smooth. The chosen `n`
satisfies the output bound by construction, so no write can pass `out.end()`. A
`static_assert` pins `kCraftTrailSplineSubdiv >= 1`, since zero would drop the
curve entirely. At 128x the cap is nowhere near contended: about 18 source
points give 17 segments and 273 vertices against a 2000-vertex region.

## Wiring it into the draw path

`draw_craft_geometry` in `engine/src/orbit_demo.cpp` previously regenerated the
store straight into the shared geometry scratch. It now regenerates into a
dedicated source scratch, then splines that into the trail region:

```cpp
const std::size_t src_n = craft_trail_.regenerate(
    ref_offset,
    std::span<coords::Vec3f32>{trail_src_scratch_.data(), kCraftTrailCapacity});
const std::size_t trail_n = craft_trail_spline(
    std::span<const coords::Vec3f32>{trail_src_scratch_.data(), src_n},
    kCraftTrailSplineSubdiv,
    std::span<coords::Vec3f32>{geom_scratch_.data(), kCraftTrailCapacity});
```

`trail_src_scratch_` is a `std::array<coords::Vec3f32, kCraftTrailCapacity>`
member of `OrbitDemo`, not a local. The spline reads a stable source it is not
simultaneously overwriting, and the per-frame path still allocates nothing.

The colours moved apart at the same time. The trail became a calm cyan at
moderate alpha, and the conic gained brightness and alpha:

```cpp
if (trail_n > 1) {
    push_color(0.40f, 0.72f, 0.95f, 0.65f);
    cmd.draw(static_cast<uint32_t>(trail_n), 1, 0, 0);
}
if (conic_count > 1) {
    push_color(1.00f, 0.45f, 0.92f, 0.92f);
    cmd.draw(static_cast<uint32_t>(conic_count), 1, kCraftConicVertexOffset, 0);
}
```

The predicted conic is now the brightest line on screen, and the trail reads as
history behind it. When a burn reshapes the orbit, the divergence between cyan
history and magenta prediction is the thing the player is meant to see, and it
stays readable because the two lines no longer compete.

Nothing below the draw call moved. The float64 store, its minimum-travel gate
and its one-offer-per-rendered-frame append rule are byte-untouched, the locked
deterministic force kernel `nbody_force.cpp` is not in the changeset, and no
worker or integrator translation unit was touched. The one new libm call,
`std::pow`, lives in the render-tier `craft_geometry.cpp`, which already called
`std::sqrt` for the prograde marker.

## Tests

`tests/unit/render/test_craft_trail_spline.cpp` runs under the tag
`[craft_trail_spline]` and pins four properties.

1. **Circle fidelity.** Eight points on a circle of radius 1000. The raw chord
   polygon dips `R*(1 - cos(pi/8))` inside the circle at each chord midpoint,
   which is 7.6% of R. Interior spline points must sit within 25% of that
   deviation — at least 4x tighter than the chords they replace — and within 2%
   of R absolutely. The bound is computed from the control-point count rather
   than hard-coded. The two clamped end segments are excluded by design.
2. **Control-point interpolation.** Five arbitrary points, `k = 8`. Every
   source point `j` must land at output index `j*k`, compared for exact
   equality. The final endpoint is checked the same way.
3. **Degenerate guards.** Zero source points writes nothing. One source point
   copies through and returns 1. Two source points return `k + 1` vertices
   bracketed by both endpoints exactly. An empty output span writes nothing.
4. **The buffer cap.** A full 2000-sample source must return at most 2000
   vertices, with the newest sample first. A 100-vertex output span must cap
   proportionally to `(fit - 1)*k + 1`, with `fit` recomputed in the test from
   the same formula.

Full suite after the change: **893/893 in both the Debug and Release lanes.**
Flying it confirmed the visible result — the trail renders as a smooth curve as
circular as the conic, and cyan against magenta reads cleanly.

## Where it is now (drift since 2026-07-23)

- **The kernel is unchanged.** Phase 53.3 followed immediately and touched only
  the camera, splitting `zoom_factor_` into a target and an eased current value
  so that refit, recenter and zoom stop snapping. It never touches the trail.
- **Full historical fidelity is still open.** Subdividing each segment along
  its own historical osculating conic, instead of along a spline, would need
  per-sample orbital elements in the store. That is a change to the locked
  store, so it moves to M1.2 alongside craft-orbital subcycling. The current
  curve is faithful at every stored sample and interpolated between them, and
  the interpolated stretch of a long-ago pre-burn arc is never the part of the
  trail the player is looking at.
- **The underlying coarseness is unchanged, and so is the gate.** The trail
  still holds ~18 points per orbit at 128x, and the 30 km minimum-travel gate
  still has nothing to reject. Both change together the moment the craft's
  published position advances more often than once per 300 s, which is exactly
  what craft-orbital subcycling in M1.2 would do. Until then the spline is what
  stands between a coarse store and a smooth line.

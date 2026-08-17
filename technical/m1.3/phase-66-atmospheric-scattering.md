# M1.3 Phase 66 — Atmospheric Scattering: Technical Deep-Dive

## Starting point

The renderer could draw a planet and terrain, but the sky above both was a flat
clear color. Phase 66 replaces it with a physical atmosphere: a Rayleigh/Mie
scattering model that produces a blue dome at the surface, a reddened horizon
at sunset, a thin bright limb from orbit, and a true black night sky, all from
one physics model rather than a gradient texture. It is also the engine's
first Vulkan compute work — every render pass before this phase was a graphics
pipeline.

## A float64 sky with no GPU in it

The atmosphere model comes from Sébastien Hillaire's 2020 EGSR paper, the same
technique behind the sky in several shipped flight and space games. Before any
GPU code existed, the full pipeline was built as a float64 CPU function
library: density profiles for the Rayleigh, Mie, and ozone layers, the
transmittance integral through those layers, a closed-form geometric-series
sum for multiple scattering, and a sky-view raymarch that turns a view
direction into a color. This CPU version bakes and samples its own lookup
tables the same way the GPU eventually will, and it runs the identical
step counts and quadrature the shaders use — it is a wider-precision copy of
the algorithm, never a more accurate one, so any later gap between the CPU
and GPU sides can only come from float32 rounding.

The scattering coefficients are the literature RGB values from Hillaire's own
demo scene, not the wavelength-integrated spectral constants used in Eric
Bruneton's 2008/2017 model — the two produce similar-looking skies through
different math, so mixing a coefficient from one into the other would be
subtly wrong.

```cpp
inline constexpr double kRayleighScatteringRedPerM   = 5.802e-6;
inline constexpr double kRayleighScatteringGreenPerM = 13.558e-6;
inline constexpr double kRayleighScatteringBluePerM  = 33.1e-6;

inline constexpr double kMieScatteringPerM  = 3.996e-6;
inline constexpr double kMieExtinctionPerM  = 4.44e-6;

inline constexpr double kOzoneAbsorptionRedPerM   = 0.650e-6;
inline constexpr double kOzoneAbsorptionGreenPerM = 1.881e-6;
inline constexpr double kOzoneAbsorptionBluePerM  = 0.085e-6;
```

Rayleigh scattering falls off with an 8 km scale height, Mie with 1.2 km, and
ozone absorption follows a tent function centered at 25 km. The Mie phase
function uses Cornette-Shanks with an asymmetry factor of 0.8. Every one of
these numbers is pinned by a compile-time `static_assert` in
`engine/include/interstellar/render/atmosphere_constants.hpp`, so a future
edit cannot quietly drift the sky's color.

A second, much looser check runs Bruneton's published spectral model
side by side and asks only "is this an Earth sky at all" — a clear vertical
air column should pass most red light and noticeably less blue, the zenith
should read blue by a factor of a few rather than a factor of twenty, and the
sky should be far dimmer than the sun. That check is a sanity floor, not a
tolerance: the real correctness bar is the CPU oracle's own output, compared
texel for texel against the GPU tables built from it.

One bug showed up immediately: standing at the surface, the sky rendered
solid black. A camera positioned exactly on the ground sphere's radius
intersects that sphere at zero distance, which collapsed the raymarch's
travel distance to zero and returned no radiance at all. No early test
caught it, because none of them happened to sample from ground level, and
ground level is exactly the altitude the game is played at. The fix lifts
the ray's starting point a small distance off the ground before marching,
mirroring the same lift Hillaire's own reference shader applies.

## Three compute pipelines, one graphics queue

Three GLSL compute shaders port the oracle's math to float32, texel for
texel:

1. `transmittance_lut.comp` — a 256×64 table of how much sunlight survives to
   a given altitude and view angle, baked once at startup.
2. `multiscatter_lut.comp` — a 32×32 table of light that has bounced more than
   once, baked once at startup, reading the transmittance table it depends on.
3. `skyview_lut.comp` — a 192×108 table of what the sky looks like from the
   camera's current altitude and sun direction, rebuilt every frame.

All three run at `local_size_x/y = 8`, dispatched on the same
graphics-capable queue the renderer already uses, ordered by Vulkan
synchronization-2 barriers rather than a second queue. The raymarch itself
lives in one shared file, `atmosphere_march.glsl`, included by both LUT
shaders that need it, so the math exists in exactly one place instead of
three near-identical copies.

Every texel of every table is read back to the CPU and compared against the
oracle that produced the reference values, with a tolerance of the form
`|gpu - cpu| <= absolute + relative * |cpu|`. The absolute term is not a
fudge factor — it is four times the smallest quantum the 16-bit float storage
format can represent, because a texel whose true value is smaller than that
can never match regardless of how correct the shader is. The relative terms
were derived, not chosen by trial: for the transmittance table, propagating a
half-meter floating-point rounding error at Earth's radius through the
optical-depth math predicts a divergence around 1.0×10⁻³, plus about 4.9×10⁻⁴
from the storage format's own rounding — and the measured worst-case
divergence is 1.50×10⁻³, matching the prediction to the digit.

The tightest of the three tables is the multiple-scattering one, with roughly
1.6× headroom over its locked bound. Its worst texel sits at a sun angle 9.28
degrees below the horizon at 51.6 km altitude, deep in the twilight
extinction tail, where the transmittance-table lookup coordinate is computed
as the square root of a difference of two nearly equal, planet-scale squared
values — the single float32 operation in the whole pipeline that loses the
most precision. It stays in that literal form deliberately: rearranging it
algebraically would make the GPU disagree with the oracle by a different
algorithm rather than by rounding error, which the tolerance is not supposed
to absorb.

One negative control was worth keeping on record. Deleting the barrier
between a compute dispatch and the shader that reads its output should be a
correctness bug. On this GPU driver, every numeric texel comparison still
passed — the data came out right despite the missing synchronization. Only
the Vulkan validation layer caught it. It is a reminder that a texel diff and
a validation-layer check catch different classes of mistake, and a GPU test
suite that only diffs values is blind to a synchronization bug the hardware
happens to tolerate today.

## The sky on screen

The sky itself draws as a single triangle covering the whole screen, with the
depth test set to pass only where nothing else already drew. Each pixel
reconstructs a view ray, converts it to the two angles the sky-view table is
indexed by, and samples one texel — no raymarch at draw time, no branch for
"am I looking at the ground, the horizon, or space." The same four lines
produce the noon dome at the surface and the thin blue limb from 400 km,
because the compute shader that built the table already resolved which rays
hit the ground, which reach orbit, and which miss the atmosphere entirely.

The sun renders as a disc at its true angular diameter — 0.53 degrees, the
real value for the Sun seen from Earth — tinted by the same transmittance
table that lights the rest of the sky, so it reads white near the zenith and
reddens toward the horizon as a consequence of the physics rather than a
separate color ramp. It is also occluded correctly by the planet itself.

The ground-intersection bug from the CPU oracle turned out to have a second,
unpredicted failure mode. The same float32 collapse that blacked out the sky
at surface altitude also decides which half of the sky-view table's warp a
pixel samples from — and at the altitude the game is actually played at, it
classified every direction as pointing at the ground, which would have put
the entire visible sky on the below-horizon branch. The fix lifts the ray
origin by 4 meters for that one geometric test, derived from how much
rounding error the underlying subtraction can carry at Earth's radius and
then confirmed by sweeping the test across a range of altitudes by hand.

## HDR, one tonemap, and dither in the right domain

Terrain and sky both write physical radiance — not colors clamped to a
displayable range — into a 16-bit floating point offscreen target. A single
dedicated pass then reads that target, applies exposure and a tone curve, and
writes the result to the 8-bit swapchain the screen actually shows. Nothing
upstream of that one pass ever compresses or clamps, so the sky and the
terrain cannot end up tone-mapped by two different pieces of code that drift
apart from each other.

The tone curve is Khronos's PBR Neutral, ported from its published GLSL
source. Colors under a fixed compression threshold pass through close to
unchanged; brighter colors compress toward white along a curve that also
desaturates as it compresses, which keeps a blown-out sunset looking like a
bright sunset instead of a flat colored rectangle.

```cpp
inline constexpr float kPbrNeutralStartCompression = 0.8f - 0.04f;
inline constexpr float kPbrNeutralDesaturation = 0.15f;

const float d = 1.0f - kPbrNeutralStartCompression;
const float new_peak = 1.0f - d * d / (peak + d - kPbrNeutralStartCompression);
color *= new_peak / peak;
```

Before the final 8-bit write, the pass adds a small dithering offset to break
up banding in the sky's color gradients. The offset is triangular — the sum
of two independent pseudo-random draws minus one, rather than a single
uniform draw — because a triangular distribution cancels quantization error
in a way a uniform one does not. It comes from a pure hash of the pixel's
integer coordinates with no per-frame or per-draw variation, so two renders
of the same frame dither identically.

The domain the dither gets added in changes the result completely. The
swapchain format is sRGB-encoded, so the actual 8-bit rounding happens after
the hardware's own gamma encode, not on the linear values the shader
computes. The sRGB transfer curve's slope runs from about 12.92 near black
down to about 0.077 near white. A dither offset added in linear space would
show up as roughly 13 steps of visible noise in shadows and as barely
anything in highlights. That is backwards: it is loud where banding is least
visible and nearly silent where banding is worst. The dither is applied after
encoding to sRGB instead, so the hardware's own re-encode cancels out
correctly and the offset lands where the quantizer actually lives.

## The exposure ramp that had the wrong sign

Exposure is a deterministic curve of sun elevation and camera altitude,
computed once per frame from the same sun direction and camera state
already used to draw the sky. The elevation table was measured directly
from the CPU oracle: sky radiance was swept across sun angles from the
surface, and the whole curve is anchored so a sunlit patch of ground lands at
roughly half brightness on screen.

The first version of the altitude term was a straight −2.0 EV linear ramp
between 100 km and 400 km, reasoned from the assumption that orbit looks
mostly like black space with one thin bright limb, so it should need less
exposure than the ground. That assumption had never actually been measured.
Flying a scripted descent through a full grid of altitudes and sun angles
during validation found the opposite: the orbital limb is the brightest
thing in the frame, not the dimmest, and the extra two stops of the wrong-way
ramp blew six of thirty tested states out to flat white.

The fix replaces the ramp with a geometric term rather than a re-tuned
constant. From altitude, a camera looks past its own local horizon — the
ground drops away by an angle of `acos(R_bottom / r)`, where `r` is the
camera's distance from the planet's center. That same angle is added to the
sun's elevation before the exposure lookup, because the atmosphere along that
sight line is that many degrees closer to the sun than the camera's own
horizontal is:

```cpp
// dip(0) == 0 exactly, so every surface-altitude exposure value is
// untouched — only altitudes above the ground shift the lookup.
const double dip_deg = std::acos(kAtmosphereBottomRadiusM / view_height_m)
                        * (180.0 / std::numbers::pi);
const double looked_up_elevation_deg = sun_elevation_deg + dip_deg;
```

A camera at 400 km with the sun 18 degrees below its own local horizon is, by
this geometry, looking at atmosphere where the sun is still about 1.8 degrees
above the horizon — which is exactly what an orbital sunrise looks like. The
dip is 0 degrees at the surface, about 10.1 degrees at 100 km, and about 19.8
degrees at 400 km. Because the dip is exactly zero at ground level, every
surface exposure value measured earlier stayed untouched — only the part of
the curve that was actually wrong moved. After the fix, the brightest state
in the whole thirty-point grid reads at about 0.83 on screen, comfortably
under white with no clipping.

## The terminator: pure physics, no blend code

Night is black on the night side of the planet because no sunlight physically
reaches it — there is no blend curve, no terminator-width parameter, and no
special case anywhere in the shader for "it's dark now." The twilight band
between day and night falls entirely out of the transmittance and
multiple-scattering math: sky brightness decays smoothly across roughly nine
orders of magnitude as the sun drops below the horizon, with no point along
that curve where it drops sharply rather than smoothly.

A small sun-independent ambient term keeps the ground visible at night
instead of vanishing into pure black. It is added to the terrain's
illuminance outside the sunlight transmittance factor, so it survives even
when the actual sunlight term goes to zero — a faint, physically unmotivated
floor whose only job is to keep terrain relief legible as silhouette against
a genuinely black sky, at more than a hundred times the contrast between the
lit ground and the dark zenith above it.

## Scope: sky only

This phase implements the sky itself — the three lookup tables, the sky
draw, the tone-mapped HDR pipeline, and transmittance-lit terrain lighting.
It does not implement aerial perspective: the haze and color shift that a
real atmosphere adds to distant mountains, clouds, or other foreground
objects seen through several kilometers of air. That is a separate,
already-scoped piece of work for the next phase, and nothing in this phase's
three compute shaders reaches toward it.

## State of the renderer

The engine now has a full physical sky: three GPU lookup tables built from a
float64 reference model that was proven correct before a single GPU shader
existed, an HDR pipeline with one tone-mapping pass instead of several
inconsistent ones, and a terminator and night side that come from the same
scattering math as the daytime dome rather than a separate lighting rule.
The next phase adds aerial perspective on top of it.

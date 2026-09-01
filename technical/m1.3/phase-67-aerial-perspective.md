# M1.3 Phase 67 — Aerial Perspective on Terrain: Technical Deep-Dive

## Starting point

Phase 66 put a physical atmosphere in the sky and left the ground out of it.
`terrain.frag` shaded a surface point and stopped there, so a mountain 200 km
away came back as saturated as one 200 m away, and the horizon met a sky it had
no optical relationship with. Aerial perspective is the missing term: the
atmosphere between the surface and the eye absorbs what the ground reflects and
adds its own in-scattered light on top, which is what makes distance readable.

The phase was scoped with four stretch visuals and shipped one. A
pre-planning audit of the asset repository found that two of them had no data to
run on: the processed tile manifest declares exactly one layer, `elevation` /
`int16_m`, and the locked tile format contract is elevation-only, so the engine's
reader rejects any other dtype by construction. Specular ocean needs a land/water
mask and city lights need a night-lights layer, and neither layer exists —
neither was ever scheduled, let alone produced. Those two move to an inserted
Phase 67.1 behind the asset work and the additive contract revision that admits
the new layers, rather than being cut — both carry planned showcase shots. The
fourth,
horizon culling in tile selection, turned out to have shipped in Phase 65.1
already; the mapping that pointed it at this phase was stale. What remained is
aerial perspective, which depends on nothing outside the engine.

## The volume

The near field is a camera-frustum froxel volume, following Hillaire's 2020
formulation: a 32×32×32 `R16G16B16A16Sfloat` 3D image storing accumulated
in-scattered radiance, and a second one storing transmittance, both marched from
the Phase 66 tables. These are the engine's first 3D storage images and its first
frustum-aligned compute dispatch.

One invocation handles one (x, y) column and walks Z as its own loop, storing
after each slice, because the accumulation down a column is inherently serial —
Z is the algorithm's loop, not a dispatch dimension. Slice distances follow a
squared mapping out to 32 km with 4 samples per slice, so resolution concentrates
near the camera where the gradient is steepest.

Five starting numbers were locked before implementation with an explicit licence
to move any of them during calibration: the 32³ dimensions, the 32 km far
distance, the squared mapping, 4 samples per slice, and a 4 km blend band. None
of the five moved.

Two structural choices keep the volume from disagreeing with the things it must
agree with. The camera basis is recovered from the rows of the same `view_proj`
the rasterizer used rather than re-fetched from the camera, so a frustum-aligned
table cannot end up aligned to a different frustum than the fragments sampling
it. And the segment integral is extracted to exactly one definition in each
language — `detail::integrate_scattered_luminance_segment` with a running
`MarchState`, in both the float64 oracle and its GLSL twin — with the whole-ray
function delegating to it, so a piecewise march cannot drift from the whole-ray
one it is supposed to reproduce.

The frame state the volume needs is passed as a named struct rather than a
widened argument list. Widened positionally it is nine arguments, seven of them
`glm::dvec3` or `double`; a caller transposing `cam_right` and `cam_up` would
compile cleanly and render a volume rotated 90 degrees against the fragments
reading it.

## The sampler shift

The depth fetch needs a half-texel correction that the obvious inverse omits.
Froxel texel k stores the accumulation out to slice boundary k+1, but a Vulkan
sampler places texel k's centre at `(k + 0.5)/depth`. Reading the volume at
`sqrt(t / far)` therefore samples half a slice too far out at every distance,
over-applying the atmosphere across the whole frame. The mapping is
`sqrt(t/far) - 0.5/depth`, clamped, defined once with its derivation in comment.
Its near-end price is recorded rather than papered over: a fragment at zero
distance clamps to texel 0 and picks up the first slice's ~31 m of atmosphere, an
optical depth of about 1.3e-3.

## Beyond the volume

Past 32 km the volume runs out and an analytic path takes over, and the two must
meet without a visible seam. Transmittance uses Bruneton's point-to-point
identity — the quotient of two transmittances to a common exit point, each end
measured against its own local up. The ground-hit branch is load-bearing rather
than a corner case: both terms have to integrate to the same exit point for the
quotient to telescope to the segment between them, and for a descending ray that
exit lies behind the camera. The division's floor sits at 1.0e-12, seven orders
below the smallest reachable denominator, and a test asserts it never binds — the
branch always divides the shorter path's transmittance by the longer one's, so
the denominator is bounded below by the numerator.

Far in-scatter is a one-line forward to the sky pass's own evaluator, and the
test asserts exact per-channel equality rather than a tolerance. Convergence
between the terrain far field and the sky is a structural identity because the
two call the same function, not because a second march was tuned to resemble the
first.

The hand-off between the two runs over a 4 km band. Its tolerance is derived
rather than fitted: 3.4e-2 is twice the sum of two separately measured quadrature
self-consistency terms — 1.2971e-04 for the volume march and 1.6764e-02 for the
sky-view march — against a measured worst gap of 1.8914e-02, 1.80× headroom. The
sky-view march at its shipped 32 steps dominates the seam by two orders of
magnitude; the froxel volume is not what limits the hand-off. Both terms are
pinned separately, so a failure names which operator moved.

The composition branches on the blend weight instead of mixing unconditionally,
so an in-volume fragment pays two texture fetches and a far fragment three, and
only a fragment inside the band pays both paths. On terrain the result composes
as `L = L_surface * T_aerial + L_inscatter`, in the radiance domain before
tonemap. The aerial term is never a distance-keyed color, which is what
separates atmosphere from fog.

## The trap the GPU battery found

Everything above was pinned against a float64 oracle on the CPU. The GPU
readback battery — headless dispatch, whole-volume readback through one depth-32
copy, and a float64 twin of the shader's own `main()` over the identical column
grid — found a real defect in the shipped shader on its first run.

`ray_intersects_ground` collapses in float32 within about 0.5 m of the displaced
ground sphere and returns "shadowed" for every direction. The volume marches from
`lift_off_ground(view_height)`, which for a camera at or below the 10 m clearance
altitude is exactly the clearance sphere, so the first slice's samples sit inside
that dead band, the shadow term reads zero, and the direct-beam in-scatter is
silently deleted.

This is not news about float32. It is the failure mode the shared atmosphere
header's own banner derives in full, including its threshold:
`c = fl(r*r) - fl(bottom*bottom)` carries up to `2 * 0.5 ULP(4.06e13) = 4.2e6` of
its own error, which puts the collapse at heights below 0.5 m. Phase 66 closed it
for the sky pass's two *origin* tests with a 4 m occlusion lift. The volume's
*per-sample* occlusion tests were never covered by that fix, and Phase 67's
oracle pinning had no GPU battery that could see it. The banner called it a sprung
trap; it was sprung.

At a 1 m surface camera, sun at 60°, column (0, 15), green channel:

| | slice 1 | slice 2 | slice 16 | slice 32 |
|---|---|---|---|---|
| GPU | 1.26958e-5 | 1.09494e-4 | 8.52203e-3 | 2.45667e-2 |
| oracle | 3.23260e-5 | 1.29182e-4 | 8.54942e-3 | 2.46025e-2 |
| relative | −60.7% | −15.2% | −0.32% | −0.15% |

The absolute deficit is near-constant down the column, about 2.0e-5 growing to
3.6e-5 by slice 32: the error is acquired entirely in slice 1 and then carried by
the running accumulation. Slice 2's own increment matches the oracle to four
significant figures — 1.032e-6 against 1.033e-6 per metre — which localises the
defect to the first segment rather than to the fetch, the density profile or the
quadrature. Decomposing the oracle's slice-1 value into direct-beam and
multi-scatter halves closes the arithmetic: the GPU value is the full
multi-scatter term plus exactly one of the four direct-beam samples, to three
significant figures, on all three channels at two different columns. Three of the
four samples lost their shadow term.

An altitude sweep localises the transition at the clearance sphere and confirms
the banner's derived threshold from the other side: at 1 m and 10 m altitude the
slice-1 error is −41.6%; at 10.6 m, six-tenths of a metre higher, it is −0.18%.

A second family of failures at 12 m to 200 m altitude, 6.2e-2 to 8.7e-2 in bulk,
has the same root cause seen from the other direction — those cameras' descending
rays cross the same 0.5 m band on their way to the ground, and the worst froxels
all sit in the lower half of the frustum. The transmittance volume is untouched by
any of it, which is a prediction the data confirms: view-ray throughput is a
product of `exp(-sigma_e * dt)` from analytic density profiles and never calls the
occlusion test, which is why it locks cleanly at 2.07× headroom while its
in-scatter twin could not be locked at all.

## The origin lift, and the half it cannot reach

The fix that landed lifts the march's occlusion-test origin to the same 4 m the
sky pass uses, applied at all three sites of the CPU/GPU seam in one change.
`kGroundTestLiftM = 4.0` is the float64 mirror of the GLSL constant, bannered with
why it is not the existing radius offset — the offset is what float64 needs, four
metres is what float32 needs — and with the threshold chain that sizes it: above
0.17 m from the ULP alone, above 0.5 m once the rounding of `c` is carried, 4 m at
23× over that.

The origin half is measured dead. The witness channel — column (0, 15), green —
goes from `gpu 1.26958e-05 vs oracle 3.2326e-05`, −60.73%, to
`gpu 3.22461e-05 vs oracle 3.23038e-05`, −0.179%, and every non-descending
slice-1 column clears a 2% diagnostic bound with 8–14× headroom.

The other half does not close, and the measurement says why. The ground test
displaces the sphere's centre toward the sample, so a sample below 10 m altitude
sits inside that sphere and self-shadows in float64 as much as in float32. With
the origin at 10.001 m, every slice-1 sample on a descending ray was at or below
that height and both sides deleted the beam — they agreed by both being wrong.
With the origin at 14 m, samples between 10 m and 14 m are legitimately lit in
float64 while float32's discriminant still collapses within 0.5 m of the sphere,
so the two sides now disagree by the width of the band. Slice 1 reaches only
`32000 · (1/32)² = 31.25 m`, so at the surface rung a descending ray spends most
of it inside the marginal shell.

No origin lift clears this. A descending ray that reaches the ground crosses
every height between the origin and zero, so it crosses the marginal shell above
the clearance sphere by construction, at any lift; raising the lift only moves
which samples land in it. The residual is a property of the per-sample occlusion
test, not of where the march starts.

The exchange is stated as an exchange rather than as a win. The lift removes the
entire near-horizontal failure — 198 channels at up to 22.18× over the diagnostic
bound, down to zero at 0.10× — and introduces a descending-column failure, from
zero at 0.17× to 150 channels at up to 9.93×. Total over-bound 198 → 150, worst
utilisation 22.18× → 9.93×, worst signed error −33.07%: a real 2.2× improvement,
and not a clean one. It was landed rather than reverted because it regresses
nothing across 1,626 tests and is a 200× improvement on the columns it owns.

The root-cause fix — computing the discriminant in the cancellation-free
`(r − R)(r + R)` form — is one line and lives in the header that the sky pass, the
sky-view table, the multi-scatter table and the transmittance table all include.
Landing it moves the sky-view table's near-ground values, which is a surface
Phase 66 locked and Phase 69 re-opens. So it waits there, where it can retire both
origin-lift workarounds at once, and the regression probe that asserts every
column stays committed red in the default suite as the mechanical record of the
open defect: `worst tolerance utilisation 9.92628 at column (14, 25) channel 1`,
150 of 3,072 channels over bound. A red test naming a real, filed defect is a
deferral in enforcement form rather than a note in a document.

## The in-scatter bound

With the origin half closed, the in-scatter volume gets its own GPU pin across
all eight camera rungs from 1 m to 2,300 km, over the columns the deferral does
not own. The scope is a geometric predicate computed from camera state before any
texel is read: a column is excluded if and only if its view ray reaches the
ground inside the volume's own 32 km reach, through the same intersection routine
and distance clamp the reference march uses. Both halves are required non-empty at
every signal rung — 512 of 1,024 columns at the surface rungs, 412 of 1,024 at 10
km — so neither "exclude nothing" nor "exclude everything" can pass, and the
excluded half is diffed and printed at every rung rather than dropped.

The bound is derived from five named terms, not fitted:

| Term | Magnitude | Provenance |
|---|---|---|
| inherited multi-scatter, weighted by measured share | 5.98e-3 | 0.92 × 6.50e-3 |
| inherited transmittance at the fetch, weight bounded at 1 | 1.50e-3 | the transmittance tier's measured worst |
| inherited volume budget | 6.00e-4 | carried unmodified from the oracle pin |
| second store rounding | 4.88e-4 | the fp16 relative quantum |
| dead-band residual | 0.0 | proven absent over the pinned set |

That sums to a derived ceiling of 8.568e-3, locked at 1.0e-2 — a 1.17× round-up.
The first term is a narrowing rather than a weakening: the multi-scatter table's
locked tolerance of 5.0e-2 is attained at a texel where the sun sits 9.28° below
the horizon at 51.6 km, deep in the extinction tail, and the aerial volume
provably never samples there. Inheriting a bound from a domain you do not sample
imports an unrelated worst case, so the sub-domain figure the multi-scatter
banner publishes is what gets inherited, and a `static_assert` pins the result as
strictly tighter than the table it inherits from so it cannot later read as a
contradiction of the propagation ordering.

The fifth term is zero by construction rather than by omission: the lift puts the
march origin at least 4 m above the 0.5 m band, and an included column is by
definition one whose ray never reaches the ground inside 32 km, so it never
descends into the band. A census counts 0 of 65,536 and 0 of 78,336 march samples
in band, with minimum sample altitudes of 14.05 m and 96.6415 m against a band
ceiling of 10.5 m. A third assertion arm was expected for that term; two ship,
because a third would be slack with nothing to cover.

Worst measured relative over the bulk is 2.29846e-3 at the raking surface rung.
The derivation over-predicts by 3.7×, and the reason is recorded rather than
absorbed: the two inherited terms are bounded by their independent worsts, which
are not co-located. Headroom runs 4.29× to 6.12× per rung; the absolute arm is
what binds in the tail, at 1.15 to 1.53 fp16 subnormal quanta against the locked
4. The 4.29× worst rung is slacker than this file's other four tiers — 2.67×,
1.58×, 2.01×, 2.07× — and is recorded as such rather than tuned away.

Two of the five terms shipped unenforced, and the review that caught it is worth
repeating. `census_aerial_dead_band` and `measure_multi_scatter_share` computed
the right quantities on every run and wrote them only to standard output; no
assertion consumed either. The `static_assert` whose message claims the census
backs the dead-band term compares that constant to the literal that initialised
it 35 lines earlier, so it could not fire whatever the census found. The number
was never wrong — the measured share, 0.912476, sits under the 0.92 the
derivation multiplies, and the census really is zero — but nothing in the file
would have caught a regression at either term, leaving the aggregate bound's
headroom as the only backstop.

Both terms are enforced now. `CHECK(census.in_band == 0)` and
`CHECK(share.worst_bulk <= kAerialInScatterMultiScatterShare)` run inside the
pin, and the tautological assertion gained a companion that states its premise
as a relation between two constants instead of a constant against itself: the
march origin's floor at `kPlanetRadiusOffsetM + kGroundTestLiftM` against the
dead band's ceiling at `kPlanetRadiusOffsetM + kFloat32GroundTestDeadBandM`, 14 m
against 10.5 m. Shrinking the lift, or re-deriving the band wider than it, now
fails at compile time.

## The toggle and the flights

Aerial perspective gets a runtime toggle so the effect can be checked against its
own absence. The push-constant block gains a four-byte enable flag, taking it from
124 bytes to exactly 128 — Vulkan's guaranteed minimum for `maxPushConstantsSize`,
and now fully spent, which the block's own assertion message says in those words.

The gate is asymmetric on purpose. It reads `pc.aerial_enabled > 0.5 && !tint_on`,
so the LOD-tint diagnostic wins over the preference by construction rather than by
convention, and a closed gate *skips* the whole three-arm aerial term rather than
multiplying by its identity — the off state is bit-identical to the pre-phase
lighting expression, so the A/B is a control rather than an approximation of one.

Three things could only be checked by flying, because no automated test in this
repository drives window input or reads back a fragment stage: the altitude ladder
at three sun angles, the far branch beyond 32 km, and dispatch ordering across a
live multi-frame session with a moving camera. All three pass. The third carries
evidence rather than a verdict — 1,036 captured diagnostic lines across a
sustained flight with validation layers on and four toggle presses, with zero
synchronization hazards, zero validation errors and zero warnings, the only
non-empty lines being a driver skip notice and a platform banner. One observation
came back with the pass — the effect reads slightly soft — which is consistent
with 32 slices of depth resolution and is recorded as a tuning note against the
locked dimensions.

Both build configurations close at 1,629 of 1,630 and 1,620 of 1,621. The single
failure in each is the deliberately red probe.

## What's next

Phase 67.1 picks up the two deferred visuals once the mask and night-lights layers
exist and the tile format contract carries them: specular ocean, city lights on the
night side, and the coastline shading artifacts the mask also resolves.

*Built solo by Spoods Studios.*

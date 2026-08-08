# M1.1 Phase 53 — Telemetry & Debug HUD: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-22**. Flying it
> the next day (2026-07-23) surfaced control and UI defects the code-level locks
> could not see; the drift section at the end covers what 53.1–53.3 changed.

## Starting point

Phase 52 made the craft flyable inside the worker: attitude subcycles at
`kAttDt = 300/16384 s`, keyboard commands ride a tick-stamped ring, kill-rot
snaps ω to literal zero, warp propagates the tumble in closed form. None of it
reached a screen. The demo binary never populated `CraftConfig`, so the input
scaffold pushed commands into a ring no craft drained, and the renderer drew only
disks, a legacy body trail, a conic and a two-line HUD (`T+` and `dE/E`).

Phase 53 makes the craft visible: publish enough state for a readout, including
the two instants a before/after orbit comparison needs; turn it into lines on
screen; put a craft in the demo binary. Two structural problems sat underneath.
The mass-dominance scan ranks by mass, so for this body table it returns the
Sun. The Sun outweighs Earth 333,000-fold; at a 400 km altitude Earth still
out-pulls it 1,463-fold. Keyed to the Sun, the orbit block reports a
heliocentric conic near 1 AU, and a burn that reshapes a 92-minute Earth orbit
never reaches the digits it prints. And a floating-origin shift moves every
published position by a common delta, while the trail is drawn in float32.

## The burn-boundary latch

"Thrust changed the orbit" needs two orbits: one from just before ignition, one
from just after cutoff. Sampling those render-side loses them, because a burn
shorter than the publish interval never gets a "before" frame. The worker latches
them itself, on the burn-active edges:

```cpp
if (craft_burning && !craft_burn_prev_) {
    craft_latch_r_ = craft_prev_r_;
    craft_latch_v_ = craft_prev_v_;
    craft_latch_ref_r_ = craft_prev_ref_r_;
    craft_latch_ref_v_ = craft_prev_ref_v_;
    craft_latch_valid_ = true;
    craft_after_valid_ = false;   // never pair this burn's before with the last burn's after
}
// the falling edge copies the same four into craft_after_* and sets craft_after_valid_
craft_burn_prev_ = craft_burning;
```

The latch takes `craft_prev_*` — the **previous** publish, held as a one-publish
shadow. The publish that first reports `burning == true` already carries a full
step of Δv, about 316 m/s for the shipped craft, so latching the current state
would bake a large fraction of the burn into the "before" reading; the shadow
puts "before" at the ignition instant and "after" at the cutoff instant exactly.

Each latch carries a **reference half**: Earth's own position and velocity from
the same publish, which is what makes an Earth-keyed difference mean anything.
Both shadows advance together, from one read of the published span, in the block
immediately after the edge checks. Refreshing the reference shadow anywhere else
skews the pair by one step — about 8,900 km of Earth motion per 300 s step
against a 6,778 km orbit radius, which destroys the readout.

27 new trivially-copyable fields ride all four publish hops — 14 craft-latch
fields, 12 reference doubles, one warp hold-to-exit counter — all declared
outside the `if (has_craft_)` block, so a craft-absent run publishes structural
zeros.

## Earth, hardcoded — and a loud stop for the case it cannot cover

The reference body is slot 1, defined once as
`inline constexpr std::size_t kCraftHudReferenceSlot = 1;`, in `constants.hpp`
rather than beside the worker's other craft constants — the render-tier kernel
has to alias it without including the worker's public header, and a restated
literal there compiles fine, then keys the publish site and the readout to
different bodies the day either is retuned.

That fixes the display. It does not fix the warp conic, which re-keys about the
globally most massive body every warp step inside gated Phase 51 machinery, so a
craft in Earth orbit gets a conic drawn about the Sun. Reopening that machinery
was out of scope, so
the path is excluded behind a guard: a craft opts in by declaring the body its
conic must key to (`std::optional<std::size_t> warp_primary_slot`), and an empty
optional makes the check a comparison that cannot fire, which keeps every Phase
51 and 52 warp fixture bit-identical. A declaration that disagrees with the scan
throws, after `select_dominant` and strictly before `g2b`, `kepler_step` and the
craft's state slot, so no wrong-primary value reaches state or the snapshot. The
message names both slots, the dominant body's μ, the sim time, and the machinery
that would actually fix it: per-craft local-dominant conic selection, in M1.2.

## The HUD kernel

Every number the HUD shows comes out of `engine/src/craft_hud.cpp`, which names
no worker header, no snapshot type, no Vulkan type, no stream, no clock and no
frame counter. Inputs arrive as a plain `CraftHudState`, so every function is
testable from a literal, and the unit stays free of `<cmath>` via the identity
`(v == v) && ((v - v) == 0.0)`.

TWR is `thrust_max_n / (m_kg * kCraftHudTwrRefGravity)`, the reference gravity
being conventional standard gravity, the same `g` the engine's `isp_seconds`
already uses; local g would need a gravity evaluation inside a pure formatting
kernel and would drift with altitude. Δv-remaining is `v_e * det_log(m/m_dry)`,
the same transcendental the locked Phase 49 thrust kernel uses — so the figure is
bit-identical to the Δv a full burn would deliver, and machine-independent, so a
test pins it exactly where a libm `log` would have drifted by version. Outside
`det_log`'s window the NaN propagates unclamped and renders as a placeholder.

### Fixed-width cells

font8x8 is a fixed-width atlas, so a constant field width is what stops digits
jittering horizontally between frames. Each cell helper verifies its own:

```cpp
[[nodiscard]] std::string fixed_num(const char* spec, std::size_t width, double v) {
    if (!is_finite_value(v)) {
        return dashes(width);
    }
    char buf[64];
    const int n = std::snprintf(buf, sizeof buf, spec, v);
    if (n < 0 || static_cast<std::size_t>(n) != width) {
        return dashes(width);
    }
    return std::string{buf, static_cast<std::size_t>(n)};
}
```

A hyperbolic orbit, a NaN TWR, a negative mass and a 987-tonne stack in GEO all
render at byte-identical line lengths to a 12 kg probe in LEO, asserted per line
index across four orders of magnitude in both mass and semi-major axis.

The flight block is 8 lines, the orbit block 7, the status block 2. Velocity
names its frame on the line (`m/s Earth-rel`) and Δv-remaining names its
convention (`m/s (vac, all fuel)`); an unlabelled speed tape is the trap where
two different readings look identical. The orbit block declares one convention in
its header, `ORBIT (Earth, alt)`, with apoapsis, periapsis *and* semi-major axis
rendered as altitudes — the first implementation put a 6,960 km semi-major radius
beneath two 400–765 km altitudes, exactly the trap that header prevents. Its
second column is a signed delta against the pre-burn latch, since a numeric pair
doubles the column budget; the absolutes ride the stderr line in full. The status
line always carries the time scale as ASCII `x`, and its second line reports
inert input during warp with a ten-cell hold-to-exit bar over
`kWarpExitHoldTicks`.

### The stderr line

`format_craft_line` returns a `[craft]` line — a wholly separate key from the
locked `[telemetry]` line, same `key=value` convention so one tool parses both.
26 fields in constant order and constant count, raw SI radii rather than
altitudes so the machine-parsed proof carries no body-shape assumption, and
explicit integer validity flags rather than omitted fields, so a grep can never
be defeated by a field that vanished when a state went invalid. It is assembled
by appending `snprintf` chunks to a `std::string` — one oversized fixed buffer
would truncate silently at exactly the length where the element fields live — and
the trailing `post_period=` field is asserted present. Emission runs on
`kCraftLineFrameCadence = 30`, independent of the telemetry divisor.

## The adapter, and the pairing guard

`craft_hud_source.cpp` is the one place the publish surface and the pure kernel
meet. It copies the flight fields, takes the Earth-relative speed through
`det_sqrt` (keeping the render tier's libm surface empty), computes the blocks'
NDC anchors, and builds three orbits: live, pre-burn, post-burn. The latched two
go through `reference_pair_available`, an explicit all-zero test on the six
reference components, which the first implementation did not have — it leaned on
hyperbolic rejection instead, since an SSB-scale craft latch differenced against
a zero reference extracts as unbound. That is a property of the magnitudes, not
of the field: any latch small enough to be sub-escape against μ_Earth differences
against a zero reference into a perfectly bound, perfectly plausible, completely
wrong orbit. An all-zero reference now reads as "pairing unavailable" instead.

Those anchors matter because a 48-character line spans 1.2 NDC on a 1280-wide
window, and two full-width blocks do not fit in 1.9 NDC of usable width. The
orbit block right-aligns by its longest line and clamps to the flight block's
right edge plus a two-cell gutter, so a narrow window overflows rather than
overlaps.

## The font could not spell

The kernel's output needs `#%()[],|` and about thirty letters
`font8x8_basic.hpp` did not have; it covered 26 codepoints (digits, `ADEIOPRTe`,
`+-:./=` and space), and every uncovered byte rendered as the `.notdef` tofu box.
`glyph_for` became a 95-entry `constexpr` table covering 0x20–0x7E, which moves
the out-of-bounds question from "impossible" (an unreachable `switch` default) to
"depends on the promotion" — so the byte is promoted to `unsigned char` first,
and the totality case sweeps all 256 values.

The glyph data comes from Daniel Hepper's public-domain font8x8 collection, and
every new glyph is imported as `source << 1`: the file's existing glyphs are
drawn from a column-1 origin where the raw source draws at column 0, and an
unshifted import reads as per-letter jitter inside a single word.

The vertex budget became `kMaxHudLines(20) * kMaxHudCharsPerLine(48) *
kMaxLitPixelsPerGlyph(64) * kVertsPerGlyphPixel(6)` = 368,640, `static_assert`ed
to stay that product — 16.9 MiB of persistently-mapped memory across both frames
in flight. `kMaxLitPixelsPerGlyph` derives from the font's glyph geometry and is
the structural 64 (the whole cell lit), not the 30 the densest current glyph
uses, because a measured bound silently becomes an undersize the day a denser
glyph lands. `draw()`'s overflow guard truncates rather than crashes, so an
undersized budget looked like a missing bottom row and nothing else; it now emits
one latched stderr line naming the budget, the vertex count and the truncated
text. `orbit_demo.cpp`, the only translation unit that sees both tiers, asserts
the fit at compile time, so line 21 fails the build. 19 of 20 lines are used.

## The trail a floating-origin shift cannot touch

The craft trail's authoritative store is float64 and reference-relative: each
sample is `craft_r - ref_r`, both operands from the *same* published snapshot. An
origin shift translates every published position by one common delta, and a
difference of two same-snapshot positions is identically invariant under it —
there is no correction term to get wrong.

The float32 GPU buffer is rebuilt every frame by the store's single narrowing
site — `regenerate(offset_m, out)` walks the ring newest-first writing
`coords::to_render(sample_at(i) + offset_m)`, fed this frame's reference offset —
and there is no API through which a stored vertex can be patched. Patching
already-narrowed vertices with a shift delta accumulates uncorrelated rounding
that random-walks with shift count, so old segments visibly swim against new
ones. Here the error is one narrowing however many shifts have happened, and the
test drives 100 real `set_origin` calls to prove it: the worst per-component
error after the 100th shift is `to_bits`-identical to the worst after the first,
at **0.496338 m** against a ceiling of 0.5 m. The same trail narrowed
Sun-relative loses **8163.28 m** where the Earth-relative store loses
**0.249177 m**, which is what makes the frame choice a requirement.

Capacity is 2000 samples with a 30 km minimum-segment gate on the float64 store,
so arc coverage is 6.0e7 m ≈ 1.41 orbits *independent of time scale* — the gate
enforces minimum spacing, not a minimum interval — in 48 KB, comparing squared
lengths so the per-frame path never takes a square root. The only condition that
clears it is the presence flag going false: not a warp transition, not a focus
change, not an origin shift.

The conic parametrisation moved into the same kernel with its operation order
preserved verbatim, and the legacy single-body conic now delegates to it, so the
two cannot diverge; `kCameraFitMargin = 1.2` got one home for the same reason.
The attitude triad is three disjoint two-vertex segments oriented through the
locked Phase 51 `rotate_body_to_inertial` seam — disjoint because a single strip
through all three tips would zigzag between the axes — with its axis length
derived from pixels each frame so it stays a constant screen size at any zoom.

## Putting a craft in the demo

`main.cpp` seeds a 400 km circular orbit at 51.6° inclination, every figure
computed from `constants.hpp` at startup rather than transcribed, so a constant
revision moves the seed instead of desynchronising it from the tests that share
those constants. The inclination is deliberate: an exactly equatorial circular
orbit leaves both RAAN and argument of periapsis undefined, so the extractor's
general path would never be exercised. The propulsion numbers are picked so the
readouts are checkable by hand — `v_e = 3000 m/s` (Isp ≈ 306 s), 3000 N against a
1000 kg wet mass for exactly 3.000 m/s² and exactly 1 kg/s mass flow, 400 kg dry
for 3000·ln(2.5) = 2748.9 m/s of total Δv. The binary reported
`twr=3.059149e-01`, `dvrem=2.748872e+03`, `a=6.776845e+06`, `e=2.679106e-03`,
`period=5.552036e+03` and `elem_valid=1` — that last flag being direct proof the
Earth-keyed extraction resolved a bound orbit rather than the Sun-keyed nonsense
a mis-keyed craft would produce.

The attitude quaternion puts the body +X thrust axis on prograde, so the first
throttle press is already a prograde burn, and it normalises explicitly because
config validation re-derives the norm through `det_sqrt` and rejects anything
outside an 8-ulp band. Initial ω is zero, and the inertia tensor carries three
distinct principal moments so free precession is non-degenerate.

The whole craft surface hides behind `inline constexpr bool kDemoSeedCraft =
true;`, with four `if constexpr` sites gating the seed rows, the worker config,
the focus keybind and the HUD setter — which makes "the new code is inert without
a craft" an executable measurement rather than an argument. Against the last
pre-phase build: zero new stderr line skeletons, zero craft lines, and the new
`focus craft` string absent from the craft-absent binary's string table entirely.

`C` focuses the craft and fits the camera to its **current** orbit, re-deriving
the apoapsis from the live snapshot on every press. At this seed a 10 s
full-throttle burn raises apoapsis by ~106 km, so fitting to the launch-time seed
radius would have framed the pre-burn orbit forever. Scroll-wheel zoom is
`kWheelZoomPerNotch = 1.15`, about a fifth of a stepped `]` press and under the
same clamp. Full suite at close: **882/882 Release, 878/878 Debug**, with the
deterministic force kernel byte-untouched, the locked Kepler extractor called
read-only, and the `[telemetry]` line format unedited.

## Where it is now

All of that passed its automatic checks and its code-level locks. Flying it on
2026-07-23 failed anyway, and the root cause was one line: the demo booted at
256× time scale, below the warp threshold, so the ordinary integrator ran 256×
real time. Throttle drained 600 kg of fuel to 300 kg in what looked like an
instant; the ramp keys completed in about one frame and read as pops; a large
burn decayed periapsis to −2284 km; the trail sampled once per frame rendered as
a straight-line polygon; the triad alone did not show which way the craft faced;
the camera snapped on refit — no kernel at fault. Three decimal phases followed.

- **53.1 — control policy and attitude indicator.** The first attempt gated
  throttle input to 1× and blocked time-scale increases while lit. Flying that
  invalidated the model: `step_dt = 300 s` is load-bearing (Phase 52's attitude
  subcycle is exactly `300/kAttDt = 16384`), so at 1× the accumulator needs 300
  real seconds per step, the sim freezes at launch, no craft-present snapshot is
  ever published, and the whole HUD vanishes. The gate came back out and
  `time_scale_init` settled at **128.0**, live and below the warp threshold; fine
  throttle control waits on craft-orbital subcycling in M1.2. The attitude work
  survived: `craft_prograde_marker` writes one disjoint two-vertex segment along
  the craft's Earth-relative velocity, drawn amber, at a fixed length so it
  encodes direction rather than speed. The body +X axis now draws at full
  brightness while +Y and +Z draw dimmed, so the nose is unambiguous.
- **53.2 — trail interpolation.** `craft_trail_spline` subdivides each stored
  chord into `kCraftTrailSplineSubdiv = 16` sub-points along a centripetal
  Catmull-Rom spline (α = 0.5, clamped phantom endpoints, Barry-Goldman pyramidal
  blend with a zero-interval guard). Centripetal rather than uniform
  parametrisation avoids the cusps a uniform spline forms at 300 s chord spacing,
  and Catmull-Rom interpolates its knots, so every stored sample passes through
  exactly and the curve still bends faithfully across a burn boundary. Output is
  capped by dropping the *oldest* source points. Draw-time only — the float64
  store and its invariance locks are untouched.
- **53.3 — camera easing.** The zoom target (`zoom_factor_`) split from the eased
  render state (`zoom_current_`), and the focus recenter became a frame-invariant
  residual: on a pending focus change both slot positions are read from *one*
  snapshot, so the captured offset is a single-frame delta an origin shift cannot
  perturb. The residual is **folded**, not overwritten, so a focus change
  mid-ease stays continuous. `exp_approach` eases the scalar zoom and `exp_decay`
  the float64 residual (which spans ~1 AU on a Sun→Earth recentre, where float
  would shed precision), both with k clamped to [0, 1] and an exact fixed point
  at the target. `kCameraEaseFactor = 0.18` settles a step to ~90% in 12 frames.

The full re-fly at the end of 53.3 confirmed all three of Phase 53's original
criteria visually — live readouts, thrust visibly growing the orbit, a clean
mid-burn origin shift — plus the Phase 52 rotation, kill-rot and RCS translation
carry-over that had never had a renderable craft to be checked against. Suite at
that point: **903/903** in both lanes. One cosmetic item stayed open: the
prograde marker draws true LEO prograde, tangent to the 92-minute orbit, so at
the wide default zoom it can point roughly sunward. The direction is correct;
scaling the marker at extreme zoom-out is polish, not debt.

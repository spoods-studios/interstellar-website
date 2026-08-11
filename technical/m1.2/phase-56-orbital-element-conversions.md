# M1.2 Phase 56 — Orbital Element Conversions: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-31**. M1.2's
> gate-fix chain later reworked large parts of this file; the closing section
> traces those changes as they stand today.

## Starting point

The engine already had one half of the Kepler conversion: `extract_kepler_elements`
turned a state vector `{r, v}` plus `μ` into the six classical elements. Nothing
went the other way. A caller with `{a, e, i, Ω, ω, ν}` — a maneuver node's target
orbit, say — had no path back to a state vector, and the extractor's own singular
cases had never been checked against an inverse, because no inverse existed to
check them against.

The extractor's circular and equatorial branches returned flat zeroes for the
undefined angles: a circular orbit's `ω` and `ν` both came back `0`, regardless
of where on the circle the body actually was. That's a legitimate convention for
`ω` — a circular orbit genuinely has no periapsis to measure from — but for `ν`
it discards real information: the orbit's shape survives extraction, its position
does not. Nothing downstream noticed, because nothing downstream reconstructed a
position from the scalar elements. Building `state_from_elements` changes that:
the round trip `state_from_elements(extract_kepler_elements(s, μ), μ) == s` is now
a real requirement, and it cannot hold while `ν` is thrown away.

## What was built

### The widened struct

`KeplerElements` gained one field, appended last:

```cpp
// Semi-latus rectum h²/μ (m) — ALWAYS finite, including the parabolic edge
// e = 1 where a diverges to ±Inf and a(1−e²) evaluates to NaN. This is the
// shape parameter state_from_elements consumes (never a) …
double p;
```

`state_from_elements` needed a shape parameter that survives every regime,
including exactly parabolic. `a` fails that test by construction — at `e = 1`
the semi-major axis diverges, so `a(1 − e²)` evaluates to `NaN` right at the
boundary the conversion has to stay usable through. `p = h²/μ` has no such
edge. Appending rather than reordering mattered here: a tree-wide check found
`KeplerElements` is only ever built by value-init plus named-member assignment,
or by copy — never positional aggregate initialization — so appending a field
cannot silently shift what an existing call site reads.

### state_from_elements

The forward leg is Vallado's Algorithm 10 (COE2RV): build the perifocal
position and velocity from the semi-latus rectum, then rotate into the
inertial frame by `Rot3(−Ω)·Rot1(−i)·Rot3(−ω)`.

```cpp
State state_from_elements(const KeplerElements& elem, double mu) noexcept {
    const bool inputs_ok =
        std::isfinite(elem.p) && std::isfinite(elem.e) && std::isfinite(elem.i) &&
        std::isfinite(elem.Omega) && std::isfinite(elem.omega) && std::isfinite(elem.nu) &&
        std::isfinite(mu) && mu > 0.0 && elem.p > 0.0;
    if (!inputs_ok) {
        constexpr double kNaN = std::numeric_limits<double>::quiet_NaN();
        return State{Vec3f64{kNaN, kNaN, kNaN}, Vec3f64{kNaN, kNaN, kNaN}};
    }

    double s_nu = 0.0, c_nu = 0.0;
    det_sin_cos(elem.nu, s_nu, c_nu);
    const double r_mag = elem.p / (1.0 + elem.e * c_nu);
    const double r_pf_x = r_mag * c_nu;
    const double r_pf_y = r_mag * s_nu;

    const double sqrt_mu_over_p = det_sqrt(mu / elem.p);
    const double v_pf_x = -sqrt_mu_over_p * s_nu;
    const double v_pf_y = sqrt_mu_over_p * (elem.e + c_nu);
    // … Rot3(−Ω)·Rot1(−i)·Rot3(−ω) applied to (r_pf, v_pf) below
}
```

Every angle arriving here is already an input, so the only transcendentals on
the path are `det_sin_cos` and `det_sqrt` — no inverse trig anywhere, and
nothing regime-dependent: elliptic, parabolic, and hyperbolic orbits all flow
through the same six lines. The regime-dependent part — which angle carries
which substituted quantity in a singular case — happens upstream, in the
extractor. By the time an angle reaches `state_from_elements` it's just an
angle. A nonsensical input (non-finite element, `μ ≤ 0`, `p ≤ 0`) yields an
all-quiet-NaN state, mirroring the universal-variable propagator's existing
non-finite contract. The guard runs before any arithmetic, so garbage input
cannot reach the perifocal build and come out looking like a real orbit.

### Hardening the extractor's singular cases

The circular and equatorial branches were rewritten against Vallado's own
substitution table — an undefined angle gets the well-defined quantity that
takes its place, never a placeholder:

| Regime | Emitted | Vallado name |
|--------|---------|--------------|
| circular inclined | `ν := u`, `det_atan2(r·(ĥ×N̂), r·N̂)` | argument of latitude (ArgLat) |
| circular equatorial | `ν := λ_true`, `det_atan2(r.y, r.x)` | true longitude (TrueLon) |
| elliptical equatorial | `ω := ϖ`, `det_atan2(e_vec.y, e_vec.x)` | longitude of periapsis (LonPer) |

Both substitutions are written `det_atan2`-first from the start, never adapted
from the neighboring `acos`-plus-quadrant-fix pattern the extractor's
non-singular branches already used — that pattern loses precision exactly at
the domain edges its own round-off guard already showed it was hitting, and
there was no reason to import that into new code.

A retrograde orbit surfaced a bug the plan hadn't accounted for. At
`i = π` the perifocal-to-inertial rotation traverses the inertial xy-plane in
the opposite sense, so an angle measured counter-clockwise from `x̂` is not the
angle `state_from_elements` will feed back through the rotation — the two
sides of the round trip disagree by a sign for every retrograde equatorial
orbit with a non-zero angle. The regime is reachable by entirely ordinary
states (`r` along `x̂`, `v` along `−ŷ`), not a pathological corner. The fix is
Vallado's own correction, added to both equatorial substitutions:

```cpp
double retrograde_fix(double angle, double inclination) noexcept {
    return (inclination > 0.5 * std::numbers::pi) ? wrap_two_pi(kTwoPi - angle) : angle;
}
```

The inclined argument-of-latitude substitution needs no such fix — it's
measured from a real node line, which stays well-defined at any inclination in
`(0, π)` — matching Vallado, which omits the correction there too. Testing the
retrograde regime took a specific construction: building a state directly at
`i = π` doesn't work, because `det_sin_cos(π)` leaves `sin ≈ 1.22e-16` of
residual, four orders above the equatorial dispatch threshold, so the forward
path silently takes the non-singular branch. The tests instead reflect a
prograde equatorial state through the x-axis, which flips `h_z`'s sign while
keeping `h` exactly along `±z̄`.

## The test battery

`test_kepler_coe2rv.cpp` landed in two passes, 15 cases total, 440,207
assertions:

**Published fixtures.** A Curtis textbook case (`r = [1000, 5000, 7000] km`,
`v = [3, 4, 5] km/s` against `μ = 398600 km³/s²`) checks the extractor leg, the
forward leg, and a machine-precision round trip, each with its own tolerance
derived from the fixture's printed rounding rather than picked by hand — the
extractor pin allows half a printed-digit step (`h` to 3 decimals →
`5.0e2 m²/s`, angles to 2 decimal degrees → `8.727e-5` rad); the forward-leg
bound propagates that rounding through the conic denominator's amplification
at this fixture's true anomaly (`1 + e·cos ν = 0.1116`, an 8.4× amplifier).
A second published case (Vallado's Example 2-5) had no independently
verifiable printed output online, so its expected state was derived in-phase
by pushing the input tuple through `state_from_elements` and cross-validating
by extracting it back — the recovered elements reproduce the inputs to
3.33e-16 relative, the float64 noise floor. The test comment names this
explicitly as a regression witness at a second high-inclination,
high-eccentricity point: it catches future drift in the conversion pair,
and it is not an external-oracle check on either function's correctness.

**Parabolic and hyperbolic points.** A fixed `p = 1.2e7 m` swept across
`e ∈ {1 − 1e-6, 1, 1 + 1e-6}` checks finiteness, full element round trip, and
state closure — `a` and `period` are deliberately left unasserted, since `a`
diverges at exactly `e = 1` by construction. A hyperbolic case (`e = 1.5`,
`p = 1.25e7 m`) checks both round-trip directions.

**Per-regime property suites.** Five PCG-seeded generators — elliptic,
hyperbolic, circular-inclined, equatorial-elliptical, circular-equatorial —
at 10,000 samples each, asserting element-space closure (with angle
differences wrapped across the 0/2π seam), exact-zero pins on the
substituted-out slots, and state-space closure via a second forward pass.
Every bound in the file carries a written theory-versus-worst-observed
derivation rather than a picked constant; the closest gap between a theoretical
estimate and what was actually measured was 2.8×, for the elliptic shape bound.

**Boundary sweeps.** Direct sweeps across the eccentricity-dispatch and
inclination-dispatch thresholds, checking that state closes on both sides of
each singular-branch boundary.

One measurement fell out of the calibration pass that wasn't originally the
point of it: the circular-equatorial regime's residuals sit two full orders
below every other regime — `2.66e-15` rad against roughly `1e-12` elsewhere.
Both of its substituted angles route through `det_atan2`; every other regime
still passes through the extractor's `acos`-based legs for at least one angle.
That gap is the atan2-first argument for the new code, measured rather than
asserted.

## The circular-orbit lock, recalibrated

Exactly one existing math-locked test case needed touching: a circular-orbit
fixture whose two literal assertions — `elem.omega == 0.0` and
`elem.nu == 0.0` — predate this phase. Running it against the hardened
extractor confirmed empirically, not assumed, that neither literal moved: the
fixture places `r` exactly along the node line, so the argument of latitude the
new substitution computes evaluates to exactly zero, landing on the same
literal the old placeholder used. What changed is what the assertion *means* —
from "the extractor discards this circular orbit's position" to "this
orbit's argument of latitude happens to be zero" — which is a strengthening of
the case's semantic content even though its numbers are byte-identical.

## Why it was built this way

- **`p`, never `a`, as the shape parameter.** The parabolic edge is where a
  semi-major-axis-based build would fail exactly at the boundary the
  conversion is supposed to stay usable through. `p = h²/μ` has no such
  singularity, so building on it makes the same six lines cover elliptic,
  parabolic, and hyperbolic orbits without a regime branch in the forward
  function itself.
- **`det_atan2` first, not `acos` adapted.** The extractor's existing
  non-singular branches already showed where the `acos`-plus-quadrant-fix
  pattern loses precision: right at the ±1 domain edge its own round-off guard
  exists to catch. Writing the new substitutions against that same pattern
  would have imported a known weakness into new code for no reason — there was
  no cost to writing them atan2-first from day one.
- **Retrograde as its own correction, not folded into the general form.** The
  fix applies to exactly the two substitutions measured from the fixed
  inertial `x̂` axis. The general (non-singular) angle legs and the inclined
  argument-of-latitude substitution are built from the orbit's own node line
  or angular-momentum direction, which already carries the sense of motion —
  mirroring those would have broken every ordinary retrograde orbit to fix a
  problem that only exists at the equatorial edge.
- **Regression witness, not oracle, where no independent source exists.** The
  Vallado 2-5 golden values are derived from the implementation under test,
  cross-checked by extracting them back. The test comment names them a
  regression witness that catches future drift in the conversion pair, and
  states plainly that they prove nothing about the implementation's
  correctness on their own.

## Where it is now

M1.2's gate-fix chain reworked this file substantially after the phase
closed. The extractor's `acos`-based legs — inclination, RAAN, and the general
(non-singular) forms of argument of periapsis and true anomaly — were all
reconditioned onto `det_atan2`, the same posture this phase had already given
the singular-case substitutions. Inclination is now `atan2(|N|, h_z)`, where
`|N| = |ẑ × h| = √(h_x² + h_y²)` is a quantity the function already computes,
so the two-argument form costs no extra square root. The old `acos(h_z/|h|)`
form rounded its argument to exactly `±1` for any inclination below
`√(2·eps) ≈ 2.1e-8` rad, silently discarding the orbit's entire out-of-plane
component below that threshold — a defect this phase's own calibration had
measured and documented but left unfixed, since the phase's stated boundary
was leaving the non-singular branches untouched. RAAN, the general argument of
periapsis, and the general true anomaly all dropped their `acos`-plus-clamp-
plus-sign-test pattern the same way, each replaced by an `atan2` over an
in-plane basis built from vectors the function already had on hand. The
retrograde correction still applies to exactly the two equatorial
substitutions and nowhere else, unchanged from how this phase wrote it.

The equatorial-dispatch threshold comparison was also corrected to compare
dimensionless quantities. It had been tested against the node line's raw
magnitude, `|N| = |h|·sin i`, which carries units of m²/s and scales with the
orbit's angular momentum — at a low-Earth-orbit scale the equatorial branch
needed an inclination below roughly `1.7e-21` rad to fire, twelve orders
tighter than the threshold's own comment claimed. The fix computes
`sin i = |N| / |h|` once and dispatches every equatorial-branch decision off
that single dimensionless value.

`state_from_elements`'s guard ladder grew two more input rungs and gained an
output-side check it didn't have before. A negative eccentricity had passed
every existing guard, flowed through the conic and perifocal build, and
returned a finite, plausible, mirrored orbit instead of being rejected; it's
now caught directly (`elem.e >= 0.0`). A very large eccentricity against a
small semi-latus rectum could overflow `μ/p` past the representable double
range before it ever reached the square root, which is now checked explicitly.
Both angular-domain rungs were added too — the function's only transcendental,
`det_sin_cos`, returns NaN above roughly `201.06` rad, so an accumulated,
unwrapped angle now gets rejected by name instead of silently falling through
to the same all-NaN result it already produced. Most significantly, the
function gained an output-side finiteness check: the arithmetic between input
and output can introduce non-finiteness the input side never showed — an
enormous eccentricity against a small `p` can overflow the perifocal velocity
while the conic denominator keeps the position finite, producing a half-valid
state that violates the header's own all-NaN-or-fully-valid promise. The
guard ladder now rejects on the output side too, closing that gap.

Smaller fixes landed alongside these: `KeplerElements`'s nine scalar members
now each carry a default member initializer, so a bare `KeplerElements elem;`
can no longer hand a caller nine indeterminate doubles that happen to pass the
finiteness gate; the semi-latus rectum is now computed directly from
`h_vec.length_squared() / mu` rather than taking the angular-momentum
magnitude's square root and squaring it straight back, removing two
unnecessary roundings from a value that sits directly on the round-trip path;
the semi-major-axis sign at exactly zero specific energy now derives from
eccentricity rather than defaulting to positive infinity, which had been
telling every consumer that a parabola is bound; and a non-finite eccentricity
now produces a NaN period instead of the same `+Inf` a genuinely hyperbolic
orbit reports, so a fully invalid state no longer looks like a defined answer
for an undefined orbit.

The property-suite tolerances were re-derived afterward at a million samples
per regime rather than the ten thousand this phase locked against, and the
theory model simplified along with the extractor. The previous bound was
built from `acos`'s diverging derivative and a sample-count-dependent
closest-approach argument, a mechanism that stops applying once every angle
routes through `det_atan2`, which has no domain edge for that argument to
approach. The new model is a plain float64-epsilon-times-conditioning estimate
with no dependence on how many samples were drawn. Four of the five regimes'
angle and state bounds tightened by two orders of magnitude or more under the
recalibration; the two regimes whose bounds held steady are the two that
sample eccentricity down to 0.01, where the residual is dominated by
eccentricity-vector conditioning that the atan2 rework never touched. No bound
moved in the loosening direction.

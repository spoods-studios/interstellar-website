# M0.2 Phase 8 — Layer Conversions: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-04-22**; a
> drift section at the end tracks what changed since and why.

## Starting point

Phase 8 adds `coordinates/conversions.hpp`: four free functions that
convert between the Phase 7 types. Since the types themselves don't
interconvert, these functions are the only code that compiles a layer
crossing.

```cpp
to_relative(Vec3i64 pos, Vec3i64 origin)        -> Vec3f64  // storage -> physics
to_camera_relative(Vec3i64 pos, Vec3i64 camera) -> Vec3f32  // storage -> rendering
to_absolute(Vec3f64 relative, Vec3i64 origin)   -> Vec3i64  // physics -> storage
to_render(Vec3f64 relative)                     -> Vec3f32  // physics -> rendering
```

## What was built

### Subtract-before-convert — the pattern the phase exists to enforce

```cpp
[[nodiscard]] inline Vec3f64 to_relative(Vec3i64 pos, Vec3i64 origin) {
    Vec3i64 delta = pos - origin;              // subtract in int64: EXACT
    return Vec3f64{
        static_cast<double>(delta.x) * mm_to_meters,
        ...
```

The order of those two lines is the core of the phase. Two ways to
compute "position relative to origin":

- **Subtract first** (int64 − int64), then cast the small delta to double.
  The subtraction is exact; the cast of a small number is exact or
  near-exact.
- **Convert first** (int64 → double), then subtract two huge doubles.
  Both conversions round — float64 has 53 mantissa bits, int64 has 63 —
  and subtracting two nearly-equal rounded numbers leaves mostly rounding
  error. This is catastrophic cancellation.

The test suite proves it rather than asserting it: two positions at
2⁵⁴ mm with a 3 mm delta. At 2⁵⁴, float64's ULP is 4 mm — convert-first
rounds both positions to a 4 mm grid and the 3 mm delta vanishes;
subtract-first returns exactly 3 mm. The wrong order doesn't fail loudly
somewhere far away — it returns plausible nearby garbage, which is why the
correct order is baked into the only functions allowed to cross the
boundary.

### `to_camera_relative` — the 4 km contract, checked

```cpp
Vec3i64 delta = pos - camera;
assert(std::abs(delta.x) < 4'000'000 && ...
    && "Camera-relative delta exceeds float32 safe range (4km)");
```

Phase 7's research set the rule: float32 holds sub-millimeter precision
only within ~4 km of the origin. This function is where the rule becomes
executable — a debug `assert` at 4,000,000 mm per axis. Callers that
pass a far-away object without first moving the camera origin get an
immediate diagnostic instead of silent jitter on screen.

### `to_absolute` — closing the loop

```cpp
double x_mm = relative.x * meters_to_mm;
auto ix = static_cast<int64_t>(std::llround(x_mm));
return origin + Vec3i64{ix, iy, iz};
```

Physics results have to come back to storage: scale meters to mm, round to
the nearest integer, add the origin. The round-trip contract: for any
position within float64's exact-integer range (2⁵³),
`to_absolute(to_relative(pos, origin), origin) == pos`, bit-exact. The
tests exercise it out to 1 AU. `std::llround` was chosen for the rounding —
a decision reversed later (see drift).

### Scale constants, not magic numbers

```cpp
inline constexpr double mm_to_meters = 1.0 / 1000.0;
inline constexpr double meters_to_mm = 1000.0;
```

One place defines the unit relationship. Every conversion multiplies
by a named constant; a future reader greps `mm_to_meters` and finds every
site where units change.

### Free functions, per the standing decision

All four are `[[nodiscard]] inline` free functions in
`interstellar::coords` — the shape fixed before this phase started.
Layer crossings are greppable call sites (`to_camera_relative(` finds every
storage→render transition in the engine), and `[[nodiscard]]` makes
dropping a conversion result a warning.

## Why it was built this way

- **Precision rules as code, not documentation.** Subtract-before-convert
  and the 4 km limit both exist as executable enforcement (function
  structure, assert) rather than comments. The failure mode of silent
  precision loss at conversion boundaries is addressed by making the safe
  path the only path.
- **Proof tests over trust.** The cancellation test constructs the failure
  the design prevents and shows it failing under convert-first. 11 test
  cases, 123 assertions; suite at 44 cases total after this phase.
- **Mostly test work** — the four functions total ~50 lines; the test
  files carry the phase.

## Where it is now (drift since 2026-04-22)

conversions.hpp: 280 lines today, 11 commits. Two review passes and two
later milestones revised it — more than any other coordinate file. The
notable findings:

- **`std::llround` rounded half away from zero — replaced with
  `std::nearbyint` (half-to-even).** Away-from-zero rounding is biased: a
  long chain of store→physics→store round-trips accumulates drift in the
  direction of travel. Banker's rounding is statistically unbiased.
- **`* static_cast<float>(mm_to_meters)` in `to_camera_relative` was
  replaced with `/ 1000.0f`.** 0.001 is not exactly representable in
  binary floating point; 1000.0 is. Multiplying by an inexact constant
  costs a rounding error the divide avoids.
- The 4 km assert had checked magnitude per-axis with `std::abs`; the fix
  tightened it to a signed bound (int64 `abs` of INT64_MIN is UB).
- Contract violations in `to_absolute` became observable in Release — a
  one-shot stderr report — and `try_to_absolute` was added, returning
  `std::optional` for callers that can handle failure.
- A later review (M0.4) hoisted the finite/range guard *above* the
  float→int cast — casting an out-of-range double to int64 is UB, so
  checking after casting was checking too late.
- A subsequent hardening sweep (M0.4) added overflow-UB detection on the
  int64 path and replaced `M_PI` with `std::numbers::pi`, the latter
  caught by the Windows CI lane.
- The four function names and the subtract-before-convert structure are
  unchanged — every fix hardened edges (rounding mode, contract
  observability, UB) around the original design.

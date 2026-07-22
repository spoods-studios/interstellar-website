# M0.2 Phase 7 — Core Vector Types: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-04-22**; a
> drift section at the end tracks what changed since and why.

## Starting point

M0.1 ended with a triangle. M0.2 builds the coordinate system every future
physics calculation and rendered frame depends on, and Phase 7 lays its
foundation: the vector types.

The problem the whole milestone answers: standard "world coordinates in
float32" breaks at ~4 km from origin. IEEE 754 float32 has 24 bits of
mantissa — precision degrades with magnitude, and past 16 million meters
positions round to 1-meter increments. A solar-system game needs
sub-millimeter accuracy from Earth's surface to Pluto's orbit. The
architecture (still the engine's architecture today):

1. **Storage** — `int64_t` at 1 mm per unit. Integer math is exact, and the
   range is ±9.2×10¹⁵ m ≈ 600 AU, well past Pluto.
2. **Physics** — `double` (float64), positions *relative to a local
   origin*, so magnitudes stay small enough for full precision.
3. **Rendering** — `float` (float32), camera-relative, because GPUs are
   float32-only; within a ~4 km radius of the camera, float32 is safe.

Phase 7's scope is the three types and their intrinsic operations only — no
conversions between layers (Phase 8), no origin management (Phase 9), no
Vulkan integration (Phase 10).

## What was built

### Three separate structs, deliberately unrelated

```cpp
namespace interstellar::coords {

struct Vec3i64 { int64_t x{}, y{}, z{}; /* ... */ };   // storage, 1mm grid
struct Vec3f64 { double  x{}, y{}, z{}; /* ... */ };   // physics, relative
struct Vec3f32 { float   x{}, y{}, z{}; /* ... */ };   // rendering, camera-relative
}
```

The load-bearing decision: no inheritance, no common base, no
`Vec3<T>` template, no operator that mixes types. `Vec3i64 + Vec3f64` is a
compile error. The template was rejected: with `Vec3<T>`, preventing
implicit cross-instantiation conversions is harder than writing three
structs; with separate types the compiler enforces the layer boundary for
free. Tests pin this with `static_assert`: all six pairwise conversion
directions checked as non-convertible.

Naming encodes precision, not role: `Vec3f64` serves positions *and*
velocities. Role-based names (`WorldPos`, `RelativePos`) were rejected
because they'd need duplicating for every quantity.

### Operations follow the layer's semantics

All three types get `+`, `-`, scalar `*` and `/`, `==`, unary minus. The
divergence is where the layers differ:

```cpp
// Vec3i64 — integer-only surface
[[nodiscard]] constexpr int64_t dot(const Vec3i64& rhs) const;
[[nodiscard]] constexpr int64_t distance_squared(const Vec3i64& rhs) const;
constexpr auto operator<=>(const Vec3i64&) const = default;  // lexicographic
```

`Vec3i64` has **no** `length()` or `normalize()`: both require
`std::sqrt`, which returns floating point, and the storage layer stays
integer-exact. `distance_squared` covers proximity comparisons without
leaving integer math. The float types get the full geometry set: `dot`, `cross`,
`length`, `length_squared`, `normalize`, `distance`.

Everything that can be `constexpr` is — all integer operations and
float arithmetic; only the `std::sqrt`-dependent operations are runtime.
The defaulted spaceship operator gives `Vec3i64` lexicographic ordering for
use as a map key.

### Header-only, and where it lives

One header: `engine/include/interstellar/coordinates/types.hpp`.
The module folder — `types.hpp`, `conversions.hpp` (Phase 8), `service.hpp`
(Phase 9) — lets the subsystem grow by file, not by bloating one header.
The namespace choice, `interstellar::coords`, created the project's first
nested namespace, separating coordinate code from VulkanContext's flat
`interstellar`.

### Tests as the primary output

The types themselves are straightforward; tests are the primary output of
this phase. 32 test cases in
`tests/unit/coordinates/test_vec3_types.cpp`, replacing the placeholder
test M0.1 shipped with. The testing split matches layer
semantics: integer operations asserted **bit-exact**
(`REQUIRE(a.x == expected)`), float operations within Catch2 `Approx`
margins. `normalize()` on a zero-length vector got an `assert` guard.

## Why it was built this way

- **Compile-time enforcement over discipline.** The alternative — one type
  everywhere plus programmer care — was rejected: layer-crossing bugs (the
  "objects teleport or jitter at conversion boundaries" failure mode)
  become compile errors instead of runtime surprises.
- **Free-function conversions, fixed before conversions exist.** Phase 8's
  shape was fixed ahead of time: `to_relative(pos, origin)`-style free
  functions, greppable at every call site, visible in code review — rather
  than member methods that hide crossings inside the types.
- **Simple structs, public members.** No getters, no invariants to protect
  at this layer; `auto [x, y, z] = vec` structured bindings work directly.

## Where it is now (drift since 2026-04-22)

types.hpp is 364 lines today (~200 when this phase closed) with 8 commits
of history. The three-type structure, naming, namespace, and
constexpr surface are unchanged. What changed came from review:

- `distance_squared` overflowed int64 for points ~3×10⁹ km apart — within
  the storage range the type advertises. Fixed with saturating
  arithmetic.
- `normalize()` on a zero vector returned NaN through the
  assert-disabled Release path. Changed to return the zero vector.
- A later hardening sweep (M0.4-era) gave `Vec3i64` overflow detection on
  arithmetic — signed int64 overflow is undefined behavior in C++, so the
  operators now detect it with `__builtin_*_overflow`, plus an
  MSVC-portable fallback after the Windows CI lane exposed the GCC-only
  intrinsics.
- The M0.2 property-based suite added generative tests over the
  representative-point tests — part of the math-lock strengthening that
  became standing policy.
- The types now sit next to the deterministic force kernel: `Vec3f64` is
  the type the kernel computes in, and the bit-exact testing idiom
  established here (integer exact, float within derived ULP bounds) is the
  template every physics test suite since has followed.

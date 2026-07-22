# M0.2 Phase 9 — Coordinate Service: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-04-22**; a
> drift section at the end tracks what changed since and why.

## Starting point

Phase 7 defined the three coordinate types; Phase 8 defined the conversions
between them. Both are stateless — every conversion takes the origin as an
explicit parameter. Phase 9 adds the class that owns that parameter:
`CoordinateService`. One service holds the current origin; physics,
rendering, and later collision all query the same value. Per-system
origins were rejected: a physics/rendering origin mismatch produces
visible shimmer.

## What was built

### The class — origin state behind a query API

```cpp
class CoordinateService {
public:
    explicit CoordinateService(int64_t shift_threshold_mm = 1'000'000);
    CoordinateService(Vec3i64 initial_origin, int64_t shift_threshold_mm = 1'000'000);

    CoordinateService(const CoordinateService&) = delete;  // + move ctor, both assigns

    [[nodiscard]] Vec3i64 get_origin() const;
    void shift_origin(Vec3i64 new_origin);
    [[nodiscard]] bool should_shift(Vec3i64 camera_pos) const;
    [[nodiscard]] int64_t distance_from_origin(Vec3i64 pos) const;
    [[nodiscard]] Vec3f64 to_relative(Vec3i64 pos) const;
    [[nodiscard]] Vec3f32 to_camera_relative(Vec3i64 pos, Vec3i64 camera) const;

private:
    Vec3i64 current_origin_;
    int64_t shift_threshold_mm_;
};
```

Two members, six methods, 38 lines of implementation. Non-copyable and
non-movable, copying the deleted-special-members block from
`VulkanContext` — one instance per engine. The default shift threshold is
1,000,000 mm = 1 km: past ~1 km from the origin, float32 rendering
precision degrades, so the origin should move before the camera gets there.

The service stores state and answers queries; it does not decide *when* to
shift. That split is explicit: origin shifts happen only between frames,
and enforcing the timing is the caller's job — Phase 10's render loop. The
`shift_origin` docstring carries the contract.

### should_shift — threshold detection without a square root

```cpp
bool CoordinateService::should_shift(Vec3i64 camera_pos) const {
    return current_origin_.distance_squared(camera_pos)
         > shift_threshold_mm_ * shift_threshold_mm_;
}
```

Comparing squared distance against a squared threshold keeps the check in
int64 arithmetic — `sqrt` would pull floating point into the exact
storage layer. The comparison is strict: a camera at exactly threshold
distance does not trigger a shift, and a test pins the boundary
(`CHECK_FALSE` at 1,000,000 mm, `CHECK` at 1,000,001 mm).
`distance_from_origin` exposes the same squared value directly.

Squaring int64 deltas here overflows once positions are more than
~3×10⁹ mm apart — flagged during development. Disposition: accept —
thresholds are km-scale in practice, so the overflow was judged
unreachable. The M0.2 review disagreed (see drift).

### Delegation, not reimplementation

```cpp
Vec3f64 CoordinateService::to_relative(Vec3i64 pos) const {
    return coords::to_relative(pos, current_origin_);
}
```

The conversion methods are one-line wrappers that inject `current_origin_`
into the Phase 8 free functions. The tests hold them to it:
each delegation test calls the method and the free function with identical
inputs and requires identical results, so the wrapper can never silently
grow its own math.

### The tests

5 TEST_CASEs, 12 SECTIONs: construction (default threshold,
custom threshold, custom origin), exact shift, bit-exact shift round-trip
(A→B→A, `get_origin() == A` — trivially true for int64 stores,
pinned so it stays true), the threshold boundary trio, squared-distance
values, and the two delegation checks. MSVC rejected `coords::to_relative`
as ambiguous (error C2653) with `using namespace interstellar::coords`
active, so the delegation tests use the fully qualified
`interstellar::coords::` names.

## Why it was built this way

- **The design predates the phase.** Single origin, one owner, everything
  queries — fixed before Phase 9 began. Phase 9's job was the mechanical
  realization, 2 commits.
- **Service pattern established.** Stateful class owning subsystem state,
  non-copyable/non-movable — the first non-Vulkan instance of the pattern,
  reused by later engine services.
- **Thin by intent.** The service adds no arithmetic of its own; Phase 8's
  free functions stay the only conversion code. What it adds is the origin
  lifecycle: read it, replace it, decide when replacement is due.

## Where it is now (drift since 2026-04-22)

service.hpp is 101 lines today, coordinate_service.cpp 140, the test file
252. Of the six public methods shipped, the M0.2 review renamed two,
deleted one, and rewrote the synchronization story:

- **2026-04-24 — the only Critical finding from that review, and it landed
  on the accept-disposition above:** the accepted overflow was not benign:
  in Release, signed-multiply UB could sign-corrupt `should_shift` (far
  camera reads as "near origin"), and a threshold above ~3.04 Gm made
  `threshold * threshold` itself wrap negative — every comparison true, an
  infinite shift loop. Fix: `Vec3i64::distance_squared` saturates to
  `INT64_MAX` beyond its per-axis safe bound (2³⁰ mm), and the ctors
  assert the threshold into (0, 2³⁰) mm and pre-square it once into a new
  `shift_threshold_mm_squared_` member.
- **2026-04-25:** `distance_from_origin` →
  `distance_squared_from_origin`. The return is mm², the old name implied
  mm; a naive `> threshold_mm` comparison silently misreads.
- **2026-04-25:** `to_camera_relative` was removed from
  the class. It never read `current_origin_` — an instance method ignoring
  its own state implied a dependency that didn't exist. The free function
  is now the only API.
- **2026-04-25:** `shift_origin` → `set_origin`.
  "Shift" reads as apply-a-delta across C++/glm/Unity/Vulkan; the argument
  is an absolute origin. Delta-style misuse would teleport the world.
- **2026-04-25:** the phase's docs said "atomically
  sets a new origin," but `Vec3i64` is 24 bytes and no common architecture
  has a 24-byte atomic store — on x86-64 it is three separate qword stores,
  and the M0.3 physics thread reading `get_origin()` mid-store would get a
  torn origin. Fix: a seqlock (Lamport 1977) — a `std::atomic<uint64_t>`
  counter, even when idle, odd while a write is in flight. The writer bumps
  it odd, stores the payload, bumps it even; readers snapshot the counter,
  read the payload non-atomically, fence, re-read the counter, and retry if
  it changed or was odd. The writer never blocks and pays two atomic stores;
  readers only retry in the rare between-frames write window. All read
  methods route through one reader helper, and a stress test (1 writer
  cycling coherent `(v,v,v)` origins, 4 readers asserting `x == y == z`)
  pins the no-torn-read invariant.
- **2026-04-25:** the seqlock reader now yields to the OS
  (`std::this_thread::yield()`) after 8 spin retries, so a writer preempted
  mid-write can't pin readers at 100% CPU.
- **2026-06-04:** the writer's ordering was wrong on weak
  memory. A `memory_order_release` *store* only orders operations before
  it; nothing stopped the payload write from becoming visible before the
  odd marker on ARM, letting a reader see an even/even counter pair around
  a write in progress. Corrected to the canonical form — relaxed store of
  odd, release fence, payload, release fence, relaxed store of even —
  verified with a clean TSan suite plus a 60 s contention run.
- **Same sweep:** the pre-squared threshold from the fix above was
  computed in the member-init list, which runs before the ctor-body
  assert — out-of-range values hit signed-overflow UB in Release before
  any check. The range check now runs first and throws
  `std::invalid_argument` in Release.

The origin-ownership design — one service, one origin, queries only — is
unchanged since 2026-04-22. Every fix above corrected a name, a claim, or
an edge the original 38 lines had wrong.

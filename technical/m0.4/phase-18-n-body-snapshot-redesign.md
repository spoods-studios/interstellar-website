# M0.4 Phase 18 — N-Body Snapshot Redesign: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-08**; the
> drift section traces the snapshot through today's worker.

## Starting point

M0.3's physics→render handoff was a single-body `Snapshot` POD published
under a seqlock: the worker copied the whole payload every publish, render
copied it out again by value. Identified 2026-06-04: that per-publish copy
is O(N) at publish cadence, so M0.4 must adopt a fixed-capacity SoA buffer
with a published index *before* a second gravitating body exists — a
named-blocker deferral, legal because the missing machinery is the
container itself.

The replacement was locked 2026-06-05: fixed-capacity Structure-of-Arrays,
triple buffer, published `{index, generation}` atomic, read-in-place
reader, O(1) publish. Per-body seqlocks were rejected (incoherent frames),
hazard pointers as overbuilt for one reader. Phase 18 runs first in M0.4
because every later phase binds to this contract; the sim still runs one
body until multi-body enablement gates in Phase 21. In-repo prior art: the
M0.2 `coordinate_service.cpp` seqlock, and P14's two-buffer index-swap —
killed by TSan in M0.3, which is why the buffer count below is three,
never two.

## What was built

### The container

`worker_thread.hpp` replaces `struct Snapshot` with three rotating SoA pages:

```cpp
struct FrameMeta {
    double sim_time{0.0};
    coords::Vec3i64 origin{};
    double rel_energy_error{0.0};
    std::size_t count{0};   // active body count this frame (≠ capacity, D-04)
};

struct Page {
    std::vector<coords::Vec3f64> pos;
    std::vector<coords::Vec3f64> vel;
    FrameMeta meta{};
};
```

`std::array<Page,3> pages_`, each `pos`/`vel` reserved to
`Config::body_capacity` once in the constructor, never grown on the hot
path — `std::vector` rather than a `constexpr MaxBodies` array so the
deferred craft tier raises the cap without a type change. Capacity ≠
count: readers iterate `[0,count)`. Per-body payload is pos/vel only,
stored as `coords::Vec3f64`; an x/y/z scalar-split SoA was rejected as
premature SIMD on a render-facing snapshot. Per-frame scalars live *per
page* so they swap atomically with the index. A single immutable body-id
table, built once and shared by all three pages, makes slot `i` the same
body on every page — the index↔id stability the determinism lock leans
on. `Snapshot::period_estimate` is gone: an N-body system has no
well-defined period. `rel_energy_error` stays whole-system
`(ε − ε₀)/|ε₀|` — the exact quantity the close-encounter regression gates
in Phases 20/21.

### The packed word and O(1) publish

The published handle is one 64-bit atomic: page index in the low 2 bits,
generation above, the generation's low bit doubling as the seqlock odd/even
marker:

```cpp
[[nodiscard]] static constexpr std::uint64_t pack(std::uint64_t gen,
                                                  std::uint64_t idx) noexcept {
    return (gen << kIndexBits) | (idx & kIndexMask);
}
```

One word makes "swap the buffer" and "bump the generation" a single
indivisible store — a reader can never see a new index against a stale
generation. The publish protocol is the M0.2 seqlock writer, generalized:

```cpp
pub_.store(pack(gen + 1, back), std::memory_order_relaxed);  // odd: write in progress
std::atomic_thread_fence(std::memory_order_release);         // (A)
page.pos.assign(active, state_.r);   // fill back page in place — reserved, no realloc
page.vel.assign(active, state_.v);
// ... per-frame scalars, page.meta.count = active ...
std::atomic_thread_fence(std::memory_order_release);         // (B)
pub_.store(pack(gen + 2, back), std::memory_order_relaxed);  // even: page published
```

Fence (A) matters: a release *store* only constrains prior operations, so
without it the payload writes could hoist above the odd marker on weakly
ordered hardware. The publish is O(1) in N — only the `pub_` stores and the
rotation are per-publish; the page fill is the step loop's own write, not a
second copy. The rotation picks the next back page as the one that is
neither the newly published page nor the previous one a reader may still
be latching: with three pages the writer needs two publishes to return to
any page, and the generation recheck catches the first. That is the
structural fix for P14, where a double publish cycled straight back onto
the page the reader still held.

### The read-in-place reader

`latest_snapshot()` generalizes the M0.2 seqlock reader to rotating pages:

```cpp
const std::uint64_t p1 = pub_.load(std::memory_order_acquire);   // (C)
if (gen_of(p1) & 1ULL) { /* odd → write in progress: spin 8, then yield */ }
const Page& page = pages_[idx_of(p1)];
const std::size_t count = std::min(page.meta.count, page.pos.size());
view.pos.assign(page.pos.begin(), page.pos.begin() + count);
view.vel.assign(page.vel.begin(), page.vel.begin() + count);
std::atomic_thread_fence(std::memory_order_acquire);             // (D)
const std::uint64_t p2 = pub_.load(std::memory_order_relaxed);   // (E)
if (p1 == p2) return view;   // generation+index identical → coherent
```

The page bytes are read while the writer may be writing them — an
intentional benign race whose *result* the recheck makes correct: any
concurrent publish changes `pub_` and the frame is discarded. A torn
`count` is clamped to the live vector size so the loop cannot read past
the allocation. The returned `SnapshotView` owns its copied bytes plus
`state_of(i)` per-slot reconstruction, so by-value consumers stay valid as
the writer advances. The design comment states the contract plainly:
lock-free, wait-free only under a bounded publish rate — and the writer
publishes only when a step ran. `pack`/`gen_of`/`idx_of` are public
`constexpr` so a dedicated test asserts the bit-math round-trip without
re-implementing it.

### Consumer migration

`orbit_demo.cpp` reads body 0 via `state_of(0)`; the HUD drops to `T+` and
`ΔE/E`, the energy diagnostic promoted into the freed `PERIOD` slot. The
type change forced three consumers the plan had not enumerated
(`test_long_horizon.cpp:184`, `test_worker_lifecycle.cpp:93`,
`test_seqlock_contention.cpp:247`) onto `SnapshotView`; no math-lock
assertion or tolerance moved. A later fix injected a `snapshot` token into
each affected test title — `catch_discover_tests` names ctest entries by
TEST_CASE description, not file name, so `ctest -R snapshot` had matched
nothing.

### Proving the reader cannot tear

The contention soak lifts M0.2's `x==y==z` torn-read trick to N bodies: a
writer publishes 4-slot frames where every component of every slot carries
the same strictly increasing per-frame stamp, so any page-A/page-B mix
surfaces as two stamps in one frame:

```cpp
const double stamp = v.pos[0].x;
for (std::size_t i = 0; i < v.count; ++i) {
    const Vec3f64& p = v.pos[i];
    const Vec3f64& q = v.vel[i];
    if (p.x != stamp || p.y != stamp || p.z != stamp ||
        q.x != stamp || q.y != stamp || q.z != stamp) {
        return -1;  // intra-vector OR cross-slot tear
    }
}
```

The writer is `publish_stamped_frame_for_test`, an
`INTERSTELLAR_TESTING`-gated method reproducing the production publish
protocol byte-for-byte with four stamped slots; the production worker is
parked so `pub_` keeps exactly one writer. The soak asserts `torn == 0` and
stamp monotonicity over ≥5 s (60 s opt-in). A second case drives the exact
P14 kill window — back-to-back publish *pairs* during reads — and requires
`torn == 0` **and** `jumps_ge_2 > 0`: the reader must latch stamp K and
next observe K+2, proving the window fired. The soak's power was checked
empirically: without the suppression file, TSan flags the intended benign
race at `physics_worker_thread.cpp:567`/`:423` — instrumentation live, the
one added `race:` suppression scoped to the test hook. Two fixes surfaced
only under parallel TSan: one made the coherence check count-agnostic (the
reader can legitimately observe the production count=1 seed frame before
the first 4-slot publish), and another relaxed a precondition that assumed
a just-built worker was still on page 0. Exit gate: 163/163 ctest entries
green in Debug, Release, and TSan (five consecutive parallel runs), Catch2
cases 152 → 161, no M0.2/M0.3 math-lock file touched, N=1 trajectories
bit-identical.

## Why it was built this way

- **O(1) publish, not a cheaper copy.** The old memcpy scales with N at
  publish cadence; filling the back page *is* the step loop's write.
- **One packed word, not two atomics.** Independent index and generation
  atomics can be observed mutually stale; one store publishes both.
- **Three pages, never two.** Empirical: the P14 two-buffer swap was killed
  by TSan. The third page decouples the writer's next fill from the page a
  reader still holds.
- **Seqlock reader, not reader-swaps triple buffering.** The common
  formulation has the reader `exchange` ownership of a page — an RMW on the
  shared word. Keeping the reader pure extends the proven, TSan-clean M0.2
  seqlock, carried to N bodies, instead of adding a second concurrency
  idiom.
- **Shared id table, not per-page ids.** The M0.4 body set is static;
  replication buys nothing and risks divergence in the one mapping
  determinism depends on.
- **Whole-system `rel_energy_error`.** Splitting it per body would change
  the quantity the close-encounter regression gates.

## Where it is now (drift since 2026-06-08)

- **2026-06-08, Phase 21:** scalar `state_` became a `states_` vector and
  multi-body enablement went live — publish fills `[0,count)` real bodies
  (Sun–Earth–Moon, five bodies in 21.7) with no snapshot change.
- **2026-06-09, Phase 21.5:** stderr physics telemetry reads the published
  frame; `time_scale_max` raised 1024× → 2^20.
- **2026-06-13, M0.4 gate:** step and publish bodies extracted into shared
  `run_due_steps()` + `publish_with(fill)`; a zero-allocation out-param
  `latest_snapshot(SnapshotView&)` joined the allocating overload, which
  lost its `noexcept`.
- **M0.4–M0.7:** `FrameMeta` grew observability fields — integrator regime
  and method index, secular AMD (M0.5 gate), `warp_active` (M0.7 Phase 39),
  per-clump energy drift (Phase 41) — each trivially copyable so the
  read-in-place `static_assert` holds; a Phase 42 fix hoisted energy/AMD
  computation out of the seqlock write window.
- As of 2026-07-21 the packed word, three pages, and publish protocol are
  unchanged (`worker_thread.hpp` — `pub_`, `pages_`, `pack`/`gen_of`/`idx_of`);
  every tier added since — Wisdom-Holman, HJS, warp, PN, the craft
  test-particle — publishes through the Phase 18 handoff.

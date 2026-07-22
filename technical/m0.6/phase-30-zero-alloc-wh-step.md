# M0.6 Phase 30 — Zero-Alloc WH Step: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-24**; the
> drift section traces `wh_step`'s scratch-span pattern through today's
> stack.

## Starting point

Phase 24 (M0.5) built `wh_step`'s KDK map with a boundary comment marking
its one open cost: the democratic-heliocentric transform needed a working
buffer, and the function allocated it itself —
`std::vector<State> helio(n)` — once per call, sized to the live body
count. The comment called it negligible next to the Kepler solves and left
it "hoistable to a worker-owned scratch later if profiling demands." Phase
32 flips WH from built-but-disabled to the live EMB warp seat, so `wh_step`
is about to run every warp substep instead of never; at that call
frequency the per-call allocation stops being negligible, and this phase
closes it before the flip lands.

## The refactor: caller-owned span, not a smarter allocator

The fix doesn't touch the allocation strategy — it removes the allocation.
`wh_step` gains a seventh parameter, a trailing `std::span<State>
helio_scratch`, and the function reads its working buffer from
`helio_scratch.first(n)` instead of constructing one:

```cpp
void wh_step(std::span<State> states,
             const BodyTable& props,
             std::size_t dom,
             double mu_dom,
             double dt,
             double G,
             std::span<State> helio_scratch) noexcept;
```

The backing storage moves to `PhysicsWorker`, as a new
`wh_helio_scratch_` member sized once in the constructor:

```cpp
wh_helio_scratch_.assign(capacity, State{});
```

— the same reserve-once discipline `accel_` and `ias15_scratch_` already
use, and the same idiom `Ias15Scratch` established for its own working
buffer (`std::span<State>` as the parameter type). The production call
site hands over `.first(active)` of that member, plus a debug guard that
`active` never exceeds the reserved capacity:

```cpp
assert(active <= wh_helio_scratch_.size() &&
       "wh_step: active exceeds wh_helio_scratch_ capacity");
wh_step(std::span<State>{states_},
        BodyTable{std::span<const BodyProps>{body_props_}.first(active)},
        dom_slot_, mu_dom_, step_dt, physics::G,
        std::span<State>{wh_helio_scratch_}.first(active));
```

Two guards go with the new parameter. A plain `assert` inside `wh_step`
checks `helio_scratch.size() >= n` — the scratch must be big enough for
the states span it backs. It's placed *after* the existing `dom >= n`
early-return, so the no-op path for an out-of-range dominant slot
(exercised by `test_29fa_wh_safety`'s `dom=5` case) never reaches it. A
second assert, compiled only `#ifdef INTERSTELLAR_TESTING` at the time this
phase landed, checks `states.data() != helio_scratch.data()` — the caller
must pass distinct buffers, since an aliased scratch would corrupt the
transform via read-after-write. Production always passes two separate
named members, so the assert exists to catch a test or future caller
getting that wrong, not to guard against a real production path.

## Why this had to be a relock, not a rewrite

`wh_step`'s golden vectors are under math-lock: any behavioral drift
needs reviewer sign-off, but a signature-only change that produces
identical bytes doesn't count as one — it counts as a relock, and the way
you prove that distinction is by running the goldens and diffing. Every
direct call site across the test suite (30 calls in 11 files) needed the
new trailing argument, each with its own locally-scoped
`std::vector<State> wh_scratch(states.size())` so no test constructed
aliasing between two calls that share a states buffer. `test_wh_step.cpp`'s
two-body golden vectors — 35,778 `[wh]` assertions — came back bit-exact
on both Debug and Release, no tolerance touched. `nbody_force.cpp` stayed
byte-unchanged throughout, the standing determinism invariant this phase
(like every phase) has to hold.

One incidental fix rode along: `test_det04_cross_platform.cpp` only
included `<array>`-based fixtures before this phase and needed
`<vector>` added once its call sites gained a local scratch vector.

## Proving the alloc is gone

A signature change that threads a caller-owned buffer through doesn't by
itself prove zero allocations — it makes zero allocations *possible*.
`test_wh_zero_alloc.cpp` closes that gap with a TU-local override of
`::operator new` / `::operator new[]`, forwarding to `std::malloc` and
incrementing a plain `int` counter:

```cpp
void* operator new(std::size_t sz) {
    ++g_alloc_count;
    if (void* p = std::malloc(sz == 0 ? 1 : sz)) {
        return p;
    }
    throw std::bad_alloc{};
}
```

Defining the global allocation functions in one translation unit replaces
them program-wide for that test binary, so the counter has to be reset
*after* any allocation-bearing setup — fixture construction, the scratch
vector itself, Catch2's own bookkeeping — and read into a plain local
*before* the `REQUIRE` call, since the assertion machinery can itself
allocate. The test runs a 5-iteration warm-up over a Sun + Earth-mass
two-body fixture (any first-touch lazy allocation happens there, outside
the measured window), resets the counter to zero, then runs a 100-step
burst and asserts `allocs == 0`.

The `TEST_CASE` name matters beyond readability: `catch_discover_tests`
registers test entries by `TEST_CASE` name, not by source filename, and
verification runs `ctest -R wh_zero_alloc`. An initial hyphenated name
(`wh-zero-alloc`) didn't match that regex; renaming the case to contain
the literal substring `wh_zero_alloc` fixed discovery.

## What stayed exactly as it was

The KDK step order, the interaction kick, and the frame-transform math
inside `to_democratic_heliocentric` are untouched — this phase moves where
the buffer that transform writes into comes from, not what goes into it.
`nbody_force.cpp` — the locked force kernel — has no line in this diff at
all.

## Where it is now (drift since 2026-06-24)

- **A gate fix (2026-06-25):** the aliasing assert moved from
  `#ifdef INTERSTELLAR_TESTING`-gated to a plain Debug `assert` — it now
  compiles out under `NDEBUG` rather than being testing-only, so a
  Release-with-debug build still catches an aliasing bug that a
  testing-only guard would have missed.
- **Another gate fix (2026-06-25):** a second `TEST_CASE` landed in
  `test_wh_zero_alloc.cpp` — this one drives a parked
  `PhysicsWorker`'s `tick()`/`run_due_steps()` seam over the live EMB warp
  seed, proving the zero-alloc property holds through the worker dispatch
  path (WH selection, `run_due_steps`, snapshot publish) as well as
  through a direct `wh_step` call.
- **Phase 44 (M0.8, oblateness):** `wh_step` gained a second overload
  taking an `OblatenessTable` — J2 enters as an additive kick beside the
  interaction kick at both half-kick sites. The original 7-arg `wh_step`
  now forwards to this overload with an empty `OblatenessTable{}`, so
  every Phase-30-era caller stays byte-for-byte identical; the
  `helio_scratch` parameter and its two asserts carry through unchanged
  into the new overload's signature.
- **Phase 45 (M0.8, 1PN):** the oblateness overload picked up a trailing
  defaulted `PnParams pn = {}` for the ST94 1PN entry — again
  default-disabled, again forwarding-compatible, again leaving
  `helio_scratch` as the same caller-owned span this phase introduced.
- As of 2026-07-21, the scratch-span idiom this phase established —
  worker-owned, reserved once at `body_capacity()`, passed as a trailing
  span, asserted non-aliasing — is the pattern every subsequent WH
  extension (oblateness, 1PN) has built on top of rather than replaced.

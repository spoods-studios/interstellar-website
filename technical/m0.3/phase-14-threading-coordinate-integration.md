# M0.3 Phase 14 — Threading + Coordinate Integration: Technical Deep-Dive

> Retroactive technical devlog. The phase that moved physics off
> the render thread. Code shown **as built on 2026-05-21**; the drift
> section traces the worker to today's `physics_worker_thread.cpp`.

## Starting point

Phase 13 left the symplectic integrator (`step<M>(span<State>, dt,
bound_force_fn, origin)`) in a single-threaded test harness, with `SimClock`
and the per-substep `try_to_absolute` NaN filter in place.
M0.2's `CoordinateService` protected the origin with a seqlock, but its
only concurrent coverage was a synthetic 4-reader stress; the M0.2 review
gate named that gap: "M0.3 physics thread reading `get_origin`
concurrently with a frame-boundary `shift_origin` will torn-read." Phase
14's job: a dedicated physics worker thread driving the integrator at its
own cadence, and an empirical closure of that gap.

## What was built

### PhysicsWorker + Snapshot

`engine/include/interstellar/physics/worker_thread.hpp`, 287 lines: a
`PhysicsWorker` class owning a `std::jthread`, and the render-facing
`Snapshot` — a trivially-copyable POD holding `State integrator_state`,
`double sim_time`, `Vec3i64 origin`, plus `period_estimate` and
`rel_energy_error` fields the worker publishes as 0.0 until Phase 15 fills
them. `static_assert(std::is_trivially_copyable_v<Snapshot>, ...)` locks
the POD contract. `Config` carries `std::variant<Leapfrog, Yoshida4>
method`, an immutable `step_dt` (mid-run dt changes break both
symplecticity and determinism), the initial `State`, and a `bound_force_fn`
— a function pointer per Phase 13's contract, not `std::function`.
Time-scale is clamped to `[1/1024, 1024]` (geometric ×0.5/×2 steps, KSP
convention); `wall_dt_clamp_seconds = 0.25` is the Fiedler spiral-of-death
clamp — without it, a debugger or OS pause balloons the accumulator and the
next iteration burns CPU on thousands of catch-up steps. Member declaration
order encodes shutdown order: `coord_service_` first (outlives the worker),
`thread_` last, so jthread RAII joins before anything else is torn down.

### The worker loop

`engine/src/physics_worker_thread.cpp`, 353 lines. The jthread body is an
asymmetric loop: unpaused, it busy-steps — the integrator is the work, no
sleeps; paused, it blocks on `std::condition_variable_any::wait` with the
C++20 `stop_token` overload (P0660R10), so one primitive wakes on both
resume and shutdown:

```cpp
while (!st.stop_requested()) {
    if (paused_.load(std::memory_order_relaxed)) {
        std::unique_lock lock{pause_mutex_};
        pause_cv_.wait(lock, st, [this, &st]{
            return !paused_.load(std::memory_order_relaxed)
                || st.stop_requested();
        });
        prev = clock::now();
        continue;
    }
    // steady_clock wall_dt, Fiedler clamp, then:
    accumulator_iteration(wall_dt);
}
```

`accumulator_iteration` implements the fixed-timestep accumulator:
`accumulator_ += time_scale * wall_dt`, then integer `step_dt` drains with
the fractional remainder carried forward — sim time tracks wall × scale on
average while every integrator step is an exact `step_dt`. The
`std::variant` visit hoists once per iteration, not per substep;
`coord_service_.get_origin()` is read through the M0.2 seqlock on every
substep. Publication is a double buffer: the worker writes
`buffers_[1 - index_]` in place, then `index_.store(next,
std::memory_order_release)`; `latest_snapshot()` does the paired
`memory_order_acquire` load and copies the buffer out. Control inputs
(`paused_`, `time_scale_`) are `memory_order_relaxed`. The worker body is
wrapped in `try/catch(...)` storing `std::current_exception()` into an
`std::exception_ptr` under `error_mutex_`; main calls `check_and_rethrow()`
between frames, so a Phase 13 NaN-substep `std::runtime_error` surfaces on
the main thread instead of hitting `std::terminate`.

### Keybinds and wiring

`engine/src/main.cpp` constructs the worker after `VulkanContext`, so
reverse-of-declaration destruction joins the jthread while the service and
Vulkan context are still live. Keybinds: `SDL_SCANCODE_SPACE` toggles
pause, `SDL_SCANCODE_COMMA`/`SDL_SCANCODE_PERIOD` halve/double time-scale
(SDL reports scancodes; `<`/`>` are the shifted forms), each guarded with
`!event.key.repeat` — auto-repeat on a held `.` would hit `time_scale_max`
in under a second. The force is a TU-local free function with μ_Earth
hard-coded: `bound_force_fn` is a function pointer, and capturing lambdas
cannot decay to one.

### Determinism tests

`tick(double wall_dt)` is a tests-only synthetic-dt hook: it drives
one accumulator iteration with a deterministic wall_dt instead of
`steady_clock`. `test_worker_lifecycle.cpp` covers pause-then-destroy (the
CV's stop_token overload wakes the worker with no manual notify),
idempotent pause/resume, and the exception-rethrow path end-to-end: a
force returning NaN triggers the Phase 13 throw, the worker captures it,
main rethrows within 200 ms. `test_time_scale.cpp` proves wall-clock
affects scheduling, never state — with bit-exact assertions: `step_dt =
1/256` (exact in binary floating point), 60 ticks of `wall_dt = 1/64` at
scale 1.0 is exactly 240 substeps, carry-over absorbs non-integer ratios
without dropping time, and two workers fed the identical `tick()` sequence
produce bit-identical `State` on every field — the `[math-lock]` anchor
Phase 16 pins for reproducibility.

Writing those tests exposed a design contradiction: the plan had
`accumulator_iteration` early-return while paused *and* had tests pause the
worker before driving `tick()` — under both rules every determinism test
would no-op. Resolution: the pause gate lives in the hot loop
only; `tick()` advances unconditionally, keeping the synthetic-dt contract
a pure function of (method, step_dt, initial state, wall_dt sequence).

### Seqlock contention closure

`test_seqlock_contention.cpp`, 263 lines. Three participants against one
`CoordinateService`: the test main thread writing monotonic `(w,w,w)`
origins at ~60 Hz, a dedicated reader thread calling `get_origin()` at kHz
cadence, and a production `PhysicsWorker` integrating full-speed — the
first real concurrent reader the M0.2 seqlock ever had. Six assertions:
zero torn reads (every observed origin appears in the writer's history),
per-axis monotonicity across consecutive reads, a seq-bump audit inferred
as 2 × the writer's own `set_origin` count (no `seq_for_test()` accessor
added — `service.hpp` and `coordinate_service.cpp` stay untouched), reader
liveness, worker validity, and post-contention service function. Duration
comes from `INTERSTELLAR_SEQLOCK_CONTENTION_SECONDS`: default 5 s, closure
variant 60 s. The 60 s run passed on the Fedora dev machine at 60.01 s wall
— zero torn reads.

### ThreadSanitizer scaffolding

`tsan_suppressions.txt` at repo root suppresses exactly two patterns —
`race:...get_origin` / `race:...set_origin`, the seqlock's intentional,
retry-bounded payload race — injected via a separate
`add_test(NAME seqlock_contention_tsan)` entry with a scoped `TSAN_OPTIONS`
`ENVIRONMENT` property, so every other test runs TSan unfiltered. The TSan
run itself was blocked on 2026-05-21 — no libtsan runtime on the Fedora
host — and logged as a named blocker; the consequence of that deferral is
the first drift entry below.

## Why it was built this way

- **`std::jthread` over a raw thread + atomic flag**: `request_stop()` +
  `join()` in the destructor makes shutdown a language guarantee, and
  `stop_token` threads through the CV wait for free.
- **Asymmetric pause primitive**: the phase research compared
  `condition_variable_any` + stop_token, atomic-poll + `sleep_for`, and
  `counting_semaphore` + `stop_callback`. The CV overload won — but only on
  the paused branch; any sleep on the hot path would cap integrator cadence
  at OS timer granularity.
- **Double buffer over triple buffer or seqlock** for the snapshot: with a
  kHz writer and a 60 Hz reader that copies out within a frame, two buffers
  looked sufficient — dropped intermediate snapshots are invisible at
  display cadence. This held for one publish per read and failed for two;
  see drift.
- **60 seconds is load-bearing**: the seqlock's race window is the writer's
  payload-store phase, ~5–20 ns on x86. At a 60 Hz writer and kHz reader,
  expected window hits are ~1.2e-3/s — one per ~800 s. The 5 s default only
  catches catastrophic regressions (a removed fence widens the window to
  ~200 µs, hits jump to ~12/s); the 60 s variant is the closing evidence,
  and the scaling analysis is a test-file comment so nobody shortens it
  blind.

## Where it is now (drift since 2026-05-21)

- **2026-06-04**: libtsan installed, the deferred TSan run
  executed — and caught two real data races the 60 s contention test
  missed, because it audited origin monotonicity, not the snapshot handoff.
  First: the double buffer was insufficient — a reader mid-copy of
  `buffers_[idx]` gets overwritten when the worker publishes twice
  (`next = 1 - cur` cycles back to the slot the reader still holds); it was
  replaced with a seqlock over a single `Snapshot`, mirroring the M0.2
  origin seqlock. Second: tests used `sleep_for(20ms)` after
  `request_pause()` before driving `tick()` — not a happens-before edge —
  now `wait_until_parked()`: the worker release-stores a `parked_` ack
  before entering the CV wait, the test acquire-spins on it.
- **2026-06-04**: Config guards,
  an idle sleep on the hot loop's nothing-due path, integer
  sim-clock, and `rel_energy_error` wired from the worker's energy drift —
  the field Phase 14 published as 0.0. M0.3 merged 2026-06-05.
- **2026-06-08, M0.4 Phase 18**: the scalar `Snapshot` seqlock
  superseded by an SoA triple-buffer container with O(1) packed publish for
  N bodies; a follow-up commit promoted `state_` to a `states_` vector.
- **2026-06-11**: lost-wakeup fix — `request_pause`/
  `request_resume` stored `paused_` outside `pause_mutex_`, so the worker
  could load a stale predicate and sleep through the notify; the store now
  happens under the mutex.
- **2026-06-13**: zero-alloc out-param
  `latest_snapshot` overload; snapshot seqlock writer hardened.
- **TSan lanes**: Phase 22.1 routed the suppressions file into
  every discovered ctest entry, making the unfiltered `build-tsan` lane
  green; TSan-clean has been a per-phase gate since.
- **2026-07-21**: `physics_worker_thread.cpp` is 3,745 lines and
  `worker_thread.hpp` 1,886 (from 353 and 287 as built). The skeleton is
  the same — jthread, stop_token, accumulator, seqlock-family publish,
  `check_and_rethrow` — but the loop now dispatches every physics tier
  through M0.8 and M1.1: Wisdom-Holman and HJS warp, oblateness, 1PN, and
  the craft flight block. The pause primitive, with its lost-wakeup fix,
  is unchanged in shape.

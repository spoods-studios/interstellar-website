# M0.1 Phase 4 — Command Buffers + Synchronization: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-04-20**; a
> drift section at the end tracks what changed since and why. Smallest diff
> of the milestone (27 insertions). Its central sync design was later proven
> wrong — covered in the drift section.

## Starting point

Phase 3's triangle renders — but the loop is single-frame: one fence, two
semaphores, and the CPU sits idle while the GPU draws, then the GPU sits
idle while the CPU records the next frame. Ping-pong, half the machine
always waiting.

Phase 4's job: **frames-in-flight** — the CPU prepares frame N+1 while the
GPU renders frame N. No new pixels; the triangle looks identical. What
changes is that the pipeline never drains. 20 locked decisions.

## The sync vocabulary (as this phase used it)

Three primitives, three domains, from the Phase 2/3 study:

- **Fences** — GPU→CPU. The CPU blocks on a fence to know the GPU finished
  a submission. This is how the CPU knows it's safe to *reuse* a frame's
  command buffer.
- **Semaphores** — GPU→GPU. Queue operations wait on each other without CPU
  involvement: present waits for render, render waits for acquire.
- **Barriers** — within a command buffer. Ordering + layout transitions
  (Phase 3's territory).

## What was added, piece by piece

### One constant, three arrays, one index

```cpp
static constexpr uint32_t MAX_FRAMES_IN_FLIGHT = 2;

std::array<vk::raii::Semaphore, MAX_FRAMES_IN_FLIGHT> image_available_semaphores_{nullptr, nullptr};
std::array<vk::raii::Semaphore, MAX_FRAMES_IN_FLIGHT> render_finished_semaphores_{nullptr, nullptr};
std::array<vk::raii::Fence,     MAX_FRAMES_IN_FLIGHT> render_fences_{nullptr, nullptr};
uint32_t current_frame_ = 0;
```

Why 2 and not 3: each extra frame in flight adds a frame of input
latency — the frame you're seeing is N, the frame being prepared is N+2.
Two is enough to keep both processors busy; three buys throughput you don't
need at the cost of lag you'd feel. (KSP players know engines that got this
wrong.)

Every frame-in-flight owns a *complete set* of sync objects plus its own
command buffer — because the whole point is that frame 0's resources are
still in use by the GPU while the CPU writes frame 1's. Sharing any of them
reintroduces the serialization you're trying to kill.

### `render_frame` — same flow, indexed

The Phase 3 flow survives verbatim; every resource access gains
`[current_frame_]`:

```cpp
device_.waitForFences(*render_fences_[current_frame_], vk::True, UINT64_MAX);
auto [res, image_index] =
    swapchain_.acquireNextImage(UINT64_MAX, *image_available_semaphores_[current_frame_]);
// ... reset THIS frame's fence, reset + record THIS frame's command buffer,
//     submit waiting/signaling THIS frame's semaphores, present ...
current_frame_ = (current_frame_ + 1) % MAX_FRAMES_IN_FLIGHT;
```

The critical wait is *specific*: frame 0 only ever waits on frame 0's fence
— i.e., on its own previous submission, two frames ago. It never waits on
frame 1 at all. That's the overlap: while frame 0 blocks (or doesn't — the
fence is usually long signaled), frame 1's submission is still cooking on
the GPU, untouched. The pre-signaled-fence trick and reset-after-acquire
deadlock rule carry over from Phase 3 unchanged, now per-slot.

Command buffers follow the same doubling: `commandBufferCount = 2`,
recorded via `command_buffers_[current_frame_]`. The pool keeps
`eResetCommandBuffer` — per-buffer reset, since the two buffers recycle on
different schedules.

### The distinction that matters: per-frame is NOT per-image

Frames-in-flight (2) and swap-chain images (3, from Phase 2's
`minImageCount + 1`) are **different counts with different lifecycles**.
Sync objects follow *frames*; images follow the *swap chain*.
One noted edge: an acquired image might still be referenced by an
older frame — "image-in-flight fence tracking, optional for M0.1."

The design sized `render_finished_semaphores_` per frame-in-flight. It
compiles, runs, and validates clean on this workload. It is the
standard tutorial answer — and it is wrong. See the drift section.

### Recreation and shutdown stay sledgehammers

`recreate_swap_chain()` keeps `device_.waitIdle()` — resize must
wait for *all* in-flight frames, not one, and a full stall on a rare event
is the correct simple answer. Same at shutdown. The per-frame fences are for
the hot path only.

### The deviations — vk::raii's sharp edges, again

Two compile fixes, both C++-shaped rather than
Vulkan-shaped:

1. `MAX_FRAMES_IN_FLIGHT` was declared in the constants section *after* the
   members — but `std::array<T, MAX_FRAMES_IN_FLIGHT>` needs it at the point
   of use. Moved above the member block with a comment saying why it lives
   there.
2. `vk::raii::Semaphore`/`Fence` have deleted default constructors (same
   property Phase 1 hit with `SurfaceKHR`), so `std::array` can't
   default-construct — hence the `{nullptr, nullptr}` aggregate
   initialization, using the null-handle constructor that does exist.

## Why it was built this way

- **Exactly the reference pattern.** MAX_FRAMES_IN_FLIGHT cycling is the
  canonical Khronos/vkguide frames-in-flight design.
- **Smallest possible diff.** 27 insertions. Phase 3 structured
  `render_frame` so that multi-frame conversion would be pure indexing —
  and it was.
- **Deferred edge, named owner.** The image-in-flight tracking question was
  documented as out of scope rather than silently ignored. The judgment
  ("only matters at high frame rates") turned out wrong in the particulars —
  but because it was *written down*, the M0.2 fix had a paper trail to
  point at.

## Where it is now (drift since 2026-04-20)

- **The per-frame semaphore design was proven wrong nine days later.**
  M0.2's render integration tripped validation VUID-00067: a
  render-finished semaphore, sized per frame-in-flight, can be *re-waited
  by a new submission before the presentation engine finished with it* —
  with 3 images and 2 frame slots, semaphore reuse and image reuse drift
  out of phase. The Phase 10.5 fix: render-finished semaphores became a
  `std::vector` sized by **swap-chain image count**, indexed by
  `image_index` at submit. Today's header shows the hybrid truth: fences
  and image-available semaphores still per-frame arrays (correct — they
  pace the *CPU*), render-finished per-image (correct — it hands off to
  the *presentation engine*). The edge case noted above was exactly this
  bug.
- **Recreation now rebuilds those semaphores too** — sized to the *new*
  image count, which may differ after resize; ordering documented
  in the constructor (`vulkan_context.cpp:104`).
- **`MAX_FRAMES_IN_FLIGHT = 2` and the frame-cycling pattern survive
  untouched** (`vulkan_context.hpp:185`) — every per-frame resource added
  since (M0.2's per-frame recording state, push-constant capture) slots
  into the same indexing scheme this phase established.
- **The per-frame push-constant insight came free.** M0.2's camera-relative
  offset is captured into each frame's command buffer at record time — safe
  under frames-in-flight *by construction* because of this phase's
  per-frame buffers.

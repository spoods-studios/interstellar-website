# M0.2 Phase 10.5 — Semaphore Reuse Fix: Technical Deep-Dive

> Retroactive technical devlog. **Inserted tech-debt phase** — not in the
> original M0.2 roadmap. Code shown **as built on 2026-04-22**; a drift
> section at the end tracks what changed since and why.

## Starting point

Phase 10's debug runs on the AMD Radeon RX 7900 XT (Vulkan 1.4.344) put
`VUID-vkQueueSubmit-pSignalSemaphores-00067` in stderr — 14 hits in ~5
seconds of rendering. The code at fault was M0.1 Phase 4's
frames-in-flight synchronization (2026-04-20), which older
validation layers had not flagged. The bug was filed and closed in
Phase 10.5, inserted between Phases 10 and 11 before the milestone ended.

## What was built

### The race: 2 frame slots, 3 swap chain images

As built in M0.1, every sync object was sized and indexed per frame slot:

```cpp
std::array<vk::raii::Semaphore, MAX_FRAMES_IN_FLIGHT> image_available_semaphores_{nullptr, nullptr};
std::array<vk::raii::Semaphore, MAX_FRAMES_IN_FLIGHT> render_finished_semaphores_{nullptr, nullptr};
std::array<vk::raii::Fence, MAX_FRAMES_IN_FLIGHT> render_fences_{nullptr, nullptr};
```

with `MAX_FRAMES_IN_FLIGHT = 2` and the submit in `render_frame` signaling
`render_finished_semaphores_[current_frame_]`. That is a binary semaphore
with two operations per frame: `vkQueueSubmit` signals it when rendering
finishes, `vkQueuePresentKHR` hands it to the presentation engine as the
present's wait semaphore. The spec requires a signal semaphore to be
unsignaled, with no pending signal or wait operations, when its signal
executes — VUID-00067 is that rule.

The fence does not protect it. `render_fences_[current_frame_]` observes
when the *queue submission* for that frame slot finished executing; the
presentation engine's wait on the render-finished semaphore happens after
that, asynchronously, and core Vulkan provides no way to observe its
completion — there is no fence on present. The swap chain here is
triple-buffered (3 images) while `current_frame_` wraps every 2 frames,
so frame N+2 re-signals the semaphore in slot N mod 2 while the
presentation engine can still hold a pending wait on it from frame N's
present of a different image. `image_available_semaphores_` has no such
problem: its pending wait lives in `vkQueueSubmit`'s `pWaitSemaphores`,
and completion of that same submit is exactly what the fence gates before
the slot is reused. `render_fences_` tracks CPU-side in-flight
work, for which `current_frame_` is the correct key.

### Per-image semaphores, runtime-sized

The header (`vulkan_context.hpp`) changes first: the
`render_finished_semaphores_` member becomes
`std::vector<vk::raii::Semaphore>`, because the swap chain image count is
a runtime value. Construction then splits out of
`create_sync_objects()` into a new method:

```cpp
void VulkanContext::create_render_finished_semaphores() {
    const auto image_count = swapchain_.getImages().size();
    render_finished_semaphores_.clear();
    render_finished_semaphores_.reserve(image_count);
    for (std::size_t i = 0; i < image_count; ++i) {
        render_finished_semaphores_.emplace_back(device_, vk::SemaphoreCreateInfo{});
    }
}
```

The split exists because of ordering: `create_sync_objects()` needs no
swap chain, this method does. The constructor calls it after
`create_swap_chain()`, when the image count is known. The
`.clear()` + `emplace_back` pattern sidesteps a Vulkan-Hpp gotcha:
`operator=` on a live `vk::raii` object leaks the prior Vulkan handle
(Vulkan-Hpp issue #1218); `clear()` runs destructors, which call
`vkDestroySemaphore`.

### The one-word fix

The fix is a 1-line diff in `render_frame`:

```cpp
vk::Semaphore signal_semaphores[] = {*render_finished_semaphores_[image_index]};
```

`image_index` comes from `vkAcquireNextImageKHR`, so the index is the
swap chain image, not the frame slot. Semaphore i is re-signaled only
when image i is re-acquired, and acquire returns image i only after the
presentation engine has finished the prior present of that image —
including its semaphore wait. This is the per-image pattern the Khronos
Vulkan-Guide "Swapchain Semaphore Reuse" chapter prescribes as the
primary solution (also Overv/VulkanTutorial issue #407). The present
block was not edited: it reuses the same `signal_semaphores` local,
so the one edit fixes both the submit-signal and the present-wait index.

### The resize path

One more call is added in `recreate_swap_chain()`:
`device_.waitIdle()` → `create_swap_chain()` →
`create_render_finished_semaphores()` → `clear_resize()`. The image count
can legitimately change on resize, so the vector is rebuilt to what the
new swap chain reports; `waitIdle()` guarantees no in-flight
presentation still holds the old semaphores when `.clear()` destroys them.
`create_sync_objects()` is not re-called — fences and acquire
semaphores persist across resize.

### Verification

49/49 Catch2 tests stayed green after each task; no new tests were added
— the suite pins coordinate math, which this phase does not touch.
A 15-second Debug run with stderr redirected on 2026-04-23 showed zero
VUID-00067 occurrences, against the 14-hit pre-fix baseline. The visual
triangle check and the multi-frame-in-flight stability check both passed.
Code review: 0 critical, 0 warning, 2 info.

## Why it was built this way

- **Per-image semaphores over `VK_KHR_swapchain_maintenance1`:** the
  extension adds `VkSwapchainPresentFenceInfoEXT` — a fence on present —
  which would let the engine observe presentation completion directly and
  shut down without `device_.waitIdle()`. Rejected for M0.2: it needs
  extension-presence detection and a fallback branch, and the cleaner
  shutdown is unused in the current flow. This stays recorded as a
  future lever for frame-pacing, present-timing, or vsync-toggle needs in
  M0.3+.
- **No `MAX_FRAMES_IN_FLIGHT` bump to 3:** aligning frame count to image
  count does not fix the spec violation — the bug is the indexing key,
  not the array size — and it would cascade into
  `image_available_semaphores_`, `render_fences_`, and `command_buffers_`.
- **No SemaphorePool abstraction:** one consumer; "abstract when it
  hurts, not before."
- **Surgical scope:** a debt phase fixes exactly one thing. The full diff
  is 4 files, ~30 net lines; the scope guard verified no other file
  changed.

## Where it is now (drift since 2026-04-22)

- **The fix held.** Later review did not reopen the indexing; no later
  milestone touched it. The only edit inside
  `create_render_finished_semaphores()` since is from 2026-04-25, which
  caches swap chain image handles at creation — the method now reads
  `swapchain_images_.size()` instead of re-querying
  `swapchain_.getImages()`, the direction the phase's own review note had
  suggested.
- **The pattern gained a second consumer.** The M0.4 orbit demo's
  `render_orbit_frame` — today's live render path — signals
  `render_finished_semaphores_[image_index]` the same way
  (`vulkan_context.cpp:1323`).
- **Current locations:** vector declaration at `vulkan_context.hpp:216`
  between the still-per-frame acquire semaphores (:215) and fences
  (:217); `MAX_FRAMES_IN_FLIGHT` still 2 (:185); ctor call with the
  tracking comment at `vulkan_context.cpp:104`, recreate call at :542,
  method at :773, `render_frame` signal site at :935.
- **The future lever is still on the shelf.** That future-lever note
  still stands; `VK_KHR_swapchain_maintenance1` has not been adopted as
  of 2026-07-21.
- **The automated stderr-scan smoke deferred to Phase 11 never landed as
  a test** — `tests/` contains no VUID-scan harness as of 2026-07-21.
  Regression cover is the validation-layers-always-on-in-debug policy
  plus manual verification each milestone.
- **The pattern recurred.** Phase 14.5 (M0.3 — the
  `vk::OutOfDateKHRError` crash) cites Phase 10.5 by name as the
  provenance pattern: M0.1-era swap-chain code surfaced by newer
  machinery, closed in its own inserted phase.

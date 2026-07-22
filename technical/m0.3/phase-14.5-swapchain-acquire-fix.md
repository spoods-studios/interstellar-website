# M0.3 Phase 14.5 — Swapchain Acquire Fix: Technical Deep-Dive

> Retroactive technical devlog. **Inserted tech-debt phase** —
> not in the original M0.3 roadmap, and retroactive twice over: the fix
> landed first (2026-05-23 21:36), the phase was inserted around
> it the same evening (21:58). Code shown **as built on
> 2026-05-23**; a drift section at the end tracks what changed since.

## Starting point

Phase 15's visual check (2026-05-23): the user switched KDE desktops
mid-time-warp and the engine terminated —

```
Fatal error: vk::raii::SwapchainKHR::acquireNextImage: ErrorOutOfDateKHR
```

Any compositor-driven surface invalidation reproduced it: workspace switch,
window minimize/restore, fullscreen toggle. The code at fault was M0.1
Phase 3's acquire error handling (the [[../m0.1/phase-03-rendering-pipeline|Phase 3 post]]
drift section flags the origin; the fix lands here). Two call sites in
`engine/src/vulkan_context.cpp` — `render_frame` at then-line 882,
`render_orbit_frame` at then-1268 — checked the returned Result:

```cpp
auto [acquire_result, image_index] =
    swapchain_.acquireNextImage(UINT64_MAX, *image_available_semaphores_[current_frame_]);

if (acquire_result == vk::Result::eErrorOutOfDateKHR) {
    recreate_swap_chain();
    return;  // Do NOT reset fence — it wasn't signaled by a submit
}
```

That branch is dead code — `acquire_result` can never hold
`eErrorOutOfDateKHR` (next section). The dual-detection contract — SDL
resize events plus Vulkan error codes — existed on the present side only.
The 2026-05-23 decision inserted Phase 14.5 between 14 and 15 — the second
time a debt item got its own dedicated phase before the milestone closed,
citing Phase 10.5 as the precedent: both are M0.1 swap-chain code surfaced
by newer machinery exercising it.

The insertion ran in reverse order. The fix's commit message names Phase
10.5 as the analog and flags the commit as a candidate for retroactive
classification; 22 minutes later a follow-up commit inserted the phase
retroactively, pointing back at the already-landed commit. Landing the fix
first unblocked the re-run immediately.

## What was built

### Why the check was dead code

Vulkan-Hpp generates each command's wrapper from the registry, where every
command declares a success-code list. The throwing overload returns a
`vk::Result` only for codes in that list; any other code is raised as an
exception typed after the error. `vkAcquireNextImageKHR`'s success codes
are `VK_SUCCESS`, `VK_TIMEOUT`, `VK_NOT_READY`, and `VK_SUBOPTIMAL_KHR` —
`VK_ERROR_OUT_OF_DATE_KHR` is not among them, so
`vk::raii::SwapchainKHR::acquireNextImage` raises `vk::OutOfDateKHRError`
before the structured-binding assignment completes. `acquire_result` can
legitimately hold `eSuboptimalKHR`; it can never hold `eErrorOutOfDateKHR`.
The throw propagated past the check to `main()` and terminated the process.

The present side had this right: `present_queue_.presentKHR` — same
overload semantics, `eErrorOutOfDateKHR` likewise absent from `presentKHR`'s
success-code list — was wrapped in try/catch at then-lines 924 and 1304,
in place since Phase 10. The acquire side never got the same treatment.

### The fix

The fix, at the `render_frame` site (the `render_orbit_frame` site is
identical plus a pointer comment):

```cpp
uint32_t image_index;
try {
    auto [acquire_result, idx] =
        swapchain_.acquireNextImage(UINT64_MAX, *image_available_semaphores_[current_frame_]);
    image_index = idx;
    if (acquire_result == vk::Result::eSuboptimalKHR) {
        resize_requested_ = true;
    }
} catch (const vk::OutOfDateKHRError&) {
    recreate_swap_chain();
    return;  // Fence not signaled by a submit — do not reset
}
```

Three load-bearing details. `image_index` is hoisted out of the structured
binding, whose scope is now the try block. `eSuboptimalKHR` stays a Result
check inside the try — it IS a success code, the acquired image is usable,
and `resize_requested_` defers recreation to after present instead of
dropping the frame. The early return skips `resetFences`: no submit will
signal the fence this frame, and resetting it would deadlock the next
`waitForFences` — the ordering comment ("Reset fence AFTER successful
acquire") predates the fix; only the mechanism for reaching the recreate
path changed. Net diff: `engine/src/vulkan_context.cpp` only, +27/−18.

### Verification

`ctest` 115/115 green Release on Fedora dev — no numeric path touched, M0.2
math-lock unbroken. Then the crashing scenario re-run: relaunch, switch
desktops mid-time-warp. The run log (`run-20260523-213939.log`) shows clean
cycles — `Window minimized -- pausing`, `Window restored -- resuming`,
`Swap chain recreated: 2552x1556` — zero terminations until user-initiated
shutdown.

## Why it was built this way

- **Mirror the present-side pattern rather than invent a new shape.** The
  present try/catch had survived since Phase 10 against the same overload
  semantics; the acquire sites adopt its exact structure, so both halves of
  the error-code contract now read the same way.
- **The explanation lives at the call site.** The fix embeds a five-line
  comment stating the throwing-overload rule, because the bug's shape — a
  plausible-looking Result check that cannot fire — invites
  reintroduction by pattern-matching against tutorial code.
- **Scope split across three tracks.** The same visual-check session
  surfaced five findings. The new-code bugs — trail pixels, HUD text,
  `rel_energy_error` — were in Phase 15 deliverables and stayed in that
  phase's fix-loop; the two M0.1-era shader deficiencies became Phase 15.5.
  Only this acquire fix was small enough, and already landed, to close
  retroactively the same evening.

## Where it is now (drift since 2026-05-23)

- **The blocks are byte-identical to the original fix.** Git line-history
  for the acquire regions lists no later commit. Line numbers moved as
  Phase 15.5's aspect work, the M0.3 gate fixes, and two vk-hpp portability
  fixes edited elsewhere in the file: the catch handlers sit today at
  `vulkan_context.cpp:920`/`:962` (`render_frame` acquire/present) and
  `:1310`/`:1349` (`render_orbit_frame`).
- **The general rule held.** A follow-up commit (22:06, 30 minutes after
  the fix) wrote it down against the four handler bodies (`:921,963,1311,
  1350` today): check a wrapper's success-code list before trusting a
  returned Result.
- **Still exactly two acquire call sites**, with `render_orbit_frame` —
  today's live render path — carrying the pattern. The 2026-05-23 decision
  that scoped Phase 15.5 cited this fix and Phase 10.5's as the precedent.

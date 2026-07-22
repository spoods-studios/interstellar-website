# M0.1 Phase 2 — Swap Chain: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-04-09**; a
> drift section at the end tracks what changed since and why.

## Starting point

Phase 1 left a window with a valid Vulkan surface — and nothing to render
into. Unlike OpenGL, Vulkan has no default framebuffer: if you want images to
draw to and a way to hand them to the display, you build that machinery
yourself. That machinery is the **swap chain** — a driver-owned queue of
images that rotate between "being rendered to" and "being shown on screen."

Phase 2's job: create it, wrap its images in views, and survive window
resizes. One plan, five tasks, one commit: the right format, present mode,
and image count; image views; and resize recreation without crashes or
validation errors.

## What was added, piece by piece

### `choose_surface_format` — why sRGB

```cpp
for (const auto& format : formats) {
    if (format.format == vk::Format::eB8G8R8A8Srgb &&
        format.colorSpace == vk::ColorSpaceKHR::eSrgbNonlinear) {
        return format;
    }
}
return formats[0];
```

Rendering linear math into a non-sRGB surface makes everything look
mysteriously dark, because the linear values get displayed as
if they were gamma-encoded. `B8G8R8A8_SRGB` +
`SRGB_NONLINEAR` makes the hardware do the linear→gamma conversion at write
time, for free. B8G8R8A8 (not RGBA) because it's the native desktop swap
format on most hardware. Fallback is `formats[0]` — crude, but a surface
always reports at least one format.

### `choose_present_mode` — the NVIDIA input-lag pitfall

```cpp
for (const auto& mode : modes) {
    if (mode == vk::PresentModeKHR::eMailbox) return mode;
}
return vk::PresentModeKHR::eFifo;
```

Four present modes exist; two matter here. FIFO is the "vsync queue" mode
and the only one the spec *guarantees*. NVIDIA Windows drivers have a
documented real-world failure: they can queue FIFO frames deep
enough to add on the order of a second of input lag.
MAILBOX replaces the queued image instead of stacking behind it — low
latency, no tearing — and is well-supported on desktop NVIDIA. Preference
order: MAILBOX, fall back to the guaranteed FIFO.

### Image count — `minImageCount + 1`

```cpp
uint32_t image_count = capabilities.minImageCount + 1;
if (capabilities.maxImageCount > 0) {
    image_count = std::min(image_count, capabilities.maxImageCount);
}
```

Ask for one more than the driver's minimum: with exactly the minimum, the CPU
can end up blocked waiting for the driver to release an image, which on a
60 Hz FIFO display quantizes you straight to a 30 FPS floor. One extra image
is effectively triple buffering. The clamp guard matters because
`maxImageCount == 0` is Vulkan's way of saying "no upper limit" — a raw
`std::min` against 0 would break it.

### `choose_extent` — the UINT32_MAX sentinel

```cpp
if (capabilities.currentExtent.width != std::numeric_limits<uint32_t>::max()) {
    return capabilities.currentExtent;
}
// otherwise: SDL_Vulkan_GetDrawableSize + clamp to min/max bounds
```

Normally the surface tells you its size via `currentExtent`. But some
windowing systems (Wayland notably) report `UINT32_MAX` — meaning "the swap
chain decides the size, not the surface." Then and only then you compute it
yourself: the DPI-safe drawable size from SDL, clamped to the capability
bounds — exactly the `get_drawable_extent` groundwork Phase 1 laid down a
phase early.

### Sharing mode — Phase 1's queue detection pays off

```cpp
if (graphics_queue_family_index_ != present_queue_family_index_) {
    create_info.imageSharingMode = vk::SharingMode::eConcurrent;
    create_info.queueFamilyIndexCount = ...;
    create_info.pQueueFamilyIndices = queue_family_indices.data();
} else {
    create_info.imageSharingMode = vk::SharingMode::eExclusive;
}
```

EXCLUSIVE means one queue family owns images at a time — fastest, no
ownership transfers. CONCURRENT allows both families at a performance cost.
Because Phase 1 preferred a combined graphics+present family, the common path
is EXCLUSIVE. One subtle lifetime trap: the
`queue_family_indices` array must outlive `create_info` until the create call
— Vulkan create-infos store *pointers*, and a dangling one is a
silent-corruption class of bug. Hence the array sits in function scope above
the branch.

### `oldSwapchain` — recreation as a first-class design

```cpp
create_info.oldSwapchain = *swapchain_;       // VK_NULL_HANDLE on first run
swapchain_image_views_.clear();               // views die BEFORE their chain
swapchain_ = vk::raii::SwapchainKHR{device_, create_info};
```

The member is declared `vk::raii::SwapchainKHR swapchain_{nullptr}` — so on
first creation, dereferencing it yields `VK_NULL_HANDLE`, which is exactly
what Vulkan expects for "no previous swap chain." On recreation the old
handle goes in, letting the driver reuse resources and keep presenting old
frames during the swap. One code path serves both cases; no `if (first_time)`
anywhere. The image-view clear must come first: views reference swap-chain
images, so they die before the chain that owns them.

### Image views — the ownership asymmetry

```cpp
auto images = swapchain_.getImages();   // raw VkImage handles — NOT owned by us
for (const auto& image : images) {
    // ... vk::ImageViewCreateInfo ...
    swapchain_image_views_.emplace_back(device_, view_info);  // owned wrappers
}
```

Known gotcha: `getImages()` returns raw handles because the *swap chain*
owns those images — wrap them in `vk::raii::Image` and the destructor
double-frees. The views, by contrast, are yours: created by you, owned by
you, RAII-wrapped. A view is the "lens" a pipeline uses to interpret an image
(2D, color aspect, one mip, one layer); Phase 3's dynamic rendering will
attach to these directly — no framebuffer objects needed on Vulkan 1.3.

### `recreate_swap_chain` — consuming Phase 1's flag

```cpp
void VulkanContext::recreate_swap_chain() {
    device_.waitIdle();
    create_swap_chain();
    clear_resize();
}
```

And in the main loop, after event processing:

```cpp
if (vulkan_context.resize_requested()) {
    vulkan_context.recreate_swap_chain();
}
```

The `resize_requested` flag Phase 1 planted finally has a consumer.
`waitIdle` is the sledgehammer sync — block until the GPU finishes
everything, then rebuild. Correct, simple, and fine at this stage: resizes
are rare, and there was no in-flight frame machinery yet to be smarter with
(that arrives in Phase 4).

One structural note: `create_swap_chain()` is called from the constructor
*body*, not the initializer chain like everything in Phase 1. Deliberate —
the swap chain is the first resource that gets *re*-created at runtime, so it
needs an assignable member (`{nullptr}` default + assignment) rather than a
construct-once chain slot. The member still sits after `device_` in
declaration order, keeping RAII teardown correct: views → swap chain → device.

## Why it was built this way

- **Configuration fixed before code.** Format, present mode, image count,
  extent policy, sharing mode, `oldSwapchain` — the whole creation config
  follows one recommended configuration, each choice with the rationale
  above.
- **Dynamic rendering kept recreation small.** Tutorial-era Vulkan recreates
  framebuffers + render passes on resize. On Vulkan 1.3 dynamic rendering
  there are none — recreation is swap chain + views only. A milestone-wide
  architecture choice, locked in Phase 3's requirements.
- **Known limits deferred, on record.** This phase does not handle
  `OutOfDateKHR` from acquire/present (needs Phase 4's frame loop),
  fence-reset ordering, or layout transitions. Each is tagged with the phase
  that owns it.

## Where it is now (drift since 2026-04-09)

- **The choosers survive nearly verbatim** — format, present mode, extent
  logic, `minImageCount + 1`, sharing-mode branch, `oldSwapchain` pattern:
  all intact in today's `engine/src/vulkan_context.cpp:427+`.
- **Recreation grew a semaphore rebuild (M0.2, Phase 10.5).** Validation
  VUID-00067 exposed a real design bug: render-finished semaphores must be
  **per swap-chain image** (indexed by acquired image index), not per
  frame-in-flight. `recreate_swap_chain()` now rebuilds
  `render_finished_semaphores_` after `create_swap_chain()`, with a
  documented ordering constraint: semaphore creation reads the runtime image
  count, so it must follow chain creation — see the comments at
  `vulkan_context.cpp:770+`.
- **`getImages()` is now called once, not per frame.** A later fix
  (M0.2) flagged the per-frame query; images are cached into
  `swapchain_images_` at creation.
- **The deferred `OutOfDateKHR` handling landed in M0.2, Phase 14.5.**
  vk-hpp's throwing overload means acquire *throws*
  `vk::OutOfDateKHRError` rather than returning the error code — the live
  code catches it and routes into the same `resize_requested_` →
  `recreate_swap_chain()` path built here.
- **Empty present-mode list now throws explicitly.** FIFO is
  spec-guaranteed, so an empty query result means a broken driver/surface —
  the code now fails loudly with the device name instead of returning a
  mode the surface never promised.

# M0.1 Phase 1 — Window + Surface: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-04-08**; a
> drift section at the end tracks what changed since and why.

## Starting point

Before this phase, `VulkanContext` already existed: `vk::raii::Context`,
instance with validation layers, debug messenger, physical-device pick,
logical device, one graphics queue. But it was headless — `main.cpp` created
the context, printed the device name, and blocked on `std::cin.get()`. No
window, no surface, nowhere to render. Platform at the time: Windows,
MSVC, vcpkg manifest mode.

Phase 1's job: everything windowing — and nothing else. No swap chain, no
pixels. The boundary was drawn so each later phase adds exactly one layer of
the Vulkan stack (swap chain → pipeline → sync → shutdown → CI).

## What was added, piece by piece

### `SdlGuard` — the destruction-ordering trick

The subtlest problem in the whole phase, and it's pure C++, not Vulkan.
SDL needs `SDL_Init` before anything and `SDL_Quit` after everything. The
naive move — call `SDL_Quit()` in `~VulkanContext()`'s body — is wrong,
because a destructor **body runs before member destructors**. The body would
kill SDL while `vk::raii::SurfaceKHR` (created from an SDL window) was still
alive.

The fix exploits the same rule in reverse: members are destroyed in reverse
declaration order, so a tiny RAII struct declared **first** is destroyed
**last**:

```cpp
struct SdlGuard {
    SdlGuard()  { if (SDL_Init(SDL_INIT_VIDEO) != 0) throw ...; }
    ~SdlGuard() { SDL_Quit(); }
    SdlGuard(const SdlGuard&) = delete;
    SdlGuard& operator=(const SdlGuard&) = delete;
};

// members:
SdlGuard sdl_guard_;      // first declared → destroyed LAST
vk::raii::Context context_;
std::unique_ptr<SDL_Window, WindowDeleter> window_;
vk::raii::Instance instance_;
...
```

Why this shape and not alternatives: `SDL_Quit` in `main.cpp` would work but
violates the standing rule that SDL lifetime belongs to `VulkanContext`; a
manual destructor juggling order by hand is exactly the error-prone thing
RAII exists to kill.
The compiler now *enforces* teardown order. `WindowDeleter` on a `unique_ptr`
does the same for the one raw C handle (`SDL_Window*` — SDL2 predates RAII),
keeping `~VulkanContext() = default`.

### Constructor chain — declaration order is the architecture

The whole class initializes through one initializer list, one helper per
resource:

```cpp
VulkanContext::VulkanContext()
    : sdl_guard_{}                     // SDL alive
    , context_{}
    , window_{create_window()}         // window BEFORE instance (see below)
    , instance_{create_instance()}     // now includes SDL's extensions
    , debug_messenger_{create_debug_messenger()}
    , surface_{create_surface()}       // needs instance
    , physical_device_{pick_physical_device()}  // needs surface (present check)
    , device_{create_logical_device()} // enables VK_KHR_swapchain
    , graphics_queue_{device_.getQueue(graphics_queue_family_index_, 0)}
    , present_queue_{device_.getQueue(present_queue_family_index_, 0)}
```

C++ initializes members in **declaration** order regardless of what the list
says, so declaration order must equal dependency order (MSVC C5038 warns on
mismatch). That makes the member list a machine-checked statement of the
Vulkan bring-up dependency graph. This was already the house pattern
(helper-per-resource); the phase inserted three links into the chain.

### Why the window must exist before the instance

Non-obvious ordering: you'd think the window is a "presentation detail" that
comes after Vulkan is up. Backwards. `SDL_Vulkan_GetInstanceExtensions`
requires a live `SDL_WINDOW_VULKAN` window because the extension set is
platform-dependent — `VK_KHR_surface` plus `VK_KHR_win32_surface` /
`VK_KHR_xlib_surface` / `VK_KHR_wayland_surface`, whichever the windowing
system is. Those go into `vkCreateInstance`; miss them and surface
creation fails later. Hence the two-phase query pattern (count, then fill)
in `get_required_extensions()`, replacing a TODO left there when the
instance code was first written:

```cpp
unsigned int sdl_ext_count = 0;
SDL_Vulkan_GetInstanceExtensions(window_.get(), &sdl_ext_count, nullptr);
std::vector<const char*> extensions(sdl_ext_count);
SDL_Vulkan_GetInstanceExtensions(window_.get(), &sdl_ext_count, extensions.data());
if (ENABLE_VALIDATION) extensions.push_back(VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
```

### Surface — one line of C bridged into RAII

`SDL_Vulkan_CreateSurface` hands back a raw `VkSurfaceKHR`. The rule:
wrap it immediately, never let a raw handle live loose:

```cpp
vk::raii::SurfaceKHR VulkanContext::create_surface() {
    VkSurfaceKHR raw_surface{};
    if (SDL_Vulkan_CreateSurface(window_.get(), *instance_, &raw_surface) != SDL_TRUE)
        throw std::runtime_error(...);
    return vk::raii::SurfaceKHR{instance_, raw_surface};  // taking-ownership ctor
}
```

The taking-ownership constructor was verified against the installed SDK
header (`vulkan_raii.hpp:14075`) rather than trusted from tutorials — most
online examples use the older `vk::UniqueSurfaceKHR` style. Notable asymmetry:
SDL *creates* the surface but has no `SDL_Vulkan_DestroySurface`; destruction
is Vulkan's job (`vkDestroySurfaceKHR`, needs the instance, not the window),
which is exactly what the RAII wrapper does.

### Present queue — the spec doesn't promise what you'd assume

A queue family that draws can't necessarily *present to this surface* — on
desktop GPUs graphics and present are almost always family 0, but the spec
allows them to differ. So `QueueFamilyIndices` grew a `present` field, and
`find_queue_families` now asks per family:

```cpp
vk::Bool32 present_support = device.getSurfaceSupportKHR(i, *surface_);
if (present_support) indices.present = i;
// Prefer combined graphics+present family
if (indices.graphics == indices.present && indices.is_complete()) break;
```

Combined-family preference matters later: same family means no
queue-ownership transfers between draw and present. `create_logical_device`
deduplicates via `std::set<uint32_t>` so one combined family yields one
`DeviceQueueCreateInfo`, two distinct families yield two. Device suitability
also grew `check_device_extension_support` — a GPU without `VK_KHR_swapchain`
(compute-only devices exist) is rejected at pick time, not discovered at
swap-chain-creation time in Phase 2. Enabling the extension now, one phase
early, was deliberate Phase-2 readiness.

### `get_drawable_extent` — HiDPI honesty

Two sizes exist: logical window size (`SDL_GetWindowSize`) and pixel size
(`SDL_Vulkan_GetDrawableSize`). On a HiDPI display they differ, and a swap
chain built from the logical size renders at the wrong resolution. The fix
picks the drawable size, then clamps it to the surface's `minImageExtent`/
`maxImageExtent` capabilities — the two classic swap-chain-sizing traps
closed before the swap chain even exists.

### Event loop — main.cpp drives, VulkanContext serves

Deliberate split: VulkanContext owns resources; the *application* owns
the loop. `SDL_PollEvent` drains all pending events, then the frame would
render (a comment marked the future render site). Three behaviors:

- **Quit/close** → clean scope exit, destructors do the rest.
- **Resize** → `notify_resize()` sets `resize_requested_` — Phase 1 only
  detects; Phase 2 consumes the flag to recreate the swap chain. This is
  half of a dual detection design. The other half (catching
  `VK_ERROR_OUT_OF_DATE_KHR` from acquire/present) couldn't exist yet — no
  swap chain — but was designed now: drivers differ in when they report
  OUT_OF_DATE, and Wayland never reports it at all.
- **Minimize** → drawable size becomes 0×0, which is invalid for swap chains.
  Instead of busy-spinning, the loop blocks on `SDL_WaitEvent` and pushes the
  woken event back with `SDL_PushEvent` so the normal poll loop processes it.
  CPU drops to ~zero while minimized.

### The one deviation: `sdl2[vulkan]`

Smoke test failed: vcpkg's SDL2 was installed without its `vulkan` feature, so
`SDL_CreateWindow(SDL_WINDOW_VULKAN)` errored with "Vulkan support is either
not configured in SDL". Fix: `{"name": "sdl2", "features": ["vulkan"]}` in
`vcpkg.json`. Classic dependency-feature-flag trap — the headers compile fine;
only runtime reveals the missing loader glue.

## Why it was built this way (the standing decisions)

- **Single class, no Window abstraction.** A split (Window
  class + VulkanContext taking a surface) was on the table and rejected:
  "abstract when it hurts, not before." At ~350 projected lines, one class was
  honest about the coupling — window, surface, and device selection genuinely
  depend on each other.
- **RAII everywhere, C only at the SDL boundary.** Every Vulkan object rides
  `vk::raii`; the two SDL C artifacts (library lifetime, window pointer) each
  got a minimal RAII shim rather than manual cleanup.

## Where it is now (drift since 2026-04-08)

- **All core pieces survive intact** in today's tree: `SdlGuard`,
  `WindowDeleter`, member-order destruction, combined-family preference,
  extent clamping, the loop-in-main split (`engine/src/vulkan_context.cpp:130`
  still creates the same 1280×720 window).
- **The ~350-line assumption blew past 4×.** `vulkan_context.cpp` is ~1360
  lines after swap chain, pipeline, sync, and per-scale depth work. The call
  that one class was manageable was right for M0.1 and increasingly wrong
  after; render architecture got split in later milestones, but
  VulkanContext remains the big owner.
- **Dual detection's second half landed in M0.2.** The plan
  assumed you check acquire's *return code* for OUT_OF_DATE. In vk-hpp's
  throwing overload, `eErrorOutOfDateKHR` isn't in the success-code list — it
  *throws* `vk::OutOfDateKHRError`, making post-return checks dead code. The
  live code wraps acquire/present in try/catch and sets `resize_requested_`
  from the handler (`vulkan_context.cpp:906–920`). The Phase-1 flag design
  survived; the detection mechanism had to adapt to the binding's exception
  model.
- **Platform moved.** Built on Windows/MSVC/vcpkg; primary development is now
  Fedora/GCC with MSVC as a CI lane. The `sdl2[vulkan]` vcpkg fix still lives
  in the manifest for the Windows lane; Fedora gets SDL2 via dnf.
- **`main.cpp` grew from 71 to ~605 lines** — the "// Future: render frame
  here" comment became the simulation/render loop, and resize handling now
  feeds actual swap-chain recreation.

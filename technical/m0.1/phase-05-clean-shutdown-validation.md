# M0.1 Phase 5 — Clean Shutdown + Validation: Technical Deep-Dive

> Retroactive technical devlog. Audited **2026-04-13** — docs only; drift
> section at the end. Shortest phase of the milestone: zero code changes,
> by design.

## Starting point

Four phases of resource creation: SDL, window, instance, surface, device,
queues, swap chain, image views, pipeline, command pool, sync objects.
Phase 5 audits the teardown. From the phase boundary: "the main
deliverable is confidence that the engine bootstrap is solid, not new
features." Three things get audited: destruction in dependency order,
zero validation errors *and* warnings on a full run-and-close cycle, and
that RAII handles all cleanup.

The expected outcome, stated up front in the plan: no code changes needed,
because Phases 1–4 were built RAII-first. The phase exists to *prove* that
instead of assuming it.

## The audit

### The destruction chain

C++ destroys members in reverse declaration order, so the entire shutdown
sequence is encoded in one header block. The audit walks it bottom-up
(first destroyed → last destroyed):

```
fences / semaphores        (sync objects release first)
→ command buffers → command pool
→ pipeline → pipeline layout
→ image views → swap chain     (views before the chain that owns their images)
→ queues → device              (everything device-created is gone by now)
→ surface → debug messenger → instance
→ window                       (Vulkan fully torn down before SDL window dies)
→ SdlGuard                     (SDL_Quit, the last act)
```

Every arrow is a Vulkan dependency rule; every one is enforced by
declaration order rather than code. The audit's job was to check the header
against this chain — and it matched, because Phases 1–4 each inserted new
members at the dependency-correct position as they went (Phase 1's
initializer-list ordering, Phase 2's "after device_", Phase 4's array
placement).

### No manual teardown anywhere

```
grep -rn "vkDestroy|vkFree" engine/  →  comments only
```

Every Vulkan object in the codebase is a `vk::raii::*` wrapper. The one
grep hit is a comment explaining that `vk::raii::SurfaceKHR` calls
`vkDestroySurfaceKHR` itself. Zero manual destroy calls means zero
opportunities for double-free, use-after-free, or leaked handles at
shutdown — the whole bug class is structurally absent.

### Zero validation output, and the one runtime rule

The single thing RAII cannot do: wait for the GPU. Destroying resources the
GPU is still using is a validation storm regardless of destruction order.
The guard is one line, placed in Phase 3 as a deviation and verified here:

```cpp
vulkan_context.device().waitIdle();   // main.cpp, before scope exit
```

`waitIdle` at shutdown is the correct sledgehammer — same reasoning as
swap-chain recreation: a rare event where a full stall costs nothing and
removes every ordering question. One edge case got a decision: if a
resize was pending at close, skip the recreation — RAII destroys the old
chain regardless; rebuilding a swap chain you're about to destroy is wasted
work.

The bar itself is strict on purpose: zero errors *and* zero
warnings, root-cause fixes only, no suppression. Verified by running,
resizing, minimizing, closing — with all stderr captured.

## Why a zero-diff phase exists

The milestone treats verification as a deliverable. Phases 1–4 each carried
a "clean shutdown" assumption forward; this phase converts the assumption
into an audited claim with acceptance criteria (grep results, header order,
the waitIdle call site). M0.2
built on a bootstrap whose teardown was checked, not presumed — and the
audit doc is the artifact later phases point at when shutdown questions
come up.

## Where it is now (drift since 2026-04-13)

- **The destruction chain held through 4× growth.** Today's VulkanContext
  declares ~47 RAII members and arrays (depth resources, per-scale passes,
  HUD pipeline, semaphore vectors) — all slotted into the same
  declaration-order scheme. The manual-destroy grep still returns zero.
- **The zero-validation bar persisted.** Validation layers stay on in debug
  and VUIDs get fixed in order; since M0.2 every milestone open captures a
  debug VUID baseline, so any new validation output is attributable to the
  current milestone's changes. Phase 10.5's VUID-00067 catch — the
  per-image semaphore fix — happened because this bar was enforced, not
  luck.
- **`waitIdle()` at shutdown survives verbatim** (`engine/src/main.cpp:595`)
  — same line, same placement, now guarding a vastly larger resource set.

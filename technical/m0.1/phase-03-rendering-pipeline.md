# M0.1 Phase 3 — Rendering Pipeline: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-04-11**; a
> drift section at the end tracks what changed since and why.

## Starting point

Window, surface, swap chain, image views — all plumbing, zero pixels. Phase 3
is the payoff phase: a colored triangle on screen, via the modern Vulkan 1.3
path. 28 locked decisions, two plans, and the biggest single code drop of
the milestone: shaders, a CMake compilation pipeline, the graphics
pipeline, command recording, and a minimal render loop — 348 lines in the
main commit.

The headline architecture call: **dynamic rendering** (`vkCmdBeginRendering`
/ `vkCmdEndRendering`, Vulkan 1.3 core). Tutorial-era Vulkan makes you build
`VkRenderPass` and `VkFramebuffer` objects that describe your attachments up
front; dynamic rendering deletes both concepts — you say "render into this
image view now." The cost: nothing manages image layouts for you
anymore. Layout transitions become your problem, handled with explicit
barriers. That rule was pinned early: *no legacy VkRenderPass objects may
exist.*

## What was added, piece by piece

### Shaders — the triangle with no vertex buffer

```glsl
// triangle.vert
vec2 positions[3] = vec2[](
    vec2( 0.0, -0.5), vec2( 0.5,  0.5), vec2(-0.5,  0.5)
);
vec3 colors[3] = vec3[](
    vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0)
);
void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    fragColor = colors[gl_VertexIndex];
}
```

Positions and colors live *in the shader*, indexed by `gl_VertexIndex`
— so the pipeline's vertex-input state is completely empty. No
vertex buffer, no memory allocation, no attribute descriptions. Deliberate
scope control: buffers and MVP matrices are M0.2+ work, and the first
triangle needs none of it. The fragment shader is
four lines: pass the interpolated color through with alpha 1. The GPU's
rasterizer does the red→green→blue gradient for free — that gradient *is*
the proof that interpolation, and therefore the whole pipeline, works.

### CMake shader compilation — SPIR-V as a build artifact

```cmake
find_program(GLSLC glslc HINTS $ENV{VULKAN_SDK}/Bin REQUIRED)
add_custom_command(
    OUTPUT ${SHADER_SPV}
    COMMAND ${GLSLC} ${SHADER_SOURCE} -o ${SHADER_SPV}
    DEPENDS ${SHADER_SOURCE}
)
add_custom_target(shaders DEPENDS ${SHADER_SPV_FILES})
add_dependencies(interstellar shaders)
```

Vulkan doesn't consume GLSL — it consumes SPIR-V bytecode. The choice
was build-time compilation via `glslc`: shaders are per-file custom commands
with dependency tracking, so editing a `.vert` rebuilds exactly that `.spv`
and relinks nothing. The `add_dependencies` line makes it impossible to run
the app with stale shaders. Loading them back has one catalogued trap:
`codeSize` is in **bytes**, but `pCode` is a `uint32_t*` — the
loader reads into `std::vector<uint32_t>` and multiplies by
`sizeof(uint32_t)` at module creation.

### The graphics pipeline — 150 lines of explicit

Vulkan's pipeline object bakes nearly every GPU state decision into one
immutable object. The phase's config, each line a locked decision:

- **Input assembly:** `TRIANGLE_LIST`.
- **Rasterization:** fill mode, **no culling**, counter-clockwise front face.
  Cull-none is a first-triangle survival rule: get the
  winding wrong with backface culling on and you stare at a blank screen
  wondering which of fifty settings is wrong.
- **Color write mask: explicitly R|G|B|A.** The nastiest pitfall in
  the catalog: a zero-initialized write mask is *valid* Vulkan —
  no validation error, no warning, nothing ever written. Silent blank
  screen.
- **Dynamic state: viewport + scissor** — so window resizes never
  rebuild the pipeline; the values are set per-frame during recording. The
  companion trap: `viewportCount`/`scissorCount` must still be 1
  in the static create-info even though the values are dynamic.
- **Empty pipeline layout** — no descriptors, no push constants yet,
  but the layout object itself is still mandatory: you can't pass
  `VK_NULL_HANDLE`.
- **The dynamic-rendering handshake:**

```cpp
vk::PipelineRenderingCreateInfo rendering_info{};
rendering_info.colorAttachmentCount = 1;
rendering_info.pColorAttachmentFormats = &swapchain_format_;

pipeline_info.pNext = &rendering_info;
pipeline_info.renderPass = VK_NULL_HANDLE;   // no legacy render pass
```

With no render pass to describe attachments, the pipeline learns its target
format through this `pNext` extension struct — and that format must match
what's attached at draw time, or undefined behavior.

Shader modules are created as locals inside `create_graphics_pipeline()` and
die at scope exit — once the pipeline is baked, the modules are dead weight.
RAII makes the optimization a non-event.

### Command recording — the state-machine script

The per-frame command buffer follows a strict sequence, because a
command buffer is a state machine — each command depends on state set by the
ones before it:

```
begin
  barrier: UNDEFINED → COLOR_ATTACHMENT_OPTIMAL
  beginRendering (clear to cornflower blue)
    bindPipeline
    setViewport / setScissor      // AFTER bind, BEFORE draw (Gotcha 4)
    draw(3, 1, 0, 0)
  endRendering
  barrier: COLOR_ATTACHMENT_OPTIMAL → PRESENT_SRC_KHR
end
```

The two barriers are the price of dynamic rendering, written with the
synchronization2 API (`vk::ImageMemoryBarrier2`, already enabled on the
device since the pre-phase-1 code). The first says "this image's old contents
are garbage (UNDEFINED), make it writable as a color attachment before
color-output stage." The second flips it to `PRESENT_SRC_KHR` so the
presentation engine may read it. Swap-chain images arrive in UNDEFINED layout
every acquire — these transitions run every frame, forever.

### `render_frame` — minimal sync, one honest mistake

Phase 3's loop is single-frame by design: one fence, two semaphores;
proper multi-frame-in-flight is Phase 4's whole job.

```cpp
auto wait_result = device_.waitForFences(*render_fence_, vk::True, UINT64_MAX);
auto [acquire_result, image_index] =
    swapchain_.acquireNextImage(UINT64_MAX, *image_available_semaphore_);

if (acquire_result == vk::Result::eErrorOutOfDateKHR) {
    recreate_swap_chain();
    return;                          // do NOT reset fence
}
device_.resetFences(*render_fence_); // reset AFTER successful acquire (D-24)
```

The fence is created pre-signaled (`eSignaled`) so frame zero doesn't
deadlock waiting on a fence no submit ever signaled, and it's reset only
*after* a successful acquire — reset-then-bail on OUT_OF_DATE is a classic
self-inflicted deadlock, the same pattern flagged in Phase 2.

The mistake: the `acquire_result == eErrorOutOfDateKHR` comparison is
**dead code**. vk-hpp's throwing overload never returns that value — it
throws `vk::OutOfDateKHRError`, because the error code isn't in the
function's success-code list. The present call at the bottom of the same
function **is** wrapped in try/catch; acquire is not. Nothing failed
visibly — `eSuboptimalKHR` (a real success code) covers the common resize
path — so the bug slept until a real out-of-date event crashed it during
M0.3 validation, fixed in Phase 14.5.

### The one deviation

The plan omitted `device().waitIdle()` before
shutdown. Without it, RAII teardown can start destroying resources the GPU is
still using — validation errors on every exit. Added in-task; the eventual
Phase 5 (clean shutdown) formalized the territory.

## Why it was built this way

- **Dynamic rendering was the forward path.** Most tutorials still teach
  render passes; this phase followed the Khronos `hpp_hello_triangle_1_3`
  sample (exact stack match: vulkan.hpp, RAII, 1.3, dynamic rendering) so the
  engine never carries legacy objects it would have to migrate off later.
- **Ten pitfalls anticipated, zero rediscovered.** Every gotcha in the config
  above (write mask, viewport counts, byte sizes, layout-format match) was
  already identified before the code was written.
- **Scope drawn at "pixels, not performance."** Single-frame sync with a
  named successor phase, hardcoded geometry with a named successor milestone.
  Both deferrals have owners; neither leaked.

## Where it is now (drift since 2026-04-11)

- **The triangle still renders.** `cmd.draw(3, 1, 0, 0)` still runs every frame
  (`engine/src/vulkan_context.cpp:865`), and `triangle.vert`/`triangle.frag`
  still compile in the CMake shader list — joined by `disk`, `line`, and
  `hud` shaders. M0.2 gave the shader a push constant carrying a
  camera-relative offset, turning the test triangle into a *world-anchored*
  object that proves the coordinate pipeline: if the triangle stays put while
  the camera flies, camera-relative rendering works.
- **The acquire dead-code bug was fixed in M0.3 Phase 14.5** —
  acquire wrapped in try/catch, matching the present path this phase got
  right.
- **Single-frame sync lasted exactly one phase**, replaced by Phase 4's
  frames-in-flight arrays — and the sync design kept evolving (Phase 10.5's
  per-image semaphores, the M0.2 render integration).
- **The pipeline count grew, the pattern didn't change.** Today's multi-pass
  renderer (separate depth per scale, HUD pass) is built from the same
  recipe: `PipelineRenderingCreateInfo` in `pNext`, explicit barriers,
  dynamic viewport/scissor. Phase 3's 150-line pipeline function became the
  template for every pipeline after it.
- **CI still checks this phase's output.** The Windows lane's shader step
  verifies `build/shaders/triangle.vert.spv` exists on every push — Phase 6's
  CI guarding Phase 3's artifact, eight milestones later.

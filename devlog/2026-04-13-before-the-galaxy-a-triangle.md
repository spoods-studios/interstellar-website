---
milestone: M0.1
title: Before the Galaxy, a Triangle
date: 2026-04-13
status: published
published_date: 2026-06-15
discord_post_id: "1497781302118715554"
audience: devlog
---

# Before the Galaxy, a Triangle

Every engine starts with a triangle. Mine took six phases of work to draw one — a single
colored triangle on a cornflower-blue background. It's not much to look at. Getting those
few hundred pixels on screen meant building the whole rendering foundation from scratch.
No existing engine ran underneath, doing the work for me. This is the first brick.

## What changed

I'm building the graphics on Vulkan, which sits close to the hardware. Vulkan gives me the
kind of control a higher-level engine would fight me on — separate depth buffers for wildly
different scales, real atmospheric scattering, both needed in later milestones. That control
is why I picked it.

The cost is that nothing is automatic. To put one triangle on screen, I had to build:

1. A window and a drawing surface
2. A swap chain — the conveyor belt of images the screen flips through
3. A full graphics pipeline compiled from my own shaders
4. Synchronization that keeps the GPU and CPU from tripping over each other
5. A clean shutdown that tears it all back down in the right order

Vulkan's built-in correctness checker came back completely silent. Zero errors. That
silence is the whole milestone.

## The deep end

Three bugs from this milestone are worth explaining, because none of them announced
themselves.

The first was a deadlock. Vulkan uses "fences" to let the CPU wait for the GPU to finish a
frame. I was resetting the fence too early, before confirming the frame had actually
started. When the window got resized at the wrong moment, the frame would bail out. The
fence would never get signaled. The engine would freeze forever, with no error explaining
why. The fix was a one-line reorder: reset the fence after committing to the frame, never
before.

The second was pure black, with no warning. A setting controls which color channels get
written to the screen. I'd left it at zero, which means "write nothing." Vulkan treats that
as valid — writing nothing is a legal instruction — so no error fired. The screen was just
black. The validation layers couldn't flag it, because nothing was technically wrong. The
engine was doing exactly what I'd told it to.

The third involved two near-identical results. When a window resizes, the swap chain can
come back "out of date" — you have to rebuild it — or "suboptimal" — it still works, but
not ideally. The two states are handled differently. One throws an error you have to catch.
The other returns a status you have to check. Mixing them up causes crashes, or a slowly
degrading image.

## What's next

Now that the engine can draw, it needs to know where things are. The next milestone builds
the coordinate system. Space is big enough to break ordinary numbers. That's where "space
sim" starts to mean something.

---

*Built solo by Spoods Studios.*

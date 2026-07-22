---
milestone: M0.1
title: Before the Galaxy, a Triangle
date: 2026-04-13
status: published
published_date: 2026-06-15
discord_post_id: <set on publish>
audience: devlog
---

# Before the Galaxy, a Triangle

Every engine starts with a triangle. Mine took six phases of work to draw one — a single
colored triangle on a cornflower-blue background. It's not much to look at. But getting
those few hundred pixels on screen meant building the whole rendering foundation from
scratch, with no Unity or Unreal underneath doing it for me. This is the first brick.

## What changed

I'm building the graphics on Vulkan, which is about as close to the hardware as you can
get without writing the driver yourself. That control is the whole reason I picked it —
later milestones need things like separate depth buffers for wildly different scales and
real atmospheric scattering, the kind of thing a higher-level engine would fight me on.

The cost is that nothing is automatic. To put that one triangle on screen I had to set up
a window and a drawing surface, a swap chain (the conveyor belt of images the screen flips
through), a full graphics pipeline compiled from my own shaders, and the careful
synchronization that keeps the GPU and CPU from tripping over each other. Then a clean
shutdown that tears it all back down in the right order — with Vulkan's built-in
correctness checker coming back completely silent. Zero errors. That silence is the
whole milestone.

## The deep end

A few bugs from this one are worth sharing, because they're the kind that don't announce
themselves.

The first was a deadlock. Vulkan uses "fences" to let the CPU wait for the GPU to finish a
frame. I was resetting the fence too early — before confirming the frame had actually
started. When the window got resized at the wrong moment, the frame would bail out, the
fence would never get signaled, and the engine would just freeze forever with no error
telling me why. The fix was a one-line reorder: reset the fence *after* you've committed
to the frame, never before.

The second was pure black, no warning. There's a setting that controls which color
channels actually get written to the screen. I'd left it at zero, which means "write
nothing." Vulkan considered that perfectly valid — writing nothing is, technically, a
legal thing to do — so no error fired. The screen was just black, and the validation
layers couldn't help because nothing was wrong, exactly. It was doing exactly what I'd
told it to.

The third was a tale of two near-identical results. When a window resizes, the swap chain
can come back "out of date" (you have to rebuild it) or merely "suboptimal" (it still
works, just not ideally). They sound the same and they're handled completely differently —
one throws an error you have to catch, the other quietly returns a status you have to
check. Mixing them up means either crashes or a slowly degrading image.

## What's next

Now that the engine can draw, it needs to know *where* things are. The next milestone is
the coordinate system — and it turns out space is so big it breaks ordinary numbers. That's
where "space sim" actually starts to mean something.

---

*Built solo by Spoods Studios.*

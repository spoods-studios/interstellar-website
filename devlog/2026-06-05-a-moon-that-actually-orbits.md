---
milestone: M0.3
title: A Moon That Actually Orbits
date: 2026-06-05
status: published
published_date: 2026-06-15
discord_post_id: <set on publish>
audience: devlog
---

# A Moon That Actually Orbits

The last milestone gave the engine a coordinate system that could hold the whole solar
system without losing a millimeter. This one was the first time I asked it to *move*. A
body now traces its orbit around another, comes all the way back to where it started, and
does it again, and again — without the slow death-spiral into the sun that simpler
simulations hand you for free.

## What changed

You can watch an orbit now. Underneath it is a gravity model running in high precision, and
two integrators — the things that step the simulation forward in time — both of a special
kind called *symplectic*.

That word is the whole point of the milestone, so here's the plain version. Step a normal
simulation forward enough times and tiny rounding errors pile up in one direction: the
orbit slowly loses energy and spirals inward, or gains it and flies away. Symplectic
integrators are built so those errors cancel out over time instead of accumulating. An
orbit stays an orbit, basically forever. I proved it with a test that runs a hundred
thousand steps and confirms the energy never drifts more than a hair, and another that
checks the orbit's shape and orientation hold steady across ten thousand randomly generated orbits.

The physics also moved onto its own thread, separate from the part that draws the screen,
so the simulation can run hard without stuttering the visuals. And the look is deliberately
KSP-flavored: a fading trail showing where the body has been, a predicted path showing
where it's headed, a camera that auto-zooms to keep the orbit in frame, and a little
readout of the orbital period and energy ticking live.

## The deep end

Two things made this milestone harder than "write an integrator."

The first I caught mid-flight. The plan was to validate the engine against the real Moon's
orbit using NASA's measured data. Problem: the real Moon doesn't actually move on a clean
two-body path. The Sun yanks on it hard enough — over 1% of Earth's pull — that a simple
Earth-and-Moon simulation can *never* match the real thing, no matter how good the code is.
So I redirected the test to the Sun-and-Earth pair, where the two-body approximation
actually holds, and labeled it honestly as an approximation budget — a test whose margins
will tighten on their own once the next milestone adds the other tugging bodies. A test
that's upfront about what it's approximating is worth more than one that passes by
pretending the physics is simpler than it is.

The second was a gap in my own safety net. I had a filter to catch corrupted numbers
(infinities, not-a-numbers) before they reached the screen — but it only checked *positions*,
never *velocities*. A bad value could sneak in through velocity on the last fraction of a
step, sail straight past the filter, and poison a frame's readouts before the next step
cleaned it up. I reproduced it by deliberately injecting an infinity, watched it leak
through, and closed the hole. A separate tool for catching threading bugs also earned its
keep, surfacing two real data races in the worker thread that no amount of staring at the
code had revealed.

(All of this gets shaken out by a review pass before I lock the physics. It's a big part of
why the engine is trustworthy — but it's behind-the-scenes plumbing, so it'll get its own
post rather than crowding this one.)

## What it cost

The honest read: writing the integrator was the easy part. Validating it, and proving it
holds up under a real concurrent workload, was the actual milestone. Two problems were too
big to fix here and got named outright as blockers for next time — the way the engine hands
state to the renderer won't scale past one body, and the fast integrator bleeds energy
through close approaches. Both have to be solved before a second body can gravitate. No
hand-waving, no "we'll get to it" — they're written down as the first things M0.4 has to do.

## What's next

M0.4: multi-body gravity. More than one thing pulling on more than one other thing, all at
once — which is where orbital mechanics gets genuinely chaotic and genuinely beautiful. But
first those two blockers. The next interesting problem is making "everything attracts
everything" both correct *and* fast.

---

*Built solo by Spoods Studios.*

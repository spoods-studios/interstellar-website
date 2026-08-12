---
milestone: M0.3
title: A Moon That Actually Orbits
date: 2026-06-05
status: published
published_date: 2026-06-15
discord_post_id: "1512455992011526275"
audience: devlog
---

# A Moon That Actually Orbits

The last milestone gave the engine a coordinate system that could hold the whole solar
system without losing a millimeter. This one was the first time I asked it to *move*. A
body now traces its orbit around another and returns to exactly where it started. It does
that again, and again, without the slow death-spiral into the sun that simpler simulations
produce.

## What changed

You can watch an orbit now. Underneath it is a gravity model that runs in high precision.
The engine advances that model with two integrators — the components that step the
simulation forward in time — both of a kind called *symplectic*.

That word is the whole point of the milestone. Step a normal simulation forward enough
times and tiny rounding errors pile up in one direction. The orbit slowly loses energy and
spirals inward, or gains energy and flies away. Symplectic integrators are built so those
errors cancel out over time instead of accumulating. An orbit stays an orbit, basically
forever. I proved it with two tests. One runs a hundred thousand steps and confirms the
energy never drifts more than a hair. The other checks that an orbit's shape and orientation
hold steady across ten thousand randomly generated orbits.

The physics also moved onto its own thread, separate from the part that draws the screen.
That split lets the simulation run hard without stuttering the visuals.

The look is deliberately KSP-flavored. A fading trail shows where the body has been. A
predicted path shows where it's headed. A camera auto-zooms to keep the orbit in frame. A
small readout shows the orbital period and energy, updating live.

## The deep end

Two things made this milestone harder than "write an integrator."

The first I caught mid-flight. The plan was to validate the engine against the real Moon's
orbit using NASA's measured data. The real Moon doesn't move on a clean two-body path. The
Sun pulls on it hard enough — over 1% of Earth's pull — that a simple Earth-and-Moon
simulation can never match the real thing. So I redirected the test to the Sun-and-Earth
pair, where the two-body approximation actually holds. I labeled the result an approximation
budget — a test whose margins will tighten on their own once the next milestone adds the
other tugging bodies.

The second was a gap in my own safety net. I had a filter to catch corrupted numbers —
infinities, not-a-numbers — before they reached the screen. It only checked positions. It
never checked velocities. A bad value could sneak in through velocity on the last fraction
of a step, sail straight past the filter, and poison a frame's readouts before the next step
cleaned it up. I reproduced the bug in three steps:

1. Inject an infinity into the velocity field.
2. Watch it leak through the filter.
3. Close the hole.

A separate tool built for catching threading bugs also proved its worth. It surfaced two
real data races in the worker thread that no amount of staring at the code had revealed.

## What it cost

Writing the integrator was the easy part. Validating it was the real milestone. So was
proving it holds up under a real concurrent workload.

Two problems were too big to fix in this milestone. The way the engine hands state to the
renderer won't scale past one body. The fast integrator bleeds energy through close
approaches. Both have to be solved before a second body can gravitate.

## What's next

M0.4: multi-body gravity. More than one thing pulls on more than one other thing, all at
once. That's where orbital mechanics gets complicated. Those two problems come first. The
next interesting problem is making "everything attracts everything" both correct *and* fast.

---

*Built solo by Spoods Studios.*

---
milestone: M0.4
title: From One World to Many
date: 2026-06-14
status: published
published_date: 2026-06-15
discord_post_id: "1516130941960192102"
audience: devlog
---

# From One World to Many

This milestone was all about gravity getting complicated. For a while I kept things
simple: one planet, one star, one clean orbit. Real space is messier. You've got the
Sun, the Earth, the Moon, Mars, Jupiter — and every one is pulling on every other one,
all the time. So this time I taught the engine to handle the whole crowd. Five bodies,
all interacting at once.

## What changed

The big shift is that gravity is now a conversation between everything. Before, a planet
only felt its star. Now the Moon feels the Earth *and* the Sun *and* Jupiter, all at the
same time, and it tugs back on each of them. That's what real solar systems do. It's
where Lagrange points come from, and where the three-body problem's chaos lives — the
stuff patched-conic games like KSP smooth away.

I run it the honest way: every body pulls on every other body, in full double precision.
The calculation runs in a fixed order, so the same starting point always plays out the
same way down to the last digit. No shortcuts, no approximations papering over the hard
parts.

There's one genuinely tricky case: when two bodies swing in close, the fast method I use
for normal orbits gets shaky. When that happens, the engine:

1. Notices the close pass coming.
2. Hands that stretch of time to a slower, more careful method.
3. Switches back once the bodies separate.

And I checked the whole thing against reality. Orbital periods and positions match
NASA's JPL ephemeris data. A 100-year run confirms the total energy stays balanced over
the long haul.

## The deep end

Two bugs almost made it into this milestone.

First: my Sun was too heavy — about 0.026% too strong. Tiny, but it pulled every orbit
slightly off. The fix was a single constant. The real lesson was in *how* I'd been
testing — I'd been checking orbits against my own simulation instead of against reality.
Now every trajectory gets compared to JPL's ephemeris data, the actual measured
positions of the planets.

Second: the close-pass trigger was firing on almost every step, not just the moments it
was meant for. The engine ran the slow method the entire milestone and never used the
fast method it was built on. Retuning the trigger fixed it, with one exception baked in:
bodies that permanently orbit each other, like the Earth and Moon, don't count as a
close pass.

Neither bug crashed the simulation. Both runs looked correct at a glance. Only the
comparison against JPL's measured positions caught them.

## What's next

Right now the engine simulates five bodies perfectly, but slowly. M0.5 is about speed —
running the clock forward fast enough that you could actually sit and watch a year go by,
without the physics quietly falling apart. Exact-for-everything is easy at five bodies.
The interesting problem is staying honest when five becomes thousands.

---

*Built solo by Spoods Studios.*

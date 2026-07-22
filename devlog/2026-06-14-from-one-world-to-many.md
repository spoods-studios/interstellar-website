---
milestone: M0.4
title: From One World to Many
date: 2026-06-14
status: published
published_date: 2026-06-15
discord_post_id: <set on publish>
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
same time, and it tugs back on each of them. That's what real solar systems do — it's
where Lagrange points come from, where the chaos of the three-body problem lives, the
stuff patched-conic games like KSP smooth away.

I run it the honest way: every body pulls on every other body, computed in full double
precision, in a fixed order so the same starting point always plays out the same way
down to the last digit. No shortcuts, no approximations papering over the hard parts.

There's one genuinely tricky case — when two bodies swing in close. The fast method I
use for calm orbits gets shaky there, so the engine notices a close pass coming and
hands that stretch of time to a slower, more careful method, then switches back once the
bodies separate. And I checked the whole thing against reality: orbital periods and
positions compared to NASA's JPL ephemeris data, plus a 100-year run to prove the energy
stays balanced over the long haul.

## The deep end

Two bugs almost made it into this milestone. Both are worth talking about.

First: my Sun was too heavy — about 0.026% too strong. Tiny, but it pulled every orbit
slightly off. The fix was a single constant. The real lesson was in *how* I'd been
testing — I'd been checking orbits against my own simulation instead of against reality.
Now every trajectory gets compared to JPL's ephemeris data, the actual measured
positions of the planets.

Second, and more subtle: the engine has two ways to compute gravity — a fast one for
normal orbits, and a slower, more careful one for when bodies pass close. My solar
system was tripping the "close pass" trigger constantly, so it ran the slow path every
single step and never touched the fast path the whole milestone was built on. Retuning
the trigger fixed it, with one exception baked in: bodies that permanently orbit each
other, like the Earth and Moon, don't count as a close pass.

Neither bug was a crash. Both simulations looked completely fine. That's the part that
sticks with me — a physics engine can be confidently, invisibly wrong, and the only way
you find out is by measuring it against the real universe.

## What's next

Right now the engine simulates five bodies perfectly, but slowly. M0.5 is about speed —
running the clock forward fast enough that you could actually sit and watch a year go by,
without the physics quietly falling apart. Exact-for-everything is easy at five bodies.
The interesting problem is staying honest when five becomes thousands.

---

*Built solo by Spoods Studios.*

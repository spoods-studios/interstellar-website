---
milestone: M0.2
title: A Coordinate System That Doesn't Lie
date: 2026-04-25
status: published
published_date: 2026-06-15
discord_post_id: <set on publish>
audience: devlog
---

# A Coordinate System That Doesn't Lie

Here's a problem most games never have to think about: space is so big that ordinary
numbers can't hold it. The engine can now track a position anywhere out to about 600 times
the Earth-Sun distance and still be accurate to the millimeter. Getting there meant
rethinking how the engine stores *where things are* from the ground up.

## What changed

The usual way games store a position is with floating-point numbers — great for a level
that's a few kilometers across, useless across a solar system. A float gives you roughly
seven digits of precision. Out at Jupiter, that's kilometer-sized gaps between the numbers
you can actually represent. Your spacecraft would visibly jitter and snap to a grid.

So the engine uses three layers instead of one. Positions are *stored* as 64-bit integers
on a one-millimeter grid — exact, no rounding, all the way out to the edge of the solar
system. Physics math happens in high-precision (64-bit) floating point. And only the final
step, handing coordinates to the graphics card, drops down to the fast 32-bit floats the
GPU wants.

The trick that ties it together is a rule I called subtract-before-convert: never turn a
giant absolute position into a float. Instead, subtract two positions while they're still
exact integers, and only convert the small *difference* — the distance between two nearby
things, which is small enough to be precise. The whole engine renders relative to the
camera, with the origin shifting every frame to keep everything close to zero where floats
are sharp.

## The deep end

This milestone is where I learned how sneaky precision bugs are.

I'd written what looked like a free, harmless conversion: take an integer position, cast it
straight to a float. At solar-system scale it quietly destroys data. At around 90 trillion
millimeters out, two integers that are a millimeter apart land on the *exact same* float —
they collide, and the millimeter just vanishes. The fix was forcing every conversion
through the subtract-first path, and there's now a test that deliberately tries the naive
way and proves it loses the millimeter, so I can never accidentally reintroduce it.

The most embarrassing one: my reference data was wrong. I'd pinned a test to "Earth's
position at J2000, straight from NASA's JPL HORIZONS system." Turns out the numbers I'd
copied came from an older NASA model, and the current one disagrees about where Earth was
by around 22,000 kilometers — bigger than the entire planet. My test passed anyway, because
I'd written the allowed error margin 200 times too loose. The lesson burned in deep: tie
your tests to the *real* measured universe, and make the margins tight enough to actually
catch the thing you're afraid of.

And one conceptual fix that saved me future pain: I'd been casually calling my position
updates "atomic," meaning safe to read while they're being written. A 3D position is 24
bytes, and no processor can write 24 bytes in one indivisible step. The real solution is a
pattern called a seqlock — the writer bumps a counter, and readers retry if they catch a
half-written value. I found this *before* the next milestone put physics on its own thread,
which was exactly the point.

(Every physics and math system goes through a review pass before I lock it — that's what
surfaced the precision collision and the loose-margin bug. More on how that works in its own
post; here, the bugs are the story.)

## What's next

The engine can now hold the solar system without losing a millimeter. Next, it has to make
something *move*. M0.3 is the first real physics milestone — the first orbit. And every
single integrator step is going to ride on the conversion math I just locked down here.

---

*Built solo by Spoods Studios.*

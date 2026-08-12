---
milestone: M0.2
title: A Coordinate System That Doesn't Lie
date: 2026-04-25
status: published
published_date: 2026-06-15
discord_post_id: "1497781529424691371"
audience: devlog
---

# A Coordinate System That Doesn't Lie

Space is big enough to break ordinary numbers. This milestone the engine learned to track a
position anywhere out to about 600 times the Earth-Sun distance, accurate to the millimeter.
Getting there meant rethinking how the engine stores *where things are*, from the ground up.

## What changed

The usual way games store a position is with floating-point numbers. A float gives you
roughly seven digits of precision. That's fine for a level a few kilometers across. Out at
Jupiter, those same seven digits leave kilometer-sized gaps between the numbers you can
actually represent. Your spacecraft would visibly jitter and snap to a grid.

So the engine uses three layers instead of one. Positions are *stored* as 64-bit integers on
a one-millimeter grid. Integers don't round, so a position stays exact all the way out to the
edge of the solar system. Physics math happens in high-precision (64-bit) floating point.
Only the final step, handing coordinates to the graphics card, drops down to the fast 32-bit
floats the GPU wants.

The trick that ties it together is a rule I called subtract-before-convert: never turn a
giant absolute position into a float. Instead, subtract two positions while they're still
exact integers. Convert only the small *difference* — the distance between two nearby
things. That distance is small enough to stay precise. The whole engine renders relative to
the camera. The origin shifts every frame to keep everything close to zero, where floats are
sharp.

## The deep end

This milestone is where I learned how sneaky precision bugs are.

I'd written what looked like a free, harmless conversion: take an integer position, cast it
straight to a float. At solar-system scale it quietly destroys data. At around 90 trillion
millimeters out, two integers a millimeter apart land on the *exact same* float. They
collide, and the millimeter vanishes. The fix was forcing every conversion through the
subtract-first path. There's now a test that deliberately tries the naive conversion and
confirms it loses the millimeter. That test catches the bug if it ever comes back.

The most embarrassing one: my reference data was wrong. I'd pinned a test to "Earth's
position at J2000, straight from NASA's JPL HORIZONS system." Turns out the numbers I'd
copied came from an older NASA model. The current model disagrees about where Earth was by
around 22,000 kilometers — bigger than the entire planet. My test passed anyway, because I'd
written the allowed error margin 200 times too loose. The lesson burned in deep: tie your
tests to the *real* measured universe. Make the margins tight enough to actually catch the
thing you're afraid of.

One conceptual fix saved me future pain. I'd been casually calling my position updates
"atomic," meaning safe to read while they're being written. A 3D position is 24 bytes. No
processor can write 24 bytes in one indivisible step. The real solution is a pattern called a
seqlock. The writer bumps a counter. Readers retry if they catch a half-written value. I
found this before the next milestone put physics on its own thread. That timing was exactly
the point.

## What's next

The engine can now hold the solar system without losing a millimeter. Next, it has to make
something *move*. M0.3 is the first real physics milestone — the first orbit. Every single
integrator step is going to ride on the conversion math I just locked down here.

---

*Built solo by Spoods Studios.*

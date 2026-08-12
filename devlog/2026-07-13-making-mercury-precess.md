---
milestone: M0.8
title: Making Mercury Precess
date: 2026-07-13
status: final   # draft | published
discord_post_id: "1526309987075489812"
audience: devlog
tags: [milestone, physics, relativity, 1pn, j2, oblateness, mercury, precession, de441]
hero_visual: assets/m0.8-hero-precession.png — Mercury perihelion drift, Newtonian flat vs 1PN riding Einstein's 42.98″/century line (real engine output, PN-04 harness config)
---

# Making Mercury Precess

![Mercury's perihelion drift: Newtonian stays flat, 1PN climbs exactly along general relativity's predicted 43″/century line](../assets/m0.8-hero-precession.png)

In 1859, the astronomer Urbain Le Verrier noticed something wrong with Mercury. Its orbit is an ellipse. The ellipse itself slowly rotates around the Sun. Every planet tugs on that rotation a little. After accounting for all of them, a tiny leftover drift remained: 43 arcseconds per century, about one hundredth of a degree every hundred years. Newton's gravity had no explanation for it. People hunted for a hidden planet inside Mercury's orbit for decades. In 1915, Einstein computed Mercury's orbit using his new general relativity equations. The missing 43 arcseconds fell straight out of the equations. He later said the discovery gave him heart palpitations.

This milestone, my engine reproduced that number. I pointed it at Mercury, let the physics run for a simulated century, and measured the drift: **42.98 arcseconds**.

## What changed

Until now the engine's gravity was pure Newton: every body pulls on every other body, proportional to mass, falling off with distance squared. That gets you astonishingly far — the whole solar system to kilometer-level accuracy over months. This milestone added the last two corrections that real mission planners can't live without. Neither correction is large.

The first is relativity. General relativity's correction to gravity near the Sun is minuscule. For Mercury it shifts the force by parts in ten million. But it acts in the same direction every orbit, so it compounds. Over a century those parts-in-ten-million add up to exactly the drift Le Verrier measured. The engine now carries that correction through the same force pipeline as everything else.

The second is the shape of the planets themselves. I'd been treating every body as a perfect point of mass. Real planets spin. Spinning flattens them. Earth is 21 kilometers wider at the equator than pole-to-pole. Saturn is squashed by a full 10%. That equatorial bulge gives close-in moons and satellites an extra tug. It's the dominant perturbation for anything orbiting low. Astronomers call it J2. Every planet in the engine now has its measured J2 value, its real radius, and its real spin axis, from Mercury all the way out to Neptune.

My favorite consequence of getting J2 right: sun-synchronous orbits now work. Weather and spy satellites fly a particular tilted orbit that uses Earth's bulge as a free steering motor. The bulge twists the orbit plane exactly once around per year. That keeps the satellite crossing the equator at the same local time, forever. That behavior falls out of the J2 physics. The engine now reproduces the textbook rate. If I put a satellite on that orbit, it stays sun-synchronous because the *shape of the Earth* keeps it there.

## Checking it against the sky

The Mercury number is the flagship. But one number can flatter you. So the whole thing gets checked against JPL's DE441 ephemeris — the measured positions of the planets that real missions navigate by.

The live simulation now runs all fourteen major bodies — Sun, eight planets, the Moon, and Jupiter's four big moons — with both corrections switched on. The check is blunt: with relativity and J2 enabled, the engine's predicted positions for the inner planets must land *closer* to JPL's data than the Newtonian-only run does, epoch after epoch. They do. The outer-planet J2 values got their own reality check. Saturn's bulge was tested against Mimas, Uranus's against Miranda, and Neptune's against Naiad — a moon skimming so low that J2 twists its orbit by degrees per day. Each comparison used the real measured moon positions.

One design rule made all of this safe to ship: both corrections are additive layers on top of the locked Newtonian core. Switch them off, and the engine reproduces last milestone's trajectories exactly — bit-for-bit identical, zero difference. Switch them on and you get the refined physics. Nothing underneath was touched.

## The deep end

The relativity implementation has a genuinely weird feature. That feature caused the milestone's best bug.

The correction I used comes from a 1994 paper by Saha and Tremaine, built to slot into fast long-term integrators like mine. To keep the math clean and stable, it plays a trick: inside the integrator, bodies don't carry their true velocities. They carry *pseudo-velocities* — a slightly redefined velocity, off from the real one by a relativistic hair (for Earth, a few millimeters per second). The integrator's internal bookkeeping is all in pseudo-velocities. You convert back to true velocities at the boundary — whenever the outside world looks in.

The engine has more boundaries than I'd been thinking about. Entering time warp: converted. Leaving time warp: converted. But there's a third path. While you're *sitting in* warp, the renderer peeks at the live simulation every frame to draw the planets. That peek exported the internal state raw. It published pseudo-velocities as real ones to everything watching: the camera, the telemetry, the kinetic-energy readouts. Positions were fine. But every velocity readout during warp was subtly, systematically wrong, by a few millimeters per second, forever. No energy check inside the integrator would ever notice, because internally nothing *was* wrong.

The fix has two parts:

1. The peek path copies the state before converting it, so the live simulation stays untouched.
2. A regression test pins the published velocity to the true-velocity export, so the raw internal state can't leak again.

A second find in the same family: Newton's third law. The relativistic correction was pushing on the planets. But the matching reaction on the Sun was missing. Every orbit, that left a tiny unbalanced force on the system. The planets' orbits relative to the Sun were still perfect — Mercury's 42.98 didn't move. But the solar system's center of mass was drifting, about 650 meters per 50 years, when it should sit still. Both the simulation and its test suite now share one force routine, momentum-conserving. That keeps the convention from silently forking again.

Both bugs surfaced in a milestone-closing review, got reproduced, fixed, and locked under regression tests before the milestone closed. Final tally: 656 tests green. The Newtonian core stayed byte-identical to the day it was locked.

## What's next

This milestone closes out the engine's foundation phase. The gravity is nested, warpable, relativistic, and checked against the real sky — the physics bedrock I wanted before building anything on top of it. Next comes the part where it starts becoming a game: a controllable spacecraft. Six degrees of freedom, real thrust, real fuel consumption obeying the rocket equation, flying through this gravity field.

---

*Built solo by Spoods Studios.*

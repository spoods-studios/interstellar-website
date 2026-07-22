---
milestone: M0.5
title: Teaching the Engine to Fast-Forward
date: 2026-06-19
status: published   # draft | published
audience: devlog
hero_visual: Energy-conservation telemetry plot — dE/E hovering at ~1e-15 across a million simulated seconds of the five-body system (orbit stays exactly as tight at the end as the start)
---

# Teaching the Engine to Fast-Forward

Space happens slowly. A spacecraft coasting to Mars is in flight for the better part of a year. Nobody wants to sit and watch that in real time — so every space game lets you speed time up. Hit warp, and a year passes in a few seconds.

The problem is that orbits are fragile. Speed up the clock carelessly and the math starts taking giant, sloppy steps — and a planet that should trace a clean ellipse for a billion years instead spirals into its star, or flings itself out into the dark. The faster you warp, the worse it gets. This milestone was about teaching the engine to fast-forward *without* breaking the very thing it's simulating.

## What changed

The headline is a new way of moving time forward called a **symplectic integrator** — specifically the Wisdom-Holman method, the same family of math that real astronomers use to simulate the solar system across millions of years.

Here's the trick. A normal integrator just nudges every body forward a little, over and over. Take bigger nudges to go faster, and small errors pile up until the orbit drifts apart. A symplectic integrator is built differently: it's allowed to be a little wrong about *where* a planet is at any instant, but it is structurally forbidden from letting the orbit's energy drift. So you can take enormous time steps — this one takes steps **72 times bigger** than before — and the orbit still closes on itself perfectly. That's the energy plot at the top: a million seconds of five bodies pulling on each other, and the total energy never moves past the fifteenth decimal place.

Three more things landed alongside it:

- A **deterministic Kepler solver** — the piece that figures out where a body is along its orbit. "Deterministic" means it gives the *bit-for-bit identical* answer every single time, on every machine. That matters more than it sounds; I'll come back to it.
- A **predictive flyby detector**. When two bodies are about to have a close encounter, the simple big-step math isn't accurate enough, and the engine needs to temporarily switch to a slower, careful mode. The old detector noticed encounters as they happened. The new one sees them *coming* — it does the conic-section geometry to predict the closest approach a step ahead, so a fast flyby never slips between two snapshots unnoticed.
- **Massless test particles**. Real solar systems have a few heavy things (stars, planets) and an enormous number of light things (spacecraft, asteroids, debris). The light things feel gravity but don't meaningfully pull back. So the engine now treats them as a cheap separate tier — they ride the gravity field without each one adding to the cost of everyone else. That's what will eventually let you fly a ship through a fully-simulated system without the framerate collapsing.

## The plot twist

Here's the twist I didn't expect. I built the symplectic integrator to make things *faster*, and then I measured it carefully — and at the scale the game runs today, with a handful of bodies, it isn't actually faster. The cost of a simulation step at small body counts isn't dominated by the gravity math at all; it's dominated by handling those close encounters.

But the work isn't wasted — it's going to be useful later. Wisdom-Holman isn't a "more bodies" win, it's a "bigger time steps" win. It's the thing that will let you warp time hard once systems get big. So it's built, validated, and waiting in the engine, while the *currently shipped* simulation keeps using the older, fine-grained integrator that's genuinely faster at today's scale. 

## The issues

Two things made this milestone hard, and neither was the integrator itself.

**The frozen-Sun bug.** The first version of the symplectic integrator passed every invariant test I had — momentum conserved, the works — and was still wrong. When I built an *honest* benchmark, one that holds accuracy fixed and asks how the energy actually behaves over a long run, it showed a slow secular drift: the system's energy was creeping in one direction, 2.7e-5 over the run. Two real bugs were hiding underneath. The integrator was reconstructing the dominant body's position from the wrong reference, and it was running in a frame that wasn't the system's true center of mass. Fixing both turned the creep into a bounded wobble of 4.4e-8 — and made the whole thing invariant under a 30 km/s boost, which is the property that proves the frame bug is actually gone. The lesson stuck: an invariant test tells you a quantity is conserved; only a fixed-accuracy benchmark tells you it's conserved *for the right reason*.

**Determinism.** This is the one I'm quietly proudest of but caused me to bang my head against the desk multiple times a day. The entire physics path — the symplectic step, the Kepler solver, the predictive trigger, the test particles — produces bit-for-bit identical output on every run and across compilers. No `>` versus `>=` race, no "it converged in 7 iterations here and 8 there," no library `sin()` that's one bit different on another machine. That last one is why the Kepler solver ships with hand-rolled `det_sin`/`det_cos` built from nothing but `+ - * /`, and a fixed iteration count with no tolerance-based early exit — anything that branches differently on different hardware would break the guarantee. Same input, same bits, forever. That's the foundation the save-game system and any future multiplayer (yes, multiplayer — imagine building a space station with the homies) will stand on, and it's the milestone's single biggest risk retired.

## What's next

M0.6 flips the warp lever on for real — promoting Wisdom-Holman from "built and waiting" to the shipped integrator, with the eligibility and switching logic that decides when each scale of the simulation should use it. The fast-forward button is built. Next, it becomes usable.

---

*Built solo by Spoods Studios.*

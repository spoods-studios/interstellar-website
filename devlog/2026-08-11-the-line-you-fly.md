---
milestone: M1.2
title: The Line You Fly
date: 2026-08-11
status: published   # draft | published
discord_post_id:
audience: devlog
tags: [milestone, maneuver-nodes, trajectory-prediction, map-view, orbital-elements, flight-planning]
hero_visual: assets/m1.2-hero-predicted-vs-flown.png — predicted trajectory vs flown burn, real engine output (PRED-04 family-6 harness against libinterstellar: DE441 Sun/Earth/Moon seed, e=0.15 orbit at 400 km periapsis, 669.43 m/s prograde-axis burn over 600 s, 6,300 s span; 300 s physics step, 1,024-substep preview tier vs 16,384-substep flight tier — all shipped values, no smoothing; max predicted-vs-flown separation 1.67e-2 m ≈ 17 mm; harness → CSV → matplotlib)
---

# The Line You Fly

![Predicted trajectory overlaid with the actually flown burn path around Earth — over 105 minutes and a 669 m/s burn, the two lines never separate by more than 17 millimeters](../assets/m1.2-hero-predicted-vs-flown.png)

Last milestone the engine got a ship you could fly. This milestone it got a ship you can plan with. Click anywhere on your orbit and a maneuver node appears there. Drag its handles and a new trajectory draws itself in real time — here's where you'll go if you burn like this, at that moment. Then you fly the burn yourself, by hand, and the ship follows the line.

That last sentence is the whole milestone. Plenty of space games draw a planned trajectory. The hard promise is that the drawn line and the flown path are the same line — and that's the promise M1.2 was built around.

## Planning a burn

The pieces will feel familiar if you've played anything in this genre. A node sits at a point on your future orbit. Six handles come off it — prograde and retrograde, normal and anti-normal, radial in and out — and dragging them builds up the burn, direction by direction. The readout shows the total Δv, the per-axis breakdown, and how long the engine will need to fire to deliver it, computed from your ship's actual mass and thrust through the rocket equation. Ask for more than your fuel can give and the node doesn't stop you — it flags the overrun and lets you keep sketching.

While you drag, the predicted path redraws live. The part of the trajectory before the node never moves — you haven't changed anything about how you get *to* the burn — and the part after it swings around as the plan changes. All of it happens on a map view you can now drive with the mouse: pan, zoom, click to place, grab a handle. The predicted path draws in green; the trail you've actually flown stays amber. Two different claims about the world, two different colors.

## Why the line is trustworthy

Here's the part I want to nerd out about. Most games compute the planned trajectory with a simplified model — patched conics, usually: pretend only one body pulls on you at a time, glue the pieces together. It's fast and it's close. But this engine simulates every body pulling on your ship all the time, and "close" drifts. If the planner uses simpler physics than the flight, the line you drew quietly stops being the path you fly, and the game has to fudge or shrug.

So the predictor here doesn't get its own physics. There is exactly one piece of code that advances the craft — the same substep kernel, stepping the same forces, at the same precision — and both the live flight and the trajectory prediction call it. The predictor literally cannot disagree with the flight code about physics, because there is no second copy of the physics to disagree with. The match isn't a calibration we chase; it's the architecture. And it's tested: the suite flies burns and measures the gap between the predicted line and the flown path, with locked tolerances that fail the build if the promise degrades.

## The bug that had to die first

None of this was buildable on the ship the last milestone left behind. The planets integrate on a 300-second step — perfectly fine for planets — and the craft was riding that same step. Over a single low orbit that accumulated 546 kilometers of position error. You couldn't watch a launch at real time (the orbit visibly decayed), and every accuracy claim about nodes would have been measured against a wrong coast.

The fix gives the craft its own fine substep, derived properly from the same symplectic-integrator family as the rest of the engine rather than bolted on, with the planets untouched. The residual error over that same orbit is now about a millimeter — small enough that the remaining bias is a known, bounded rounding effect with its own regression test standing guard. As a side effect the game became playable at 1× real time with fine throttle control, which is how launches were always supposed to feel.

## The deep end

For the engineers still reading, the per-phase write-ups go deep on each piece — they're all in the Technical section now. The short version of what else landed: a full bidirectional converter between position/velocity states and classical orbital elements, verified against the standard textbook test cases across circular, elliptical, near-parabolic and hyperbolic orbits, with the numerically nasty spots (near-zero inclination, the parabolic edge) conditioned so they don't silently lose precision; the map-view input layer doing its hit-testing in screen pixels so a click means the same thing on every window shape; and the milestone-closing external review, which turned up 148 distinct findings across two independent reviewers and fourteen angles — every critical and high-severity one resolved before the release tag, several of them the kind of subtle seam bug (two clocks disagreeing about one instant, a stale marker surviving a rebuild window) that you only catch by paying people to be adversarial. The full findings ledger is public in the repo.

## What it cost

The feature work — subcycling, conversions, the shared kernel, nodes, prediction, map view — went roughly to plan. The review gate did not: closing its findings took eighteen fix phases, more than the nine phases the features themselves took. I've stopped resenting this pattern. The gate keeps finding real bugs at the seams between correct components, which is exactly where a solo project goes blind. Deferred honestly: burn planning doesn't yet model the throttle ramp you'd fly at very high time-warp (the planned-vs-flown match is proven for burns executed as scheduled), and a handful of accuracy refinements are queued for next milestone with their blockers named.

## What's next

The ship flies, and now it plans. What it can't do yet is care *where* it's going — there's no target, no rendezvous, no "get me to the Moon" beyond your own eye on the map. Making planned flight mean something is the next interesting problem.

---

*Built solo by Spoods Studios. Engine source at https://github.com/spoods-studios/interstellar-engine.*

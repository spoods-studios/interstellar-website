---
milestone: M0.6
title: Shipping the Warp Lever — With a Bouncer on the Door
date: 2026-06-25
status: published   # draft | published
audience: devlog
hero_visual: The eligibility gate in action — the WH-valid Sun/EMB/Mars/Jupiter warp config routing to Wisdom-Holman (η low, perturbations gentle) while the full Sun-Earth-Moon-Mars-Jupiter seed gets turned away to Yoshida4 (η high, the Moon is too strong a perturber). One number, computed in +−×÷, decides.
---

# Shipping the Warp Lever — Kinda

Last milestone I built a symplectic integrator — the Wisdom-Holman method, the math real astronomers use to push the solar system across millions of years — and then left it sitting in the engine, built and validated but switched off. This milestone was supposed to be the easy part: flip it on. It turned out the interesting work wasn't flipping the switch. It was building the bouncer that decides who's allowed through it.

## What we built

Wisdom-Holman is fast and stable, but only when its core assumption holds: that there's one dominant gravitational body and everything else is a gentle perturbation on top. A planet orbiting the Sun? Perfect fit. The Moon orbiting the Earth orbiting the Sun? Not even close — the Moon is bound so tightly to the Earth that, from the heliocentric frame Wisdom-Holman works in, it's not a "gentle perturbation" at all. Run WH on it anyway and the orbit quietly falls apart.

So the headline feature this milestone is a **perturbation-ratio eligibility gate**. Before the engine ever hands a system to Wisdom-Holman, it computes a single dimensionless number — call it η — that measures how strong the worst perturbation is compared to the dominant pull. Low η, the system is WH-safe and gets the fast path. High η, it gets turned away to the careful fine-grained integrator. The whole calculation is done in nothing but `+ − × ÷` — no library math functions at all — because the gate has to give the exact same verdict on every machine, forever. (More on why that matters in a second.)

The gate works. The proof is a test that takes the *real* Moon — a genuinely bound satellite — and confirms the engine correctly refuses to put it on the warp path, while the WH-valid configuration (Sun, Earth-Moon barycenter, Mars, Jupiter) sails right through. The fast lever exists, and it only engages when it's actually safe.

A few more things landed around it:

- A **zero-allocation WH step**. The integrator used to allocate a fresh scratch buffer every single step. Now it reuses a pre-reserved one owned by the worker — verified by a test that literally counts heap allocations and asserts zero. Warp means taking *millions* of these steps; an allocation per step is a million little pauses you'd rather not have.
- A **degrade-cliff benchmark** for the close-encounter integrator (IAS15), checking whether it falls off a performance cliff when flybys get frequent. It doesn't — the cost actually decays as you add bodies, and never crossed the threshold that would justify swapping it out.
- The whole **M0.5 review backlog**, reconciled. Every finding from last milestone's adversarial review either got fixed in its own dedicated sub-phase or got explicitly re-deferred with a named blocker. No silent drops.

## The hard part

Here's the twist, and it's a scope twist as much as a technical one. Partway through, the satellite problem stopped being a bug to fix and became its own milestone.

The original plan had M0.6 shipping Wisdom-Holman as *the* integrator — for everything. But the deeper I got into the eligibility math, the clearer it became that heliocentric WH fundamentally cannot model a bound satellite like the Moon. The fix isn't a tweak; it's a different algorithm — a *nested* or hierarchical Wisdom-Holman that treats the Earth-Moon system as its own little sub-simulation riding inside the bigger one. That's real work, and folding it in here would have blown the milestone open. So it got split out cleanly into a new M0.7, with the reasoning written down rather than hand-waved.

Which reframes what "shipped" means for this milestone, and I want to be precise about it: Wisdom-Holman is shipped as a **validated, gated, monitored warp seat** — wired up, eligibility-checked, energy-alarmed, and proven correct on its valid configuration. It is *not yet* the integrator the visible simulation actually flies on. The five-body system you'd watch today still runs on the trusty Yoshida4/IAS15 path. M0.7 is what consumes WH's warp-exit state and makes it the thing you're actually looking at. 

## What it cost

The honest accounting: I budgeted this as a one-feature milestone — flip the switch — and it became a five-feature one, plus a brand-new milestone spun off the side. The eligibility gate alone, the part I thought was a quick guard clause, turned into the highest-risk phase of the milestone because it's a *constructor-only* decision baked into determinism-sensitive code, and getting it both correct and bit-identical across machines took real care.

And that determinism cost is the through-line. Every single thing this milestone touched had to preserve the bit-for-bit reproducibility the engine is built on — the property that the save system and any future multiplayer will stand on. The locked force kernel came out the far side *byte-identical*; the only changes to it were a stronger type signature and a size guard that doesn't touch a single arithmetic operation. Keeping that guarantee intact while adding a whole new decision path is slow, deliberate work, and it's most of where the time went.

What got deferred is named and tracked: nested WH for satellites (→ M0.7), per-step gate hysteresis (→ M1.x), and a handful of micro-refactors blocked by the now-locked WH signature. Nothing vanished into "we'll get to it."

## What's next

M0.7 is the satellite milestone — nested Wisdom-Holman, the Earth-Moon system as a simulation-within-a-simulation, and the moment WH stops being a validated seat and becomes the integrator the camera is actually watching. 

---

*Built solo by Spoods Studios.*

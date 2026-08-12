---
title: How It's Made — AI, Tools, and What's Off-Limits
status: published
audience: policy-page
updated: 2026-08-12
---

# How It's Made

Setare Aerospace is built solo. And I use AI to help me build it. This page says exactly how —
what AI does here, what it never does, and why you can trust the result.
It's permanent and versioned. I'll keep it current as the tooling changes.

## What AI does on this project

**It writes code, under my direction.** I use frontier AI models as engineering
labor: implementing systems I've specified, working through plans I've reviewed,
in a codebase whose architecture and standards I own. Every merge is reviewed and
approved by me.

**It also reviews and checks the code before anything locks.** Every physics milestone closes
through an adversarial review gate: at least two independent frontier models from
different vendors attack the work from fourteen angles, covering mathematical
correctness, numerical stability, determinism, boundary conditions, and more.
Every serious finding then goes through the same fixed sequence:

1. Reproduce it empirically — compile, run, measure.
2. Fix it.
3. Pin it under a regression test.

Only then does the milestone ship. It has to pass through me first, we have to fix every bad finding and run tests before anything ships and is locked.

**It helps with research and drafting.** Study notes, planning documents, and
rough drafts start AI-assisted. It gives me a base outline of everything, so I have an idea of what to write and where. All sources get verified by me to make sure its up to date and accurate. The actually execution of the code is purely mechicanical, and AI has gotten very good at doing that. But, each phase doesn't close until I hand verify it. 

I understnad the hesitation when someone says they use AI for a project. I too am wary of those kinds of projects. There is a lot of AI slop and vibe-coded apps out there. Like with all tools AI can be abused and misused. I aim to use it in a way that doesn't take away my control over the project, it's vision and direction.

## What AI never does

**No generative assets. None.** No AI-generated images, textures, 3D models,
music, sound effects, or story content — now or planned. When you eventually see
Earth's terrain or Saturn's rings in this engine, the data underneath comes from
NASA and USGS spacecraft measurements — real elevation maps, real imagery, real
ring photometry. 

I have a very stong opinion on this. AI belongs no where near art, it is a human expression that could never be replicated by a machine. So for anything that has to be drawn or designed or modeled, I will use the other options available to me. Open source data for terrain maps like mentioned above, hiring artists to create logos and assets for me. I will learn blender to hand create assests like command pods and parts. (I probably will just pay someone to do the bulk of it for me, but for the first couple I will try it and record the entire process for visibility).
## Why the code is trustworthy anyway

Nothing here ships on trust. Three things make that true:

- **Reality grades the work.** Trajectories are validated against JPL's DE441
  ephemeris — the measured positions of the planets that actual missions navigate
  by. The engine reproduces Mercury's relativistic perihelion drift at
  42.98″/century because the physics is right.
- **Locked regression suites.** Once a system passes its gate, its behavior is
  pinned by hundreds of thousands of test assertions. Weakening a locked test
  requires explicit review sign-off. We can always add tests too to strengthen it even further.
- **Determinism contract.** The core force kernel produces bit-identical results,
  run after run. Changes to it are diffed at the byte level.

So the boundary becomes: AI creates the machinery, humans create the art. I maintain the direction, the planning, the architecture and vision. If you disagree and believe that I shouldn't use AI at all, I totally understand. But by my process, I am able to move much faster, do less grunt work and still come out with a quality product that I control. I am always open to feedback and discussion on this. As with all new technologies, there's a lot we don't know yet about how it will affect us in the future. I will remain transparent about this project as much as possible. 

---

*Built solo by Spoods Studios.*

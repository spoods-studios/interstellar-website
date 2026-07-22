---
title: How It's Made — AI, Tools, and What's Off-Limits
status: published
audience: policy-page
updated: 2026-07-13
---

# How It's Made

Setare Aerospace is built solo, and I use AI heavily. This page says exactly how —
what AI does here, what it never does, and why you can trust the result anyway.
It's permanent, versioned, and I'll keep it current as the tooling changes.

## What AI does on this project

**It writes code, under my direction.** I use frontier AI models as engineering
labor: implementing systems I've specified, working through plans I've reviewed,
in a codebase whose architecture and standards I own. Every merge is reviewed and
approved by me.

**It attacks the code before anything locks.** Every physics milestone closes
through an adversarial review gate: at least two independent frontier models from
different vendors, each attacking the work from fourteen angles — mathematical
correctness, numerical stability, determinism, boundary conditions, and more.
Every serious finding must be *empirically reproduced* — compiled, run, measured —
then fixed and pinned under a regression test before the milestone ships. The AI
that helped write the code does not get the final word on it.

**It helps with research and drafting.** Study notes, planning documents, and
devblog drafts start AI-assisted. Every published word is edited, verified, and
owned by me — if the devblog says a number, that number came from a measured run,
not from a language model's memory.

## What AI never does

**No generative assets. None.** No AI-generated images, textures, 3D models,
music, sound effects, or story content — now or planned. When you eventually see
Earth's terrain or Saturn's rings in this engine, the data underneath comes from
NASA and USGS spacecraft measurements — real elevation maps, real imagery, real
ring photometry — rendered by shaders I wrote. The textures come from spacecraft,
not a diffusion model.

## Why the code is trustworthy anyway

"AI wrote some of this code" would be a fair concern if the code shipped on
trust. It doesn't. Nothing here ships on anyone's word — human or machine:

- **Reality grades the work.** Trajectories are validated against JPL's DE441
  ephemeris — the measured positions of the planets that actual missions navigate
  by. The engine reproduces Mercury's relativistic perihelion drift at
  42.98″/century because the physics is right, not because someone typed it in.
- **Locked regression suites.** Once a system passes its gate, its behavior is
  pinned by hundreds of thousands of test assertions. Weakening a locked test
  requires explicit review sign-off; it can't happen silently.
- **Determinism contract.** The core force kernel produces bit-identical results,
  run after run, and changes to it are diffed at the byte level.

The honest summary: AI is the labor. The physics, the data, and the test suites
are the judge. I'm the one accountable for all of it.

— Spoods, Spoods Studios

*Questions? Ask in the Discord — I answer this stuff in #engine-tech.*

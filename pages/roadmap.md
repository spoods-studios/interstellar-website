---
title: Roadmap
updated: 2026-07-22
status: published
---

# Roadmap

The engine is being built one milestone at a time, and this page tracks the
arc: Era 0 — engine foundations (done) → Era 1 — first gameplay (in
progress) → Era 2 — Early Access MVP → Era 3+ — career & story.

Every milestone gets its own devblog announcement here, and every phase
inside it gets a technical deep-dive in the Technical section. Confused by
tags like `WIN-01` or `[Rule 3]` in the deep-dives? The How to Read page in
the Technical section explains the whole system.

## Era 0 — engine foundations ✅

- **M0.1 Vulkan Bootstrap** ✅ — window → swap chain → first triangle →
  sync → clean shutdown → CI (6 phases)
- **M0.2 Coordinate System** ✅ — int64 mm storage → float64 physics →
  float32 camera-relative rendering (6 phases)
- **M0.3 Basic Orbit** ✅ — force model, symplectic integrator core, JPL
  validation, math-lock, first review gate (8 phases)
- **M0.4 Multi-Body** ✅ — direct n-body, close-encounter detection, system
  energy, CI hardening (14 phases incl. gate fixes)
- **M0.5 Gravity Performance** ✅ — deterministic Kepler solver,
  fixed-accuracy benchmarks (7 phases)
- **M0.6 Wisdom-Holman** ✅ — barycentric WH integrator tier, warp
  foundations (5 phases)
- **M0.7 Nested Wisdom-Holman** ✅ — hierarchical WH for satellites (the
  Moon problem) (7 phases)
- **M0.8 Perturbations** ✅ — J2 oblateness, relativistic precession:
  Mercury's 42.98″/cy reproduced (5 phases)

## Era 1 — first gameplay 🔨

- **M1.1 Spacecraft Control** 🔨 — in progress

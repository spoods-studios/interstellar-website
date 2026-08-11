---
milestone: M1.2
title: Three Small Fixes Before Closing the Books
date: 2026-08-11
status: published   # draft | published
discord_post_id: "1536774144853549106"
audience: devlog
tags: [milestone-addendum, tech-debt, deterministic-math, maneuver-nodes, testing, ci]
---

# Three small fixes before closing the books

The maneuver-node milestone shipped last week, and the write-ups are already out. But my close-out ritual has one last gate: nothing on the tech-debt list survives the milestone that created it. Three items were still open, so before the branch merges, here's what cleaning them up looked like.

## The last of the library math

The engine computes almost everything with its own deterministic math functions, so the same orbit produces the same bits on every machine. One holdout: a diagnostic that tracks the health of the whole planetary system (its angular-momentum deficit) still called the system math library's `cos` and `sqrt`. It never touched a trajectory, but it was the last place the old math lived.

The port had a catch. The test suite checks the engine's copy of that formula bit-for-bit against a reference copy in the tests, so both had to switch in the same commit, operation for operation, or the comparison would light up red. Both moved together; every comparison stayed green.

While I was in there I wrote an automated check that inspects the compiled code and fails the build if a library `cos` or `sin` ever sneaks back in. Fun discovery: in unoptimized builds that check is meaningless, because the compiler emits a library `sqrt` call from nearly every file via inlined helpers the optimizer would normally turn into a single instruction. The check runs on the optimized build, where it measures what actually ships.

## A marker that could lie for a quarter second

When you drag a maneuver node, the predictor rebuilds the trajectory line. During one rebuild window, the node marker and Δv readout could still be drawn from the *previous* node's position, while everything reported itself valid. Nobody had caught it on screen; the review gate caught it on paper months ago, and the fix fell between two phases and never landed.

The predictor now publishes the timestamp its node-entry state belongs to, and the renderer compares that against the node it's about to draw. If they disagree by more than one prediction step, the marker and readout blank together until the rebuild lands — at most a quarter of a second — instead of showing stale numbers.

## The flaky test that wasn't the test

A stress test failed once on a two-core CI machine. The debt entry blamed a lock-free queue test. Digging in, the test name in CI was a filter that matched a *different* file — the real failure was a pause/resume stress test that resumes the physics worker ten thousand times and requires progress within two seconds each cycle. On a starved two-core box, two seconds is sometimes just the scheduler's mood.

A genuinely hung worker never advances at all, so any finite deadline still catches real bugs. The deadline is now derived from the failure evidence rather than optimism, and the queue test that took the original blame got the same treatment: its hundred-million-iteration spin counters became wall-clock deadlines. Counting loop iterations measures how fast the machine is; a deadline measures whether the thing ever happened.

Debt list: empty. Now the branch can merge.

---

*Built solo by Spoods Studios. Engine source at https://github.com/spoods-studios/interstellar-engine.*

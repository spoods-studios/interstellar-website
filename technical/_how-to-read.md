# How to Read the Roadmap Detail + Technical Devlogs

Short legend for the structure these entries use. Read once, then everything
else parses.

## The hierarchy

| Term | Meaning | Example |
|---|---|---|
| **Era** | Top-level arc of the project | Era 0 = engine foundations |
| **Milestone** | A gated release unit — a body of work that ships together | M0.1 Vulkan Bootstrap |
| **Phase** | One bounded chunk of work inside a milestone, built and validated on its own | Phase 1: Window + Surface |

Each **phase** gets a roadmap-detail entry (what it set out to do and what
landed) and a technical deep-dive (the code, and why it is shaped that way).
Each **milestone** gets the announcement-style devblog you already know.

Phases are numbered continuously across the project, so Phase 23 follows Phase
22 even though they sit in different milestones. Decimal numbers (Phase 10.5,
Phase 21.7) are phases inserted after the fact — usually to fix something found
while building the phase before them.

## What the deep-dives contain

The code as it was written, with the reasoning behind it: the structures and
functions that landed, the constraints that forced their shape, the bugs found
along the way, and the tests that pin the behaviour. Snippets are quoted from
the engine source, and file paths point at where the code lives in the tree.

The engine repository is private, so the source is not browsable yet — the
snippets in each entry are the code.

## As-built-then

Deep-dive code is shown **as it was written at the time**. A closing "Where it
is now" section covers what changed since and why, so early entries never
silently describe code that no longer exists.

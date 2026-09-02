---
name: website-implement
description: Phase implementation wrapper for the Official website, devblog, press kit, and community hub repo. Thin mirror of the engine's /implement — pre-flight gates (clean tree, dependency check, D-AH coupling pre-flight), then the GSD loop (discuss → plan → execute), then post-flight (summaries, gate-tier reminders, technical devlog draft→accept→post). Use for all phase work instead of calling gsd-* ceremonies raw.
argument-hint: "<phase-number>"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Skill, ListAgents, SendMessage, AskUserQuestion, mcp__playwright__*
---

# /website-implement — Phase implementation wrapper

Thin wrapper around the GSD per-phase loop. Exists so process gates are
codified in a skill, not left to CLAUDE.md prose that can get missed. No
engine-style heavy machinery (no research pipeline, no wave mode, no
math-lock) — if this repo ever needs those, promote it to a bespoke skill
the way the engine did.

## Usage

```
/website-implement <phase-number>
```

## Step 1 — Pre-flight

**1a. Clean worktree check.**
```bash
git status --porcelain
```
If uncommitted: warn, then commit with `chore: commit pre-implement state for phase {N}`.

**1b. Coupling pre-flight (Session Pairing Protocol — studio Decision Log
D-AH/D-AI; DO NOT REMOVE this step without a superseding studio Decision Log
entry).** Check the active org-milestone manifest(s) —
`../studio/vault/project/milestones/*/manifest.md` with `status: active` — for
a "Coupled phases" table naming this repo's Phase {N}. If none, skip silently.
If Phase {N} is coupled:
- `ListAgents` → is a session for the peer repo live?
  - **Live** → handshake via SendMessage: state this phase, the intended write
    set, and the checkpoints owed each way (per
    `studio/vault/project/Session Pairing Protocol.md`), then proceed.
    Checkpoint payloads that matter go into
    `.planning/research/<PEER>-COORDINATION.md` or committed vault docs — peer
    messages are coordination, never the record.
  - **Dark** → HALT before the discuss step. Print the coupling row and ask the
    user to open the peer repo's session, or to grant an explicit waiver to
    proceed one-sided. A waiver is recorded, dated, in the coordination file
    with what the absent side is owed. Never self-grant the waiver.

**1c. Read phase context from `.planning/ROADMAP.md`.** Extract Phase {N}'s
goal, requirements, success criteria, dependencies. If a dependency phase is
incomplete, abort and say which.

## Step 2 — Run the GSD loop

**2a. Discuss (INTERACTIVE — never `--auto`).** Run `/gsd-discuss-phase {N}`.
Gray areas get discussed WITH the user; decisions land in CONTEXT.md. If a
CONTEXT.md already exists, only re-open areas genuinely still gray.

**2b. Plan.** Run `/gsd-plan-phase {N}`.

**2b′. Budget claim (Performance Charter — studio Decision Log D-AK).** Before
the plan is accepted, PLAN.md must carry a `## Budget claim` section. Read this
repo's `perf_tier` from the activating manifest and apply the matching shape:

- **p1** — which ledger slice this phase draws from, the predicted cost with an
  order-of-magnitude derivation, and the halt condition. New slice ⇒ add the row
  to `vault/project/perf-ledger.md` **now**, at plan time, not at verify time.
- **p2** — the route(s) touched and their byte/vitals deltas against the charter
  defaults (LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1, JS ≤ 150 KB gz/route, page
  ≤ 1 MB).
- **p3** — the resource this phase spends (shipped bytes, LFS delta, CI
  wall-clock, mod-call count) and its ceiling.

A phase that touches no hot path, ships no bytes, and adds no CI time writes one
line and moves on:

```markdown
## Budget claim
budget draw: none
```

Anything that lands in the player's install also names its **Ship Budget**
contributor row (charter § Ship Budget) — download and installed size are
Counter-Locks and they block.

**2c. Execute.** Run `/gsd-execute-phase {N}` — atomic commits, retries on failure.

## Step 3 — Post-flight

**3a.** If anything residual: `git add -A && git commit -m "chore: commit remaining work from /website-implement phase {N}"`.

**3b. Per-plan SUMMARY files.** For every `.planning/phases/{N}-*/{N}-{NN}-PLAN.md`,
ensure a sibling `{N}-{NN}-SUMMARY.md` exists (GSD's execute/verify flow requires
a committed SUMMARY sibling before it counts a plan done). Write any missing ones,
then commit: `git add .planning && git commit -m "docs(phase-{N}): per-plan summaries"`.

**3c. Gate-tier reminder at phase close.** Read this repo's tier from the
activating manifest (`gate_tier` scalar + per-repo prose override). If **t2**:
the phase does not close without the user's playtest verdict
(pass / pass-with-notes / block — block re-opens work; AI review cannot
override). If t3: note that `gsd-code-review` or the gate-tiers checklist is
due at milestone close, not per phase.

**3d. Coupled-phase closeout.** If Step 1b found a coupling: confirm every
checkpoint payload owed to the peer this phase is on disk in their
coordination file (or explicitly still owed, with the peer notified). Don't
leave owed state only in message history.

## Step 4 — Return to human

Short report: what was built, requirements addressed, commits made,
verification status, and (if coupled) checkpoint state with the peer repo.

## Rules

- Never skip Step 1b or auto-grant its waiver.
- Discuss is always interactive — never answer gray areas on the user's behalf.
- This wrapper drives ceremonies; it does not replace `gsd-verify-work` — run
  that (or the repo's verification flow) when the user wants phase verification.

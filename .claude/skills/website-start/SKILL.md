---
name: website-start
description: Session-resume skill for the Official website, devblog, press kit, and community hub repo (active — v1.0 live). Auto-fires on the first user turn in this repo. Reads vault/context.md + vault/conventions.md, checks vault/decisions/ for recent entries, surfaces git status and GSD phase state, and prints a compact briefing.
argument-hint: ""
allowed-tools: Read, Bash, Grep, Glob
---

# /website-start — Resume session

Lean session-resume briefing for a dormant stub repo. No engine-style heavy
machinery here (no brain-state-stamp, no STATUS.md, no math-lock) — the
briefing is built fresh each time from the vault + git state.

## When to invoke

- **Automatically** on the first user message of any Claude session in this repo.
- **Manually** when the user types `/website-start`.

## Procedure

### Step 1 — Read vault context

Read `vault/context.md` and `vault/conventions.md` (both should exist —
stub scaffolding). Note it and continue if either is missing.

### Step 2 — Read the runbook

Read `RUNBOOK.md` at the repo root — it carries the skills catalog and the
what-next decision table; use it to ground the briefing's "ready to"
suggestions.

### Step 3 — Check decisions

```bash
ls -1t vault/decisions/*.md 2>/dev/null | grep -v '\.gitkeep'
```

If any exist, read the newest 1-2 for recent decision context.

### Step 4 — Git state

```bash
git status -sb
git log --oneline -3
```

Interpret briefly: is the tree clean? What do the last 3 commits suggest
about recent focus?

### Step 5 — GSD state (if active)

```bash
test -f .planning/STATE.md && cat .planning/STATE.md
```

If present, print milestone/phase/status from frontmatter. Skip silently
if absent — most of these repos have no GSD state yet (pre-activation).

### Step 6 — Obligations (cheap, optional)

```bash
grep -l "^status: active$" ../studio/vault/project/milestones/*/manifest.md 2>/dev/null
```

No active org-milestone → skip this step silently, no line in the briefing.

If one or more are active: for each, read its `obligation_spec:` frontmatter
field and open `../studio/vault/obligations/{that file}`, then check
`../studio/vault/obligations/*.md` whose `milestone` glob matches this
manifest's milestone and whose `repos` (if set) includes this repo. List any
with `status` not `done` as a one-line `Obligations:` addition to the
briefing (slug + title). Skip silently on any read failure — this is a
courtesy surface, not a gate.

### Step 6b — Coupled phases (Session Pairing Protocol — D-AH)

```bash
grep -l "status: active" ../studio/vault/project/milestones/*/manifest.md 2>/dev/null
```

For each active manifest, check its "Coupled phases" table for rows naming
this repo. If the repo's current/next phase (Step 5's GSD state) matches a
row, the briefing gains a `Coupled:` line — peer repo + phase, plus
"shaping steps need BOTH sessions live (Session Pairing Protocol)". Skip
silently when no manifest, no table, or no match.

### Step 7 — Compose briefing (≤8 lines)

```
## Resume briefing — Official website, devblog, press kit, and community hub
Status: <dormant / active, from vault/context.md>
Branch: <name> (<clean | N dirty>)
Last commits: <1-line interpretation of last 3>
Recent decision: <newest vault/decisions/ title + date, or "none">
GSD: <milestone/phase/status, or "no active plan">
Obligations: <unmet obligation slugs + titles for this repo; omit line if none/no active org-milestone>
Coupled: <peer repo · phase — both sessions live for shaping steps; omit line if none>
Ready to: <1-3 suggestions from RUNBOOK.md's "What do I do next?" table + context.md's "Activates when" + dirty files>
```

## Rules

- Read-only. Never edits, never commits.
- Skip any line/section whose source is missing or empty — don't pad the briefing.
- Don't invent GSD/engine machinery this repo doesn't have.

## Output

Markdown to stdout. ≤8-line briefing, then proceed with the user's first message.

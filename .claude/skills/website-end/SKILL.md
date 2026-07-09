---
name: website-end
description: Close a session in the Official website, devblog, press kit, and community hub repo — append a dated entry to vault/learnings/sessions.md, capture any gray-area decision to vault/decisions/, and commit the working tree with a conventional-commit message (no push). Use --discard to skip all writes.
argument-hint: "[--discard]"
allowed-tools: Read, Bash, Grep, Glob, Write, Edit
---

# /website-end — Close session

Lean session-close for a dormant stub repo. No stamp file, no STATUS.md
bump, no devlog pipeline — just a session log entry, an optional decision
capture, and a commit.

## When to invoke

- User signals end of session: "done for now", "let's wrap", `/website-end`.

## Procedure

### Step 1 — `--discard` check

If `--discard` is passed, skip straight to done — no writes, no commit.
Print `Session discarded — no writes.` and stop.

### Step 2 — Append session log

Ensure `vault/learnings/sessions.md` exists (create with a
`# Official website, devblog, press kit, and community hub — session log` heading if missing). Append:

```markdown
## YYYY-MM-DD — <slug>
- **Changed:** <1-3 bullets — what actually changed this session>
- **Decisions:** <link to vault/decisions/<file>.md if one was captured, else "none">
- **Next:** <one-line handoff for the next session>
```

### Step 3 — Capture gray-area decision (only if one was made)

If the session made a gray-area call (naming, scope, convention, vendor
choice), write it to `vault/decisions/<kebab-slug>.md` — one file per
decision, matching the studio Decision Log entry structure:

```markdown
# <Decision Title>

**Captured:** YYYY-MM-DD

**Decision:** <what was decided>
**Reasoning:** <why>
**Alternatives:** <what else was considered, if any>
```

Skip this step entirely if nothing gray-area came up.

### Step 4 — Commit

```bash
git add -A
git status -s
```

Refuse if any staged path looks like a secret (`*.env`, `*credentials*`,
`*secret*`, `*.pem`, `id_rsa*`, `*.key`, `*.kdbx`) — surface and stop.
Otherwise commit with a Conventional Commits message describing the
session's actual change:

```bash
git commit -m "<type>: <summary>"
```

Do **not** push. Note the unpushed state in the final report.

### Step 5 — Report

```
Session log: vault/learnings/sessions.md — 1 entry added
Decision: <vault/decisions/<file>.md written, or "none">
Commit: <sha> "<message>" — unpushed (no push per policy)
```

## Rules

- `--discard` skips Steps 2-4 entirely (no session log, no decision, no
  commit) — for purely exploratory sessions with nothing worth persisting.
- One concern per commit (Spoods global convention) — split before
  committing if the session touched unrelated things.
- Never push. Never commit files matching secret patterns — refuse and stop.
- These stub repos have no CLAUDE.md — everything durable lands in the vault.

## Output

Markdown to stdout — final report per Step 5.

# Runbook — interstellar-website

Official website, devblog, press kit, and community hub — the public
publish target for studio content. **Semi-active today**: it already
receives devblog `.md` commits from the studio `draft-devblog` → promote
pipeline (one post lands in `devlog/` per milestone) even though the site
build itself is a dormant scaffold. Fully activates at **Phase 2** (Steam
page / press kit era).

## Skills available here

| Skill | What it does |
|---|---|
| `/website-start` | Auto-fires on the first turn of any session here. Reads `vault/context.md` + `vault/conventions.md`, checks `vault/decisions/` for recent entries, surfaces git status and `.planning/STATE.md` (if present), prints a compact briefing. |
| `/website-end [--discard]` | Session close — appends `vault/learnings/sessions.md`, captures any gray-area decision to `vault/decisions/`, commits (no push). `--discard` skips all writes. |
| `gsd-*` phase-loop ceremonies (`gsd-new-milestone`, `gsd-discuss-phase`, `gsd-plan-phase`, `gsd-execute-phase`, `gsd-verify-work`, `gsd-code-review`) | Seeded once `/bootstrap-repo website` activates this repo. |

## Lifecycle & gate tier

**Tier t3 — Standard Review** (`gate-tiers.md`). Milestone close needs a
standard `gsd-code-review` run, or a plain checklist review for non-code
content (copy, broken links, press-kit accuracy). No mandatory multi-vendor
grid, no mandatory playtest. Bugs/broken pages still block; cosmetic nits
don't.

The devblog `.md` commits landing here pre-activation **don't trigger a
milestone or review** — they're routed by studio's `draft-devblog` →
promote flow, not by this repo's own GSD loop. Full site-build/press-kit
work only starts once Phase 2 routes through `/bootstrap-repo website`.

**Activation flow:** `/bootstrap-repo website` from a studio session →
`gsd-new-project` fed the PRD/Roadmap sections scoped to this repo →
`gsd-new-milestone` per the org manifest's website slice (Phase 2).

## What do I do next?

| State | Action |
|---|---|
| Repo still dormant (pre-Phase 2) | Nothing GSD-tracked to do — a devblog commit landing here via the promote flow is expected and needs no action beyond noting it in the session log. |
| Just bootstrapped | Run `gsd-new-milestone` using the manifest's website slice. |
| Mid-milestone | Check `.planning/STATE.md`, then run the next phase: `gsd-discuss-phase` → `gsd-plan-phase` → `gsd-execute-phase` → `gsd-verify-work`. |
| Phase complete | Standard review — `gsd-code-review` or a plain content checklist. No playtest gate at this tier. |
| Milestone slice complete | File the review record, then run `/studio-milestone status` in `studio` to write back the slice and get the `Next up:` line. |
| Session ending | `/website-end` (or `--discard` for a purely exploratory session). |
| Unsure | Read `../studio/RUNBOOK.md`. |

## Org context

- `../studio/RUNBOOK.md` — org-wide skill catalog + current state
- `../studio/vault/project/Milestone Playbook.md` — full open → close → devblog tutorial
- `../studio/vault/project/gate-tiers.md` — full tier definitions (this repo is t3)
- Standing obligations auto-surface at every session start via the SessionStart hook — nothing to run to see them.

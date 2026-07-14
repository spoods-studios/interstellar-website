# CLAUDE.md — interstellar-website

## What This Repo Is
Official website, devblog, press kit, and community hub — the devblog's
canonical home from engine M1.1 (Decision Log D-H). Part of the spoods-studios
ecosystem — see `~/Projects/spoods-studios/studio/` for the org-wide PRD,
Roadmap, and cross-repo decisions (the source of truth for anything spanning
repos). Activated 2026-07-13 under org-milestone m1.x.

## Vault
`vault/context.md` — repo purpose + activation trigger.
`vault/conventions.md` — repo-local conventions (grows as GSD phases land).
`vault/decisions/` — repo-local decisions; cross-repo decisions live in studio's
Decision Log instead.

## Content
`devlog/` is the drop target for studio's `draft-devblog` → promote pipeline —
never move, rename, or restyle its `.md` files; the site layer renders them
as-is (VOICE.md is locked, studio-side).

## Gate Tier
t3 — standard review/checklist; see `studio/vault/project/gate-tiers.md` for
what that requires at phase/milestone close.

## Workflow
GSD-driven: `.planning/STATE.md` is the authoritative phase/progress position.
See `.planning/ROADMAP.md` for the phase breakdown. GSD guidance:
`.claude/CLAUDE.md` (generated).

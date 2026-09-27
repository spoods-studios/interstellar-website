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
`devlog/`, `roadmap/`, and `pages/` are drop targets for the
studio devlog draft → promote pipeline (drafted in-repo per D-AJ) — never move, rename, or restyle their
`.md` files; the site layer renders them as-is (VOICE.md is locked, studio-side).
The per-phase technical deep-dive series (`technical/`) was retired and
unpublished (studio Decision Log D-BN, 2026-09-02).

Once a devlog or roadmap page has deployed, its URL is permanent —
Discord embeds, RSS guids, and studio-vault references all pin these URLs, so a
rename without a stub breaks links already published to readers, and unlike a
broken build nothing tells you it happened (the only trace is the analytics
dashboard counting the 404 page at the dead URL's own path). If a promoted file
must be renamed anyway, add the old path to `SLUG_REDIRECTS` in
`astro.config.mjs` in the same commit as the rename: base-free key, destination
composed from `NORMALIZED_BASE` (Astro emits string destinations verbatim, so a
base-less destination redirects readers to a path that does not exist).

## Gate Tier
t3 — standard review/checklist; see `studio/vault/project/gate-tiers.md` for
what that requires at phase/milestone close.

## Workflow
GSD-driven: `.planning/STATE.md` is the authoritative phase/progress position.
See `.planning/ROADMAP.md` for the phase breakdown. GSD guidance:
`.claude/CLAUDE.md` (generated).

## Git workflow
`origin` = Forgejo forge; push to `origin` only. Every `main` push auto-mirrors to
GitHub (the org's one exception) so Pages `deploy.yml` keeps publishing — never
add a manual `git push github main`. Issues live on the forge (D-BJ/D-BK).
See `RUNBOOK.md` § Git workflow.

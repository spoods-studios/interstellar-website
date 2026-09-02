# Runbook — interstellar-website

Official website, devblog, press kit, and community hub — the public publish
target for studio content. **Active — v1.0 shipped 2026-08-11**: Astro 7
static site live at `spoods-studios.github.io/interstellar-website` (GitHub
Pages, Actions deploy on every push to `main`). 99 pages: full devblog archive
(manifesto + M0.1–M1.1 announcements), 55+ technical deep-dives, roadmap
pages, How It's Made AI-transparency page, RSS + OpenGraph + Discord CTA.

**Steady-state today (rest of Era 1):** the repo is a publish target, not a
build site. Engine devlogs dual-post here per studio **D-Z** — every engine
phase verify drafts a technical deep-dive, the user accepts it, and it lands
in BOTH Discord `#technical-devlog` and this repo (`technical/m{X.Y}/`);
milestone announcements land in `devlog/`. Commit + push = deploy. Next
build-out milestone is **Era 2** (press kit / Steam launch campaign — Roadmap
§5.4); no site milestone is scheduled before then.

## Skills available here

| Skill | What it does |
|---|---|
| `/website-start` | Auto-fires on the first turn of any session here. Reads `vault/context.md` + `vault/conventions.md`, checks `vault/decisions/` for recent entries, surfaces git status and `.planning/STATE.md`, prints a compact briefing. |
| `/website-end [--discard]` | Session close — appends `vault/learnings/sessions.md`, captures any gray-area decision to `vault/decisions/`, stamps the org status board (`../studio/vault/project/repo-status.md`, D-AA), commits (no push). `--discard` skips all writes. |
| `gsd-*` phase-loop ceremonies | Live since v1.0 bootstrap (2026-07-13). Used for site build-out milestones only — content promotion never runs through GSD. |

## Lifecycle & gate tier

**Tier t3 — Standard Review** (`gate-tiers.md`). Milestone close needs a
standard `gsd-code-review` run, or a plain checklist review for non-code
content (copy, broken links, press-kit accuracy). No mandatory multi-vendor
grid, no mandatory playtest. Bugs/broken pages still block; cosmetic nits
don't.

**Content commits don't trigger milestones or review** — devlog/technical
`.md` files landing here via the D-Z publish flow (or studio's `draft-devblog`
→ promote for announcements) deploy on push and need no ceremony. GSD wakes
up again only for real site work (Era 2 press kit, feature changes).

## Publish rules (v1.0 invariants — violating these breaks live readers)

- **URLs are permanent.** Deployed devlog/technical/roadmap URLs are pinned by
  Discord embeds, RSS guids, and studio-vault references. Renaming a promoted
  file requires a `SLUG_REDIRECTS` entry in `astro.config.mjs` in the SAME
  commit (base-free key, base-composed destination) — see CLAUDE.md.
- **Content renders as-is.** `devlog/`, `technical/`, `roadmap/`, `pages/` are
  drop targets; never restyle or restructure their `.md` (VOICE.md is locked
  studio-side).
- **Deploy is self-checking.** `deploy.yml` runs a post-deploy live-probe
  smoke job (homepage, feed, launch post, 404-under-base, redirect stub);
  build-sha freshness stamp on every page. A red smoke job means readers see
  a broken site — fix before anything else.

## Known gaps (v1.0 close, accepted)

- **ANLT-01 deferred (D-61):** GoatCounter analytics mechanism shipped but not
  live-certified — needs signup → `GOATCOUNTER_CODE` in `src/lib/site.mjs` →
  push → confirm dashboard records (incl. 404 traffic per D-62).
- Nyquist VALIDATION.md for Phases 3–4 left `draft` — coverage TODO.
- Full audit: `.planning/MILESTONES.md` + `milestones/v1.0-MILESTONE-AUDIT.md`.

## What do I do next?

| State | Action |
|---|---|
| A devlog/technical post needs publishing | Copy the accepted master in, commit, push — deploy is automatic. Verify the smoke job stays green. |
| Broken page / red smoke job | Fix now — this is the only t3 state that blocks everything else. |
| Era 2 opens (press kit slice) | `gsd-new-milestone` from the Era-2 org manifest's website slice. |
| Session ending | `/website-end` (or `--discard` for purely exploratory sessions). |
| Unsure | Read `../studio/RUNBOOK.md`; live org state: `../studio/vault/project/repo-status.md`. |

## Git workflow (forge — D-BJ/D-BK)

`origin` = `ssh://git@git.home.spoodsstudio.com:2222/spoods-studios/interstellar-website.git`
(Forgejo, LAN/Tailscale); `github` = mirror. Push to `origin` only. This repo is
the one exception to the org's tag-only mirror: `.forgejo/workflows/release.yml`
mirrors **every** `main` push to GitHub, where `deploy.yml` publishes Pages —
so "commit + push = deploy" still holds, and a manual `git push github main`
is never needed. Issues live on the forge. Full rules:
`../studio/vault/project/git-forge-workflow.md`.

## Org context

- `../studio/RUNBOOK.md` — org-wide skill catalog + current state
- `../studio/vault/project/repo-status.md` — live org status board (D-AA)
- `../studio/vault/project/milestones/m1.x/manifest.md` — this repo's m1.x slice (closed)
- `../studio/vault/project/gate-tiers.md` — full tier definitions (this repo is t3)
- `../studio/vault/devlog/discord/POSTING.md` — Discord half of the dual-post flow
- Standing obligations auto-surface at every session start via the SessionStart hook.

# Runbook — interstellar-website

Official website, devblog, press kit, and community hub — the public publish
target for studio content. **Active — v1.0 shipped 2026-08-11**: Astro 7
static site live at `spoods-studios.github.io/interstellar-website` (GitHub
Pages, Actions deploy on every push to `main`). Full devblog archive
(manifesto + milestone announcements), roadmap pages, How It's Made
AI-transparency page, RSS + OpenGraph + Discord CTA.

**Steady-state today (rest of Era 1):** the repo is a publish target, not a
build site. Milestone announcements land in `devlog/`. Commit + push =
deploy. The per-phase technical deep-dive series (`technical/`) was
retired and unpublished (studio Decision Log D-BN) — engine devlogs no
longer dual-post here. Next build-out milestone is **Era 2** (press kit /
Steam launch campaign — Roadmap §5.4); no site milestone is scheduled
before then (Era 2 is parked in `../.forge/todo.md`; the old Roadmap is
archived at `../.forge/archive/Roadmap.md`).

## Skills available here

| Skill | What it does |
|---|---|
| forge (`/forge-new`, `/forge-quick`, `/forge-fast`) | Planned and ad-hoc work in this repo. `CLAUDE.md` routes to the `.forge/` docs. |
| `/forge-discuss` → `/forge-phase` → `/forge-verify` → `/forge-ship` | Feature loop for site build-out work a workspace track carries for this repo. Content promotion never runs through it. (v1.0 was built on the now-retired GSD loop, bootstrapped 2026-07-13; history in `.forge/archive/gsd/`.) |

## Lifecycle & gate tier

**Tier t3 — Standard Review** (`gate-tiers.md`). Milestone close needs a
standard forge review (the `/forge-phase` review step and `/forge-ship` final review), or a plain checklist review for non-code
content (copy, broken links, press-kit accuracy). No mandatory multi-vendor
grid, no mandatory playtest. Bugs/broken pages still block; cosmetic nits
don't.

**Content commits don't trigger milestones or review** — devlog `.md` files
landing here (announcements drafted by `/studio-milestone devlog` at the
workspace root, then promoted) deploy on push and need no ceremony. Forge
feature work is only for real site work (Era 2 press kit, feature changes).

## Publish rules (v1.0 invariants — violating these breaks live readers)

- **URLs are permanent.** Deployed devlog/roadmap URLs are pinned by
  Discord embeds, RSS guids, and studio-vault references. Renaming a promoted
  file requires a `SLUG_REDIRECTS` entry in `astro.config.mjs` in the SAME
  commit (base-free key, base-composed destination) — see CLAUDE.md.
- **Content renders as-is.** `devlog/`, `roadmap/`, `pages/` are drop
  targets; never restyle or restructure their `.md` (VOICE.md is locked
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
- Full audit: `.forge/archive/gsd/MILESTONES.md` + `milestones/v1.0-MILESTONE-AUDIT.md`.

## What do I do next?

| State | Action |
|---|---|
| A devlog post needs publishing | Copy the accepted master in, commit, push — deploy is automatic. Verify the smoke job stays green. |
| Broken page / red smoke job | Fix now — this is the only t3 state that blocks everything else. |
| Era 2 opens (press kit) | `/forge-new` at the workspace root opens the track and adds the website feature; then `/forge-discuss` here, `/forge-phase` per phase, `/forge-verify`, `/forge-ship`. |
| Small site fix | `/forge-quick` or `/forge-fast`. |
| Unsure | Read `../RUNBOOK.md`; live org state: `../vault/project/repo-status.md`. |

## Git workflow (forge — D-BJ/D-BK)

`origin` = `ssh://git@git.home.spoodsstudio.com:2222/spoods-studios/interstellar-website.git`
(Forgejo, LAN/Tailscale); `github` = mirror. Push to `origin` only. This repo is
the one exception to the org's tag-only mirror: `.forgejo/workflows/release.yml`
mirrors **every** `main` push to GitHub, where `deploy.yml` publishes Pages —
so "commit + push = deploy" still holds, and a manual `git push github main`
is never needed. Issues live on the forge. Full rules:
`../vault/project/git-forge-workflow.md`.

## Org context

- `../RUNBOOK.md` — org-wide skill catalog + current state
- `../vault/project/repo-status.md` — live org status board (D-AA)
- `../vault/project/milestones/m1.x/manifest.md` — this repo's m1.x slice (closed; the org manifest machinery is retired, kept as history)
- `../vault/project/gate-tiers.md` — full tier definitions (this repo is t3)
- `../vault/devlog/discord/POSTING.md` — Discord half of the dual-post flow
- No hook surfaces obligations: this repo's `.claude/settings.json` is `{}` and the user-level settings add no SessionStart hook. Obligation specs live in `../vault/obligations/`; read them there. (Auto-surfacing went with the retired `/studio-milestone open|status|close` machinery.)

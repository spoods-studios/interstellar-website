# Interstellar Engine Website

## What This Is

The official Interstellar Engine website — the permanent, searchable home of the
devblog and the public face of the project. Launches at engine milestone M1.1
close as the canonical devblog archive (manifesto + M0.1–M0.8 posts), the "How
It's Made" AI-transparency page, and a roadmap page; from launch, Discord
#devlog carries each post's opening + link while the full post lives here.

## Core Value

Every devblog post has a permanent, linkable home before the audience ramp
starts — if everything else slips, the archive + launch post must be live at
M1.1 close.

## Requirements

### Validated

- [x] Deployed on GitHub Pages (custom domain attachable later without
      rework) — Validated in Phase 1: Stack & Scaffolding (push-to-main
      Actions deploy live at spoods-studios.github.io/interstellar-website;
      URL/base config-driven solely in `astro.config.mjs`)

### Active

- [ ] Devblog archive: manifesto + all M0.1–M0.8 posts rendered from the
      existing `.md` drafts (studio `vault/devlog/drafts/`), VOICE.md canon
      preserved
- [ ] "How It's Made" AI-transparency page (from `how-its-made.md` draft —
      obligation `ai-transparency-post`, D-G honesty constraints)
- [ ] Roadmap page mirroring the Discord #roadmap pinned overview
- [ ] M1.1 devblog post published as the launch post
- [ ] Prominent Discord invite CTA (Discord-first audience building, D-F)
- [ ] RSS feed for the devblog
- [ ] Privacy-respecting analytics (no cookies — Plausible/GoatCounter class)

### Out of Scope

- Press kit — Phase 2 per PRD §21.2 (EA launch era)
- Steam page / wishlist funnel — Phase 2
- Patreon integration — Patreon launches at M1.6 (D-F), not M1.1
- Comments / accounts / any backend — static site; Discord is the conversation
  venue
- Custom domain purchase — deferred; GitHub Pages URL is fine for launch,
  domain attaches later
- Generative-AI imagery/branding assets — D-G policy: no generative images;
  visuals come from engine captures and NASA/USGS data

## Context

- Part of the 12-repo spoods-studios ecosystem; org source of truth is
  `../studio/vault/` (PRD §21 Marketing, §22 Community Outreach scoped to this
  repo). Activated by `/bootstrap-repo` under org-milestone m1.x (slice:
  "Devblog home live at M1.1 close").
- Repo was a dormant stub already receiving devblog `.md` commits via studio's
  `draft-devblog` → promote pipeline (`devlog/` dir). The one post present
  (2026-04-07 manifesto) was previously flagged a misupload but is now the
  canonical manifesto per D-H launch content. `vault/context.md` / RUNBOOK.md
  "Phase 2/EA activation" lines are stale — D-H pulled activation to M1.1.
- Devblog voice is LOCKED: `../studio/vault/devlog/VOICE.md` (written video
  essay, Scott Manley/Everyday Astronaut register). The site renders that
  content; it must not restyle it.
- Marketing philosophy (PRD §21.1): no fake hype, show real work, let the work
  speak. The site is quiet and content-first, not a marketing splash.
- Obligations gating M1.1 close: `website-launch.md`, `ai-transparency-post.md`
  (both `on-complete M1.1`, studio vault).

## Constraints

- **Gate tier**: T3 (standard review/checklist per
  `../studio/vault/project/gate-tiers.md`) — bugs/broken pages block, cosmetic
  nits don't. No multi-vendor grid, no playtest.
- **Timeline**: Live by engine M1.1 close — the engine milestone is the clock;
  site work must not become the long pole.
- **Tech stack**: Static site generator, choice made in-phase after research
  (vendor-conservative: well-established tools only). Must deploy to GitHub
  Pages.
- **Content**: Site renders existing locked content; devblog `.md` files remain
  the source of truth (promote pipeline keeps landing them in `devlog/`).
- **Privacy**: No cookies, no invasive tracking — analytics must be
  privacy-respecting or absent.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| GitHub Pages hosting, domain TBD | Free, zero-ops, repo already on GitHub; custom domain attaches later without rework | — Pending |
| v1 includes Discord CTA + RSS + privacy analytics beyond the four D-H pieces | Discord-first growth (D-F), devblog readers expect RSS, measure without tracking | — Pending |
| Static-site tooling decided in-phase | M1.1-window decision per D-H; research compares established options | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-14 after Phase 1 completion (Stack & Scaffolding — Astro + Pages deploy pipeline live)*

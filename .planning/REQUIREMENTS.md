# Requirements — Interstellar Engine Website

v1 scope pinned at bootstrap (2026-07-13, org-milestone m1.x, D-H launch content)
plus research-promoted table stakes. Target: live at engine M1.1 close.

## v1 Requirements

### Site Platform

- [x] **SITE-01**: Site builds with Astro and deploys to GitHub Pages via GitHub Actions on every push to main
- [x] **SITE-02**: Site URL/base path is config-driven in one place, so attaching a custom domain later requires no content or template changes
- [ ] **SITE-03**: Build fails loudly on schema/content errors (no silent skips); a post-deploy smoke check verifies the live site actually updated
- [x] **SITE-04**: Baseline polish present: mobile-responsive layout, custom 404 page, favicon, canonical URLs, sitemap.xml

### Content

- [x] **CONT-01**: Devblog posts in `devlog/` render from Markdown via a permissive content schema — full frontmatter honored, missing frontmatter tolerated with date/slug derived from `YYYY-MM-DD-slug.md` filenames (manifesto has no frontmatter)
- [x] **CONT-02**: Full archive live at launch: manifesto + M0.1–M0.8 posts (promoted from studio `vault/devlog/drafts/`), rendered alongside the technical deep-dive series (55 phase-level entries plus the how-to-read legend) and the milestone roadmap detail docs (8 pages, one per M0.1–M0.8) that Plan 02-01 promoted in the same pass — VOICE.md content untouched by the site layer across all four content trees
- [x] **CONT-03**: "How It's Made" AI-transparency standalone page renders from `pages/` (structurally separate collection — never appears in archive/RSS), content per D-G honesty constraints
- [x] **CONT-04**: Roadmap overview page rendering the site-voice transcription of the Discord #roadmap pinned overview (D-37), plus 8 milestone-level roadmap detail pages (D-38) sourced from a separate `roadmap/` collection, each cross-linking into its milestone's technical deep-dives
- [ ] **CONT-05**: M1.1 devblog post published as the launch post
- [ ] **CONT-06**: Slug-immutability norm documented; redirect-stub mechanism exists for any future slug change (Discord links must not 404)

### Distribution

- [ ] **DIST-01**: RSS feed generated from the same content-collection query as the archive page (cannot drift), validates clean
- [x] **DIST-02**: Every post and page emits OpenGraph + Twitter Card metadata; a live post URL renders a rich embed when pasted in Discord *(research-promoted: Discord-first distribution makes this load-bearing)*
- [x] **DIST-03**: Prominent Discord invite CTA on every page (Discord-first audience building, D-F)

### Analytics

- [ ] **ANLT-01**: Cookieless privacy-respecting pageview analytics (GoatCounter-class) on all pages; no consent banner needed because nothing needs consent

## v2 Requirements (deferred)

- **SITE-05**: Dark mode (pair with syntax-highlighting themes — do together)
- **CONT-07**: KaTeX math rendering remains deferred to v2 (needed for D-H rendering deep-dive series, M1.3+). Build-time syntax highlighting — the other half of this requirement — shipped in Phase 2 via Shiki's `github-light` theme (D-41) and is no longer deferred.
- **DIST-04**: Custom domain attachment (SITE-02 keeps this a non-event)
- **CONT-08**: Search / tag taxonomy — deferred; the corpus is reachable via two structural routes (the technical era/milestone index and the roadmap-generated deep-dive cross-links, D-40), so a search index still has no payoff

## Out of Scope

- Comments, accounts, newsletter — Discord is the conversation venue; static site, no backend
- Press kit, Steam page, wishlist funnel — Phase 2 (PRD §21.2, EA era)
- Patreon integration — Patreon launches at M1.6 (D-F)
- CMS / admin UI — Markdown in git is the CMS
- Generative-AI imagery — D-G policy; visuals are engine captures + NASA/USGS data
- Automated studio→website promote script — process gap noted in research; studio-side concern, not this repo's scope

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SITE-01 | Phase 1 | Complete |
| SITE-02 | Phase 1 | Complete |
| CONT-01 | Phase 1 | Complete |
| CONT-02 | Phase 2 | Complete |
| CONT-03 | Phase 2 | Complete |
| CONT-04 | Phase 2 | Complete |
| SITE-04 | Phase 2 | Complete |
| DIST-01 | Phase 3 | Pending |
| DIST-02 | Phase 3 | Complete |
| DIST-03 | Phase 3 | Complete |
| ANLT-01 | Phase 4 | Pending |
| CONT-05 | Phase 4 | Pending |
| CONT-06 | Phase 4 | Pending |
| SITE-03 | Phase 4 | Pending |

**Coverage:** 14/14 v1 requirements mapped — no orphans, no duplicates.

---
*REQ-IDs stable once committed. Scope changes go through PROJECT.md Key Decisions.*

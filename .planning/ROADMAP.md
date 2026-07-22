# Roadmap: Interstellar Engine Website

## Overview

A boring, content-first Astro static site on GitHub Pages that gives every
devblog post a permanent, linkable home before the audience ramp starts. The
journey: scaffold the Astro pipeline with a permissive filename-fallback schema
and a config-driven URL (Phase 1) → render the full archive plus the "How It's
Made" and Roadmap standalone pages with baseline polish, VOICE.md prose
untouched (Phase 2) → wire RSS, OpenGraph/Twitter cards, and the Discord CTA so
shared links produce rich embeds and readers can subscribe (Phase 3) → add
cookieless analytics, publish the M1.1 launch post, and harden the deploy
against silent failure and dead links (Phase 4). Live by engine M1.1 close, and
never the long pole.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Stack & Scaffolding** - Astro pipeline deploys to GitHub Pages with a config-driven URL and permissive devlog ingestion (completed 2026-07-14)
- [ ] **Phase 2: Content Rendering & Templating** - Full archive + How It's Made + Roadmap pages render with baseline polish, VOICE untouched
- [ ] **Phase 3: RSS, OpenGraph & Discord Distribution** - Rich Discord embeds, a clean RSS feed, and a prominent Discord CTA on every page
- [ ] **Phase 4: Analytics, Launch Content & Deploy Hardening** - Cookieless analytics, the M1.1 launch post live, and a deploy safe against silent failure

## Phase Details

### Phase 1: Stack & Scaffolding

**Goal**: The Astro pipeline deploys to GitHub Pages from a config-driven URL and ingests devlog Markdown permissively — the foundation is green end-to-end on a trivial page.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: SITE-01, SITE-02, CONT-01
**Success Criteria** (what must be TRUE):

  1. Pushing to `main` triggers a GitHub Actions run that builds the site and deploys it to GitHub Pages
  2. A visitor can load the deployed site at its GitHub Pages URL
  3. The site's URL/base path lives in one config location; changing it updates all internal links with no template edits (no hardcoded `github.io` strings)
  4. A `devlog/*.md` file with no frontmatter is ingested with date and slug derived from its `YYYY-MM-DD-slug.md` filename, without failing the build

**Plans**: 2/2 plans complete
**Wave 1**

- [x] 01-01-PLAN.md — Scaffold Astro at repo root + local ingest→build slice (config-driven URL, permissive devlog ingestion, loud-fail on malformed content)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — Deploy to GitHub Pages via GitHub Actions on every push to main + live-deploy verification

### Phase 2: Content Rendering & Templating

**Goal**: The full devblog archive and both standalone pages render as readable, mobile-friendly pages with baseline polish, VOICE.md prose untouched by the site layer.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: CONT-02, CONT-03, CONT-04, SITE-04
**Success Criteria** (what must be TRUE):

  1. A visitor can browse an archive index listing the manifesto + all M0.1–M0.8 posts and open any one to read the full post
  2. Rendered post text matches the source `.md` exactly — the site restyles nothing about the locked VOICE content
  3. A visitor can open the "How It's Made" and "Roadmap" standalone pages, neither of which appears in the archive listing
  4. The site is legible on mobile and desktop, serves a custom 404, shows a favicon, exposes `sitemap.xml`, and emits canonical URLs

**Plans**: 8 plans
**UI hint**: yes

**Wave 1**

- [ ] 02-01-PLAN.md — Promote all four content trees for M0.1–M0.8 (9 announcements, 55 deep-dives + legend, 8 roadmap docs, 2 standalone pages)
- [ ] 02-02-PLAN.md — Site shell: hand-written CSS, BaseLayout header/nav/footer, favicon, custom 404

**Wave 2** *(blocked on Wave 1)*

- [ ] 02-03-PLAN.md — Three new collections, shared helpers, Sätteri wikilink mdast plugin, light-theme Shiki, sitemap

**Wave 3** *(blocked on Wave 2)*

- [ ] 02-04-PLAN.md — Shared PostLayout + build-time TOC + announcement post route

**Wave 4** *(blocked on Wave 3)*

- [ ] 02-05-PLAN.md — Archive homepage (includes blocking D-16 one-liner sign-off)
- [ ] 02-06-PLAN.md — Technical tree: full/per-milestone indexes, deep-dive pages, bidirectional cross-links
- [ ] 02-07-PLAN.md — Roadmap overview + 8 milestone detail pages + How It's Made page

**Wave 5** *(blocked on Wave 4)*

- [ ] 02-08-PLAN.md — SITE-04 whole-site sweep, loud-fail fixtures, requirement-wording housekeeping, human verification

### Phase 3: RSS, OpenGraph & Discord Distribution

**Goal**: Shared links produce rich Discord embeds, readers can subscribe by RSS, and every page routes to Discord — making the Discord-first distribution strategy actually work.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: DIST-01, DIST-02, DIST-03
**Success Criteria** (what must be TRUE):

  1. A reader can subscribe to an RSS feed listing every devblog post (standalone pages excluded), generated from the same collection query as the archive so the two cannot drift
  2. Pasting a live post or page URL into Discord renders a rich embed with title, description, and image
  3. Every page displays a prominent Discord invite CTA
  4. The RSS feed validates clean against a standard feed validator

**Plans**: TBD

### Phase 4: Analytics, Launch Content & Deploy Hardening

**Goal**: The site measures traffic without cookies, the M1.1 launch post is live, and the pipeline is safe against silent failure and dead links as the site enters its low-attention steady state.
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: ANLT-01, CONT-05, CONT-06, SITE-03
**Success Criteria** (what must be TRUE):

  1. Pageviews are recorded via cookieless, privacy-respecting analytics on all pages, with no consent banner shown
  2. The M1.1 devblog launch post is live and appears at the top of the archive and the RSS feed
  3. A malformed or invalid post fails the build loudly (no silent skip), and a post-deploy smoke check confirms the live site actually served the new content
  4. The slug-immutability norm is documented and a redirect-stub mechanism exists, so a future renamed post's old URL does not 404

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Stack & Scaffolding | 2/2 | Complete    | 2026-07-14 |
| 2. Content Rendering & Templating | 0/8 | Planned | - |
| 3. RSS, OpenGraph & Discord Distribution | 0/TBD | Not started | - |
| 4. Analytics, Launch Content & Deploy Hardening | 0/TBD | Not started | - |

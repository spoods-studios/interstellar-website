# Project Research Summary

**Project:** interstellar-website
**Domain:** Content-first static devblog / marketing site (indie game-engine studio), GitHub Pages, solo developer
**Researched:** 2026-07-13
**Confidence:** MEDIUM

## Executive Summary

This is a Markdown-sourced static devblog site: render an existing, human-drafted archive (manifesto + M0.1-M0.8 devlog posts) plus two standalone pages (AI-transparency "how it's made," roadmap) onto GitHub Pages, with zero backend and near-zero ongoing maintenance. Research converges on a single clear recommendation: **Astro 7.x**, deployed via the official `withastro/action` + `actions/deploy-pages` GitHub Actions workflow, with a **permissive, filename-fallback content schema** -- because the one live post today has no frontmatter at all while future promoted posts will, and the schema must tolerate both without blocking a build or requiring a content-pipeline rewrite.

The recommended approach treats `devlog/` as an untouchable drop target for the existing studio-to-website manual-promote pipeline (never migrate it into an SSG's default content folder), separates standalone pages into a sibling `pages/` directory so they structurally can't leak into the RSS/archive, and keeps the whole stack boring and small: Astro + `@astrojs/rss` + `@astrojs/sitemap` + hosted GoatCounter analytics (cookieless, zero-ops, matches the project's explicit no-tracking constraint). No CMS, no comments, no accounts, no custom domain yet -- all correctly identified as anti-features or deferred scope per PROJECT.md.

The key risk is not technical difficulty but **scope creep and silent-failure classes typical of "invisible infrastructure" sites**: the site competing with engine-dev time via endless polish, broken OpenGraph/RSS previews shipping unnoticed (directly undermining the Discord-first distribution strategy), baseurl assumptions that create migration pain when a custom domain attaches later, and CI reporting green while serving a stale build. All are cheap to prevent by baking fixes into the scaffolding/templating phase (permissive schema, per-post OG tags, root-relative/config-driven URLs, fail-loud builds, a post-deploy smoke check) rather than expensive to fix retroactively. One scope gap surfaced by research: **OpenGraph/social-embed metadata is not explicitly in the v1 scope as written but should be promoted to P1** -- it is the single highest-leverage feature given Discord is the primary distribution channel.

## Key Findings

### Recommended Stack

Astro 7.0.9 is the clear pick: purpose-built for content-heavy, low-interactivity sites (ships zero JS by default via islands), has an official GitHub Pages deploy Action, and its Content Collections give schema-validated Markdown ingestion with per-field optionality -- directly solving this repo's mixed-frontmatter problem. Eleventy and Hugo are reasonable seconds (less abstraction, single-binary/no-Node respectively) but were passed over because Astro's official tooling more directly reduces the "site must never become the long pole" risk. Jekyll's legacy zero-config GitHub Pages auto-build path is explicitly discouraged (stale pinned version, not the modern recommended path).

**Core technologies:**
- Astro 7.0.9 -- static site generator -- official GH Pages Action, Content Collections solve mixed-frontmatter problem, zero-JS-by-default
- @astrojs/rss 4.0.19 -- RSS feed generation -- build-time endpoint fed by the same `getCollection()` query as the archive, single source of truth
- GitHub Actions (`withastro/action` + `actions/deploy-pages@v5`) -- build + deploy -- GitHub's own recommended modern Pages path
- GoatCounter (hosted) -- privacy-respecting analytics -- free non-commercial tier, cookieless, zero server to run, satisfies the no-tracking constraint

### Expected Features

**Must have (table stakes):**
- Devblog archive rendering the existing `.md` corpus -- the Core Value / reason the site exists
- RSS feed, sitemap.xml, canonical URLs, custom 404, favicon -- near-zero-cost SSG defaults
- Mobile-responsive layout, readable long-form typography (65-75ch column), accessible contrast
- **OpenGraph + Twitter Card meta tags -- flagged gap, recommend promoting to v1/P1**: without it, every Discord-shared link renders as a bare URL, undercutting the primary distribution channel

**Should have (competitive):**
- "How It's Made" AI-transparency page -- genuine trust differentiator, content already drafted
- Roadmap page mirroring Discord #roadmap pin -- transparency most competitor devblogs don't offer outsiders
- Devblog archive as a permanent, linkable, searchable home -- the actual product differentiator vs. treating Discord as the de facto archive
- Cookieless analytics -- quiet trust signal vs. GA-tracked competitor blogs

**Defer (v2+):**
- Code syntax highlighting, KaTeX math rendering -- trigger: first rendering-deep-dive / physics-notation post lands (verify SSG supports both now so it's cheap later)
- Dark mode toggle -- trigger: post-launch, verify SSG support pre-launch to avoid a retheme
- Custom domain -- deferred per PROJECT.md, must be a zero-rework later add
- Press kit, Steam funnel, Patreon, tag/category filtering, comments -- explicitly out of scope (Phase 2 / M1.6 / never, per PROJECT.md)

### Architecture Approach

The site is a one-way pipeline: studio vault drafts -> manual human-promoted commit into `devlog/*.md` (untouched, flat, `YYYY-MM-DD-slug.md` naming) -> Astro build-time content collection with a **permissive, filename-derived-fallback schema** (date/slug always from filename; title/milestone/status/hero_visual all optional) -> shared collection object drives both the archive page and RSS feed -> GitHub Actions build/deploy -> GitHub Pages. Standalone pages (`how-its-made.md`, `roadmap.md`) live in a new sibling `pages/` directory, structurally excluded from the post collection so they can never leak into the RSS feed or archive listing.

**Major components:**
1. `devlog/*.md` (content source) -- canonical posts, promote-pipeline drop target, never moved/renamed to fit an SSG convention
2. Content collection / schema layer -- parses frontmatter with fallbacks, validates, feeds both archive templates and RSS generator from one query
3. `pages/*.md` (standalone content) -- how-its-made, roadmap; separate directory/collection, structural (not flag-based) exclusion from archive/RSS
4. GitHub Actions build+deploy -- checkout -> setup-node/Astro action -> build -> upload-pages-artifact -> deploy-pages, minimal-permissions workflow
5. Client-side analytics embed -- single script tag in base layout, zero build-time coupling

### Critical Pitfalls

1. **Site becomes a second project competing with engine dev time** -- pick the SSG with smallest ongoing surface, define "done" as a fixed checklist before starting, treat "renders locked content, doesn't restyle it" as a hard scope fence.
2. **Broken RSS/OpenGraph previews at launch (silent, high-visibility)** -- every template must emit per-page OG tags from frontmatter (never hardcoded once in base layout), absolute URLs throughout, validate feed + manually test a real Discord embed before the launch post goes out.
3. **GitHub Pages baseurl/custom-domain rework at migration time** -- never hardcode `github.io` strings in templates; use root-relative paths and a single config-driven URL source so attaching a custom domain later is a <5 min change, not a rework.
4. **Silent stale deploys** -- CI can report green while Pages serves an old build; build must fail loudly on malformed content, and a post-deploy smoke check (curl + grep latest slug) should be part of the workflow, not manual-only.
5. **Dead links from slug changes** -- GitHub Pages has no server-side redirect layer; treat slugs as permanent once published, and generate a static meta-refresh redirect stub if a rename is ever unavoidable.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Stack & Scaffolding
**Rationale:** The SSG choice and project structure are the single highest-leverage decisions for containing scope and avoiding the baseurl/frontmatter pitfalls -- cheap to get right now, expensive to fix after content and templates exist.
**Delivers:** Astro project scaffolded, `devlog/` wired in-place via a content-collection loader pointed at its existing path, permissive filename-fallback schema in place, `pages/` sibling directory created, GitHub Actions deploy workflow (Actions-based Pages source, minimal permissions) green on a trivial page.
**Addresses:** Devblog archive foundation, mobile-responsive baseline, fast/no-heavy-JS goal (Astro's zero-JS-by-default).
**Avoids:** Pitfall 1 (scope creep -- pick the smallest-surface SSG, define "done" checklist), Pitfall 3 (baseurl rework -- root-relative/config-driven URLs from day one), Anti-Pattern 2 (requiring full frontmatter before render).

### Phase 2: Content Rendering & Templating
**Rationale:** With the schema and structure in place, render the actual corpus (manifesto already live, M0.1-M0.8 pending promotion) and standalone pages, since RSS/OG/archive all depend on working post templates.
**Delivers:** Post template, archive/index template, `how-its-made` and `roadmap` page templates, custom 404, favicon, canonical URLs, sitemap.xml.
**Uses:** Astro Content Collections (STACK.md), `@astrojs/sitemap`.
**Implements:** Content collection/schema layer, layouts/templates, pages/ standalone-page boundary (ARCHITECTURE.md components 2-3).

### Phase 3: RSS, OpenGraph & Discord Distribution
**Rationale:** These features share one dependency (post metadata from the collection) and one purpose (make the Discord-first distribution strategy actually work) -- grouping them ensures the feed and social previews are built and validated together rather than treated as separate afterthoughts.
**Delivers:** RSS feed (`@astrojs/rss`, collection-driven), per-post OpenGraph + Twitter Card meta tags (promoted to P1 per FEATURES.md flag), Discord CTA (prominent placement).
**Addresses:** RSS feed, OpenGraph metadata (FEATURES.md P1), Discord CTA (FEATURES.md P1).
**Avoids:** Pitfall 2 (broken RSS/OG previews -- validate feed, manually test real Discord embed before launch).

### Phase 4: Analytics, Launch Content & Deploy Hardening
**Rationale:** Last phase before going live -- wires in the zero-ops analytics vendor, lands the M1.1 launch post and remaining promoted M0.x posts, and hardens the deploy pipeline against silent failure since the site enters a low-attention steady state immediately after launch.
**Delivers:** GoatCounter embed, remaining devlog posts promoted from studio vault, launch post live, post-deploy smoke-check step in CI, redirect-stub convention documented for future slug changes.
**Addresses:** Privacy-respecting analytics, launch post, remaining archive completeness.
**Avoids:** Pitfall 5 (silent stale deploy -- fail-loud build + post-deploy check), Pitfall 6 (dead links -- redirect-stub norm documented pre-launch).

### Phase Ordering Rationale

- Stack/scaffolding must come first because the schema-permissiveness decision (filename fallback) is load-bearing for every later phase -- the one live post today would fail a strict schema, so getting this wrong blocks content rendering entirely.
- Templating before RSS/OG because both the feed and social metadata are generated FROM the same post templates/collection query (ARCHITECTURE.md Pattern 3) -- building them in the wrong order risks a second, drifting content list.
- RSS/OG/Discord CTA are grouped because PITFALLS.md identifies broken social previews as the single highest-visibility launch-day failure mode, and it's cheaper to build-and-validate as one unit than to bolt OG tags on after templates are "done."
- Deploy hardening and launch content are last because the pitfalls they address (stale deploys, dead links) only matter once real, frequently-changing content exists and the site enters its post-launch low-maintenance steady state.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (Stack & Scaffolding):** Astro Content Collections' exact API for pointing a `glob` loader at a path outside `src/content/` and mixing optional/fallback fields -- STACK.md's example is illustrative, not verified against current Astro 7.x docs for this specific pattern.
- **Phase 3 (RSS/OpenGraph):** No official Astro OG-tag-generation convention was fetched this session (only general SSG best-practice sources) -- worth a `--research-phase` pass to confirm the idiomatic Astro pattern for per-post OG image generation (static asset vs. generated banner).

Phases with standard patterns (skip research-phase):
- **Phase 2 (Content Rendering & Templating):** Astro's Content Collections + layout patterns are well-documented (official docs fetched this session, MEDIUM-HIGH confidence).
- **Phase 4 (Analytics & Deploy Hardening):** GitHub Actions Pages deploy workflow and GoatCounter script embed are both simple, well-established, single-script integrations.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Versions verified against npm/GitHub registries (HIGH); comparative/qualitative claims (Astro vs. Hugo vs. Eleventy, analytics vendor comparison) are web-search-only, cross-checked across 2-3 sources |
| Features | MEDIUM | Cross-verified against two live official engine-blog sites (Factorio, Godot) plus general SSG/blog convention search; no curated docs for this specific ecosystem exist |
| Architecture | MEDIUM-HIGH | Repo-state claims (current frontmatter shapes, promote-pipeline behavior, git log) are HIGH confidence -- read directly this session; generic SSG architecture patterns are MEDIUM, cross-checked against Astro's official docs |
| Pitfalls | MEDIUM | Web-cross-checked community and vendor-discussion sources (GitHub Community threads, Hugo/Jekyll forums); no HIGH-tier curated docs consulted for pitfalls specifically |

**Overall confidence:** MEDIUM

### Gaps to Address

- Frontmatter backfill decision: whether to retroactively add frontmatter to the already-live manifesto post, or rely solely on the filename-fallback schema -- flag for Phase 1 planning, not a blocker either way.
- No automated studio-to-website promote script exists today (manual git copy) -- out of scope for this repo, but worth flagging to the studio side as a future efficiency win once the manual pattern is proven a few times.
- Exact Astro Content Collections API syntax for external-path glob loaders + optional-field schemas should be verified against current docs during Phase 1 planning, not assumed from the illustrative example in STACK.md.
- OpenGraph image strategy (static per-post asset vs. build-time generated banner) needs a decision during Phase 3 planning -- research did not resolve which approach fits the "no generative AI imagery" constraint (D-G) best while staying near-zero-maintenance.

## Sources

### Primary (HIGH confidence)
- npm registry (`npm view astro version`, `@astrojs/rss`, `@11ty/eleventy`) -- version facts, run this session
- GitHub Releases API (Hugo, Zola, `actions/deploy-pages`) -- version facts, run this session
- Repo files read directly this session: `interstellar-website/devlog/2026-04-07-*.md`, `interstellar-website/PROJECT.md`, `interstellar-website/RUNBOOK.md`, `studio/vault/devlog/_TEMPLATE.md`, `studio/vault/devlog/drafts/*.md`, `~/.claude/skills/draft-devblog/SKILL.md`, `interstellar-website` git log

### Secondary (MEDIUM confidence)
- docs.astro.build (GitHub Pages deploy guide, RSS guide, Content Collections guide) -- fetched this session
- Live fetches of factorio.com/blog and godotengine.org/blog -- direct primary-source feature observation
- GitHub Community Discussions (#140606, #184514, #200884), docs.github.com HTTPS guide -- Pages/HTTPS/TLS pitfalls
- Hugo/Jekyll community discussions on baseurl/custom-domain migration

### Tertiary (LOW confidence)
- WebSearch comparisons: "Astro vs Hugo vs Eleventy 2026", "GoatCounter vs Plausible vs Umami 2026", general SSG/OG/RSS convention articles -- used only for comparative/qualitative claims, cross-checked across 2-3 sources where cited

---
*Research completed: 2026-07-13*
*Ready for roadmap: yes*

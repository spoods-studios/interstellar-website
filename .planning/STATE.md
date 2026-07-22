---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 2
current_phase_name: Content Rendering & Templating
status: executing
stopped_at: Completed 02-04-PLAN.md
last_updated: "2026-07-22T17:33:26.454Z"
last_activity: 2026-07-22
last_activity_desc: Phase 2 execution started
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 10
  completed_plans: 7
  percent: 25
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-13)

**Core value:** Every devblog post has a permanent, linkable home before the audience ramp starts — if everything else slips, the archive + launch post must be live at M1.1 close.
**Current focus:** Phase 2 — Content Rendering & Templating

## Current Position

Phase: 2 (Content Rendering & Templating) — EXECUTING
Plan: 6 of 8
Status: Ready to execute
Last activity: 2026-07-22 — Phase 2 execution started

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 2
- Average duration: — min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 2 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01 P01 | 5min | 3 tasks | 8 files |
| Phase 01 P02 | 6min | 2 tasks | 1 files |
| Phase 02 P01 | 20min | 3 tasks | 80 files |
| Phase 02 P02 | 15min | 2 tasks | 5 files |
| Phase 02 P03 | 30min | 3 tasks | 13 files |
| Phase 02 P04 | 20min | 2 tasks | 5 files |
| Phase 02 P05 | 15min | 2 tasks | 2 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Stack: Astro static site on GitHub Pages via GitHub Actions (`withastro/action` + `actions/deploy-pages`); tooling confirmed in-phase per D-H.
- Structure: `devlog/` is an untouchable promote-pipeline drop target; standalone pages live in a sibling `pages/` collection, structurally excluded from archive/RSS.
- Scope: v1 adds Discord CTA + RSS + OpenGraph + cookieless analytics beyond the four D-H content pieces; OG metadata promoted to P1 (Discord-first distribution).
- [Phase 01-01]: glob() loader base path corrected to './devlog' (project-root-relative, not content.config.ts-relative) per installed astro@7.0.9 .d.ts — RESEARCH.md Pattern 1's '../devlog' pointed one directory above the repo root and silently produced an empty collection
- [Phase 01-01]: Used Astro's set:html directive for devlog post titles instead of default {expr} escaping — Default interpolation HTML-encodes apostrophes, breaking the literal manifesto-title acceptance check; titles are git-trusted content, not runtime user input
- [Phase 01-01]: Task 3 tdd RED/GREEN satisfied via committed tests/build.smoke.sh instead of a JS test framework — RESEARCH.md's Validation Architecture explicitly scoped out a JS test framework for this build-pipeline phase; npm run build is the harness
- [Phase 01]: [Phase 01-02] 01-RESEARCH.md's deploy workflow code example was used verbatim per 01-PATTERNS.md's no-local-deviation assignment
- [Phase 02-01]: grep -c counts matching lines not occurrences; used grep -o | wc -l in tests/build.smoke.sh to correctly assert the nine-announcement archive count against Astro's minified single-line build output
- [Phase 02-01]: pages/how-its-made.md status line rewritten to bare 'status: published' (staging comment dropped) to satisfy exact-line-match publication criterion
- [Phase ?]: [Phase 02-02]: Normalized import.meta.env.BASE_URL to always carry a trailing slash before appending route segments in BaseLayout.astro/404.astro -- astro.config.mjs's base has no trailing slash, so naive concatenation produced malformed nav/favicon URLs
- [Phase ?]: [Phase 02-02]: tests/shell.smoke.sh checks dist/404.html's own chrome directly rather than diffing against dist/index.html, since index.astro has not adopted BaseLayout yet (out of this plan's scope)
- [Phase 02-03]: package.json "type" flipped commonjs->module so plain .ts helpers under src/lib/ resolve as ESM under Node 24's native type-stripping
- [Phase 02-03]: milestoneSortKey compares major/minor as separate parsed integers, not parseFloat on the whole string -- parseFloat('0.10') collapses to 0.1, sorting before parseFloat('0.9')=0.9
- [Phase 02-03]: Wikilink resolver's known-ids set built by walking technical/ directly with node:fs, mirroring content.config.ts's generateId logic, independent of Astro's internal collection state
- [Phase 02-03]: No real page template renders technical/roadmap/pages bodies yet -- collection-counts.json.ts and markdown-render-check.astro are small build-time-only routes proving collection counts and the wikilink/Shiki pipeline until Plans 04-07 land real routes
- [Phase 02-04]: Meta-line renders above the slot (above the body's own H1), not below it, since D-14 forbids splitting the rendered body
- [Phase 02-04]: Prev/next link text is the neighbouring post's actual title (arrow plus title), matching UI-SPEC's worked example, not a literal 'Previous' string
- [Phase 02-04]: Astro only hoists the exported getStaticPaths() function to true module scope -- helper functions it calls must live in an imported src/lib module, not as sibling frontmatter declarations, or the build fails at prerender time
- [Phase 02-05]: D-16 homepage one-liner approved verbatim by developer 2026-07-22: 'A space engine built from scratch on real n-body physics.' (replaces all three plan candidates)

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- Timeline: the whole roadmap must fit inside the engine M1.1 window — the site must not become the long pole.
- Phase 1 planning: verify current Astro Content Collections API for an external-path glob loader + optional/fallback fields (research example is illustrative). Also decide manifesto frontmatter-backfill vs. filename-fallback only.
- Phase 3 planning: decide OpenGraph image strategy (static per-post asset vs. build-time banner) within the D-G "no generative AI imagery" constraint.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Content | SITE-05 dark mode (pair with syntax themes) | v2 | 2026-07-13 |
| Content | CONT-07 syntax highlighting + KaTeX (verify Astro support in v1) | v2 | 2026-07-13 |
| Distribution | DIST-04 custom domain attachment (SITE-02 keeps it a non-event) | v2 | 2026-07-13 |
| Content | CONT-08 search / tag taxonomy (no payoff at ~9 posts) | v2 | 2026-07-13 |

## Session Continuity

Last session: 2026-07-22T17:32:41.250Z
Stopped at: Completed 02-04-PLAN.md
Resume file: None

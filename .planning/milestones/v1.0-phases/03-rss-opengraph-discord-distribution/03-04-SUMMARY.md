---
phase: 03-rss-opengraph-discord-distribution
plan: 04
subsystem: site-metadata
tags: [opengraph, discord, seo, ordering, d-45, d-50, d-51, d-52]
requires:
  - "src/lib/describe-entry.ts (describeBody) — Plan 03-01"
  - "src/lib/devlog-meta.ts (sortEntriesNewestFirst) — Plan 03-01"
  - "src/lib/site.mjs (SITE_TAGLINE) — Plan 03-01"
  - "src/layouts/PostLayout.astro metadata pass-through — Plan 03-01"
provides:
  - "Body-derived og:description on all 55 technical deep-dives"
  - "Body-derived og:description on all 8 roadmap milestone detail pages"
  - "Body-derived og:description on how-to-read, the roadmap overview and How It's Made"
  - "Homepage description sourced from the single D-16 SITE_TAGLINE constant"
  - "404 description reusing its own on-page D-19 sentence"
  - "The homepage archive on the shared newest-first comparator (D-45 drift fix)"
affects:
  - "Plan 03-05's whole-site coverage assertions (tests/distribution.smoke.sh)"
tech-stack:
  added: []
  patterns:
    - "Route computes its own description in page frontmatter; layout stays a pure pass-through"
    - "Descriptive copy is extracted from content bodies at build time, never hand-written site-side"
key-files:
  created: []
  modified:
    - src/pages/technical/[milestone]/[slug].astro
    - src/pages/technical/how-to-read.astro
    - src/pages/roadmap/[milestone].astro
    - src/pages/roadmap/index.astro
    - src/pages/how-its-made.astro
    - src/pages/index.astro
    - src/pages/404.astro
decisions:
  - "The nine generated index routes (technical index + 8 milestone indexes) deliberately inherit SITE_TAGLINE rather than carrying invented per-page prose"
  - "No publishedTime on the technical or roadmap trees — neither carries a real publication date, and `updated` on the standalone pages is a revision date"
  - "FEED_DESCRIPTION was left as its own literal rather than composed from SITE_TAGLINE, honouring Plan 03-01's recorded capitalization reasoning"
metrics:
  duration: ~25m
  completed: 2026-07-22
status: complete
---

# Phase 03 Plan 04: Whole-Site OpenGraph Coverage Summary

Expanded Plan 03-01's metadata slice from the one announcement route to every remaining
route, so all 86 built pages now emit the full OpenGraph/Twitter block with a description
drawn from their own body — and closed the D-45 ordering-drift loose end by moving the
homepage archive onto the shared `sortEntriesNewestFirst` comparator.

## What Was Built

**Task 1 — five entry-backed route families (`6ba9db1`).** The same two-line change in each
of `technical/[milestone]/[slug].astro`, `technical/how-to-read.astro`,
`roadmap/[milestone].astro`, `roadmap/index.astro` and `how-its-made.astro`: import
`describeBody`, compute `const description = describeBody(entry.body, entry.id)` after the
existing title computation, and pass `description` plus an explicit `ogType` through the
existing `<PostLayout …>` invocation. `article` on the 55 deep-dives and the 8 milestone
detail pages; `website` on the legend, the roadmap overview and the policy page. No
`publishedTime` on any of the five and no `ogImage` — the layout's default card stands.

The 55 deep-dives were the point of this task: all 55 open with the byte-identical
`> Retroactive technical devlog…` blockquote, which `describeBody`'s block skip-list drops,
so each page's description comes from its own first real prose paragraph rather than
collapsing 55 embeds onto one sentence.

**Task 2 — single-sourced copy, shared ordering, whole-site coverage (`b88e89d`).**
`index.astro` now imports `SITE_TAGLINE` for both the rendered one-liner and its
`description` prop, so the D-16 string has exactly one home in the repo. Its inline
newest-first comparator — which had no tie-break — was replaced by the shared
`sortEntriesNewestFirst`, putting the archive, the announcement route's prev/next chain and
the feed on one expression. `404.astro` extracts its existing D-19 sentence to a constant,
renders the paragraph from it and passes it as the description; no 404-specific marketing
copy was written.

`technical/index.astro` and `technical/[milestone]/index.astro` were deliberately not
edited — see Decisions below.

## Verification

| Check | Result |
|-------|--------|
| `npm run build` | exits 0, 86 pages |
| Distinct `og:description` values across build output | **76** (criterion: > 60) |
| `og:type` split | **72 article / 14 website**, summing to 86 |
| `article:published_time` page count | **9** (announcements only) |
| `article:published_time` in `dist/technical/` or `dist/roadmap/` | none |
| Every HTML file carries exactly one of each of the 12 unconditional tags | pass (scripted loop over `find dist -name '*.html'`) |
| Every `og:url` / `og:image` starts with the config-derived `https://spoods-studios.github.io/interstellar-website/` | pass |
| Longest `og:description` | ≤ 165 chars on every page |
| Deep-dive descriptions beginning `Retroactive technical devlog` | none |
| Tagline literal under `src/` | only `src/lib/site.mjs` |
| `sortEntriesNewestFirst` in index.astro, devlog/[slug].astro, devlog-meta.ts | all three |
| Local comparator `entryDate(b).getTime()` in index.astro | gone, not shadowed |
| Homepage post-list order before vs after comparator swap | byte-identical (`diff` of captured hrefs empty) |
| `git status --porcelain devlog/ technical/ roadmap/ pages/` | empty |
| `git diff --exit-code src/styles/global.css src/layouts/` | clean — zero new CSS, no layout change |
| `git diff --exit-code` on the two generated index routes | clean |
| `npm test` | exits 0, `ALL CHECKS PASSED` |

## Decisions Made

**Nine index pages inherit the site tagline by design.** `technical/index.astro` and the
eight `technical/[milestone]/index.astro` outputs are generated-only indexes with no backing
content entry — there is no body to extract from, and writing per-page prose for them would
be invented copy the developer never approved. They take `BaseLayout`'s `SITE_TAGLINE`
fallback and `website` default. This is why the distinct-description count is 76 rather
than 86: those nine collapse to one, and the homepage shares the same string. Recorded here
explicitly so it does not later read as an oversight.

**No fabricated publication times.** The technical tree carries no dates at all (D-33) and
the `updated` frontmatter on the two standalone pages is a revision date, not a publication
date. Emitting either as `article:published_time` would misstate when the work happened, so
the tag appears on exactly the 9 announcements and nowhere else.

## Deviations from Plan

**1. [Documented, no code change] Task 2's tagline-count criterion expected `src/lib/site.mjs`
to contain the literal twice; it contains it once.**
- **Found during:** Task 2 verification.
- **Issue:** The criterion reads "that file's count is 2 (the standalone tagline and the feed
  description that embeds it)". Plan 03-01 deliberately made `FEED_DESCRIPTION` its own
  literal rather than composing it from `SITE_TAGLINE`, with a WHY-comment recording that
  both are developer-approved copy with *different capitalization* and that deriving one from
  the other would silently rewrite approved wording on the next edit. `FEED_DESCRIPTION` and
  `OG_DEFAULT.alt` therefore carry a lowercase `a space engine…`, which the case-sensitive
  grep does not match.
- **Resolution:** Left `site.mjs` untouched. The criterion's actual guarantee — the literal
  lives in `site.mjs` and in no other file under `src/` — holds and was verified. Rewriting
  `FEED_DESCRIPTION` to embed `SITE_TAGLINE` would have contradicted a recorded 03-01
  decision and would have changed copy that Plan 03-02 (sibling, same wave) consumes.
- **Files modified:** none.

**2. [Out of scope, noted] One `og:title` ends with the site name.**
- **Found during:** Task 2 verification of the "MUST NOT append the site name inside
  og:title" prohibition.
- **Issue:** `dist/technical/index.html` emits
  `og:title = "Technical Deep-Dives — Interstellar Engine"`.
- **Analysis:** This is not a site-layer suffix. `BaseLayout` passes the bare `title` prop
  into `og:title` with no concatenation (its own comment records exactly this). The brand is
  part of the authored page title literal at `src/pages/technical/index.astro:63`, from an
  earlier phase — the same shape as the homepage's authored `"Interstellar Engine — Devblog"`.
  The prohibition targets site-layer doubling, which does not occur.
- **Resolution:** Not fixed. `technical/index.astro` is explicitly listed by this plan as
  deliberately unmodified, and changing an authored page title is outside this plan's scope.
  Logged for phase-level review rather than auto-fixed.
- **Files modified:** none.

No auto-fixes under Rules 1–3 were required; no architectural decisions arose.

## Known Stubs

None. Every route this plan touches computes a real description from a real source.

## Threat Flags

None. This plan introduced no new mechanism — it applied Plan 03-01's single escaping site
(`BaseLayout`'s plain `{expr}` attribute interpolation) to 75 more pages. No route added here
performs its own escaping or markup construction, and `src/lib/escape-html.ts` was correctly
not used for any attribute value. T-03-13 (fabricated timestamps) is mitigated and asserted:
`article:published_time` appears on exactly 9 pages and in neither dateless tree.

## Self-Check: PASSED

- `src/pages/technical/[milestone]/[slug].astro` — FOUND
- `src/pages/technical/how-to-read.astro` — FOUND
- `src/pages/roadmap/[milestone].astro` — FOUND
- `src/pages/roadmap/index.astro` — FOUND
- `src/pages/how-its-made.astro` — FOUND
- `src/pages/index.astro` — FOUND
- `src/pages/404.astro` — FOUND
- commit `6ba9db1` — FOUND
- commit `b88e89d` — FOUND

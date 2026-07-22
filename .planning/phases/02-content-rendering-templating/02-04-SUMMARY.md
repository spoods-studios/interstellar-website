---
phase: 02-content-rendering-templating
plan: 04
subsystem: content
tags: [astro, layout, toc, devlog, markdown]

requires:
  - phase: 02-content-rendering-templating
    provides: "02-02: BaseLayout.astro and the BASE_URL trailing-slash normalization pattern; 02-03: the devlog collection, isVisible/assertNonEmpty/titleFromH1/buildToc helpers, and the Satteri-processed markdown pipeline (wikilinks + Shiki github-light)"
provides:
  - src/layouts/PostLayout.astro -- the single shared reading layout for all four content trees, parameterized by title/meta/headings/breadcrumbs/prevNext/backLink, rendering the untouched Markdown body through one <slot />
  - src/components/TableOfContents.astro -- zero-JS build-time TOC, one markup tree (native <details>/<summary>) that global.css presents as a sticky sidebar at >=640px and an inline disclosure below it
  - src/pages/devlog/[slug].astro -- the first real content route in the phase, one static page per visible devlog entry at /devlog/<id>/, with meta line, TOC, and prev/next/back-link chrome
  - src/lib/devlog-meta.ts -- entryDate/entryTitle/formatDate helpers shared between getStaticPaths' sort and the rendered page
  - tests/post.smoke.sh -- committed harness, auto-discovered by tests/run-all.sh
affects: [02-05 (homepage archive index reuses PostLayout's ordering/date-fallback contract), 02-06/02-07 (technical/roadmap detail pages consume PostLayout directly with their own meta/breadcrumbs/prevNext), 02-08 (final requirement close-out and diagnostic-route cleanup)]

tech-stack:
  added: []
  patterns:
    - "PostLayout.astro is the one shared post-reading shell every content tree passes props into -- title/meta/headings/breadcrumbs/prevNext/backLink are all optional so a tree that doesn't need one (e.g. no breadcrumbs on devlog posts) simply omits it and PostLayout renders nothing for that slot"
    - "Astro only hoists an exported getStaticPaths() to real module scope -- helper functions referenced from inside getStaticPaths must live in an imported module (src/lib/*.ts), not as sibling const/function declarations in the same frontmatter block, or the build fails at prerender time with '<name> is not defined'"
    - "set:html is reserved for strings that actually carry titles/derived prose (prev/next link text); the meta line (milestone + date only) uses plain {expr} interpolation since it never carries user/content-derived HTML-unsafe text"

key-files:
  created:
    - src/layouts/PostLayout.astro
    - src/components/TableOfContents.astro
    - src/pages/devlog/[slug].astro
    - src/lib/devlog-meta.ts
    - tests/post.smoke.sh
  modified: []

key-decisions:
  - "Meta-line placement: renders immediately above the slot (above the body's own H1), not below it -- D-14 forbids splitting the rendered body to slot a meta line beneath the H1, and 14px Label styling directly above a 30px semibold H1 still reads as clearly subordinate."
  - "Prev/next link text is '&larr; {title}' / '{title} &rarr;' (arrow plus the neighbouring post's actual title), matching UI-SPEC's own worked example ('&larr; M0.2: Coordinate System') rather than a literal '&larr; Previous' string."
  - "entryDate/entryTitle/formatDate extracted to src/lib/devlog-meta.ts rather than left as sibling frontmatter functions in [slug].astro -- Astro's compiler only hoists the named getStaticPaths export to true module scope, so a helper only reachable from the render-body scope throws 'entryDate is not defined' the moment getStaticPaths calls it during prerendering. Importing from a real module fixes this and gives the page render body the same functions for free."
  - "PostLayout's meta prop switched from set:html to plain {expr} interpolation once its only real content (milestone tag + date) was confirmed to never carry a derived title string -- avoids an unnecessary raw-HTML injection point."

patterns-established:
  - "Any future dynamic [slug].astro route needing helper functions inside getStaticPaths must import them from src/lib/, never declare them as frontmatter siblings -- documented above as the concrete failure mode this plan hit."

requirements-completed: []

coverage:
  - id: D1
    description: "PostLayout.astro renders BaseLayout + optional breadcrumbs/meta/TOC around exactly one untouched slot, with no site-generated <h1> and no client JS"
    requirement: "CONT-02"
    verification:
      - kind: unit
        ref: "npm run build && node tests/lib.smoke.mjs"
        status: pass
      - kind: other
        ref: "grep -c '<script' / grep -c 'onclick|addEventListener' / grep -c '<h1' acceptance greps on src/layouts/PostLayout.astro"
        status: pass
    human_judgment: false
  - id: D2
    description: "TableOfContents.astro renders one anchor per H2/H3 heading only when the entry has 3+ H2s, otherwise renders nothing, with zero client JS"
    requirement: "CONT-02"
    verification:
      - kind: other
        ref: "grep -c 'details' src/components/TableOfContents.astro; buildToc null-threshold behavior verified via node tests/lib.smoke.mjs"
        status: pass
    human_judgment: false
  - id: D3
    description: "All nine visible devlog entries build to /devlog/<id>/ with correct meta line (milestone+date, or date-only for the manifesto), working prev/next neighbour nav honoring the same date ordering as the future archive index, a back-to-devblog link, an untouched rendered body, and zero client JS"
    requirement: "CONT-02"
    verification:
      - kind: integration
        ref: "bash tests/post.smoke.sh"
        status: pass
      - kind: integration
        ref: "npm test (full run-all.sh harness)"
        status: pass
    human_judgment: false
  - id: D4
    description: "An embedded body image (e.g. m0.7-hero-contrast.png) renders as a real <img> whose src resolves to an asset present under dist/, via Astro's built-in Content Collection image optimization -- no extra wiring needed"
    requirement: "CONT-02"
    verification:
      - kind: integration
        ref: "bash tests/post.smoke.sh (asset-exists assertion on dist/devlog/2026-07-10-warping-without-losing-the-moon/index.html)"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-07-22
status: complete
---

# Phase 2 Plan 4: Shared PostLayout, Table of Contents & Announcement Route Summary

**Shared `PostLayout.astro` + zero-JS build-time `TableOfContents.astro`, wired into a real `/devlog/<id>/` route that renders all nine promoted announcements with correct meta lines, working prev/next navigation, and untouched Markdown bodies.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-22
- **Tasks:** 2
- **Files modified:** 5 (4 new source files + 1 new test harness)

## Accomplishments
- `src/layouts/PostLayout.astro`: the single reading layout every content tree (devlog now, technical/roadmap/pages in Plans 06-07) wraps `BaseLayout` with -- optional breadcrumbs, optional meta line, optional TOC, then exactly one `<slot />` carrying the untouched Markdown body (D-14: no site-generated `<h1>`, no H1 dedup), then optional prev/next + back-link chrome
- `src/components/TableOfContents.astro`: one markup tree (`<details class="toc">`) driven entirely by `buildToc`'s H2/H3 filter and 3+ H2 threshold; renders nothing when the threshold isn't met; zero `<script>`, zero event handlers -- global.css's existing `.toc` rules turn the same markup into a sticky sidebar at >=640px and a native disclosure below it
- `src/pages/devlog/[slug].astro`: `getStaticPaths` over the visible (`isVisible`-filtered) devlog collection, sorted newest-first (the same ordering Plan 05's archive index will use), emitting all nine announcements at `/devlog/<id>/` with a correct meta line (`M0.3 · June 5, 2026`; manifesto renders `April 7, 2026` alone, no fabricated milestone), TOC, prev/next neighbour links (`&larr; {title}` / `{title} &rarr;`, correctly omitted at the two ends of the timeline), and a `Back to devblog` link
- `src/lib/devlog-meta.ts`: `entryDate`/`entryTitle`/`formatDate`, extracted after discovering Astro only hoists the exported `getStaticPaths` function to true module scope -- sibling helper functions declared in the same frontmatter block aren't reachable from inside it during prerendering
- `tests/post.smoke.sh`: new committed harness -- all nine pages built, manifesto fallback (H1 title, no fabricated milestone), M0.3's milestone tag + date, back-link, oldest/newest neighbour-only nav, embedded-image asset resolution, zero client JS, and the repo-wide hardcoded-base guard

## Task Commits

1. **Task 1: Shared PostLayout and the build-time table of contents** - `2d60a88` (feat)
2. **Task 2: Announcement post route with meta line, prev/next and back-to-archive** - `0989f67` (feat) — includes the devlog-meta.ts extraction and PostLayout's set:html→plain-interpolation fix for the meta prop, both discovered while finishing this task

## Files Created/Modified
- `src/layouts/PostLayout.astro` - shared reading layout (title/meta/headings/breadcrumbs/prevNext/backLink props)
- `src/components/TableOfContents.astro` - zero-JS build-time TOC component
- `src/pages/devlog/[slug].astro` - announcement post route, one page per visible devlog entry
- `src/lib/devlog-meta.ts` - entryDate/entryTitle/formatDate helpers
- `tests/post.smoke.sh` - new post-route smoke harness

## Decisions Made
- Meta-line placement resolved per CONTEXT.md's open discretion item: renders immediately above the slot (above the body's own H1), since D-14 forbids splitting the rendered body to place it below the H1, and the 14px/30px size contrast keeps it reading as subordinate either way.
- Prev/next link text uses the neighbouring post's actual title (`&larr; {title}` / `{title} &rarr;`), matching UI-SPEC's own worked example (`"&larr; M0.2: Coordinate System"`) rather than a literal `"&larr; Previous"` string.
- `entryDate`/`entryTitle`/`formatDate` were extracted to `src/lib/devlog-meta.ts` rather than kept as sibling frontmatter functions in `[slug].astro` -- see Deviations below.
- `PostLayout`'s `meta` prop switched from `set:html` to plain `{expr}` interpolation once confirmed it only ever carries a milestone tag + date (never a raw title), removing an unnecessary raw-HTML injection point from Task 1's initial draft.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Extracted date/title helpers to a real module after a prerender-time "is not defined" build failure**
- **Found during:** Task 2, first `npm run build` after writing `src/pages/devlog/[slug].astro`
- **Issue:** `entryDate`, `entryTitle`, and `formatDate` were declared as sibling functions in the same frontmatter block as `getStaticPaths`. Astro's compiler only hoists the exported `getStaticPaths` function itself to true module scope for the prerender pass; sibling frontmatter declarations are only reachable from the per-page render body. The build failed with `entryDate is not defined` inside the compiled prerender chunk the moment `getStaticPaths` tried to sort by it.
- **Fix:** Extracted `entryDate`/`entryTitle`/`formatDate` into `src/lib/devlog-meta.ts` (a real ES module, so its exports are available in both scopes) and imported them into the route file.
- **Files modified:** `src/pages/devlog/[slug].astro` (new), `src/lib/devlog-meta.ts` (new)
- **Verification:** `npm run build` exits 0, all nine pages generate correctly.
- **Committed in:** `0989f67` (Task 2 commit)

**2. [Rule 1 - Bug] Removed an unnecessary set:html on PostLayout's meta prop**
- **Found during:** Task 2, while wiring the meta line through PostLayout
- **Issue:** Task 1's PostLayout rendered the `meta` prop via `set:html`, following the plan's "use set:html for derived title strings" guidance too broadly -- the meta line never actually carries a title (only a milestone tag and a formatted date), so the raw-HTML injection point was unneeded.
- **Fix:** Changed `<p class="meta" set:html={meta} />` to `<p class="meta">{meta}</p>`; the route composes the meta string with a literal `·` Unicode character rather than an HTML entity, so plain interpolation renders it correctly with no encoding artifact.
- **Files modified:** `src/layouts/PostLayout.astro`
- **Verification:** `dist/devlog/*/index.html` meta lines render correctly (`M0.3 · June 5, 2026`; `April 7, 2026` alone for the manifesto); `bash tests/post.smoke.sh` passes.
- **Committed in:** `0989f67` (Task 2 commit, folded in alongside the devlog-meta.ts extraction since both touch the same meta-line feature)

---

**Total deviations:** 2 auto-fixed (1 Rule 3 blocking-build fix, 1 Rule 1 bug fix)
**Impact on plan:** Both were necessary for the route to build and for the meta line to match the Copywriting Contract exactly. No scope creep, no architectural changes, no files touched outside this plan's `files_modified` list (`devlog-meta.ts` is an implementation detail of the meta-line/route logic named in that list's `[slug].astro` entry).

## Issues Encountered
None beyond the two auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `PostLayout`'s final prop list is stable and ready for Plans 06/07 to consume directly: `{ title: string; meta?: string; headings?: MarkdownHeading[]; breadcrumbs?: LinkRef[]; prevNext?: { prev?: LinkRef; next?: LinkRef }; backLink?: LinkRef }` (types exported from `src/layouts/PostLayout.astro` as `LinkRef`, and `MarkdownHeading` from `src/lib/toc`).
- Plan 05's archive index must sort devlog entries with the exact same date-fallback rule this plan uses (`entry.data.date` else the filename-derived date) -- reuse `entryDate`/`entryTitle` from `src/lib/devlog-meta.ts` rather than re-deriving the logic, or the two views risk disagreeing.
- Embedded Markdown images work with zero extra wiring -- Astro's Content Collection image pipeline already optimizes and hashes `../assets/*.png` references into `dist/_astro/*.webp` automatically; neither this plan nor future plans need a separate image-handling step for the two posts (`M0.7`, `M0.8`) that embed one.
- `npm run build`, `npm test` (now including `tests/post.smoke.sh`), and all prior harnesses (`tests/build.smoke.sh`, `tests/shell.smoke.sh`, `tests/lib.smoke.mjs`, `tests/collections.smoke.sh`, `tests/markdown.smoke.sh`) remain green.
- Per this plan's scope, no `REQUIREMENTS.md` IDs were marked complete -- `CONT-02` remains open until Plan 02-08's close-out pass.

---
*Phase: 02-content-rendering-templating*
*Completed: 2026-07-22*

## Self-Check: PASSED

All created files verified present on disk (`src/layouts/PostLayout.astro`, `src/components/TableOfContents.astro`, `src/pages/devlog/[slug].astro`, `src/lib/devlog-meta.ts`, `tests/post.smoke.sh`); both task commit hashes (`2d60a88`, `0989f67`) verified in `git log`.

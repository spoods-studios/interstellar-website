---
phase: 02-content-rendering-templating
plan: 05
subsystem: content
tags: [astro, homepage, archive, devlog]

requires:
  - phase: 02-content-rendering-templating
    provides: "02-03: devlog collection, assertNonEmpty/isVisible/titleFromH1 helpers; 02-04: entryDate/entryTitle/formatDate in devlog-meta.ts, and the post route's ordering contract this archive must match"
provides:
  - src/pages/index.astro -- the site root as the announcement archive (D-13): developer-approved one-liner + flat reverse-chronological list of all 9 visible devlog entries, rendered through BaseLayout
  - Approved D-16 homepage sentence, recorded verbatim below for Plan 02-08 Task 3 to write into 02-UI-SPEC.md's Copywriting Contract row
affects: ["02-08 (writes the approved D-16 sentence into 02-UI-SPEC.md and owns REQUIREMENTS.md close-out for CONT-02/CONT-03)", "Phase 3 RSS (reuses this same devlog-only, isVisible-filtered, date-descending query)"]

tech-stack:
  added: []
  patterns:
    - "Homepage archive reuses src/lib/devlog-meta.ts's entryDate/formatDate for date derivation/formatting rather than re-deriving Phase 1's inline ISO-date logic, so the archive and the post route (src/pages/devlog/[slug].astro) can never disagree on ordering or meta-line format"
    - "Standalone-page exclusion from a generated list is structural (query only the devlog collection), never a filter -- the pages collection literally isn't fetched, so no filter logic exists to audit or get wrong (CONT-03/T-02-03/D-26/D-31)"
    - "Smoke-test string-absence checks for site-chrome-adjacent strings (e.g. 'how-its-made', which also appears in BaseLayout's site-wide nav) must scope the grep to the specific generated region (e.g. the <ul> archive list) rather than the whole page, or the assertion collides with legitimate chrome and is unsatisfiable"

key-files:
  created: []
  modified:
    - src/pages/index.astro
    - tests/build.smoke.sh

key-decisions:
  - "D-16 homepage one-liner approved verbatim by the developer on 2026-07-22: \"A space engine built from scratch on real n-body physics.\" None of the three plan-supplied candidates were used -- the developer supplied this replacement wording directly, built around their requested phrase \"built from scratch\" with the concrete \"real n-body physics\" hook chosen over adjectival claims like \"physics-accurate\". This sentence ships verbatim in src/pages/index.astro; 02-UI-SPEC.md's Copywriting Contract row still carries the old placeholder and is Plan 02-08 Task 3's responsibility to update, not this plan's (02-UI-SPEC.md is not in this plan's files_modified)."
  - "Title is derived inline as entry.data.title ?? titleFromH1(entry.body, entry.id) rather than by importing devlog-meta.ts's entryTitle wrapper, so that assertNonEmpty/isVisible/titleFromH1 are all directly imported into index.astro per the plan's own acceptance criterion, while entryDate/formatDate are still reused from devlog-meta.ts for date derivation and formatting to guarantee identical ordering/meta-line format with the post route."

patterns-established:
  - "Any future generated list that needs to assert a related-but-distinct page's absence via smoke test must scope the grep to the specific generated markup region, not the whole rendered page, when that page's slug/title also appears in shared site chrome (nav, footer)."

requirements-completed: []  # CONT-02/CONT-03 remain open until Plan 02-08's close-out pass, per this plan's explicit scope boundary

coverage:
  - id: D1
    description: "Site root (/) is the announcement archive: flat reverse-chronological list of all 9 visible devlog entries, each a title link to /devlog/<id>/ plus a milestone+date (or date-only) meta line, ordering identical to the post route's prev/next chain"
    requirement: "CONT-02"
    verification:
      - kind: integration
        ref: "bash tests/build.smoke.sh (nine-href-shape count, newest-before-oldest byte-offset check, M0.8/M0.1 milestone spot-checks)"
        status: pass
      - kind: unit
        ref: "node tests/lib.smoke.mjs"
        status: pass
    human_judgment: false
  - id: D2
    description: "The developer-approved D-16 sentence ships verbatim above the list; the 02-UI-SPEC.md placeholder sentence is absent from the built output"
    requirement: "CONT-02"
    verification:
      - kind: integration
        ref: "bash tests/build.smoke.sh (grep -qF exact-match on the approved sentence; negated grep -qF on the placeholder sentence)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Neither standalone page (pages/how-its-made.md, pages/roadmap.md) appears in the archive listing -- structural exclusion via a devlog-only collection query, not a filter"
    requirement: "CONT-03"
    verification:
      - kind: integration
        ref: "bash tests/build.smoke.sh (archive-list-scoped absence check for 'how-its-made' and 'roadmap' within the <ul> region)"
        status: pass
    human_judgment: false
  - id: D4
    description: "D-16 homepage one-liner wording signed off by the developer (blocking decision checkpoint, Task 1)"
    verification: []
    human_judgment: true
    rationale: "Developer sign-off is the deliverable itself, not something automation verifies -- recorded here for traceability; the decision was already made and supplied to this continuation agent verbatim."

duration: 15min
completed: 2026-07-22
status: complete
---

# Phase 2 Plan 5: Announcement Archive Homepage Summary

**Site root rewritten as the D-13 announcement archive -- BaseLayout shell, developer-approved D-16 one-liner, and a flat reverse-chronological list of all 9 visible devlog entries, with the two standalone pages structurally absent via a devlog-only collection query.**

## Performance

- **Duration:** ~15 min (continuation session; Task 1's decision checkpoint was resolved in a prior session with no commits)
- **Completed:** 2026-07-22
- **Tasks:** 2 (Task 1: decision checkpoint, resolved by developer prior to this session; Task 2: executed this session)
- **Files modified:** 2

## Accomplishments
- `src/pages/index.astro` replaced wholesale: Phase 1's throwaway ingestion-proof page is gone, replaced by the real archive rendered through `BaseLayout` with the developer-approved D-16 sentence and a 9-row reverse-chronological list (title link + milestone/date meta line per row)
- Query scoped to `getCollection('devlog')` only -- the entirety of CONT-03's structural exclusion; the `pages` collection (containing `how-its-made.md` and `roadmap.md`) is never fetched, so no filter logic exists that could leak or be bypassed
- Reused `assertNonEmpty`, `isVisible`, `titleFromH1` (imported directly) and `entryDate`/`formatDate` (from `src/lib/devlog-meta.ts`) rather than re-deriving Phase 1's inline ISO-date/title logic, guaranteeing the archive's ordering and meta-line format can never drift from `src/pages/devlog/[slug].astro`'s prev/next chain
- `tests/build.smoke.sh` re-pointed at the archive's href shape (9 links matching the devlog post path) and extended with: exact verbatim-sentence check (approved sentence present, UI-SPEC placeholder absent), newest-before-oldest byte-offset ordering check, and an archive-list-scoped absence check for both standalone pages' slugs

## Task Commits

1. **Task 1: Developer sign-off on the homepage one-liner (D-16)** - resolved by the developer in a prior session (no commit; decision-only checkpoint, no files modified per the plan)
2. **Task 2: Rewrite the site root as the announcement archive** - `f9a0e95` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `src/pages/index.astro` - site root rewritten as the announcement archive (BaseLayout, D-16 sentence, 9-row list)
- `tests/build.smoke.sh` - re-pointed row assertion, added ordering/sentence/standalone-page-absence checks, updated the manifesto date-format assertion to match the new long-form meta line

## Decisions Made
- **D-16 (developer, 2026-07-22):** The approved homepage sentence is **"A space engine built from scratch on real n-body physics."**, used verbatim. This is not one of the plan's three candidate options -- the developer rejected all three and supplied this replacement, built around their requested "built from scratch" phrasing with "real n-body physics" as the concrete hook (in place of the candidates' adjectival "physics-accurate"/simulation framing). Plan 02-08 Task 3 is responsible for writing this exact sentence into `02-UI-SPEC.md`'s Copywriting Contract row; this plan does not touch `02-UI-SPEC.md` (not in its `files_modified`).
- Title derivation uses `entry.data.title ?? titleFromH1(entry.body, entry.id)` inline (mirroring `devlog-meta.ts`'s `entryTitle` logic exactly) rather than importing `entryTitle` itself, so that the plan's acceptance criterion -- direct imports of `assertNonEmpty`, `isVisible`, and `titleFromH1` -- is satisfied literally, while date derivation/formatting still reuses `entryDate`/`formatDate` from `devlog-meta.ts` to guarantee identical ordering and meta-line format with the post route.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Scoped the standalone-page-absence smoke assertion to the archive list, not the whole page**
- **Found during:** Task 2, first `bash tests/build.smoke.sh` run after wiring `BaseLayout` into the homepage
- **Issue:** The plan's literal acceptance criterion (`grep -c 'how-its-made' dist/index.html` outputs `0`) is unsatisfiable as written once the homepage renders through `BaseLayout`, because `BaseLayout`'s own site-wide nav legitimately links to `/how-its-made/` and `/roadmap/` on every page, including the homepage -- confirmed by building and checking `dist/404.html`, which already contains the literal substring `how-its-made` in its nav from an earlier plan. A whole-page grep for either standalone page's slug therefore always returns a count of 1 (one matching line, since production HTML is minified to a single line), regardless of whether the *archive listing itself* leaks the page.
- **Fix:** Scoped the absence check to the `<ul>...</ul>` archive-list markup specifically (`grep -o '<ul>.*</ul>' dist/index.html`, then check that substring for `how-its-made`/`roadmap`), which is the one place a genuine leak of either standalone page into the generated list would actually appear. This preserves the acceptance criterion's real intent (CONT-03's structural exclusion, verified) without colliding with legitimate, unrelated nav chrome.
- **Files modified:** `tests/build.smoke.sh`
- **Verification:** `bash tests/build.smoke.sh` passes; manually confirmed `grep -o 'how-its-made' dist/index.html | wc -l` returns `1` (from nav) while the `<ul>`-scoped check correctly returns `0`.
- **Committed in:** `f9a0e95` (Task 2 commit)

**2. [Rule 1 - Bug] Updated the manifesto date-format assertion to match the new meta-line rendering**
- **Found during:** Task 2, first `npm run build && bash tests/build.smoke.sh` run
- **Issue:** The pre-existing "manifesto ingests and renders" smoke check asserted the raw ISO date string `2026-04-07` (Phase 1's throwaway rendering). This archive now formats dates via `formatDate()` (matching the post route), which renders the manifesto's date as `April 7, 2026` -- the old assertion would fail against the new, correct output.
- **Fix:** Updated the assertion to `grep -q "April 7, 2026" dist/index.html`.
- **Files modified:** `tests/build.smoke.sh`
- **Verification:** `bash tests/build.smoke.sh` passes.
- **Committed in:** `f9a0e95` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1, both confined to `tests/build.smoke.sh` assertions that no longer matched the plan's own required rendering changes)
**Impact on plan:** Both fixes were necessary to make the plan's own acceptance criteria and its `BaseLayout` requirement mutually satisfiable / to match the intentional meta-line format change. No scope creep, no architectural changes, no files touched outside this plan's `files_modified` list.

## Issues Encountered
None beyond the two auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The site root is now the real announcement archive; all 9 visible devlog entries list correctly, newest first, each opening to a working post page.
- `02-UI-SPEC.md`'s Copywriting Contract row for the homepage one-liner still carries the old placeholder text -- Plan 02-08 Task 3 must update it to the approved sentence recorded above before phase close.
- `CONT-02` and `CONT-03` remain open in `REQUIREMENTS.md` -- per this plan's explicit scope, no requirement IDs were marked complete; Plan 02-08's close-out pass owns that.
- `npm run build`, `npm test` (all of `tests/lib.smoke.mjs`, `tests/build.smoke.sh`, `tests/collections.smoke.sh`, `tests/markdown.smoke.sh`, `tests/post.smoke.sh`, `tests/shell.smoke.sh`), remain green.
- Phase 3's RSS feed can reuse this exact devlog-only, `isVisible`-filtered, `entryDate`-descending query pattern directly -- it's the same structural-exclusion argument this plan demonstrates for the archive.

---
*Phase: 02-content-rendering-templating*
*Completed: 2026-07-22*

## Self-Check: PASSED

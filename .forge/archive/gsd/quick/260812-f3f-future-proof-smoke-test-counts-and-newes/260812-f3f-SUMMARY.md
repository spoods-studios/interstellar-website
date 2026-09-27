---
phase: quick-260812-f3f
plan: 01
subsystem: testing
tags: [bash, node, astro, content-collections, smoke-test]

requires: []
provides:
  - "tests/helpers/content-expectations.mjs -- single Node CLI deriving every corpus-sized test expectation (devlog/technical/roadmap/pages counts, composed site page total, distinct og:image count, devlog hero-image count, newest/oldest devlog id via the site's own compareNewestFirst tie-break) from the source content tree at run time"
  - "All seven tests/*.smoke.sh harnesses read corpus-sized expectations from the helper instead of hardcoded literals -- npm test is green against the current 12-post/76-deep-dive/10-roadmap corpus and stays green as content grows"
affects: [tests, devlog, technical, roadmap]

tech-stack:
  added: []
  patterns:
    - "Single derivation CLI (one bare value per key on stdout) consumed by every harness via command substitution, instead of each harness re-deriving or hardcoding its own expected counts"
    - "Minimal hand-rolled frontmatter line scanner (no YAML dependency) reading only the keys each derivation needs, throwing loudly on unexpected shapes rather than guessing"

key-files:
  created:
    - tests/helpers/content-expectations.mjs
  modified:
    - tests/build.smoke.sh
    - tests/collections.smoke.sh
    - tests/post.smoke.sh
    - tests/technical.smoke.sh
    - tests/roadmap.smoke.sh
    - tests/site.smoke.sh
    - tests/distribution.smoke.sh

key-decisions:
  - "og_image_count (distinct og:image basenames, +1 default) and devlog_hero_count (devlog entries carrying a body image) are two separate derived keys, not one -- the RSS feed's hero-URL assertion counts entries embedding an image, which is a different quantity from the distinct-basename count that drives the og:image meta-tag assertion, and they would only coincide by accident of the current corpus never reusing a hero image across posts."
  - "roadmap.smoke.sh's 'M1.2 is next' assertion (written when M1.1 had just shipped and M1.2 hadn't) is replaced with a corpus-size-independent invariant: every promoted roadmap row must show closed (checkmark), none 'in progress' -- since only completed milestones are ever promoted into roadmap/, this holds regardless of how many milestones land, unlike naming a specific 'next' milestone by name."
  - "pages/ singletons (roadmap overview, how-its-made) stay named constants inside site_page_count's composition rather than reading pages_count -- per the plan's explicit direction, since these are route-shaped structural pages, not part of the content-growth surface this task future-proofs against."

requirements-completed: [QT-COUNT-01, QT-NEWEST-01]

coverage:
  - id: D1
    description: "npm test exits 0 against the current 12-post/76-deep-dive/10-roadmap corpus, with no test-layer number edited to a new fixed value -- every corpus-sized assertion reads its expected value from content-expectations.mjs at run time"
    requirement: QT-COUNT-01
    verification:
      - kind: integration
        ref: "npm test (bash tests/run-all.sh) -- full run, exit 0"
        status: pass
      - kind: unit
        ref: "grep -nE '\\-(eq|ne) (4|9|10|65|66|99)\\b' tests/*.smoke.sh -- zero matches; grep -nE '^EXPECTED_PAGES=[0-9]+' tests/site.smoke.sh -- zero matches; grep -l content-expectations tests/*.smoke.sh -- exactly 7 files"
        status: pass
    human_judgment: false
  - id: D2
    description: "Adding a 13th devlog post leaves the suite's corpus-sized assertions green without touching tests/ -- verified with a throwaway devlog/2026-12-31-zz-scratch.md fixture"
    requirement: QT-COUNT-01
    verification:
      - kind: integration
        ref: "npm test with the scratch fixture present: build.smoke.sh's archive-count and ten-announcement checks both passed against 13 entries/116 pages before the pre-existing, unrelated D-10 dirty-tree guard tripped on the fixture's own untracked presence (expected -- that guard checks blanket devlog/ cleanliness, not this task's assertions); node tests/helpers/content-expectations.mjs devlog_count/site_page_count/newest_devlog_id all correctly reported 13/116/2026-12-31-zz-scratch with the fixture present, then reverted to 12/115/2026-08-11-three-small-fixes-... after deletion"
        status: pass
    human_judgment: false
  - id: D3
    description: "The newest-post assertions resolve to the entry the site itself considers newest, tie-break included -- the two same-date (2026-08-11) posts resolve to the milestone-addendum-tagged one, not a date-only pick"
    requirement: QT-NEWEST-01
    verification:
      - kind: unit
        ref: "node tests/helpers/content-expectations.mjs newest_devlog_id -- prints 2026-08-11-three-small-fixes-before-closing-the-books (the addendum), not 2026-08-11-the-line-you-fly"
        status: pass
      - kind: integration
        ref: "tests/build.smoke.sh's newest-first ordering check (byte-offset comparison of derived newest/oldest hrefs) and tests/post.smoke.sh's neighbour-navigation check (derived oldest/newest ids) both pass"
        status: pass
    human_judgment: false

duration: ~35min
completed: 2026-08-12
status: complete
---

# Quick Task 260812-f3f: Future-Proof Smoke-Test Counts and Newest-Post Slug Summary

**Added `tests/helpers/content-expectations.mjs`, a single Node CLI deriving every corpus-sized test expectation from the source content tree, and rewired all seven `tests/*.smoke.sh` harnesses to consume it instead of hardcoded literals -- `npm test` is green again and stays green as devlog/technical/roadmap content grows.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-08-12
- **Tasks:** 3 completed
- **Files modified:** 8 (1 created, 7 modified)

## Accomplishments
- `tests/helpers/content-expectations.mjs` derives ten expectation keys (devlog/technical/roadmap/pages counts, composed site page total, distinct og:image count, devlog hero-image count, newest/oldest devlog id) by reading `devlog/`, `technical/`, `roadmap/`, and `pages/` directly and importing `compareNewestFirst` from `src/lib/entry-order.ts` for the tie-break-honoring newest/oldest sort.
- All seven `tests/*.smoke.sh` harnesses (`build`, `collections`, `post`, `technical`, `roadmap`, `site`, `distribution`) now source their corpus-sized expectations from the helper instead of a hardcoded literal or stale slug.
- Fixed two content-drift bugs discovered while chasing a fully green `npm test`, both resolved within `tests/`: `roadmap.smoke.sh`'s "M1.2 is next" assertion (stale now that M1.2 itself shipped) and `distribution.smoke.sh`'s feed hero-URL count (undercounted at 3 against the corpus's 4 image-bearing posts).
- `npm test` exits 0 end to end against the full 12-post/76-deep-dive/11-milestone/10-roadmap/115-page corpus.
- Future-proofing verified live: a throwaway 13th devlog post made every derived count scale correctly (13/116/new-newest-id) with zero edits to `tests/`, then was deleted, leaving `devlog/` clean.

## Task Commits

Each task was committed atomically:

1. **Task 1: Derivation helper, proven end-to-end through build.smoke.sh** - `186832d` (feat, tracer)
2. **Task 2: Rewire collections.smoke.sh and post.smoke.sh** - `d937469` (feat)
3. **Task 3: Rewire the remaining four harnesses and take the full suite green** - `632f684` (feat)

_Docs commit (SUMMARY.md, STATE.md) handled by the orchestrator, not this executor._

## Files Created/Modified
- `tests/helpers/content-expectations.mjs` - New derivation CLI; ten expectation keys, minimal frontmatter line scanner, fail-loud zero-count guard
- `tests/build.smoke.sh` - Archive-count and newest-first-ordering assertions now derived; ordering check compares hrefs instead of rendered titles
- `tests/collections.smoke.sh` - All four collection-count assertions derived
- `tests/post.smoke.sh` - Announcement count and oldest/newest neighbour-nav page paths derived
- `tests/technical.smoke.sh` - Both deep-dive-count assertions (built pages, index links) derived
- `tests/roadmap.smoke.sh` - Overview milestone-link count derived; "M1.2 is next" replaced with a corpus-size-independent "every promoted row is closed" invariant
- `tests/site.smoke.sh` - `EXPECTED_PAGES` now derived (`site_page_count`) instead of a hardcoded `99`
- `tests/distribution.smoke.sh` - Distinct og:image count derived; feed hero-URL count derived via new `devlog_hero_count` key

## Decisions Made
- **`og_image_count` vs `devlog_hero_count` are separate derived keys.** The site-wide distinct-basename count (og:image meta tags) and the RSS feed's per-entry hero-URL count are different quantities in general (they'd only diverge if two posts reused the same hero image, which the current corpus doesn't do) -- keeping them as two named, independently-testable derivations avoids silently conflating "distinct images" with "images-bearing entries" the moment that assumption breaks.
- **`roadmap.smoke.sh`'s stale "M1.2 is next" assertion replaced with a general invariant**, not a re-pinned name. Only completed milestones are ever promoted into `roadmap/`, so asserting every promoted row shows closed (and none "in progress") holds regardless of which milestone is current -- the same anti-pattern the plan's newest-post-slug fix targets, generalized to a second location the plan's own corpus-size table didn't enumerate.
- **`pages/` singletons stay named constants** in `site_page_count`'s composition (per the plan's explicit direction) rather than reading `pages_count` -- these are route-shaped (`roadmap` overview, `how-its-made`), not part of the devlog/technical/roadmap content-growth surface this task future-proofs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `roadmap.smoke.sh`'s "M1.2 is next" assertion was stale**
- **Found during:** Task 3 (running the full suite to confirm green)
- **Issue:** The check asserted the M1.2 roadmap row's text contained "next," a fact that was true when M1.1 had just shipped and M1.2 hadn't been promoted yet. Since then M1.2 shipped too -- its row now shows closed (checkmark), and no roadmap row currently says "next" at all (M1.3 hasn't been promoted into `roadmap/` yet). This blocked `npm test` from exiting 0, independent of any corpus-size literal.
- **Fix:** Replaced the specific-milestone assertion with a general invariant that holds for any corpus size: every `<strong>M*</strong>` row in the built overview must show closed (✅), and none may say "in progress." Only completed milestones are ever promoted into `roadmap/`, so this is guaranteed by the promote process itself, not by a point-in-time fact about which milestone is current.
- **Files modified:** tests/roadmap.smoke.sh
- **Verification:** `bash tests/roadmap.smoke.sh` passes; the new check would catch a genuinely still-open milestone being promoted early.
- **Committed in:** 632f684 (Task 3 commit)

**2. [Rule 1 - Bug] `distribution.smoke.sh`'s feed hero-URL count was stale**
- **Found during:** Task 3 (running the full suite to confirm green)
- **Issue:** `HERO_URLS -ne 3` hardcoded the number of absolute hero image URLs expected in `dist/rss.xml`. The corpus now has 4 devlog entries embedding a body image (`m0.7-hero-contrast.png`, `m0.8-hero-precession.png`, `m1.1-hero-first-burn.png`, `m1.2-hero-predicted-vs-flown.png`), so this failed even after the `og_image_count`-derived distinct-card-image assertion (the one item this check explicitly named) was fixed.
- **Fix:** Added `devlog_hero_count` to the helper (count of devlog entries carrying a body image, distinct from `og_image_count`'s distinct-basename semantics) and rewired the assertion to read from it.
- **Files modified:** tests/helpers/content-expectations.mjs, tests/distribution.smoke.sh
- **Verification:** `bash tests/distribution.smoke.sh` passes; `node tests/helpers/content-expectations.mjs devlog_hero_count` prints 4.
- **Committed in:** 632f684 (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 -- bugs blocking the plan's own "npm test exits 0" done criterion, both resolved entirely within tests/, neither touching src/ or content)
**Impact on plan:** Both fixes were necessary to reach the plan's stated success criteria; neither was foreseeable from the plan's `<current_state>` table (which enumerated corpus-size literals, not these two content-drift facts). No scope creep -- both stay inside the plan's tests/-only constraint.

## Issues Encountered
None beyond the two auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `npm test` is green from a clean tree; the suite is proven future-proof against devlog/technical/roadmap content growth via the live 13th-post sanity check.
- No outstanding stale-literal or stale-slug items remain in `tests/*.smoke.sh` (confirmed by the Task 3 verify sweep: zero `-eq`/`-ne` matches against the old corpus-size numbers, zero hardcoded `EXPECTED_PAGES`, zero references to the old newest-post slug, all seven harnesses sourcing from the helper).
- Not addressed (out of scope, noted for awareness): `tests/technical.smoke.sh` and `tests/roadmap.smoke.sh`'s hardcoded per-milestone existence loops (`for m in m0.1 ... m1.1`) don't yet cover `m1.2`/`m1.3` -- these are existence checks, not corpus-size assertions, and the plan's task list explicitly scoped only the count-derivation work, not this coverage gap.

---
*Phase: quick-260812-f3f*
*Completed: 2026-08-12*

## Self-Check: PASSED

`tests/helpers/content-expectations.mjs` found on disk; all 3 task commits (`186832d`, `d937469`, `632f684`) found in git log.

---
phase: quick-260812-eot
plan: 01
subsystem: ui
tags: [astro, css, zod, content-collections, sort]

requires: []
provides:
  - "Unconditional img { max-width: 100%; height: auto } rule in global.css so devlog hero images render inside the 65ch reading column instead of overflowing the viewport"
  - "compareNewestFirst addendum tie-break (milestone-addendum tag) shared by the archive, prev/next chain, and rss.xml, so the M1.2 addendum sorts above the announcement it addends"
affects: [devlog, rss, archive]

tech-stack:
  added: []
  patterns:
    - "Single shared comparator (compareNewestFirst) extended with a same-date tie-break rather than adding a second ordering expression per consumer"

key-files:
  created: []
  modified:
    - src/styles/global.css
    - src/content.config.ts
    - src/lib/entry-order.ts
    - src/lib/devlog-meta.ts
    - tests/lib.smoke.mjs

key-decisions:
  - "Tie-break mechanism is the milestone-addendum tag, not discord_post_id: Discord snowflakes (addendum 16:31:48Z, announcement 17:27:04Z) and git commit order both show the announcement posted ~55min AFTER the addendum, so a chronologically-authoritative tie-break would keep the current (unwanted) order. Author intent — the addendum's opening line reads as coming after the milestone write-ups — is the spec; the same-day publish timestamps are a batching artifact."
  - "img sizing rule applied site-wide (unconditional, outside the 640px media query) rather than scoped to a devlog wrapper, since technical/roadmap pages share the same main column and no selector distinguishes them"

requirements-completed: [QT-HERO-01, QT-ORDER-01]

coverage:
  - id: D1
    description: "Hero images render within the 65ch reading column at every viewport width, aspect ratio intact"
    requirement: QT-HERO-01
    verification:
      - kind: unit
        ref: "build artifact grep: img{max-width:100%;height:auto} present in dist/index.html and dist/devlog/2026-07-13-making-mercury-precess/index.html inline <style>; hero width=1920 height=1080 attrs unchanged"
        status: pass
    human_judgment: true
    rationale: "No browser/screenshot tool available in this executor context to visually confirm the rendered layout at desktop and sub-640px widths; automated check proves the CSS rule and intrinsic attributes are both present and mathematically sufficient, but a human should do the npm run preview visual pass described in the plan's <human-check>."
  - id: D2
    description: "M1.2 addendum (Three Small Fixes Before Closing the Books) sorts above the announcement it addends (The Line You Fly) on the archive, in the prev/next chain, and in the feed, from one shared comparator"
    requirement: QT-ORDER-01
    verification:
      - kind: unit
        ref: "tests/lib.smoke.mjs -- entry-order block, 6 new assertions (both input orders, unflagged regression guard, both-flagged fallback, date-overrides-flag guard, real-id pin)"
        status: pass
      - kind: integration
        ref: "dist/index.html byte-offset check: 'Three Small Fixes' at 3242 < 'The Line You Fly' at 3408; dist/rss.xml: 569 < 4909; addendum page prev/next nav links '&larr; The Line You Fly'"
        status: pass
    human_judgment: false

duration: ~15min
completed: 2026-08-12
status: complete
---

# Quick Task 260812-eot: Fix Hero Visual Overflow and Devlog Addendum Ordering Summary

**Capped devlog hero images at the reading-column width via a bare `img` rule, and added a `milestone-addendum` tag tie-break to the shared `compareNewestFirst` comparator so same-date addenda sort above the post they addend.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-08-12T14:46:45Z
- **Tasks:** 2 completed
- **Files modified:** 5

## Accomplishments
- `src/styles/global.css` gained an unconditional `img { max-width: 100%; height: auto }` rule, fixing overflow on all four hero devlog posts (M0.7 1900x1060, M0.8 1920x1080, M1.1 1200x1125, M1.2 1600x1000), verified in the built inline `<style>` block on both the archive and a hero devlog page.
- `src/content.config.ts` now declares `tags` on the devlog schema (previously stripped by Zod's default `z.object` behavior, leaving `entry.data.tags` `undefined` despite the frontmatter carrying it).
- `src/lib/entry-order.ts`'s `compareNewestFirst` gained an `isAddendum` tie-break sitting strictly between the date comparison and the id comparison, so a flag can never outrank a date.
- `src/lib/devlog-meta.ts` gained an `isAddendum(entry)` predicate reading the `milestone-addendum` tag, feeding both operands of the one shared `sortEntriesNewestFirst` call — the archive, `/devlog/<slug>/` prev/next chain, and `rss.xml` all inherited the fix with zero edits to those three files.
- 6 new unit assertions in `tests/lib.smoke.mjs` pin both input orders, the unflagged id-ascending regression guard, the both-flagged fallback, the flag-never-overrides-date guard, and a real-id pin for the actual M1.2 pair.

## Task Commits

Each task was committed atomically:

1. **Task 1: Constrain rendered images to the reading column** - `af7af13` (fix)
2. **Task 2: Sort a same-date addendum above the post it addends**
   - RED: `8a0edc8` (test) — 6 new assertions, confirmed failing before implementation
   - GREEN: `d5cf729` (feat) — schema field, comparator tie-break, predicate; `node tests/lib.smoke.mjs` prints ALL CHECKS PASSED
   - No REFACTOR commit — implementation was already minimal, no cleanup needed

_Docs commit (SUMMARY.md, STATE.md) handled by the orchestrator, not this executor._

## Files Created/Modified
- `src/styles/global.css` - Added `img { max-width: 100%; height: auto }`
- `src/content.config.ts` - Added optional `tags: z.array(z.string())` to the devlog schema
- `src/lib/entry-order.ts` - Added `isAddendum?: boolean` to `OrderableEntry`, tie-break in `compareNewestFirst`
- `src/lib/devlog-meta.ts` - Added `isAddendum(entry)` predicate, wired into `sortEntriesNewestFirst`
- `tests/lib.smoke.mjs` - 6 new assertions in the `== entry-order ==` block

## Decisions Made
- **Tie-break mechanism: `milestone-addendum` tag, not `discord_post_id`.** Discord snowflakes decode to addendum 2026-08-11T16:31:48Z, announcement 2026-08-11T17:27:04Z — the announcement was posted ~55 minutes *later*. Git commit order agrees (addendum `0ee2b6c` at 12:32 local, announcement `4e28464` at 13:26 local). A chronologically-authoritative tie-break would therefore keep the current, unwanted order. The addendum's own opening line ("The maneuver-node milestone shipped last week, and the write-ups are already out") establishes that it is meant to read as coming *after* the milestone write-ups — author intent about reading order is the spec here, and the same-day publish timestamps are a batching artifact, not a signal.
- **CSS rule scope: site-wide, unconditional.** Applied outside the 640px media query (narrow viewports are where overflow is worst) and without a devlog-specific wrapper class, since the technical and roadmap trees share the same `main` column and no existing selector distinguishes them.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Adjusted Task 1's automated verify target for Astro's CSS inlining**
- **Found during:** Task 1 verification
- **Issue:** The plan's automated check expected a separate emitted stylesheet at `dist/_astro/*.css`. Astro 7's default build inlines small stylesheets as a `<style>` block directly in each page's `<head>` rather than emitting a separate CSS asset — no file matches `dist/_astro/*.css` at all.
- **Fix:** Verified the equivalent fact by grepping the inline `<style>` block in `dist/index.html` and `dist/devlog/2026-07-13-making-mercury-precess/index.html` for `img{max-width:100%;height:auto}`, confirming the rule reaches the built output through Astro's actual (inlined) delivery mechanism. No code change — this is a verification-methodology adjustment, not a bug.
- **Files modified:** None (verification only)
- **Verification:** `grep -o 'img{max-width:100%;height:auto}' dist/index.html` and same on the hero devlog page both matched.
- **Committed in:** N/A (verification step, not a code change)

---

**Total deviations:** 1 auto-fixed (1 blocking — verification methodology)
**Impact on plan:** No scope creep; the underlying `<verify>` intent (built output ships the constraint) is satisfied via the actual Astro delivery mechanism.

## Issues Encountered
- No browser/screenshot tool was available in this executor context to perform the plan's `<human-check>` visual pass (`npm run preview`, confirm no horizontal scrollbar at desktop and sub-640px widths). Substituted automated build-artifact inspection: the CSS rule (`max-width: 100%; height: auto`) combined with the hero's unchanged intrinsic `width`/`height` attributes is mathematically sufficient to guarantee the fix, but a human should still do a quick visual pass. Flagged as `human_judgment: true` on coverage item D1.
- Confirmed but out of scope per the plan's explicit instruction: `tests/collections.smoke.sh:34`, `tests/post.smoke.sh:20`, and `tests/build.smoke.sh:27` still hardcode a post count of 10 against a 12-post corpus, and `tests/post.smoke.sh:42` still names `2026-07-30-first-burn` as the newest post. `npm test` was not run for this reason (pre-existing red suite, unrelated to these two bugs); targeted gates (`node tests/lib.smoke.mjs`, `npm run build`, build-artifact greps) were run instead, matching the plan's explicit direction.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Both bugs fixed and verified at the build-artifact level; a human visual pass on `npm run preview` for the hero layout (D1) is the one remaining soft-recommend item, not a blocker.
- The stale hardcoded test counts noted above remain a pre-existing, unrelated cleanup item for a future quick task or phase.

---
*Phase: quick-260812-eot*
*Completed: 2026-08-12*

## Self-Check: PASSED

All 5 modified files found on disk; all 3 task commits (`af7af13`, `8a0edc8`, `d5cf729`) found in git log.

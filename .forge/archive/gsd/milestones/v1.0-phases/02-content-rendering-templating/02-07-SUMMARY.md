---
phase: 02-content-rendering-templating
plan: 07
subsystem: content
tags: [astro, roadmap, satteri, mdast, cross-links, standalone-pages]

requires:
  - phase: 02-content-rendering-templating
    provides: "02-03: roadmap/pages collections, milestone-key/content-guards/title-from-h1 helpers, the Satteri mdastPlugins pipeline (T-02-18 satteri dependency); 02-04: PostLayout/TableOfContents, the getStaticPaths hoisting constraint; 02-06: the technical/ deep-dive route shape this plan's generated links point into, the roadmap breadcrumb URL shape technical pages already assume"
provides:
  - "src/pages/roadmap/[milestone].astro -- 8 roadmap detail pages (one per visible roadmap entry) at /roadmap/m0.X/, rendered through PostLayout with a milestone-only meta line, TOC, breadcrumb to the milestone's announcement, and a back link to the roadmap overview"
  - "src/lib/mdast-deepdive-links.mjs -- createDeepDiveLinkPlugin({ resolvePhase }), a Satteri mdast plugin (heading + text visitors sharing the per-document data bag) resolving every Discord-era deep-dive placeholder in roadmap/ into a real technical/ link, covering both the bold and plain-text placeholder shapes actually present in the corpus"
  - "astro.config.mjs extended -- resolvePhase(milestone, phaseNumber) walks technical/<milestone>/ once per milestone (cached), and the new plugin is registered alongside the existing D-39 wikilink plugin in one mdastPlugins array"
  - "src/pages/roadmap/index.astro -- the /roadmap/ overview: pages/roadmap.md's authored prose rendered untouched, plus a generated list of the 8 milestone detail links appended as chrome below the body"
  - "src/pages/how-its-made.astro -- the /how-its-made/ standalone policy page, rendered through PostLayout with a last-updated meta line and TOC, no breadcrumbs/prevNext"
  - "tests/roadmap.smoke.sh -- committed harness covering all 8 detail pages, the zero-placeholder-survival assertion, per-milestone technical-tree anchor counts, the overview's 8-link/zero-M1.1 assertion, and the How It's Made meta line"
affects: ["02-08 (final requirement close-out for CONT-03/CONT-04, must confirm this plan's coverage before marking them complete)"]

tech-stack:
  added: []
  patterns:
    - "Satteri mdast plugins that need cross-node state (a heading recording a value a later text node consumes) go through the visitor context's per-document `data` bag, reset fresh each compile -- the same mechanism a future plugin needing this shape should reuse rather than module-level mutable state"
    - "A roadmap-phase-number-to-technical-URL resolver is built directly in astro.config.mjs (not a new src/lib file) by walking technical/<milestone>/ once per milestone and caching the result -- mirrors the existing wikilink-resolver.mjs pattern's shape (walk once, resolve by lookup) without adding a second lib file for a small, single-purpose mapping"
    - "Placeholder-text matching in a promoted content tree should never assume the sampled file's format is the corpus's only format -- always grep every file in the tree for the target string before writing an equality/regex match, since promoted vault content used at least 3 slightly different wordings for the same conceptual marker across this one 8-file tree"

key-files:
  created:
    - src/pages/roadmap/[milestone].astro
    - src/lib/mdast-deepdive-links.mjs
    - src/pages/roadmap/index.astro
    - src/pages/how-its-made.astro
    - tests/roadmap.smoke.sh
  modified:
    - astro.config.mjs

key-decisions:
  - "The stateful heading-to-text ordering approach (Task 1's primary path) was used, not the chrome-block fallback -- Satteri's per-document data bag reliably preserves document order for the heading-then-text sequence across all 8 files, confirmed by a build with zero unresolved-placeholder throws once the marker-matching regex covered every wording variant actually present."
  - "The per-phase placeholder is matched by a single MARKER_RE covering two distinct corpus shapes -- the majority bold '**Deep-dive:** posted in #technical-devlog' (text visitor sees only the plain remainder, since the label is a separate strong node) and a plain unbolded 'Deep dive: [Phase N ]post(ed) in #technical-devlog[.]' present on 8 phases across M0.5-M0.8 -- rather than two separate code paths, since both resolve identically once the wording is normalized."
  - "The phase number used to resolve every marker always comes from the heading-tracked ctx.data value, never re-parsed out of a placeholder's own embedded text (e.g. 'Deep dive: Phase 46.1 post in...') -- matches the plan's own stated design ('phase number from the recorded value') and avoids a class of bug where a typo'd embedded number could silently disagree with the section it sits in."
  - "M0.5-M0.8's intro blockquote ('...Deep-dives:\\nposted in #technical-devlog.') is a generic, non-phase-specific mention of the same Discord channel, distinct from the per-phase marker -- it has no phase to link to, so it is stripped (not linked) via a second, narrower regex, keeping the 'zero technical-devlog survival' success criterion true without inventing a link target that doesn't exist."
  - "resolvePhase's phase-to-id map is built directly inside astro.config.mjs and cached per milestone directory, rather than as a new src/lib file -- Task 1's files_modified list names only mdast-deepdive-links.mjs as the new lib file; the resolver logic is small enough (one readdirSync + one regex) to live alongside the existing wikilinkResolver construction it sits next to."

patterns-established:
  - "Any future roadmap-tree transform needing phase-scoped state should register on `heading` to populate `ctx.data` and consume it from `text`/other visitors in the same pass, following this plugin's shape -- the per-document data bag is the sanctioned mechanism, not module-level mutable variables (which would leak across documents in the same compile)."

requirements-completed: []  # CONT-03/CONT-04 remain open until Plan 02-08's close-out pass, per this phase's established per-plan scope boundary (02-04 through 02-06 precedent)

coverage:
  - id: D1
    description: "8 roadmap detail pages render at /roadmap/m0.X/ through PostLayout with milestone-only meta line, phase headings, a TOC, a breadcrumb to the milestone's announcement, and a back link to /roadmap/"
    requirement: "CONT-04"
    verification:
      - kind: integration
        ref: "bash tests/roadmap.smoke.sh"
        status: pass
      - kind: integration
        ref: "npm run build && test $(find dist/roadmap -mindepth 1 -maxdepth 2 -name index.html | wc -l) -ge 8"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every Discord-era deep-dive placeholder across all 8 roadmap docs (both the majority bold wording and the plain-text variants found only in M0.5-M0.8) resolves to a real, generated link into technical/; the non-phase-specific intro-blurb mention is stripped rather than linked; zero occurrences of the placeholder wording survive anywhere in dist/roadmap/"
    requirement: "CONT-04"
    verification:
      - kind: integration
        ref: "bash tests/roadmap.smoke.sh (placeholder-survival and per-milestone anchor-count assertions)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The D-39 wikilink plugin from Plan 03/06 keeps working after the new deep-dive plugin is registered in the same mdastPlugins array -- all 55 technical deep-dive pages still build and the phase-14.5 wikilink still resolves"
    requirement: "CONT-02"
    verification:
      - kind: integration
        ref: "npm test (tests/technical.smoke.sh, full run-all.sh harness)"
        status: pass
    human_judgment: false
  - id: D4
    description: "/roadmap/ renders the authored overview prose untouched plus a generated list of exactly 8 milestone links (never hand-listed) and zero M1.1 link; /how-its-made/ renders with a last-updated meta line; neither standalone page's slug appears in the archive's post list"
    requirement: "CONT-03"
    verification:
      - kind: integration
        ref: "bash tests/roadmap.smoke.sh (overview link-count, era-arc prose, How It's Made meta-line, and archive-leak assertions)"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-07-22
status: complete
---

# Phase 2 Plan 7: Roadmap Detail Pages, Overview & How It's Made Summary

**Eight roadmap detail pages with every Discord-era "Deep-dive:" placeholder — including two wording variants the plan's own sampled file didn't show — resolved into real generated links into technical/, plus the site-voice roadmap overview and the How It's Made standalone policy page.**

## Performance

- **Duration:** ~45 min
- **Completed:** 2026-07-22
- **Tasks:** 2
- **Files modified:** 6 (5 new source files + 1 modified config)

## Accomplishments
- `src/lib/mdast-deepdive-links.mjs`: `createDeepDiveLinkPlugin({ resolvePhase })`, a Satteri mdast plugin registered on `heading` (records the current phase number in the per-document `ctx.data` bag) and `text` (resolves the placeholder once a phase number is recorded). A single marker regex covers both corpus shapes: the majority bold `**Deep-dive:** posted in #technical-devlog` (text visitor sees only the plain remainder) and a plain, unbolded `Deep dive: [Phase N ]post(ed) in #technical-devlog[.]` present on 8 phases scattered across M0.5-M0.8. A second, narrower regex strips (never links) the non-phase-specific intro-blockquote mention of the same Discord channel present on M0.5-M0.8's opening blockquote.
- `astro.config.mjs`: `resolvePhase(milestone, phaseNumber)` added directly in-file (mirroring the existing wikilink-resolver's shape), walking `technical/<milestone>/` once per milestone and caching the phase-number-to-id map; the new plugin registered in the same `mdastPlugins` array as the D-39 wikilink plugin, `github-light` and `sitemap()` untouched.
- `src/pages/roadmap/[milestone].astro`: 8 pages at `/roadmap/m0.X/`, one per visible `roadmap` collection entry (id already the lowercase milestone key), rendered through `PostLayout` with the body H1 as title, a milestone-only meta line (this tree has no dates), the TOC, a breadcrumb to the milestone's announcement (`normalizeMilestone`/`isVisible`-resolved, omitted rather than dead-linked if absent), and a back link to `/roadmap/`.
- `src/pages/roadmap/index.astro`: renders `pages/roadmap.md`'s authored overview untouched through `PostLayout` (title from H1, last-updated meta line from `updated` frontmatter), with a generated `<h2>`+list of the 8 milestone detail links appended below the body as chrome (D-35/D-37 — never hand-listed in the prose), ordered by `milestoneSortKey`. M1.1 correctly produces no link (no roadmap entry exists until Phase 4/D-44).
- `src/pages/how-its-made.astro`: renders the policy page through `PostLayout` with a last-updated meta line and TOC, no breadcrumbs or prev/next.
- `tests/roadmap.smoke.sh`: new committed harness — all 8 detail pages built with milestone name/phase headings/TOC, zero survival of the Discord-era placeholder wording anywhere in `dist/roadmap/`, at least one (M0.3: at least 8) generated anchor into each milestone's own technical tree, a breadcrumb to the M0.1 announcement, zero client JS, both standalone pages building with the expected content, exactly 8 generated milestone links and zero M1.1 link on the overview, and confirmation that neither standalone page's slug leaks into the archive's `<main>` post list (the header nav legitimately links both routes on every page, so the check is scoped to `<main>`, not the whole page).

## Task Commits

1. **Task 1: Roadmap detail pages with resolved deep-dive links** - `7cbe92d` (feat)
2. **Task 2: Roadmap overview and the How It's Made standalone page** - `5133b4f` (feat)

## Files Created/Modified
- `src/pages/roadmap/[milestone].astro` - 8 roadmap detail pages
- `src/lib/mdast-deepdive-links.mjs` - the deep-dive link resolution mdast plugin
- `astro.config.mjs` - `resolvePhase` helper + plugin registration
- `src/pages/roadmap/index.astro` - roadmap overview with generated milestone list
- `src/pages/how-its-made.astro` - How It's Made standalone page
- `tests/roadmap.smoke.sh` - new committed harness for this plan's routes

## Decisions Made
- Used the stateful heading→text ordering approach (Task 1's primary path), not the chrome-block fallback — Satteri's per-document data bag preserved document order reliably across all 8 files once the marker regex covered every wording variant actually present.
- A single `MARKER_RE` handles both the bold-remainder shape and the plain unbolded shape, always resolving via the heading-tracked phase number rather than any digits embedded in a placeholder's own wording (see Deviations).
- The generic intro-blurb mention of `#technical-devlog` (M0.5-M0.8, not tied to any phase) is stripped rather than linked, since there's no link target for it and the objective requires zero survival of the placeholder wording.
- `resolvePhase` lives directly in `astro.config.mjs` rather than a new `src/lib/` file, per Task 1's `files_modified` list naming only `mdast-deepdive-links.mjs` as the new lib file.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Extended the placeholder-marker regex to cover wording variants the plan's read_first sample (M0.3 only) didn't surface**
- **Found during:** Task 1, first full `npm run build` + `tests/roadmap.smoke.sh` pass
- **Issue:** The plan's read_first instruction sampled only `roadmap/M0.3.md`, where every occurrence is the bold `**Deep-dive:** posted in #technical-devlog` line. Grepping all 8 files (done before writing the plugin, but the actual placeholder-survival failure only surfaced after a first build) showed two more wordings scattered across M0.5-M0.8: a plain, unbolded `Deep dive: posted in #technical-devlog.` (M0.8 phase 45) and `Deep dive: Phase N post in #technical-devlog.` (7 occurrences across M0.5-M0.8, phase number embedded directly in the text, "post" instead of "posted"). An initial implementation matching only the exact bold-remainder string left these 8 occurrences unresolved, failing the acceptance criterion that `technical-devlog` survive nowhere in `dist/roadmap/`.
- **Fix:** Replaced the single exact-string check with one regex (`MARKER_RE`) matching both shapes on the trimmed node value, always resolving via the heading-tracked `ctx.data` phase number (never the embedded digits in the plain variant, so a stray transcription mismatch — none was found, but the corpus's Phase 46.1 case confirmed they agree — can never silently produce a wrong link).
- **Files modified:** `src/lib/mdast-deepdive-links.mjs`
- **Verification:** `grep -rn 'technical-devlog' dist/roadmap/` returns nothing; `bash tests/roadmap.smoke.sh` and `npm test` both exit 0.
- **Committed in:** `7cbe92d` (Task 1 commit)

**2. [Rule 1 - Bug] Stripped a second, non-phase-specific placeholder mention discovered in M0.5-M0.8's intro blockquote**
- **Found during:** Task 1, same build/test pass as deviation 1
- **Issue:** M0.5, M0.6, M0.7, and M0.8 each open with a blockquote mentioning `"... Deep-dives:\nposted in #technical-devlog."` as general prose describing where deep-dives live — not a per-phase marker (it appears before any `## Phase` heading, and there is no phase number to attach a link to). It initially caused the plugin's per-phase resolution path to throw (`no phase heading recorded before it`) since this text appears ahead of the first heading; once excluded from the per-phase path, it still needed to not survive verbatim, since the acceptance criteria require zero `technical-devlog` occurrences anywhere in `dist/roadmap/`.
- **Fix:** Added a second, narrower regex (`GENERIC_MENTION_RE`) matching only this exact generic phrasing, stripping it from the text node's value (via `ctx.setProperty`) rather than resolving it into a link, since it has no single phase to point to.
- **Files modified:** `src/lib/mdast-deepdive-links.mjs`
- **Verification:** The intro blockquote's remaining prose ("Granular retroactive roadmap...") renders correctly with the Discord-channel clause removed; `bash tests/roadmap.smoke.sh` passes the zero-survival assertion.
- **Committed in:** `7cbe92d` (Task 1 commit)

**3. [Rule 3 - Blocking] Cleared a stale Astro content-layer cache after an earlier build attempt had thrown mid-compile**
- **Found during:** Task 1, debugging why `roadmap/m0.5` through `m0.8` rendered with an entirely empty `<Content />` slot (no H1, no body, no TOC) despite the build reporting success with no errors
- **Issue:** An interim version of the plugin (before deviation 2's fix) threw on the intro-blockquote text for M0.5-M0.8. That failed compile appears to have left a stale, content-less entry cached in `node_modules/.astro/`'s content-layer data store; once the plugin was fixed to stop throwing, subsequent builds kept reusing the cached empty result instead of recompiling, with no warning printed.
- **Fix:** Removed `node_modules/.astro/` and `dist/` and rebuilt from a clean cache.
- **Files modified:** None (build-cache artifact, not a tracked file).
- **Verification:** All 8 roadmap detail pages re-rendered with full content (`wc -c` on each `dist/roadmap/m0.X/index.html` confirmed non-trivial byte counts); `bash tests/roadmap.smoke.sh` and `npm test` both exit 0.
- **Committed in:** N/A (no file changes — cache-only fix, verified before Task 1's commit)

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bug fixes correcting the placeholder-matching logic against the corpus's actual wording variety, 1 Rule 3 blocking fix clearing a stale build cache)
**Impact on plan:** All three were necessary to meet this plan's own explicit success criteria ("no Discord-era placeholder text left on the page") and acceptance grep (`technical-devlog` must survive nowhere in `dist/roadmap/`). No scope creep, no architectural changes, no files touched outside this plan's `files_modified` list.

## Issues Encountered
- The corpus's Discord-era deep-dive placeholder is not uniform across all 8 roadmap docs, despite the plan's read_first instruction sampling only M0.3 (which happens to use the single, cleanest wording). A full grep of all 8 files before writing the plugin would have caught this earlier; this plan's `GENERIC_MENTION_RE` and multi-shape `MARKER_RE` are now committed as the reference pattern noted in `patterns-established` above for any future roadmap-tree text transform.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All four content trees are now fully reachable end-to-end: `devlog/` (Plan 04/05), `technical/` (Plan 06), `roadmap/` (this plan, overview + 8 detail pages), `pages/` (this plan, both standalone pages).
- `resolvePhase`'s phase-to-id map lives in `astro.config.mjs`, cached per milestone; any future plan needing the same phase-number-to-technical-URL mapping should import/extend it there rather than re-deriving the walk.
- Per this plan's explicit scope, no `REQUIREMENTS.md` IDs were marked complete — `CONT-03` and `CONT-04` remain open until Plan 02-08's close-out pass, which should confirm this plan's coverage rows above.
- `npm run build`, `npm test` (all of `tests/lib.smoke.mjs`, `tests/build.smoke.sh`, `tests/shell.smoke.sh`, `tests/collections.smoke.sh`, `tests/markdown.smoke.sh`, `tests/post.smoke.sh`, `tests/technical.smoke.sh`, `tests/roadmap.smoke.sh`) remain green.

---
*Phase: 02-content-rendering-templating*
*Completed: 2026-07-22*

## Self-Check: PASSED

All created files verified present on disk (`src/pages/roadmap/[milestone].astro`, `src/lib/mdast-deepdive-links.mjs`, `src/pages/roadmap/index.astro`, `src/pages/how-its-made.astro`, `tests/roadmap.smoke.sh`); both task commit hashes (`7cbe92d`, `5133b4f`) verified in `git log`.

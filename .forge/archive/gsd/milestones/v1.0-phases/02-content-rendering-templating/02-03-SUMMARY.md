---
phase: 02-content-rendering-templating
plan: 03
subsystem: content
tags: [astro, content-collections, satteri, mdast, shiki, sitemap, zod]

requires:
  - phase: 02-content-rendering-templating
    provides: "02-01: the four promoted content trees (devlog/technical/roadmap/pages) with real, byte-verified content and counts; 02-02: BaseLayout.astro and the BASE_URL trailing-slash normalization pattern this plan's resolver mirrors"
provides:
  - Three new Astro collections (technical, roadmap, pages) beside devlog, each with a per-tree generateId that throws naming the offending file on a non-conforming filename
  - Five pure helpers (phase-sort, milestone-key, title-from-h1, content-guards, toc) every content template in this phase queries
  - The Satteri wikilink mdast plugin (src/lib/wikilink-resolver.mjs + src/lib/mdast-wikilinks.mjs) resolving Obsidian wikilinks to real internal anchors at build time, loud-failing on an unresolvable target
  - astro.config.mjs extended with satteri({ mdastPlugins }), shikiConfig.theme github-light, and the @astrojs/sitemap integration
  - tests/lib.smoke.mjs (committed JS assertion script), tests/run-all.sh (harness runner wired to npm test), tests/collections.smoke.sh, tests/markdown.smoke.sh
affects: [02-04 through 02-07 (page templates query these collections and helpers directly), 02-08 (owns the actual REQUIREMENTS.md close-out for CONT-02/03/04/SITE-04 once real routes exist)]

tech-stack:
  added:
    - "satteri (^0.9.5) -- declared explicitly; was already installed transitively via @astrojs/markdown-satteri, now pinned so a future npm ci can't silently relocate or version-shift it (T-02-18)"
    - "@astrojs/sitemap (^3.7.3) -- the one genuinely new dependency this phase, official withastro package, audited OK in 02-RESEARCH.md"
  patterns:
    - "Sätteri mdast plugins via defineMdastPlugin -- a plain object of per-node-type visitor functions (text, code, etc.) plus a name; structural edits go through the visitor context's insertBefore/removeNode, not a return-value replacement"
    - "Build-time debug routes (src/pages/collection-counts.json.ts, src/pages/markdown-render-check.astro) as the 'small build-time check' proving a collection/pipeline behavior that no real page template exercises yet -- superseded once Plans 04-07 land the actual index/detail routes"
    - "package.json \"type\": \"module\" so plain .ts helpers under src/lib/ resolve as ESM when imported directly by Node 24's native type-stripping (node tests/lib.smoke.mjs)"

key-files:
  created:
    - src/lib/phase-sort.ts
    - src/lib/milestone-key.ts
    - src/lib/title-from-h1.ts
    - src/lib/content-guards.ts
    - src/lib/toc.ts
    - src/lib/wikilink-resolver.mjs
    - src/lib/mdast-wikilinks.mjs
    - src/pages/collection-counts.json.ts
    - src/pages/markdown-render-check.astro
    - tests/lib.smoke.mjs
    - tests/run-all.sh
    - tests/collections.smoke.sh
    - tests/markdown.smoke.sh
  modified:
    - src/content.config.ts (technical/roadmap/pages collections added)
    - astro.config.mjs (satteri processor, sitemap, shikiConfig)
    - package.json ("type": "module"; satteri and @astrojs/sitemap dependencies; npm test script)
    - package-lock.json
    - tests/build.smoke.sh (fixed a pre-existing count bug, see Deviations)

key-decisions:
  - "package.json \"type\" flipped from \"commonjs\" to \"module\": plain .ts files under src/lib/ need Node's module-type detection to resolve them as ESM when imported directly (node tests/lib.smoke.mjs); .mts would have avoided the package.json change but the plan's files_modified list names plain .ts files, and no other file in the repo relied on commonjs semantics."
  - "milestoneSortKey compares major/minor as separate parsed integers (major*100000 + minor), not parseFloat on the whole string -- parseFloat('0.10') collapses to 0.1, which sorts (wrongly) before parseFloat('0.9')=0.9. Caught by the plan's own M0.10 > M0.9 behavior assertion."
  - "The wikilink resolver's known-ids set is built once at construction by walking technical/ with node:fs and mirroring content.config.ts's own generateId logic (including the _how-to-read.md -> how-to-read special case), rather than depending on Astro's internal collection state -- keeps the resolver constructible and testable independent of the Astro build pipeline."
  - "No route in this phase renders a technical/, roadmap/, or pages/ entry's Markdown body yet (Plans 04-07 own those), so Task 2 and Task 3's collection-count and wikilink/Shiki assertions run against two small build-time-only pages (collection-counts.json.ts, markdown-render-check.astro) instead of real dist/ routes -- exactly the 'small build-time check' the plan's own action text sanctions for this case."

patterns-established:
  - "Per-tree generateId with a loud throw naming the offending file is the shape every future promoted content tree (e.g. Phase 4's M1.1 promote) should repeat -- three now-verified instances (technical/roadmap/pages) beside devlog."
  - "isVisible (src/lib/content-guards.ts) is the single draft-filter implementation every future index page and cross-link generator must import, not reimplement inline (T-02-03)."

requirements-completed: []

coverage:
  - id: D1
    description: "Five pure helpers (parsePhaseNumber/sortByPhaseNumber, normalizeMilestone/milestoneSortKey, titleFromH1, assertNonEmpty/isVisible, buildToc) with a committed node:assert/strict harness proving decimal-aware sort, milestone case/decimal join key, H1 fallback, draft guard, and the 3-H2 TOC threshold"
    verification:
      - kind: unit
        ref: "node tests/lib.smoke.mjs"
        status: pass
    human_judgment: false
  - id: D2
    description: "technical/, roadmap/, and pages/ collections added beside devlog, each resolving to its exact expected count (technical 56, roadmap 8, pages 2) and each throwing naming the offending file on a non-conforming filename"
    verification:
      - kind: integration
        ref: "bash tests/collections.smoke.sh (positive count assertions + D-33 negative fixture)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Satteri wikilink mdast plugin resolves the real corpus's one wikilink to a live internal anchor at build time, throws naming file+link on an unresolvable target, and structurally never sees the [[nodiscard]] C++ attribute (text-node-only visitor)"
    verification:
      - kind: unit
        ref: "node tests/lib.smoke.mjs (resolver + markdownToHtml compile assertions)"
        status: pass
      - kind: integration
        ref: "bash tests/markdown.smoke.sh (dist/markdown-render-check/index.html anchor assertion)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Shiki ships github-light theme with inline styles and zero client JS; sitemap.xml is emitted with base-prefixed URLs; satteri is declared as an explicit dependency (was transitive-only) with npm ls satteri reporting one deduped copy"
    verification:
      - kind: integration
        ref: "bash tests/markdown.smoke.sh; npm ls satteri; npm ci from a clean node_modules/ followed by npm run build"
        status: pass
    human_judgment: false

duration: 30min
completed: 2026-07-22
status: complete
---

# Phase 2 Plan 03: Collections, Helpers & Markdown Pipeline Summary

**Wired technical/roadmap/pages into Astro collections with loud-fail filename rules, extracted five pure helpers from Phase 1's throwaway index page, and landed the Sätteri wikilink plugin + light-theme Shiki + sitemap that every later template in this phase depends on.**

## Performance

- **Duration:** ~30 min
- **Completed:** 2026-07-22
- **Tasks:** 3
- **Files modified:** 9 created + 5 modified across 3 commits (Task 1: 8 files; Task 2: 3 files; Task 3: 8 files)

## Accomplishments
- `src/lib/phase-sort.ts`, `milestone-key.ts`, `title-from-h1.ts`, `content-guards.ts`, `toc.ts`: five pure helpers extracted from the Phase 1 throwaway `index.astro` plus the new decimal-aware phase sort and milestone join key, proven by a committed `node:assert/strict` script
- `src/content.config.ts` extended with `technical` (56 entries, `m0.X/phase-NN[.N]-slug.md` filename rule + `_how-to-read.md` special case), `roadmap` (8 entries, `M{milestone}.md` case-insensitive), and `pages` (2 entries, flat loader) collections -- all four collections now resolve at their exact expected counts, verified against a real `getCollection()` call, not just source-tree file counts
- `src/lib/wikilink-resolver.mjs` + `src/lib/mdast-wikilinks.mjs`: the Sätteri `defineMdastPlugin`-based wikilink resolver, registered as a `text`-node-only visitor so the C++ `[[nodiscard]]` attribute (present in 6+ deep-dives, inside `code`/`inlineCode` mdast nodes) is structurally never offered to it. The real corpus's one wikilink (`technical/m0.3/phase-14.5-swapchain-acquire-fix.md`) resolves to a live internal anchor; an unresolvable target throws naming both the source file and the raw bracketed text
- `astro.config.mjs`: `satteri({ mdastPlugins: [wikilinkPlugin] })`, `shikiConfig.theme: 'github-light'`, `integrations: [sitemap()]` -- all additive, Astro's own heading-id/image/Shiki plugins survive alongside the custom wikilink plugin
- `package.json`: `satteri` declared explicitly (was only a transitive of `@astrojs/markdown-satteri`), `@astrojs/sitemap` installed (the one genuinely new dependency), `npm test` wired to `tests/run-all.sh`
- `tests/lib.smoke.mjs`, `tests/run-all.sh`, `tests/collections.smoke.sh`, `tests/markdown.smoke.sh`: full committed harness set, `npm test` runs all of them plus `tests/build.smoke.sh` and `tests/shell.smoke.sh` and exits 0

## Task Commits

Each task was committed atomically:

1. **Task 1: Pure helpers -- phase sort, milestone key, H1 title, guards, TOC** - `5b5bc7e` (feat)
2. **Task 2: Three new collections with per-tree filename rules and loud failure** - `916747c` (feat)
3. **Task 3: Sätteri wikilink mdast plugin, light-theme Shiki, and sitemap** - `62901e8` (feat)

## Files Created/Modified
- `src/lib/phase-sort.ts` - `parsePhaseNumber`/`sortByPhaseNumber`, decimal-aware (D-34)
- `src/lib/milestone-key.ts` - `normalizeMilestone`/`milestoneSortKey`, the D-35 cross-collection join key
- `src/lib/title-from-h1.ts` - `titleFromH1`, D-01/D-33 fallback
- `src/lib/content-guards.ts` - `assertNonEmpty`/`isVisible`, the RESEARCH Pitfall 1 guard and D-30's single draft-filter implementation
- `src/lib/toc.ts` - `buildToc`, D-42/UI-SPEC H2+H3, 3+ H2 threshold
- `src/lib/wikilink-resolver.mjs` - `createWikilinkResolver`, walks `technical/` once, resolves targets against the known-ids set
- `src/lib/mdast-wikilinks.mjs` - `createWikilinkPlugin`, `text`-node-only Sätteri mdast plugin
- `src/content.config.ts` - `technical`, `roadmap`, `pages` collections added beside `devlog`
- `astro.config.mjs` - `satteri({ mdastPlugins })`, `shikiConfig.theme`, `sitemap()` integration
- `src/pages/collection-counts.json.ts` - build-time regression guard for RESEARCH Pitfall 1 (no real index route queries all four collections yet)
- `src/pages/markdown-render-check.astro` - build-time proof page rendering a real `technical/` entry's body through the full pipeline (wikilink + Shiki), until Plans 06/07 land the real detail route
- `package.json` - `"type": "module"`; `satteri`, `@astrojs/sitemap` dependencies; `npm test` script
- `package-lock.json` - regenerated for the `satteri`/`@astrojs/sitemap` dependency changes
- `tests/lib.smoke.mjs` - committed assertion script (helpers + resolver + plugin compile assertions)
- `tests/run-all.sh` - harness runner, wired to `npm test`
- `tests/collections.smoke.sh` - collection count assertions + D-33 negative fixture
- `tests/markdown.smoke.sh` - sitemap + wikilink/Shiki build-output assertions
- `tests/build.smoke.sh` - fixed a pre-existing count-assertion bug (see Deviations)

## Decisions Made
- `package.json`'s `"type"` field flipped from `"commonjs"` to `"module"` so the plain `.ts` helpers under `src/lib/` resolve as ESM under Node 24's native type-stripping when imported directly by `node tests/lib.smoke.mjs`. No other file in the repo relied on CommonJS semantics; Astro's own `.mjs` files and Vite's build-time TS compilation are unaffected by this field either way.
- `milestoneSortKey` compares major/minor as separate parsed integers (`major * 100000 + minor`) rather than `parseFloat` on the whole normalized string -- `parseFloat('0.10')` collapses to `0.1`, which numerically sorts *before* `parseFloat('0.9') = 0.9`, silently breaking the exact ordering guarantee the helper exists to provide. Caught immediately by the plan's own `milestoneSortKey('M0.10') > milestoneSortKey('M0.9')` behavior assertion during the RED-to-GREEN pass.
- The wikilink resolver's known-ids set is built once at `createWikilinkResolver` construction time by walking `technical/` directly with `node:fs`, mirroring `content.config.ts`'s own `generateId` logic (including the `_how-to-read.md` -> `how-to-read` special case) rather than reading Astro's internal collection state. This keeps the resolver constructible and directly unit-testable (`tests/lib.smoke.mjs`) independent of running a full Astro build.
- Neither Task 2 nor Task 3 has a real page template to assert against yet (Plans 04-07 own the actual index/detail routes), so both tasks add a small, permanent build-time-only route (`src/pages/collection-counts.json.ts`, `src/pages/markdown-render-check.astro`) that exercises the real `astro:content` API end-to-end. This is the "small build-time check" the plan's own action text explicitly sanctions for exactly this situation, and both routes remain useful as ongoing regression guards even after later plans add real templates.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed a pre-existing count-assertion bug in `tests/build.smoke.sh`**
- **Found during:** Task 1, running `npm test` for the first time against the newly-wired `tests/run-all.sh`
- **Issue:** `tests/build.smoke.sh`'s nine-announcement assertion used `grep -o '<li' dist/index.html | wc -l`. `'<li'` (without the closing `>`) also matches inside `<link rel="canonical" ...>`, which is present in every build -- inflating the real count of 9 `<li>` list items to 10 and failing the assertion. This bug was latent in Plan 02-01's own harness (created in that plan, unrelated to anything Plan 02-03 touches) but directly blocked this plan's own `npm test` acceptance criterion once `tests/run-all.sh` started running every `tests/*.smoke.sh` file.
- **Fix:** Narrowed the pattern to `grep -o '<li>' dist/index.html | wc -l`, matching the full opening tag so `<link` no longer collides.
- **Files modified:** `tests/build.smoke.sh`
- **Verification:** `bash tests/build.smoke.sh` and `npm test` both exit 0 with the count correctly reading 9.
- **Committed in:** `5b5bc7e` (Task 1 commit)

**2. [Rule 1 - Bug] Reworded an astro.config.mjs comment that tripped its own "no unified()" guard**
- **Found during:** Task 3, running the acceptance-criteria check `grep -c 'unified' astro.config.mjs`
- **Issue:** A WHY-comment explaining the D-39 amendment ("not remark/unified") contained the literal substring `unified`, which is exactly the string the plan's own guard checks for to prove the classic remark/unified pipeline was never wired in. The comment was failing the check it was itself explaining.
- **Fix:** Reworded the comment to describe the amendment without using the word "unified".
- **Files modified:** `astro.config.mjs`
- **Verification:** `grep -c 'unified' astro.config.mjs` outputs `0`; `npm run build` still exits 0.
- **Committed in:** `62901e8` (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 bug fixes, both caught and corrected before their respective task commits)
**Impact on plan:** Both fixes were necessary to make this plan's own committed harness and acceptance-criteria greps actually pass. No scope creep, no architectural changes.

## TDD Gate Compliance

This plan's frontmatter declares `type: tdd`. Per this repo's established convention (Phase 1 Plan 01, documented in `.planning/STATE.md`: "Task 3 tdd RED/GREEN satisfied via committed `tests/build.smoke.sh` instead of a JS test framework"), each task's RED confirmation (writing/extending `tests/lib.smoke.mjs` first and confirming it fails against the not-yet-written module) was done as a manual verification step within task execution, not as a separate `test(...)` git commit -- all three tasks landed as single `feat(...)` commits containing both the test assertions and the implementation together, matching Plans 02-01 and 02-02's precedent for this repo.

RED was confirmed for each task before writing implementation:
- Task 1: `node tests/lib.smoke.mjs` failed with `ERR_MODULE_NOT_FOUND` against the five not-yet-written helper modules.
- Task 2: `npm run build` was not run against the extended `content.config.ts` until the collections were written (no separate RED artifact recorded, since the collection additions are declarative config, not behavior with a standalone red state -- verified instead via the build succeeding at exactly the expected counts).
- Task 3: `node tests/lib.smoke.mjs` failed with `ERR_MODULE_NOT_FOUND` against `wikilink-resolver.mjs`/`mdast-wikilinks.mjs` before those modules existed; the resolver/plugin implementation was written guided by direct introspection of the installed `satteri`/`@astrojs/markdown-satteri` `.d.ts` files (required per the plan's own instruction to "verify exact export names... before writing this"), then the compile assertions were added to `tests/lib.smoke.mjs` and confirmed passing against the finished implementation.

No `git log` gate-sequence warning is otherwise applicable: this is a documented, repo-wide convention deviation from the generic RED/GREEN/REFACTOR commit-splitting flow, not a gap in verification rigor -- every behavior claim in the plan's `<behavior>` blocks has a corresponding passing assertion in `tests/lib.smoke.mjs`.

## Issues Encountered
- Astro's Content Layer stores synced collection data in `node_modules/.astro/data-store.json` using the `devalue` serialization format -- an internal implementation detail, not a stable public API. Rather than parse it directly (which would also require declaring `devalue` as an explicit dependency, the exact class of risk this plan's own `satteri` fix addresses), `tests/collections.smoke.sh` and `tests/markdown.smoke.sh` instead assert against two small build-time-only pages (`src/pages/collection-counts.json.ts`, `src/pages/markdown-render-check.astro`) that call the official, stable `astro:content` API (`getCollection`, `getEntry`, `render`) directly. Both routes build into `dist/` as real, harmless static output.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All four content trees are now queryable Astro collections with per-tree loud-fail filename rules; `technical` (56), `roadmap` (8), and `pages` (2) join `devlog` (9) at their exact expected counts.
- Five pure helpers (`phase-sort`, `milestone-key`, `title-from-h1`, `content-guards`, `toc`) are ready for every page template Plans 04-07 build -- `isVisible` in particular must be imported (not reimplemented) by every future index page and cross-link generator per D-30/T-02-03.
- The Sätteri wikilink plugin resolves the real corpus's one wikilink today; Plan 07's `src/lib/mdast-deepdive-links.mjs` inherits the `satteri` explicit-dependency fix from this plan and needs no separate `package.json` declaration of its own.
- `astro.config.mjs`'s `markdown.processor` is Sätteri with an additive `mdastPlugins` array -- Plan 07 should append to that array, not replace it, so Astro's own heading-id plugin (which Plan 04's TOC anchors depend on) keeps running.
- Per this plan's explicit instruction, no requirement IDs were marked complete in `.planning/REQUIREMENTS.md` -- `CONT-02`, `CONT-03`, `CONT-04`, and `SITE-04` remain "In Progress" until Plan 02-08 closes them out once the actual rendered routes exist.
- `npm test` (the full harness: `tests/lib.smoke.mjs`, `tests/build.smoke.sh`, `tests/shell.smoke.sh`, `tests/collections.smoke.sh`, `tests/markdown.smoke.sh`) remains green, and `npm ci` from a clean `node_modules/` was verified to still build successfully with the new `satteri`/`@astrojs/sitemap` dependencies.

---
*Phase: 02-content-rendering-templating*
*Completed: 2026-07-22*

## Self-Check: PASSED

All created files verified present on disk (five `src/lib/` helper modules, `wikilink-resolver.mjs`, `mdast-wikilinks.mjs`, `collection-counts.json.ts`, `markdown-render-check.astro`, and all four `tests/*.mjs`/`tests/*.sh` harness files); all three task commit hashes (`5b5bc7e`, `916747c`, `62901e8`) verified in `git log`.

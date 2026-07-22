---
phase: 02-content-rendering-templating
plan: 02
subsystem: ui
tags: [astro, css, layout, favicon, 404]

requires:
  - phase: 01-stack-scaffolding
    provides: Astro build pipeline, tests/build.smoke.sh RED/GREEN harness, config-driven site/base pair
provides:
  - src/styles/global.css implementing the full 02-UI-SPEC.md design system (font stack, palette, type scale, spacing, 65ch reading column, single 640px breakpoint, code-fence and TOC groundwork)
  - src/layouts/BaseLayout.astro as the single <head> owner (canonical URL, favicon, viewport) and shared header/nav/footer chrome
  - public/favicon.svg (hand-authored IE letterform)
  - src/pages/404.astro rendering the exact D-19 copywriting contract through BaseLayout
  - tests/shell.smoke.sh as this plan's committed harness
affects: [02-03 through 02-07 (content templates adopt BaseLayout), Phase 3 (OpenGraph tags and Discord CTA slot into BaseLayout's existing <head>/footer structure)]

tech-stack:
  added: []
  patterns:
    - "Single-owner <head>: only BaseLayout.astro imports global.css and computes the canonical <link>, so every future page inherits one URL/meta source of truth"
    - "BASE_URL normalization: import.meta.env.BASE_URL has no guaranteed trailing slash; layouts must append '/' before concatenating route segments"
    - "All responsive rules for the whole shell (header/main/footer/.toc padding + sticky offsets) live in exactly one @media (min-width: 640px) block, enforced by a literal grep -c '@media' == 1 acceptance check"

key-files:
  created:
    - src/styles/global.css
    - src/layouts/BaseLayout.astro
    - public/favicon.svg
    - src/pages/404.astro
    - tests/shell.smoke.sh
  modified: []

key-decisions:
  - "Fixed a real bug found while building Task 2: import.meta.env.BASE_URL resolves to '/interstellar-website' with no trailing slash (matches astro.config.mjs's base literal), so BaseLayout's nav/favicon hrefs were concatenating directly onto the base (e.g. '/interstellar-websitetechnical/'). Normalized to always append a trailing slash before composing any route segment."
  - "tests/shell.smoke.sh checks dist/404.html's own wordmark and footer text directly rather than diffing against dist/index.html, because index.astro has not adopted BaseLayout yet (it is explicitly commented 'replaced wholesale by Phase 2 templating' and is not in this plan's files_modified) -- there is no second migrated page yet to compare chrome against."

patterns-established:
  - "Hand-written CSS only, zero framework/classless base, single breakpoint consolidated into one @media block -- future content templates (PostLayout, index layouts) extend global.css's existing rules (.toc, pre/code) rather than introducing new breakpoints or per-component stylesheets."

requirements-completed: [SITE-04]

coverage:
  - id: D1
    description: "global.css implements the UI-SPEC design system: system font stack, light-only palette (#fefefe/#1a1a1a/#1d5fae), 18/14/22/30px type scale at weights 400/600 only, 65ch reading column, single 640px breakpoint, code-fence and TOC groundwork rules"
    requirement: "SITE-04"
    verification:
      - kind: other
        ref: "npm run build && grep checks for 65ch/#fefefe/#1a1a1a/#1d5fae/640px/overflow-x literals, 0 prefers-color-scheme, 0 !important, 1 @media occurrence"
        status: pass
    human_judgment: false
  - id: D2
    description: "BaseLayout.astro owns the single <head> (canonical <link>, favicon, viewport), header wordmark + four-item nav, and minimal footer, with zero client JS and no hardcoded host/base string"
    requirement: "SITE-04"
    verification:
      - kind: other
        ref: "grep checks for rel=canonical/Astro.site/import.meta.env.BASE_URL/viewport/nav labels; 0 <script tags; 0 discord|rss matches; negative grep for github.io and literal base string under src/"
        status: pass
    human_judgment: false
  - id: D3
    description: "public/favicon.svg hand-authored and served at the artifact root"
    verification:
      - kind: other
        ref: "npm run build && test -f dist/favicon.svg"
        status: pass
    human_judgment: false
  - id: D4
    description: "src/pages/404.astro renders the exact D-19 copy through BaseLayout and builds to dist/404.html"
    requirement: "SITE-04"
    verification:
      - kind: other
        ref: "bash tests/shell.smoke.sh (asserts dist/404.html heading/back-home copy and shared chrome)"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-07-22
status: complete
---

# Phase 2 Plan 02: Site Shell Summary

**Hand-written global.css + BaseLayout.astro implementing the full 02-UI-SPEC.md visual contract (system fonts, light-only palette, 65ch column, single 640px breakpoint), plus a hand-authored favicon and a D-19-compliant 404 page.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-22
- **Tasks:** 2
- **Files modified:** 5 (2 new source files + favicon + 404 page + test harness)

## Accomplishments
- `src/styles/global.css`: system font stack (zero webfonts), monospace stack, light-only palette (`#fefefe`/`#1a1a1a`/`#1d5fae`), 18/14/22/30px type scale at exactly two weights (400/600), 4px-multiple spacing tokens applied to header/main/footer, 65ch reading column centered via `margin-inline: auto`, a single consolidated `@media (min-width: 640px)` block, code-fence chrome (8px/16px padding, `overflow-x: auto`, no color overrides so Shiki's inline styles win), and `.toc` groundwork (sticky offset 32px desktop, `<details>`-ready mobile styling) for later TOC-consuming plans
- `src/layouts/BaseLayout.astro`: single `<head>` owner (`title`/`description` props, canonical `<link>` from `Astro.site` + `Astro.url.pathname`, viewport meta, favicon reference), wordmark + four-item wrapping nav (Devblog / Technical / How It's Made / Roadmap), minimal footer, zero `<script>` tags, no Phase 3 Discord/RSS placeholders
- `public/favicon.svg`: hand-authored 315-byte "IE" letterform SVG, near-black text on near-white background, system font stack, no raster fallback
- `src/pages/404.astro`: renders through BaseLayout with the D-19 copywriting contract verbatim ("Page not found." / explanatory sentence / "← Back home" link)
- `tests/shell.smoke.sh`: new committed harness asserting `dist/404.html` + `dist/favicon.svg` exist, the 404 copy, and the shared BaseLayout chrome — without touching Plan 01's `tests/build.smoke.sh`

## Task Commits

1. **Task 1: Hand-write global.css and BaseLayout.astro** - `8f5e67c` (feat)
2. **Task 2: Custom 404 page wired to the shell** - `ae06d26` (feat) — includes a same-commit fix to `BaseLayout.astro`'s BASE_URL handling, discovered while verifying Task 2's build output

## Files Created/Modified
- `src/styles/global.css` - the whole hand-written stylesheet implementing 02-UI-SPEC.md
- `src/layouts/BaseLayout.astro` - shared `<head>` + header/nav/footer shell every later template imports
- `public/favicon.svg` - hand-authored favicon
- `src/pages/404.astro` - custom 404 page
- `tests/shell.smoke.sh` - new shell-specific smoke harness

## Decisions Made
- Normalized `import.meta.env.BASE_URL` to always carry a trailing slash before appending route segments in `BaseLayout.astro` and `404.astro` — `astro.config.mjs`'s configured base has no trailing slash, so naive concatenation (`${base}technical/`) produced malformed URLs like `/interstellar-websitetechnical/`.
- `tests/shell.smoke.sh` asserts 404's own chrome (wordmark + footer text) directly rather than diffing against `dist/index.html`, since `index.astro` is an explicitly-marked throwaway (Phase 1 comment: "replaced wholesale by Phase 2 templating") that has not adopted `BaseLayout` yet and is outside this plan's `files_modified` scope.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed malformed nav/favicon URLs from an un-trailing-slashed BASE_URL**
- **Found during:** Task 2 (building `404.astro` and inspecting the rendered `dist/404.html`)
- **Issue:** `import.meta.env.BASE_URL` resolves to `/interstellar-website` (no trailing slash, matching `astro.config.mjs`'s literal `base` value). `BaseLayout.astro`'s nav links and favicon `<link>` concatenated route segments directly onto this value (`${base}technical/`), producing broken paths like `/interstellar-websitetechnical/` and `/interstellar-websitefavicon.svg` in the built HTML.
- **Fix:** Normalized `base` in both `BaseLayout.astro` and `404.astro` to always end with `/` before any segment is appended (`rawBase.endsWith('/') ? rawBase : \`${rawBase}/\``).
- **Files modified:** src/layouts/BaseLayout.astro, src/pages/404.astro
- **Verification:** Rebuilt and inspected `dist/404.html` — all hrefs now correctly separated (`/interstellar-website/technical/`, `/interstellar-website/favicon.svg`, etc.); `bash tests/shell.smoke.sh` and `bash tests/build.smoke.sh` both pass.
- **Committed in:** ae06d26 (Task 2 commit)

**2. [Rule 1 - Bug] Removed a WHY-comment that itself tripped the hardcoded-base guard**
- **Found during:** Task 2, immediately after the BASE_URL fix above
- **Issue:** The explanatory comment describing the BASE_URL bug quoted the literal string `/interstellar-website` verbatim, which the smoke tests' `! grep -rIn -e 'github\.io' -e '/interstellar-website' src/` guard (T-02-07 mitigation) flags as a hardcoded base string under `src/` — the comment itself was failing the exact check it was explaining.
- **Fix:** Reworded the comment to describe the bug without quoting the literal base path.
- **Files modified:** src/layouts/BaseLayout.astro
- **Verification:** `! grep -rIn -e 'github\.io' -e '/interstellar-website' src/` now succeeds; both smoke harnesses pass.
- **Committed in:** ae06d26 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 bug fixes, both caught and corrected before the Task 2 commit)
**Impact on plan:** Both fixes were necessary for the shell to actually render correct URLs and to keep the plan's own SITE-02 hardcoded-base guard green. No scope creep — no architectural changes, no files touched beyond this plan's declared `files_modified` list.

## Issues Encountered
- The plan's Task 2 acceptance criterion describing `dist/404.html` matching `dist/index.html`'s footer copyright line could not be checked literally: `index.astro` (Phase 1's throwaway placeholder) does not yet render any header/footer/chrome at all and is outside this plan's scope. Resolved by asserting 404's own chrome directly in `tests/shell.smoke.sh` — see Decisions Made above. Once a later plan migrates `index.astro` to `BaseLayout`, this harness's checks and any future cross-page chrome assertion will both hold trivially since they share the same layout.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Every later template in this phase (devlog post/index, technical deep-dive/index, roadmap, how-its-made pages) can now `import BaseLayout from '../layouts/BaseLayout.astro'` and inherit the full approved visual contract, a working 404, a favicon, and canonical URLs — with zero client JS.
- `global.css`'s `.toc` rules and single `@media` block are ready for the TOC-consuming `PostLayout` a later plan builds; no CSS changes should be needed there beyond adding markup that targets the existing `.toc` class.
- `index.astro` still needs to adopt `BaseLayout` (tracked as out-of-scope here, per its own "replaced wholesale by Phase 2 templating" comment) — likely the homepage-index plan's job.
- `npm run build` and both `tests/build.smoke.sh` (Plan 01) and `tests/shell.smoke.sh` (this plan) remain green.

---
*Phase: 02-content-rendering-templating*
*Completed: 2026-07-22*

## Self-Check: PASSED

All created files verified present on disk (`src/styles/global.css`, `src/layouts/BaseLayout.astro`, `public/favicon.svg`, `src/pages/404.astro`, `tests/shell.smoke.sh`); both task commit hashes (`8f5e67c`, `ae06d26`) verified in `git log`.

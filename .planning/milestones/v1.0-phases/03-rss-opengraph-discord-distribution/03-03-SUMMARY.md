---
phase: 03-rss-opengraph-discord-distribution
plan: 03
subsystem: ui
tags: [astro, opengraph, discord, hero-image, vite-glob, tdd]

requires:
  - phase: 03-rss-opengraph-discord-distribution
    provides: "Plan 03-01's ogImage prop seam (route -> PostLayout -> BaseLayout) and the default-card fallback branch"
provides:
  - "src/lib/hero-image.ts — pure, import-free heroBasename + lookupHero with the D-48 loud-fail naming post and path"
  - "src/lib/hero-assets.ts — eager import.meta.glob over assets/*.png supplying the basename map, exporting heroFor(entry)"
  - "The M0.7 and M0.8 announcements emit their own engine plot as og:image with matching width/height and title-as-alt"
  - "tests/lib.smoke.mjs '== hero-image ==' section — the lookup and its failure path asserted under bare Node"
affects: [03-05 distribution smoke tests]

tech-stack:
  added: []
  patterns:
    - "Injected-dependency split for Vite-only APIs: the pure half takes its map as a parameter and stays bare-Node importable; the import.meta.glob call lives in a separate supplier module the test harness never imports"
    - "Basename-keyed asset lookup against a fixed eager glob — no filesystem read is performed with a content-authored path, so there is no traversal surface"

key-files:
  created:
    - src/lib/hero-image.ts
    - src/lib/hero-assets.ts
  modified:
    - tests/lib.smoke.mjs
    - src/pages/devlog/[slug].astro

key-decisions:
  - "The image-record shape is a locally declared exported interface (HeroRecord) rather than an imported ImageMetadata type, so hero-image.ts has literally zero import statements and cannot regress into bare-Node unimportability via a type-only import."
  - "hero-assets.ts imports the ImageMetadata type only to parameterize the glob's return; the type import is confined to the module bare Node never loads."
  - "The PNG is used, not the Markdown pipeline's WebP of the same source (D-59) — both coexist in dist/ under different hashes; the build log shows the WebP variants emitted alongside and deliberately unused by the metadata."

requirements-completed: [DIST-02]

coverage:
  - id: D1
    description: "heroBasename returns the final path segment for a ../assets/ reference, an assets/ reference, and a bare basename"
    requirement: DIST-02
    verification:
      - kind: unit
        ref: "tests/lib.smoke.mjs '== hero-image ==' section"
        status: pass
    human_judgment: false
  - id: D2
    description: "lookupHero returns null on an absent reference (no body image -> default card) and the mapped record identically on a hit"
    requirement: DIST-02
    verification:
      - kind: unit
        ref: "tests/lib.smoke.mjs — null case plus src/width/height equality on the hit"
        status: pass
    human_judgment: false
  - id: D3
    description: "D-48: an unresolvable body reference throws naming both the post id and the offending path, and is never downgraded to no-image"
    requirement: DIST-02
    verification:
      - kind: unit
        ref: "tests/lib.smoke.mjs — two assert.throws on /2026-07-10-warping-without-losing-the-moon/ and /does-not-exist\\.png/, plus an empty-map throw"
        status: pass
    human_judgment: false
  - id: D4
    description: "The Vite-only glob is confined to the supplier; the pure module has no import statement and no glob call site"
    requirement: DIST-02
    verification:
      - kind: unit
        ref: "grep -cE '^\\s*import\\b' src/lib/hero-image.ts -> 0; grep -qE '^\\s*(const|let|var|export) .*import\\.meta\\.glob' src/lib/hero-image.ts -> exit 1; same pattern in hero-assets.ts -> exit 0"
        status: pass
    human_judgment: false
  - id: D5
    description: "The two hero announcements emit exactly one og:image each, a PNG carrying their own plot, with dimensions from the same lookup"
    requirement: DIST-02
    verification:
      - kind: integration
        ref: "dist/devlog/2026-07-10-.../index.html -> m0.7-hero-contrast.pk4qHc1U.png, 1900x1060; dist/devlog/2026-07-13-.../index.html -> m0.8-hero-precession.SUqOEvDl.png, 1920x1080; one og:image tag per page; neither contains og-default or .webp"
        status: pass
    human_judgment: false
  - id: D6
    description: "Exactly three distinct og:image URLs site-wide, every one absolute under site+base and resolving to a real file in dist/"
    requirement: DIST-02
    verification:
      - kind: integration
        ref: "grep -rhoP 'property=\"og:image\" content=\"\\K[^\"]+' dist --include='*.html' | sort -u | wc -l -> 3; all three prefixed https://spoods-studios.github.io/interstellar-website/; ls confirms dist/_astro/m0.7-*.png (119184 B), dist/_astro/m0.8-*.png (134885 B), dist/og-default.png (32965 B)"
        status: pass
    human_judgment: false
  - id: D7
    description: "og:image:alt on a hero post equals the page's own <title> text"
    requirement: DIST-02
    verification:
      - kind: integration
        ref: "og:image:alt and <title> on the M0.7 page both read 'Warping Without Losing the Moon'"
        status: pass
    human_judgment: false
  - id: D8
    description: "No regression: 86 pages, full suite green, no promote drop target edited"
    requirement: DIST-02
    verification:
      - kind: integration
        ref: "find dist -name '*.html' | wc -l -> 86; npm test -> ALL CHECKS PASSED; git status --porcelain devlog/ technical/ roadmap/ pages/ -> empty"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-22
status: complete
---

# Phase 3 Plan 03: Hero OpenGraph Images Summary

**The two announcements that carry a genuine engine plot in their body now advertise that plot as their OpenGraph image, resolved from `entry.assetImports` through a basename-keyed eager glob, with an unresolvable reference stopping the build rather than degrading to the default card.**

## Performance

- **Duration:** ~8 min
- **Tasks:** 2/2 (1 TDD, 1 auto)
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments

- **The phase's highest-uncertainty mechanism is wired and asserted.** `assetImports` → basename → eager-glob `ImageMetadata` produced exactly the URLs research predicted: `m0.7-hero-contrast.pk4qHc1U.png` and `m0.8-hero-precession.SUqOEvDl.png`, both base-prefixed and content-hashed, no drift from the probe measurements.
- **Precedence is total.** Exactly three distinct `og:image` values exist across all 86 pages — the default card plus the two heroes. The hero pages emit one `og:image` each and carry neither `og-default` nor `.webp`; every other page keeps the card. The two never coexist because the resolver returns `null` rather than a placeholder and the fallback lives in the layout.
- **Dimensions cannot disagree with the image.** `og:image:width`/`height` come from the same lookup that produced the URL — 1900×1060 and 1920×1080, both comfortably above the 1200×630 large-embed threshold.
- **The split held under bare Node.** `hero-image.ts` has zero import statements (verified `grep -c` → 0) and no glob call site; `hero-assets.ts` owns the single `import.meta.glob` and delegates. The lookup, the null branch and the D-48 throw are all covered by `tests/lib.smoke.mjs` with no test framework introduced.
- **`npm test` green** with `ALL CHECKS PASSED`, including the unchanged 86-page, sitemap, zero-client-JS, dead-link and no-hardcoded-base assertions.

## Task Commits

1. **Task 1: The hero lookup, pure half + Vite-backed supplier** — `54376fb` (test, RED) → `699d619` (feat, GREEN)
2. **Task 2: The two hero announcements embed their own image** — `cdaee32` (feat)

## TDD Gate Compliance

Gate sequence verified in `git log`: `test(03-03)` at `54376fb` precedes `feat(03-03)` at `699d619`. RED was confirmed failing (`ERR_MODULE_NOT_FOUND` on `src/lib/hero-image.ts`) before any implementation was written. No REFACTOR commit — the GREEN implementation needed no cleanup. No test framework was introduced; the assertions run through the existing `tests/lib.smoke.mjs` under `node:assert/strict` with a direct `.ts` import, which is exactly why the lookup takes its map as a parameter.

## Files Created/Modified

**Created**
- `src/lib/hero-image.ts` — `HeroRecord`, `heroBasename`, `lookupHero`; import-free, WHY-comment naming D-48/D-59 and why the glob lives elsewhere
- `src/lib/hero-assets.ts` — the eager `import.meta.glob('../../assets/*.png', { eager: true })`, the basename map, and `heroFor(entry)`

**Modified**
- `tests/lib.smoke.mjs` — new `== hero-image ==` section before the terminal `ALL CHECKS PASSED`
- `src/pages/devlog/[slug].astro` — `heroFor` import, `const hero`/`const ogImage`, and `ogImage={ogImage}` on the existing `<PostLayout …>` invocation; nothing else in the file changed

## Decisions Made

- **`HeroRecord` is declared locally rather than importing `ImageMetadata`.** The plan called for a local interface so nothing at all is imported; recording the reason explicitly because a later "tidy-up" that swaps it for `import type { ImageMetadata } from 'astro'` would silently make the module unimportable under bare Node and remove the D-48 failure path from coverage. The type import belongs only in `hero-assets.ts`.
- Beyond that, the plan's locked decisions (D-48 loud-fail, D-59 PNG-over-WebP, no `hero_visual` parsing, no image-generation dependency) were followed as written.

## Deviations from Plan

None — plan executed exactly as written. No auto-fixes were needed; both tasks passed every acceptance criterion on first verification.

## Issues Encountered

None. The pre-existing `astro` GHSA-4g3v-8h47-v7g6 advisory noted by Plan 03-01 remains open and out of scope here — this plan installed nothing.

## Known Stubs

None.

## Threat Flags

None. The plan's `<threat_model>` covers the one trust boundary this plan touches (a Markdown body image reference selecting an advertised URL). T-03-09 is mitigated structurally: the reference is used only as a `Map` key against a fixed eager glob of the committed asset directory, so no filesystem read is performed with content-authored input and there is no traversal surface. T-03-10 is mitigated by the D-48 throw, now asserted twice under unit test. No new endpoint, auth path or schema change was introduced.

## User Setup Required

None.

## Follow-up for Later Plans

- **03-05** should write the permanent build-output assertions for hero coverage into `tests/distribution.smoke.sh` — the three-distinct-URL count, the PNG-not-WebP check on both hero pages, and the dimension match. The values are recorded under `coverage` above.
- Any future promoted post that references a body image whose file is missing will now **fail the build**, naming the post and the path. That is intended (D-48); it is worth knowing before a promote lands.

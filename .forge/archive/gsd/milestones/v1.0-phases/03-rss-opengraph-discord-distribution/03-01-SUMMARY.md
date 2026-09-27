---
phase: 03-rss-opengraph-discord-distribution
plan: 01
subsystem: ui
tags: [astro, opengraph, discord, metadata, seo, rss-prep, tdd]

requires:
  - phase: 02-content-rendering
    provides: BaseLayout/PostLayout shell, canonicalUrl + normalized base expressions, devlog-meta date/title fallbacks, tests/lib.smoke.mjs harness
provides:
  - "src/lib/site.mjs — locked D-55 Discord invite, site/feed copy constants, OG_DEFAULT descriptor, assertInviteConfigured() build guard"
  - "Config-load-time D-54 loud-fail wired into astro.config.mjs beside validateContentLoudFail()"
  - "public/og-default.png — 1200x630 alpha-free default OpenGraph card, with src/assets/og-default.svg as its editable master"
  - "src/lib/describe-entry.ts — D-51/D-52/D-58 body-derived description extraction, surrogate-safe"
  - "src/lib/entry-order.ts — deterministic newest-first comparator with id tie-break"
  - "sortEntriesNewestFirst adapter in src/lib/devlog-meta.ts, consumed by the announcement route"
  - "Full OG/Twitter/theme-color <head> block on all 86 built pages with absolute config-derived og:url and og:image"
  - "Discord CTA in the header nav (fifth item) and footer on every page"
  - "description/ogType/ogImage/publishedTime prop seam through PostLayout to BaseLayout"
  - "@astrojs/rss@4.0.19 and sanitize-html@2.17.6 installed at exact pins for Plan 03-02"
affects: [03-02 RSS feed, 03-03 hero OG images, 03-04 remaining route metadata, 03-05 distribution smoke tests, 03-06 studio vault sync]

tech-stack:
  added: ["@astrojs/rss@4.0.19", "sanitize-html@2.17.6"]
  patterns:
    - "Config-load-time assertion for constants that must never ship unset (D-54), placed beside validateContentLoudFail() because Astro's glob loader swallows per-entry throws"
    - "Bare-filename asset descriptor (OG_DEFAULT) composed into an absolute URL by the consumer via import.meta.env.BASE_URL + Astro.site — no module under src/ hardcodes the host"
    - "Import-free .ts modules so tests/lib.smoke.mjs can import them directly under bare Node without a test framework"
    - "Pure comparator + thin collection-aware adapter, so archive/route/feed share one ordering expression"
    - "Plain Astro {expr} attribute interpolation for all <meta> content values — never escape-html.ts"

key-files:
  created:
    - src/lib/site.mjs
    - src/lib/describe-entry.ts
    - src/lib/entry-order.ts
    - src/assets/og-default.svg
    - public/og-default.png
  modified:
    - astro.config.mjs
    - package.json
    - package-lock.json
    - src/lib/devlog-meta.ts
    - src/layouts/BaseLayout.astro
    - src/layouts/PostLayout.astro
    - src/pages/devlog/[slug].astro
    - tests/lib.smoke.mjs

key-decisions:
  - "The @astrojs/rss + sanitize-html SUS/too-new legitimacy verdict is a recency-keyed false positive — accepted on live registry evidence (first-party withastro/astro provenance; 566,717 and 9,750,645 weekly downloads; no deprecation; no preinstall/install/postinstall on either). Do not re-litigate in Phase 4."
  - "Both new deps pinned exactly (--save-exact), a deliberate departure from the repo's surrounding caret convention, so a later range resolution cannot pull a different artifact (T-03-SC)."
  - "D-55 invite https://discord.gg/yeyyh6ycfw published into shipped markup — developer-confirmed one-way at the Task 3 gate. Permanent, no expiry, no use limit. Plan 03-06 must write this literal byte-for-byte."
  - "truncate() implements the strict D-52 reading with no minimum-length floor: a complete 53-char sentence beats a 160-char severed one."
  - "twitter:title / twitter:description / twitter:image deliberately not emitted — OpenGraph is always present, so they are redundant tags with no consumer."
  - "og:title carries the bare title prop; <title> has no site-name suffix, so appending SITE_NAME would visibly double the brand beside og:site_name."

patterns-established:
  - "Metadata prop seam: description/ogType/ogImage/publishedTime flow route -> PostLayout (pure pass-through) -> BaseLayout. Plans 03-03 and 03-04 extend behind this seam with no layout surgery."
  - "article:published_time is the single conditional tag — emitted only where a real entry date exists, never fabricated (D-33)."

requirements-completed: [DIST-02, DIST-03]

coverage:
  - id: D1
    description: "Two new npm dependencies installed at exact pins behind a passed human package-legitimacy gate"
    requirement: DIST-02
    verification:
      - kind: unit
        ref: "node -e \"const p=require('./package.json'); if(p.dependencies['@astrojs/rss']!=='4.0.19'||p.dependencies['sanitize-html']!=='2.17.6') process.exit(1)\""
        status: pass
    human_judgment: false
  - id: D2
    description: "assertInviteConfigured() fails the build at config-load time naming DISCORD_INVITE_URL when the invite is empty, whitespace-only, or the placeholder sentinel"
    requirement: DIST-03
    verification:
      - kind: unit
        ref: "node -e \"import('./src/lib/site.mjs').then(m=>m.assertInviteConfigured())\""
        status: pass
      - kind: integration
        ref: "grep -q 'assertInviteConfigured()' astro.config.mjs, call ordered before export default defineConfig"
        status: pass
    human_judgment: false
  - id: D3
    description: "public/og-default.png is a committed 1200x630 alpha-free PNG under 200 KB with its editable SVG master"
    requirement: DIST-02
    verification:
      - kind: unit
        ref: "identify -format '%wx%h %[channels]' public/og-default.png -> 1200x630 srgb (3 channels, no alpha); stat -c %s -> 32965 bytes"
        status: pass
    human_judgment: false
  - id: D4
    description: "The rendered OG card's typography resolves to the site's sans-serif stack, with wordmark, glyph, accent rule and both tagline lines inside the 96px safe inset"
    requirement: DIST-02
    verification:
      - kind: manual_procedural
        ref: "Executor read public/og-default.png back and eyeballed it against the UI-SPEC composition contract"
        status: pass
    human_judgment: true
    rationale: "Font fallback is machine-dependent; UI-SPEC requires the export be eyeballed against the live header before commit, which no build-time assertion can do."
  - id: D5
    description: "describeBody extracts a body-derived description (D-51 chrome-skipping, D-52 strict truncation, surrogate-safe) and throws naming the entry when a body yields no prose"
    requirement: DIST-02
    verification:
      - kind: unit
        ref: "tests/lib.smoke.mjs '== describe-entry ==' section"
        status: pass
    human_judgment: false
  - id: D6
    description: "compareNewestFirst orders newest-first with a deterministic id tie-break independent of input order"
    requirement: DIST-02
    verification:
      - kind: unit
        ref: "tests/lib.smoke.mjs '== entry-order ==' section"
        status: pass
    human_judgment: false
  - id: D7
    description: "The announcement route emits the full OG/Twitter/theme-color block with absolute config-derived og:url and og:image, exactly one of each tag"
    requirement: DIST-02
    verification:
      - kind: integration
        ref: "13 exactly-one grep counts on dist/devlog/2026-07-10-warping-without-losing-the-moon/index.html; og:url and og:image both prefixed by site+base; og:image resolves to an existing dist/ file"
        status: pass
    human_judgment: false
  - id: D8
    description: "Every one of the 86 built pages carries the Discord CTA in header nav and footer, with rel=noopener noreferrer on both, and zero new CSS"
    requirement: DIST-03
    verification:
      - kind: integration
        ref: "grep -rlo 'https://discord.gg/yeyyh6ycfw' dist/ --include='*.html' | wc -l -> 86; 2x invite and 2x rel per page; git diff --exit-code src/styles/global.css"
        status: pass
    human_judgment: false
  - id: D9
    description: "Pasting a deployed devblog post URL into Discord renders a rich embed with title, description and large image"
    requirement: DIST-02
    verification: []
    human_judgment: true
    rationale: "03-UI-SPEC § E4 is explicit that verification is a paste, not a grep — dist/ greps prove the tags exist, not that the embed renders. Requires the deployed site; Discord also will not re-scrape a URL already pasted (03-RESEARCH Pitfall 7)."

duration: 12min
completed: 2026-07-22
status: complete
---

# Phase 3 Plan 01: Distribution Spine Tracer Summary

**One thin production path proven end to end — a devblog post URL now emits a complete OpenGraph card built from absolute config-derived URLs and a body-extracted description, and all 86 built pages route to Discord from both header and footer.**

## Performance

- **Duration:** ~12 min
- **Tasks:** 4/4 (2 checkpoints cleared by the developer, 1 auto, 1 TDD tracer)
- **Files modified:** 13 (5 created, 8 modified)

## Accomplishments

- **The tracer holds.** Config constant → `src/lib/` helper → `BaseLayout` `<head>` and chrome → `PostLayout` → announcement route → built `dist/` HTML → committed assertions, all in one slice. No architectural dead-end surfaced in absolute-URL construction, two-layout prop threading, or the config-load-time loud-fail — the three risks this plan existed to de-risk before Plans 03-02 through 03-06.
- **All 86 pages carry the full metadata block**, the 404 included, with `article:published_time` correctly the only conditional tag (present on the dated announcement, absent on `dist/404.html` and `dist/index.html`).
- **`og:url` and `og:image` are absolute and config-derived** — `https://spoods-studios.github.io/interstellar-website/…`, composed via `new URL(card.src, Astro.site)` from `site` + `base`. No host literal anywhere under `src/`. This was flagged as the phase's single most likely silent failure; it is now asserted.
- **The D-54 guard is live at config-load time**, the one layer Astro's glob loader cannot swallow, and now functions as a permanent regression guard rather than a live blocker.
- **The default OG card is committed and correct** — 1200x630, sRGB 3-channel (no alpha), 32,965 bytes (16% of the 200 KB budget), typography resolved through the system fallback chain to the site's sans-serif rather than a serif or condensed face.
- **`npm test` green** with `ALL CHECKS PASSED`, including the pre-existing 86-page, 85-sitemap, zero-client-JS, dead-link and no-hardcoded-base assertions — none weakened.

## Task Commits

1. **Task 1: Package legitimacy gate** — no commit (blocking-human checkpoint; approved by developer)
2. **Task 2: Dependencies, invite constant + D-54 guard, default OG card** — `6f0bbef` (feat)
3. **Task 3: Confirm publishing the permanent Discord invite** — no commit (decision checkpoint; developer selected `publish`)
4. **Task 4: End-to-end tracer** — `8300487` (test, RED) → `199dce7` (feat, GREEN)

## TDD Gate Compliance

Gate sequence verified in `git log`: `test(03-01)` at `8300487` precedes `feat(03-01)` at `199dce7`. RED was confirmed failing (`ERR_MODULE_NOT_FOUND` on `describe-entry.ts`) before any implementation was written. No REFACTOR commit — the GREEN implementation needed no cleanup. No test framework was introduced; assertions run through the existing `tests/lib.smoke.mjs` (`node:assert/strict`, direct `.ts` import under bare Node), which is why `describe-entry.ts` and `entry-order.ts` are both import-free.

## Files Created/Modified

**Created**
- `src/lib/site.mjs` — locked D-55 invite, placeholder sentinel, site/feed copy constants, `OG_DEFAULT` descriptor, `assertInviteConfigured()`
- `src/lib/describe-entry.ts` — `firstProseBlock` / `stripInline` / `truncate` / `describeBody`, import-free and surrogate-safe
- `src/lib/entry-order.ts` — `compareNewestFirst`, import-free
- `src/assets/og-default.svg` — hand-authored editable master, literal Phase 2 font stack, no generative imagery
- `public/og-default.png` — the published 1200x630 raster

**Modified**
- `astro.config.mjs` — imports `assertInviteConfigured` and calls it bare at top level after `validateContentLoudFail()`
- `src/lib/devlog-meta.ts` — adds `sortEntriesNewestFirst` adapter delegating to `compareNewestFirst`
- `src/layouts/BaseLayout.astro` — four new optional props, resolved `metaDescription`/`resolvedType`/`card`/`ogImageUrl`, full `<head>` block, fifth nav item, footer CTA
- `src/layouts/PostLayout.astro` — four new optional props, pure pass-through to `BaseLayout`
- `src/pages/devlog/[slug].astro` — consumes `sortEntriesNewestFirst`, computes `describeBody(entry.body, entry.id)`, passes `ogType="article"` and `publishedTime`
- `tests/lib.smoke.mjs` — two new assertion sections before the terminal `ALL CHECKS PASSED`
- `package.json` / `package-lock.json` — two exact-pinned dependencies

## Decisions Made

Both plan checkpoints were cleared by the developer:

- **Task 1 (package legitimacy):** approved. Live registry re-verification confirmed all three checks on both packages. The `SUS`/`too-new` seam verdict is accepted as recency-keyed, not reputation-keyed — recorded here so Phase 4 does not re-litigate it.
- **Task 3 (one-way):** `publish`. The D-55 invite goes into shipped markup; it never expires, has no use limit, and lands in `#rules`. Never regenerate or substitute. Plan 03-06 must write the identical literal.

Beyond those, the plan's own locked decisions were followed as written.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's `describeBody` test input could not produce its own stated expected output**

- **Found during:** Task 4 (RED phase)
- **Issue:** The plan's behavior spec asserts `describeBody("# Title\n\nSetare Aerospace is built solo, and I use AI heavily. This page says exactly how.", 'pages/how-its-made')` returns `'Setare Aerospace is built solo, and I use AI heavily.'`. That prose block is 81 characters — under the 160-character limit — so `truncate` returns it unchanged per its own contract ("return `s` unchanged when its length is at most `max`", reinforced by the plan's `truncate('Short sentence.', 160)` and curly-quote criteria). The expected 53-character output was unreachable; the input was an abbreviated paraphrase that never reaches the truncation path.
- **Fix:** Substituted the **real** first prose block of `pages/how-its-made.md` (238 characters after inline stripping) as the test input, keeping the plan's expected output byte-identical. Verified by trace that the strict implementation yields exactly `'Setare Aerospace is built solo, and I use AI heavily.'` — the `. ` at index 52 is the last sentence terminator inside the 161-character window. This preserves the assertion's stated intent (the strict D-52/D-58 reading with no minimum-length floor) and makes it a real corpus case rather than a synthetic one. `truncate`'s implementation was **not** weakened to fit the test.
- **Files modified:** `tests/lib.smoke.mjs`
- **Verification:** `node tests/lib.smoke.mjs` → `describe-entry OK`; the assertion now exercises the truncation branch it was written for.
- **Committed in:** `8300487` (RED commit)

### Notes recorded, not acted on

- **`identify` output format.** The plan's Task 2 criterion expects `identify -format '%wx%h %[channels]\n'` to print exactly `1200x630 srgb`. This machine's ImageMagick 7 prints `1200x630 srgb  3.0` — the same substantive facts (1200x630, three channels, no alpha; an alpha image would report `srgba`) with an extra channel-depth suffix. The assertion holds on substance. **Plan 03-05 should write its committed version of this check as a prefix/`srgba`-absence match rather than exact string equality**, or it will fail spuriously on this machine.
- **Exact version pins** are a deliberate departure from the repo's surrounding caret convention, per `03-RESEARCH.md` § Security — recorded in `key-decisions` above as the plan instructed.

---

**Total deviations:** 1 auto-fixed (1 × Rule 1). **Impact on plan:** Confined to a test fixture; no implementation behavior changed, no scope added, no locked decision touched.

## Issues Encountered

**Pre-existing `astro` advisory surfaced by `npm audit` during install.** GHSA-4g3v-8h47-v7g6 (moderate, reflected XSS via unescaped View Transition animation properties, affects `astro` 2.9.0–7.0.9). Not introduced by either new package and not exploitable here — the site does not use View Transitions and ships zero client JS (asserted by the existing smoke suite). Out of scope for this plan under the executor scope boundary; logged to `deferred-items.md` for resolution when a fixed `astro` release exists.

## Known Stubs

None. `INVITE_PLACEHOLDER` in `src/lib/site.mjs` is a rejection sentinel consumed by `assertInviteConfigured()`, not a placeholder awaiting replacement — the live constant beside it is the real locked D-55 value.

## Threat Flags

None. The plan's `<threat_model>` covers every security-relevant surface this plan introduced: `T-03-SC` (both installs gated and exact-pinned), `T-03-01` (plain `{expr}` interpolation, `escapeHtml` absence asserted in `BaseLayout.astro`), `T-03-03` (`rel="noopener noreferrer"` asserted at exactly 2 per page — the site's first `target="_blank"`). No new endpoint, auth path, file-access pattern or trust-boundary schema change was introduced.

## User Setup Required

None — no external service configuration required. The Discord server and its permanent invite already exist.

## Follow-up for Later Plans

- **03-02** inserts `<a>RSS</a> · ` before the footer's `Join the Discord` link; the separator structure was shaped so that stays a pure insertion. `@astrojs/rss` and `sanitize-html` are already installed.
- **03-03** supplies the two hero posts' `ogImage` prop through the existing seam — no layout change needed.
- **03-04** expands metadata to the remaining nine routes through the same `PostLayout` pass-through.
- **03-05** should write the `identify` assertion as a prefix match (see Deviations → Notes).
- **03-06** must write `https://discord.gg/yeyyh6ycfw` into the studio vault byte-for-byte.

## Self-Check: PASSED

All created files verified present on disk (`src/lib/site.mjs`, `src/lib/describe-entry.ts`, `src/lib/entry-order.ts`, `src/assets/og-default.svg`, `public/og-default.png`). All three task commits verified in `git log`: `6f0bbef`, `8300487`, `199dce7`. `npm test` exits 0 with `ALL CHECKS PASSED` as its final line. `git status --porcelain devlog/ technical/ roadmap/ pages/` is empty — no promote drop target was touched. `git diff --exit-code src/styles/global.css` succeeds — zero new CSS rules.

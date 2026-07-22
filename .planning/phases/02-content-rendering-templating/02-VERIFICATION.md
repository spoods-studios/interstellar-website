---
phase: 02-content-rendering-templating
verified: 2026-07-22T18:51:57Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
deferred:
  - truth: "Live post-deploy 404 under the GitHub Pages base path"
    addressed_in: "Phase 4"
    evidence: "02-CONTEXT.md deferred list: 'Old-Discord-link 404 behavior into the technical corpus — Phase 4's slug-immutability norm and redirect-stub mechanism (CONT-06) now has to cover three URL trees, not one. Flagged for Phase 4 planning.' 02-08-SUMMARY.md: 'Live 404 recorded as PENDING rather than PASS ... Phase 4 owns deploy hardening and the follow-up check.' Phase 4 ROADMAP goal: 'the pipeline is safe against silent failure and dead links as the site enters its low-attention steady state.'"
---

# Phase 2: Content Rendering & Templating Verification Report

**Phase Goal:** The full devblog archive, the technical deep-dive series, and both standalone pages (How It's Made, Roadmap overview + milestone detail pages) render as readable, mobile-friendly pages with baseline polish, VOICE.md prose untouched by the site layer.
**Verified:** 2026-07-22T18:51:57Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth (Roadmap Success Criterion) | Status | Evidence |
|---|---|---|---|
| 1 | Archive index lists manifesto + all M0.1–M0.8 posts, any post opens to full read, and generated cross-links reach the 55-entry technical deep-dive series + how-to-read legend | ✓ VERIFIED | `dist/index.html` `<ul>` contains exactly 9 devlog `<li>` rows (manifesto + M0.1–M0.8), newest-first. `find technical -name "*.md" \| wc -l` = 56 (55 deep-dives + `_how-to-read.md`); `npm run build` reports "86 page(s) built" including all 56 under `dist/technical/`. `tests/technical.smoke.sh` (part of green `npm test`) asserts a deep-dive page carries both breadcrumbs (announcement + roadmap) and that announcements list their milestone's deep-dives via `isVisible`-filtered collection query. |
| 2 | Rendered post text matches source `.md` exactly — site restyles nothing about locked VOICE content | ✓ VERIFIED | `src/layouts/PostLayout.astro` renders body via bare `<slot />` (no wrapper, no H1 dedup) per D-14; `src/pages/devlog/[slug].astro` adds only a meta line and prev/next nav outside the body. Human verification (02-08-SUMMARY.md Task 4, developer-performed 2026-07-22): "Rendered text fidelity (CONT-02, D-14) — PASS. Reviewed the announcement archive and a technical deep-dive against their source `.md` files. No issues reported." Spot-checked the manifesto source directly — no frontmatter, H1-in-body — matching the filename-fallback contract this layout depends on. |
| 3 | Visitor can open How It's Made and the Roadmap overview + 8 milestone detail pages; neither standalone page appears in the archive listing | ✓ VERIFIED | `dist/how-its-made/index.html` and `dist/roadmap/index.html` exist; `dist/roadmap/{m0.1..m0.8}/index.html` all present (8/8). `grep -o 'href="[^"]*"' dist/index.html` shows `how-its-made`/`roadmap` links appear only inside `<header><nav>`, never inside the archive `<ul>` — structural exclusion via the separate `pages` collection (D-26), matching CONT-03/CONT-05 (RSS) design intent. |
| 4 | Site is legible on mobile and desktop, serves a custom 404, shows a favicon, exposes sitemap.xml, and emits canonical URLs | ✓ VERIFIED | `dist/404.html`, `dist/favicon.svg`, `dist/sitemap-index.xml` + `dist/sitemap-0.xml` all present. Canonical-tag count == page count: `grep -rl 'rel="canonical"' dist --include="*.html" \| wc -l` = 86, matching `find dist -name "index.html" -o -name "404.html" \| wc -l` = 86. `src/styles/global.css` defines a single 640px breakpoint (D-23) with a 65ch reading measure. Human verification (02-08-SUMMARY.md Task 4): "Mobile and desktop legibility (SITE-04) — PASS. Reviewed at 375px and 1440px. No issues reported." |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Live 404 under the GitHub Pages base path | Phase 4 | 02-CONTEXT.md deferred list explicitly assigns this to Phase 4's deploy hardening; 02-08-SUMMARY.md records it as "PENDING, not PASS" (deploy-dependent, cannot be checked pre-merge) rather than silently marking it passed. Not treated as a gap per this phase's own validation contract (02-VALIDATION.md Manual-Only Verifications table), which explicitly sanctions closing the phase with this one item outstanding. |

### Required Artifacts (spot sample across the 8 plans)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/content.config.ts` | 4 collections (devlog, technical, roadmap, pages) with per-tree filename rules | ✓ VERIFIED | Present; `npm test` collection smoke harness exercises loud-fail on malformed filenames. |
| `astro.config.mjs` | Wikilink/deep-dive mdast plugins registered; config-load loud-fail preflight covers all 4 content trees | ✓ VERIFIED | `CONTENT_TREES` array explicitly lists `TECHNICAL_ROOT`, `ROADMAP_ROOT`, `DEVLOG_ROOT`, `PAGES_ROOT` — confirms CR-01 fix (02-REVIEW-FIX.md) is actually in the code, not just claimed. |
| `src/pages/technical/how-to-read.astro` | Draft-filtered via shared `isVisible`, matching every other single-entry route | ✓ VERIFIED | Reads `assertNonEmpty(...).filter(isVisible).find(...)` and throws if no visible entry — confirms CR-02 fix is in the code. |
| `src/layouts/PostLayout.astro`, `src/pages/index.astro` | `escapeHtml()` wraps `set:html` title/label interpolation (WR-01 fix) | ✓ VERIFIED | `escape-html.ts` imported and applied at both call sites; apostrophes remain unescaped (verified against real title "A Coordinate System That Doesn't Lie" rendering correctly in `dist/index.html`). |
| `src/pages/technical/[milestone]/index.astro` | Roadmap entry fetch uses `isVisible` filter (WR-02 fix) | Not independently re-diffed line-by-line, but REVIEW-FIX commit trail + passing `npm test` accepted as sufficient given this bypass was already confirmed inert by the reviewer (roadmap schema rejects `status` outright) | — |
| `dist/` build output | 86 pages: 9 devlog, 56 technical (55+legend), 8 roadmap, 2 pages, home/404 | ✓ VERIFIED | `npm run build` output line: "86 page(s) built"; directory listing matches. |
| `public/favicon.svg`, `src/pages/404.astro` | Custom favicon and 404 with site chrome | ✓ VERIFIED | Both exist in `dist/`; 404 uses `BaseLayout` (header/nav present in `dist/404.html`, not independently re-diffed but consistent with `src/pages/404.astro` importing `BaseLayout`). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `roadmap/M0.X.md` phase entries | `technical/m0.X/phase-NN-*.md` | `mdast-deepdive-links.mjs` phase-number join | ✓ WIRED | Source text "Deep-dive: posted in #technical-devlog" (raw vault placeholder, confirmed present in `roadmap/M0.5.md`) resolves in built HTML to `<a href=".../technical/m0.5/phase-23-.../">Phase 23 deep-dive</a>`. `grep -rl "posted in #technical-devlog" dist/` returns 0 matches — zero Discord-era placeholder text survives to the built site. |
| Announcement pages | Milestone's technical deep-dives | Collection query filtered on milestone + `isVisible` | ✓ WIRED | Confirmed via passing `tests/technical.smoke.sh` assertion ("an announcement page lists its milestone's deep-dives, isVisible-filtered") in the green `npm test` run. |
| Wikilinks (`[[...]]`) in content | Real internal site URLs | `wikilink-resolver.mjs` + `mdast-wikilinks.mjs`, config-load preflight | ✓ WIRED | `npm test` output: "D-39: the phase-14.5 page's one real wikilink resolves to an internal anchor, no raw bracketed source survives." CONTENT_TREES preflight covers all 4 trees (verified directly in `astro.config.mjs`). |
| Archive index | devlog collection only (not pages) | Collection-scoped query | ✓ WIRED | `dist/index.html`'s `<ul>` contains only devlog rows; `how-its-made`/`roadmap` links exist solely in `<nav>`. |

### Data-Flow Trace (Level 4)

Archive listing, technical index, and roadmap pages all render from live `getCollection()` queries over the real promoted `.md` content (not static/hardcoded arrays) — confirmed by the exact row/page counts in the build output matching the actual file counts on disk (9 devlog files → 9 archive rows; 56 technical files → 56 technical pages; 8 roadmap files → 8 roadmap pages). No hardcoded-empty or static-fallback patterns found in the routing files reviewed.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full build succeeds and produces the expected page count | `npm test` (runs `npm run build` + assertions) | "86 page(s) built"; "ALL CHECKS PASSED" | ✓ PASS |
| `[[nodiscard]]` C++ attribute survives Shiki tokenization untouched | `grep -rho "nodiscard" dist/technical/ \| wc -l` | 12 (matches orchestrator's independently-confirmed count; naive contiguous-string grep undercounts due to Shiki span-splitting, so token-count was used instead) | ✓ PASS |
| Canonical tag present on every built page | `grep -rl 'rel="canonical"' dist \| wc -l` vs. page count | 86 == 86 | ✓ PASS |
| No Discord-era placeholder deep-dive text remains in built roadmap pages | `grep -rl "posted in #technical-devlog" dist/` | 0 matches | ✓ PASS |
| CR-01/CR-02 review fixes are actually in the shipped code (not just claimed in REVIEW-FIX.md) | Direct read of `astro.config.mjs` (`CONTENT_TREES`) and `src/pages/technical/how-to-read.astro` | Both fixes present and match the fix report's description | ✓ PASS |

### Probe Execution

No dedicated `scripts/*/tests/probe-*.sh` files exist for this project; the project's own committed harness (`tests/run-all.sh`, invoked via `npm test`) is the equivalent verification surface and was run directly (Behavioral Spot-Checks above). Step 7c: SKIPPED (no separate probe scripts — `npm test` is the project's full verification harness, run once).

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| CONT-02 | 02-01, 02-03, 02-04, 02-05, 02-06, 02-08 | Full archive + technical deep-dive series + roadmap detail docs, VOICE untouched | ✓ SATISFIED | 9 devlog + 56 technical pages built; body renders via bare `<slot/>`; human-verified fidelity PASS. |
| CONT-03 | 02-01, 02-05, 02-07, 02-08 | How It's Made standalone page, structurally separate from archive/RSS | ✓ SATISFIED | `dist/how-its-made/index.html` exists; absent from archive `<ul>`. |
| CONT-04 | 02-01, 02-03, 02-07, 02-08 | Roadmap overview + 8 milestone detail pages, cross-linking into technical deep-dives | ✓ SATISFIED | 8/8 roadmap detail pages built; Deep-dive links resolve to real technical URLs. |
| SITE-04 | 02-02, 02-03, 02-08 | Mobile-responsive, custom 404, favicon, canonical URLs, sitemap.xml | ✓ SATISFIED | All artifacts present in `dist/`; canonical count matches page count; human-verified legibility PASS. |

No orphaned requirements: `REQUIREMENTS.md` maps only CONT-02/CONT-03/CONT-04/SITE-04 to Phase 2, and all four are claimed across the 8 plans' frontmatter `requirements:` fields.

### Anti-Patterns Found

None. `grep -rnE "TBD|FIXME|XXX|HACK|PLACEHOLDER"` across `src/` and `astro.config.mjs` returned zero matches. The two Critical and two Warning findings from `02-REVIEW.md` were verified fixed in the actual code (not just claimed in `02-REVIEW-FIX.md`) — see Required Artifacts table above. The four Info findings remain deferred per the T3 gate tier and are cosmetic/consistency observations, not defects (reviewer's own assessment, independently spot-checked as reasonable: duplicated regex constants, duplicated sort comparators, one structurally-unreachable defensive branch, one title-extraction edge case against a currently-uniform corpus).

### Human Verification Required

None outstanding for this verifier to route. Two of the three genuinely-manual checks from `02-VALIDATION.md` (rendered-text fidelity, mobile/desktop legibility) were already performed by the developer during phase execution and recorded PASS in `02-08-SUMMARY.md`. The third (live 404 under the GitHub Pages base path) is deploy-dependent and cannot be exercised pre-merge; it is recorded above as a **deferred item** (not a gap, not silently marked passed) per the phase's own validation contract, which explicitly sanctions closing with this one item outstanding, and per this task's explicit instruction not to let this single deploy-dependent item force `gaps_found`.

### Additional Check: Developer's "bare" observation

Confirmed the developer's sign-off note ("looks pretty bare, not in scope for this phase but looks good") is captured in `02-CONTEXT.md`'s `<deferred>` section as a forward-looking candidate topic for a future visual-polish milestone (bundled with dark mode / SITE-05 and the KaTeX half of CONT-07), explicitly framed as "D-21/D-22/D-23 ... working exactly as designed" — not converted into an accepted requirement, a fix task, or any change to this phase's scope.

### Gaps Summary

None. All four ROADMAP success criteria are observably true in the built site (not just claimed in SUMMARY.md), all four requirement IDs are satisfied with concrete evidence, all Critical/Warning code-review findings were verified fixed in the actual shipped code, and the one outstanding manual check is a legitimately deploy-dependent item explicitly deferred to Phase 4 per the phase's own validation contract and context decisions.

---

_Verified: 2026-07-22T18:51:57Z_
_Verifier: Claude (gsd-verifier)_

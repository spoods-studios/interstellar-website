---
phase: 03-rss-opengraph-discord-distribution
plan: 05
subsystem: test-harness
tags: [smoke-tests, rss, opengraph, discord, fixtures, d-45, d-48, d-54, d-57]
status: complete
requires:
  - "src/pages/rss.xml.ts (feed endpoint) — Plan 03-02"
  - "src/layouts/BaseLayout.astro (OpenGraph block, CTA, autodiscovery) — Plan 03-01/03-03"
  - "src/lib/site.mjs (DISCORD_INVITE_URL, INVITE_PLACEHOLDER, OG_DEFAULT) — Plan 03-01"
  - "src/lib/hero-assets.ts / hero-image.ts (D-48 loud-fail) — Plan 03-03"
  - "src/pages/index.astro on the shared newest-first comparator — Plan 03-04"
provides:
  - "tests/distribution.smoke.sh — permanent build-output gate for DIST-01, DIST-02 and DIST-03"
  - "Feed/archive count-and-order drift lock (the only build tree where both artifacts coexist)"
  - "Three trap-and-restore fixtures: D-48 hero path, D-54 invite constant, D-30 draft"
affects:
  - "Plan 03-06's human verification legs (W3C feed validation, Discord embed render) — deliberately NOT proxied here"
tech-stack:
  added: []
  patterns:
    - "Occurrence counting via grep -o | wc -l, never a line count (Astro minifies each page to one line)"
    - "URL prefix and invite derived from astro.config.mjs / src/lib/site.mjs, never typed as literals"
    - "Trap installed before any mutation; git status --porcelain asserted after every fixture"
    - "Every URL assertion resolves its value; presence-only greps are treated as vacuous"
key-files:
  created:
    - tests/distribution.smoke.sh
  modified: []
decisions:
  - "absolutize()'s a/href branch stays fixture-free; a live negative assertion gates it instead"
  - "The D-48 fixture runs two legs because Astro's own ImageNotFound guard fires upstream of heroFor()"
  - "identify (ImageMagick) and xmllint are local-harness system tools, not npm or deploy dependencies"
metrics:
  duration: ~35 min
  tasks: 3
  files_changed: 1
  lines_added: 448
  completed: 2026-07-22
---

# Phase 3 Plan 05: Distribution Smoke Harness Summary

One committed 448-line bash script, auto-discovered by the existing runner, that proves the
phase's feed, metadata, CTA and three loud-failure paths against real build output — offline,
with no test framework, no network call and no harness edit.

## What Was Built

`tests/distribution.smoke.sh`, executable, picked up by `tests/run-all.sh`'s pre-existing
`tests/*.smoke.sh` glob with `git diff --exit-code tests/run-all.sh` clean.

**Task 1 — metadata and CTA coverage** (commit `4fb8cfe`)
- Per-page loop over all 86 built pages asserting exactly one occurrence of each of the twelve
  unconditional tags (description, `og:type`/`site_name`/`title`/`description`/`url`/`image`/
  `image:width`/`image:height`/`image:alt`, `twitter:card`, `theme-color`).
- `og:url` and `og:image` prefix-checked against a `PREFIX` composed from `astro.config.mjs`'s
  own `site` and `BASE` via `grep -oP`. No host or base literal appears in the file.
- `og:image` **resolved back to a real file** under `dist/` — the assertion a presence-only grep
  would have passed while every embed silently blanked.
- Declared dimensions asserted at or above 1200×630 on every page.
- Exactly 3 distinct card images site-wide; the default card measured at exactly `1200x630` via
  `identify -format '%wx%h'`, with a loud failure if `identify` is absent.
- 77 distinct description values (gate: > 60).
- Per-page CTA loop: exactly 2 invite links, 2 external-link `rel` pairs, 1 feed autodiscovery
  link. Footer byte-offset check proving RSS precedes Discord.
- Two consecutive builds emit an identical sorted `og:image`/`og:url` set.

**Task 2 — feed structure** (commit `90c8100`)
- `xmllint --noout dist/rss.xml`, explicitly commented as only the offline half of D-57's split
  criterion.
- Item count (9) equals the homepage archive link count, using `tests/build.smoke.sh`'s own
  expression.
- **Order diff**: archive slugs in document order vs feed guid slugs in document order, required
  identical. Plus a negative grep proving no inline `entryDate(b).getTime()` comparator was
  reintroduced in `index.astro`, `[slug].astro` or `rss.xml.ts`.
- Channel shape: one `<channel>`, title/link/description/language present, `rel="self"` present,
  `xmlns:content` declared exactly once.
- Item shape: every `<link>` and `<guid>` prefix-correct; 9 guids, 9 distinct; 9 RFC-822 `<pubDate>`
  values with zero non-matching.
- Content fidelity: exactly 2 absolute `_astro/*.webp` hero URLs; zero root-relative `src`; zero
  non-absolute anchor `href`; zero `__ASTRO_IMAGE_`; zero `[[`.
- `package.json` asserted free of a second Markdown parser.

**Task 3 — loud-fail fixtures and tail** (commit `3f6b3dc`)
- **D-48**, two legs (see Deviations): a body image with no file behind it, and one Astro can
  import but `heroFor()` rejects.
- **D-54**, three variants: empty, whitespace-only and the `INVITE_PLACEHOLDER` sentinel, each
  required to fail the build with `DISCORD_INVITE_URL` in the log.
- **D-30/D-45**: the frontmatter-less manifesto drafted; the build must succeed and both the feed
  item count and the archive link count must drop by exactly one, via a leak accumulator.
- Tail: `trap - EXIT`, final clean rebuild, `git status --porcelain` over `devlog/ technical/
  roadmap/ pages/ src/`, then `ALL CHECKS PASSED`.

## Mutation Checks (proof the script is not vacuous)

| # | Injected regression | Observed exit | Message |
|---|---------------------|---------------|---------|
| 1 | `BaseLayout.astro` og:title changed to `` `${title} — Interstellar Engine` `` | **1** | `FAIL: an og:title value ends with the site-name suffix` |
| 2 | `public/og-default.png` moved away | **1** | `FAIL: dist/404.html og:image … does not resolve to a file` |
| 3 | `rss.xml.ts` content prefixed with `__ASTRO_IMAGE_0__` | **1** | `FAIL: the feed carries unresolved Astro image placeholders` |
| 4 | `assertInviteConfigured()` commented out in `astro.config.mjs` | **1** | `D-54 FIXTURE FAIL: build succeeded with the invite constant set to ''` |

All four sources were restored; `git status --porcelain` is clean.

Note on mutation methodology: the plan proposed mutating files inside `dist/`, but the script
opens with `rm -rf dist && npm run build`, so a `dist/` mutation is erased before any assertion
runs. Each check therefore mutates the **source** that produces the regression, which is the
stronger form — it proves the assertion survives a real build.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] `BAD_DATES` assignment tripped `set -e` on a clean result**
- **Found during:** Task 2
- **Issue:** `BAD_DATES=$(… | grep -cvP …)` exits 1 when the count is zero, and under
  `set -euo pipefail` a failing command substitution in an assignment aborts the script. A
  perfectly clean feed made the script exit non-zero with no message.
- **Fix:** appended `|| true` with a WHY-comment, and added a separate assertion that the
  `<pubDate>` count equals the item count so the `|| true` cannot mask a feed with no dates at all.
- **Commit:** `90c8100`

**2. [Rule 1 — Bug] Task 1 acceptance criterion `grep -c 'grep -c '` returned 1**
- **Found during:** Task 1
- **Issue:** a WHY-comment explaining *why not* to use the line-counting form contained the literal
  string it warned against, tripping the plan's own negative criterion.
- **Fix:** reworded to "grep's count flag counts matching LINES". Criterion now returns 0.
- **Commit:** `4fb8cfe`

### Plan-Text Corrections (verified against real output)

**3. D-48 fixture needed two legs, not one.** The plan (and the validation map) expect a single
unresolvable-hero fixture whose build log names both the post id and the referenced path.
Measured behaviour: pointing the body image at a nonexistent file makes **Astro's own**
`[ImageNotFound]` guard fire in `vite-plugin-content-assets` during the Markdown asset import —
upstream of `heroFor()` — and its message names the path but **not** the post. Rather than weaken
the requirement, the fixture runs two legs: leg 1 asserts the nonexistent-file path fails loudly
naming the path; leg 2 points the body at `../src/assets/og-default.svg` (an asset Astro *can*
import but which is not in the `assets/*.png` hero glob), which reaches `lookupHero()`'s own throw
and names both `2026-07-10-warping-without-losing-the-moon` and the reference. Both legs are
required to fail.

**4. `content:encoded` is XML-escaped, not CDATA** (carry-forward from Wave 2, re-verified). The
feed emits `src=&quot;https://…&quot;`, so the plan's `! grep -q "src=\"${BASE}"` would have passed
vacuously forever. The script asserts **both** the escaped and raw forms for root-relative `src`
and non-absolute `href`, and the hero-URL count pattern is written against `[^&"]` rather than
`[^"]`.

**5. `identify` output shape** (carry-forward). Used `identify -format '%wx%h'`, which yields a
bare `1200x630` and sidesteps the ImageMagick-7 trailing-field difference entirely. `identify`
absent from `PATH` fails the script naming the tool; it is never skipped.

## Known Coverage Gap (decided, not silent)

`absolutize()`'s `a`/`href` branch remains unexercised by real content — all 9 devlog bodies
contain zero anchors, and 03-02 logged this honestly as coverage D7 `partial`.

**Decision: no fixture.** Exercising it would require mutating a locked content drop-target to
insert a link that does not exist in the source of truth, and the branch is the same
`toAbsolute()` factory instantiated with a different attribute name — the `src` instantiation is
exercised by both hero images, so the logic itself is covered. Instead the script carries a **live
negative gate**: any `href=&quot;<base>…` or `href=&quot;..` in the feed fails. It passes
vacuously today and becomes a real assertion the moment a promoted post adds its first link,
which is precisely when the branch starts to matter.

## Threat Mitigations Applied

| Threat | Mitigation |
|--------|------------|
| T-03-14 (fixtures leave a tree dirty) | Trap installed before every mutation; explicit restore on both branches; 4 `git status --porcelain` assertions; final clean rebuild + final clean-tree assertion. Verified: `git status --porcelain devlog/ technical/ roadmap/ pages/ src/` is empty after a full run, and after all four mutation checks. |
| T-03-15 (silent embed blanking) | `og:image` resolved to a real file, not merely present; mutation check 2 confirms exit 1. |
| T-03-16 (network dependence) | `! grep -qE 'curl\|wget\|validator\.w3\.org'` holds; no assertion reaches the network; no build-time proxy for either human leg. |
| T-03-17 (vacuous harness) | Four mutation checks, all exit 1, recorded above. |

## Verification

- `bash tests/distribution.smoke.sh` → exit 0, last line `ALL CHECKS PASSED`.
- `npm test` → exit 0, ends `ALL CHECKS PASSED`; `== running tests/distribution.smoke.sh ==` present.
- `git diff --exit-code tests/run-all.sh tests/site.smoke.sh tests/build.smoke.sh` → clean.
- `git status --porcelain devlog/ technical/ roadmap/ pages/ src/` → empty.
- No test framework installed; no npm dependency added; no npm script added.

## Still Human-Only (Plan 03-06)

The W3C feed validation leg (D-57) and the Discord embed render remain unautomated **by decision**.
The script says so in a WHY-comment at the `xmllint` call so a future reader does not mistake
well-formedness for validity, or try to bolt a network validator into the harness.

## Self-Check: PASSED

- `tests/distribution.smoke.sh` — FOUND (448 lines, executable)
- `4fb8cfe` — FOUND
- `90c8100` — FOUND
- `3f6b3dc` — FOUND

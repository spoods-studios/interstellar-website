---
phase: 3
slug: rss-opengraph-discord-distribution
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-22
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `03-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | **none by decision** — `bash` smoke scripts + `node:assert/strict` (D-03/D-09, Phase 1 RESEARCH). Do not introduce one. |
| **Config file** | `tests/run-all.sh` (runner); `package.json` `test → bash tests/run-all.sh` |
| **Quick run command** | `npm run build` — the D-46/D-48/D-54 loud-fails ARE the fast gate |
| **Full suite command** | `npm test` |
| **Estimated runtime** | ~15–30 seconds (build-dominated) |
| **Baseline** | GREEN — `npm test` ended `ALL CHECKS PASSED` at research time |

`tests/run-all.sh` runs `node tests/lib.smoke.mjs` first, then every `tests/*.smoke.sh` in
sorted order. A new `tests/distribution.smoke.sh` is picked up automatically — no harness
edit, no parallel-plan collision risk.

**Existing idioms to reuse, not reinvent:**
- `grep -o … | wc -l` for occurrence counts — `grep -c` counts *lines*, and Astro minifies
  `dist/*.html` to one line (`tests/build.smoke.sh:24-28`).
- Derive `$PREFIX` from `astro.config.mjs` with `grep -oP`; never hardcode
  (`tests/site.smoke.sh:22-27`).
- Trap-and-restore fixtures for loud-fail proofs — back up the file, mutate, assert the build
  fails naming the offender, restore, assert the content trees are clean
  (`tests/site.smoke.sh`, existing D-39/D-30 fixtures).

---

## Sampling Rate

- **After every task commit:** `npm run build`
- **After every plan wave:** `npm test`
- **Before `/gsd-verify-work`:** `npm test` green **and** both human items below complete
- **Max feedback latency:** ~30 seconds

---

## Per-Requirement Verification Map

Task IDs are assigned at planning; this map is the requirement-level contract the planner
must decompose into tasks. Every ❌ row is a Wave 0 gap.

| Req | Behavior | Test Type | Automated Command | File Exists | Status |
|-----|----------|-----------|-------------------|-------------|--------|
| DIST-01 | `/rss.xml` builds and is well-formed XML | smoke | `xmllint --noout dist/rss.xml` | ❌ W0 | ⬜ pending |
| DIST-01 | Feed item count == homepage archive link count (cannot drift) | smoke | `<item>` count vs `devlog/` href count in `dist/index.html` | ❌ W0 | ⬜ pending |
| DIST-01 | A drafted post leaves the feed **and** the archive together | smoke fixture | trap-and-restore `status: draft`, rebuild, both counts drop by 1 | ❌ W0 | ⬜ pending |
| DIST-01 | Every feed `<link>`/`<guid>` carries the config-derived prefix | smoke | grep vs `$PREFIX` from `astro.config.mjs` | ❌ W0 | ⬜ pending |
| DIST-01 | `<pubDate>` is RFC-822 | smoke | pattern check over extracted `<pubDate>` values | ❌ W0 | ⬜ pending |
| DIST-01 | Feed content carries the two hero images, absolutized | smoke | 2 absolute `_astro/*.webp` URLs; zero root-relative `src="/interstellar-website` | ❌ W0 | ⬜ pending |
| DIST-01 | No second-parse artifacts in the feed | smoke | `! grep -qF '__ASTRO_IMAGE_'` and `! grep -qF '[['` | ❌ W0 | ⬜ pending |
| DIST-01 | `<atom:link rel="self">` present (pre-empts the predictable W3C warning, D-57) | smoke | grep | ❌ W0 | ⬜ pending |
| DIST-01 | Feed validates clean per W3C (D-57 human leg) | 🧪 human, once | paste deployed `/rss.xml` into `validator.w3.org/feed`; zero errors | n/a | ⬜ pending |
| DIST-02 | All 86 pages emit `og:title`/`og:description`/`og:image`/`og:url`/`og:site_name`/`og:type`/`twitter:card`/`theme-color` | smoke | per-file loop, exactly 1 of each (mirrors `tests/site.smoke.sh:34-52`) | ❌ W0 | ⬜ pending |
| DIST-02 | `og:image` and `og:url` absolute and prefix-correct on every page | smoke | extract `content="…"`, assert prefix match | ❌ W0 | ⬜ pending |
| DIST-02 | `og:image` targets a file that exists in `dist/` | smoke | strip `$SITE$BASE`, `test -f "dist/$rel"` (UI-SPEC E3 error row) | ❌ W0 | ⬜ pending |
| DIST-02 | 2 hero posts get their own image, ~84 pages get `og-default.png` | smoke | distinct `og:image` values across `dist/**/*.html` == 3 | ❌ W0 | ⬜ pending |
| DIST-02 | D-48 loud-fail fires on an unresolvable hero path | smoke fixture | trap-and-restore a bad image path; build fails naming post + path | ❌ W0 | ⬜ pending |
| DIST-02 | Descriptions are not identical boilerplate | smoke | distinct `<meta name="description">` values > 60 | ❌ W0 | ⬜ pending |
| DIST-02 | `og:title` is not doubled with the site name | smoke | `! grep -q 'og:title" content="[^"]*— Interstellar Engine"'` | ❌ W0 | ⬜ pending |
| DIST-02 | A pasted live URL renders a rich Discord embed | 🧪 human, backstop | see Manual-Only below | n/a | ⬜ pending |
| DIST-03 | Every page carries the header Discord link + footer `RSS · Join the Discord` | smoke | per-file loop: exactly 2 invite-URL occurrences, 1 `rss.xml` in the footer `<p>` | ❌ W0 | ⬜ pending |
| DIST-03 | `<link rel="alternate" type="application/rss+xml">` on every page (D-47) | smoke | per-file loop, exactly 1 | ❌ W0 | ⬜ pending |
| DIST-03 | D-54 loud-fail fires on an unset invite constant | smoke fixture | trap-and-restore; build fails **naming the constant** | ❌ W0 | ⬜ pending |
| unit | `describeEntry` extraction + strict D-52/D-58 truncation | node assert | cases appended to `tests/lib.smoke.mjs` | ✅ file exists | ⬜ pending |
| unit | `heroFor` returns null on no-image entries, throws naming the post on unresolvable paths | node assert | cases appended to `tests/lib.smoke.mjs` | ✅ file exists | ⬜ pending |
| regression | Zero client JS still holds | smoke | `tests/site.smoke.sh:78-79` | ✅ exists | ⬜ pending |
| regression | Page count 86, sitemap count 85 unchanged (`/rss.xml` is an endpoint, excluded from both) | smoke | `tests/site.smoke.sh:63-70,120-127` | ✅ exists | ⬜ pending |
| regression | Dead-link sweep covers the new footer RSS link | smoke | `tests/site.smoke.sh:83-115` | ✅ exists | ⬜ pending |
| regression | No hardcoded host/base under `src/` | smoke | `tests/build.smoke.sh:16` | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/distribution.smoke.sh` — all DIST-01/02/03 build-time assertions (auto-discovered
      by `tests/run-all.sh`; no runner edit)
- [ ] New assertion cases appended to `tests/lib.smoke.mjs` — `describeEntry`, `heroFor`
- [ ] `src/lib/hero-image.ts` must expose a **pure, glob-free** lookup function so
      `tests/lib.smoke.mjs` can import it under bare Node — `import.meta.glob` is Vite-only
      and cannot be unit-tested outside a build
- [ ] Framework install: **none** (no test framework by decision)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Pasting a live URL into Discord renders a rich embed with title, description, and image | DIST-02 (success criterion 2) | Requires the *deployed* site and Discord's own scraper. `dist/` greps prove the tags exist, not that the embed renders. | After deploy, paste 3 **fresh** URLs (Discord caches by URL): an M0.7 or M0.8 hero post, a technical deep-dive, and a roadmap page. Confirm large image + title + description + accent left border on each. Also paste the longest deep-dive title and confirm it still reads as a complete thought after Discord's client-side truncation. |
| RSS feed validates clean at W3C | DIST-01 (success criterion 4, D-57 human leg) | The W3C Feed Validation Service is a network service; nothing else in the harness depends on one. | After deploy, submit the deployed `/rss.xml` URL to `validator.w3.org/feed`. Require zero errors. `<atom:link rel="self">` is emitted from the start to pre-empt the one predictable warning. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all ❌ references above
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] Both Manual-Only rows completed against the deployed site
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

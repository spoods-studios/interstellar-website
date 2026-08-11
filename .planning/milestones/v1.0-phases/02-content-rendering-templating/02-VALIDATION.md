---
phase: 2
slug: content-rendering-templating
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-22
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `02-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None installed — carries forward Phase 1's precedent. This phase is templating + content ingestion; there is no application logic that warrants a JS test runner. The Astro build *is* the test harness: it exercises all four collections' Zod schemas, every custom `generateId` throw path, and the wikilink resolver's loud-fail path in one pass. |
| **Config file** | none — see Wave 0 Requirements |
| **Quick run command** | `npm run build` |
| **Full suite command** | `npm run build` + the post-build file-existence and count assertions below |
| **Estimated runtime** | ~15–40 seconds (4 collections, ~74 content files, Shiki highlighting on heavy C++ fences) |

---

## Sampling Rate

- **After every task commit:** Run `npm run build`
- **After every plan wave:** Run `npm run build` + the post-build assertions + a manual click-through of at least one full path per content tree (announcement → its deep-dives → roadmap detail → back)
- **Before `/gsd-verify-work`:** Full suite green, all four ROADMAP success criteria manually confirmed TRUE, promoted-file counts sanity-checked (9 announcements, 55 + 1 technical, 8 roadmap, 2 pages), and the live post-deploy 404 check performed
- **Max feedback latency:** 40 seconds

---

## Per-Task Verification Map

> Task IDs are assigned by the planner; this map binds each **requirement and locked decision** to its proof. The planner must attach each row to the task that delivers it.

| Ref | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|-----|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| CONT-02 | 02-01 T1, 02-04 T2, 02-05 T2 | 1, 3, 4 | CONT-02 | — | N/A | build + manual | `npm run build` (exit 0); `/` lists 9 announcement entries; one full post's rendered body matches its source `.md` (manual row, verified in 02-08 T4) | ✅ W0 closed by 02-01 | ✅ green |
| CONT-03 | 02-01 T3, 02-07 T2 | 1, 4 | CONT-03 | — | N/A | build + assertion | `npm run build`; the archive index output contains zero references to the standalone-page slug | ✅ W0 closed by 02-01 | ✅ green |
| CONT-04 | 02-01 T2/T3, 02-07 T1/T2 | 1, 4 | CONT-04 | — | N/A | build + manual | `npm run build`; overview → each `/roadmap/m0.X/` → each phase's resolved deep-dive link resolves (dead-link sweep in 02-08 T1) | ✅ W0 closed by 02-01 | ✅ green |
| SITE-04 | 02-02 T1/T2, 02-03 T3, 02-08 T1/T4 | 1, 2, 5 | SITE-04 | — | N/A | build + assertion + live | `npm run build`; `test -f dist/404.html && test -f dist/favicon.svg`; `ls dist/sitemap*.xml`; canonical + dead-link sweep in `tests/site.smoke.sh`; live-fetch a nonexistent URL post-deploy (02-08 T4) | ✅ W0 closed by 02-02/02-03 | ✅ green |
| D-33 | 02-03 T2 | 2 | CONT-02 | — | Malformed content cannot reach rendered HTML silently | negative smoke | `tests/collections.smoke.sh`: stage a bad-named fixture inside `technical/` under trap-and-restore, confirm non-zero exit **and** the offending filename in output, then assert the tree is clean | ✅ `tests/collections.smoke.sh` (02-03) | ✅ green |
| D-39 | 02-03 T3, 02-08 T2 | 2, 5 | CONT-02 | T-02-01 | Resolver returns an internal site path or `null` (which throws) — never passes a raw wikilink target through to `href` | negative smoke | `tests/lib.smoke.mjs` compile-level case (02-03 T3) plus the `tests/site.smoke.sh` fixture case (02-08 T2): unresolvable target → non-zero exit naming file **and** link | ✅ `tests/lib.smoke.mjs` (02-03) | ✅ green |
| D-39b | 02-03 T3, 02-06 T1 | 2, 4 | CONT-02 | T-02-01 | The C++ double-bracket attribute inside code is never rewritten | build + assertion | Compile-level assertion in `tests/lib.smoke.mjs` (02-03) and route-level assertion in `tests/technical.smoke.sh` (02-06) that the attribute survives verbatim inside a rendered code element | ✅ closed by 02-03/02-06 | ✅ green |
| D-34 | 02-03 T1, 02-06 T2 | 2, 4 | CONT-02 | — | N/A | build + assertion | `tests/lib.smoke.mjs` unit cases on `sortByPhaseNumber`; `tests/technical.smoke.sh` byte-offset assertion that phase-14.5 falls between phase-14 and phase-15 on the rendered M0.3 index | ✅ closed by 02-03/02-06 | ✅ green |
| D-30 | 02-03 T1, 02-08 T2 | 2, 5 | CONT-02 | T-02-03 | A drafted entry never leaks into a generated cross-link list | build + assertion | `tests/lib.smoke.mjs` unit cases on `isVisible`; `tests/site.smoke.sh` fixture case asserting absence from the milestone index, the full index, **and** the announcement's generated deep-dive list | ✅ closed by 02-03/02-08 | ✅ green |
| D-41 | 02-03 T3 | 2 | CONT-07 (partial) | — | N/A | build + assertion | `tests/markdown.smoke.sh`: code fences carry Shiki inline-style markup, zero client JS is emitted, and `astro.config.mjs` sets the light theme rather than the dark default | ✅ `tests/markdown.smoke.sh` (02-03) | ✅ green |
| D-42 | 02-04 T1, 02-06 T1 | 3, 4 | CONT-02 | — | N/A | build + assertion | `tests/lib.smoke.mjs` threshold cases on `buildToc`; `tests/technical.smoke.sh` asserts a TOC on a long deep-dive with anchors matching emitted heading ids and no script tag | ✅ closed by 02-03/02-04 | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

All Wave 0 gaps are assigned to real plans; none is left unowned. All five
closed out during execution (confirmed against the built site, not on faith,
by Plan 02-08).

- [x] `technical/`, `roadmap/`, `pages/` directories — **assigned to 02-01 (wave 1)**, the promote plan. Every content-dependent row above is blocked on it.
- [x] Three new collection definitions in `src/content.config.ts` — **assigned to 02-03 T2 (wave 2)**
- [x] Shared helpers: mdast wikilink plugin, decimal-aware phase sort, milestone-key normalizer (`M0.1` ↔ `m0.1` ↔ `M0.1.md`) — **assigned to 02-03 T1/T3 (wave 2)**
- [x] Committed harness runner `tests/run-all.sh` plus `tests/lib.smoke.mjs` — **assigned to 02-03 T1 (wave 2)**. Each plan thereafter adds its own `tests/<area>.smoke.sh`, which the runner auto-discovers, so no two parallel plans edit a shared harness file.
- [x] No JS test framework install needed — same MVP-mode reasoning as Phase 1. `tests/lib.smoke.mjs` uses `node:assert/strict` in a plain committed script, matching Phase 1's `tests/build.smoke.sh` precedent; no runner, no dependency.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Rendered post text matches source `.md` exactly | CONT-02 | "Untouched prose" is a fidelity judgement against locked VOICE content; no assertion short of a full byte-diff harness proves it, and that harness is more surface than the rule it guards | Open one announcement and one deep-dive side by side with their source files; confirm the body text, headings, lists, blockquotes and code fences carry no site-injected restyling and no H1 duplication |
| Mobile legibility | SITE-04 | Responsive reading comfort at the ~65ch measure is not machine-checkable | Load `/`, one deep-dive (with TOC), and `/roadmap` at 375px and 1440px; confirm nav wraps rather than overflowing, TOC switches from sticky sidebar to `<details>`, and no horizontal scroll appears |
| 404 under the GitHub Pages base path | SITE-04 | Research resolved this at MEDIUM confidence only — docs are silent and search results conflicted | After deploy, fetch a URL that does not exist under the project base path; confirm the custom 404 renders with site chrome, not GitHub's default |

---

## Validation Sign-Off

- [x] All tasks have an `<automated>` verify or a declared Wave 0 dependency
- [x] Sampling continuity: no 3 consecutive tasks without an automated verify
- [x] Wave 0 covers all `❌ W0` references above
- [x] No watch-mode flags
- [x] Feedback latency < 40s (`npm test` runs the full committed suite in ~25s)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-22 — all rows green except the three genuinely
manual checks (rendered-text fidelity, mobile legibility, live post-deploy
404), which Plan 02-08 Task 4 records separately and are never blockers to
this validation contract itself.

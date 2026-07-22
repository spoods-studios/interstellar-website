---
phase: 2
slug: content-rendering-templating
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| CONT-02 | TBD | TBD | CONT-02 | — | N/A | build + manual | `npm run build` (exit 0); `/` lists 9 announcement entries; one full post's rendered body matches its source `.md` | ❌ W0 | ⬜ pending |
| CONT-03 | TBD | TBD | CONT-03 | — | N/A | build + assertion | `npm run build`; `grep -c "how-its-made" dist/index.html` → expect `0` | ❌ W0 | ⬜ pending |
| CONT-04 | TBD | TBD | CONT-04 | — | N/A | build + manual | `npm run build`; overview → each `/roadmap/m0.X/` → each phase's resolved deep-dive link resolves | ❌ W0 | ⬜ pending |
| SITE-04 | TBD | TBD | SITE-04 | — | N/A | build + assertion + live | `npm run build`; `test -f dist/404.html && test -f dist/favicon.svg && test -f dist/sitemap.xml`; live-fetch a nonexistent URL post-deploy | ❌ W0 | ⬜ pending |
| D-33 | TBD | TBD | CONT-02 | — | Malformed content cannot reach rendered HTML silently | negative smoke | Stage a bad-named fixture in a scratch copy (never in real `technical/`), point a throwaway loader at it, confirm non-zero exit **and** the offending filename in stderr | N/A — manual | ⬜ pending |
| D-39 | TBD | TBD | CONT-02 | T-02-01 | Resolver returns an internal site path or `null` (which throws) — never passes a raw wikilink target through to `href` | negative smoke | Same scratch-fixture approach, applied to the mdast wikilink plugin: unresolvable target → non-zero exit naming file **and** link | N/A — manual | ⬜ pending |
| D-39b | TBD | TBD | CONT-02 | T-02-01 | `[[nodiscard]]` inside code fences is never rewritten | build + assertion | `npm run build`; grep the rendered HTML of a deep-dive known to contain `[[nodiscard]]` and confirm the literal text survives unmodified inside its `<code>` block | ❌ W0 | ⬜ pending |
| D-34 | TBD | TBD | CONT-02 | — | N/A | build + manual | Confirm `phase-10.5` sorts between `phase-10` and `phase-11` on the rendered per-milestone technical index (decimal-aware, not lexical) | ❌ W0 | ⬜ pending |
| D-30 | TBD | TBD | CONT-02 | T-02-03 | A `status: draft` entry never leaks into a generated cross-link list | build + assertion | Temporarily mark one technical doc `status: draft`, rebuild, confirm it is absent from **both** the index **and** its milestone announcement's generated deep-dive list; revert | ❌ W0 | ⬜ pending |
| D-41 | TBD | TBD | CONT-07 (partial) | — | N/A | build + assertion | `npm run build`; confirm code fences carry Shiki markup **and** that zero client JS is emitted for highlighting; theme is `github-light`, not the `github-dark` default | ❌ W0 | ⬜ pending |
| D-42 | TBD | TBD | CONT-02 | — | N/A | build + manual | TOC renders on a 3+ H2 doc, is absent below that threshold, anchors match generated heading slugs, and no JS ships | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `technical/`, `roadmap/`, `pages/` directories — do not exist in the repo yet; created by the promote step, which is itself a deliverable of this phase. Every `❌ W0` row above is blocked on it.
- [ ] Three new collection definitions in `src/content.config.ts` — extend Phase 1's file, mirroring its permissive-schema + loud-fail `generateId` pattern
- [ ] Shared helpers: mdast wikilink plugin, decimal-aware phase sort, milestone-key normalizer (`M0.1` ↔ `m0.1` ↔ `M0.1.md`)
- [ ] No JS test framework install needed — same MVP-mode reasoning as Phase 1

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Rendered post text matches source `.md` exactly | CONT-02 | "Untouched prose" is a fidelity judgement against locked VOICE content; no assertion short of a full byte-diff harness proves it, and that harness is more surface than the rule it guards | Open one announcement and one deep-dive side by side with their source files; confirm the body text, headings, lists, blockquotes and code fences carry no site-injected restyling and no H1 duplication |
| Mobile legibility | SITE-04 | Responsive reading comfort at the ~65ch measure is not machine-checkable | Load `/`, one deep-dive (with TOC), and `/roadmap` at 375px and 1440px; confirm nav wraps rather than overflowing, TOC switches from sticky sidebar to `<details>`, and no horizontal scroll appears |
| 404 under the GitHub Pages base path | SITE-04 | Research resolved this at MEDIUM confidence only — docs are silent and search results conflicted | After deploy, fetch a URL that does not exist under the project base path; confirm the custom 404 renders with site chrome, not GitHub's default |
| D-33 / D-39 loud-fail paths | CONT-02 | Committing deliberately malformed fixtures would poison the real content trees, which are read-only promote targets | Use a scratch copy outside the repo; confirm non-zero exit and that the error names the offending file (and link, for D-39) |

---

## Validation Sign-Off

- [ ] All tasks have an `<automated>` verify or a declared Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without an automated verify
- [ ] Wave 0 covers all `❌ W0` references above
- [ ] No watch-mode flags
- [ ] Feedback latency < 40s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

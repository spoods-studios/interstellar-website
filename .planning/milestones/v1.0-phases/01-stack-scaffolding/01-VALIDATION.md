---
phase: 1
slug: stack-scaffolding
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-14
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — `astro build` IS the test harness (runs the Content Layer glob loader, Zod schema validation, and the D-10 loud-fail guard). No JS test framework is installed, by deliberate scope decision (RESEARCH.md "Validation Architecture" + Wave 0 Gaps; user anti-scope-creep preference). Introducing Vitest/Jest for a build-pipeline phase with no application logic would be scope creep. |
| **Config file** | none |
| **Quick run command** | `npm run build` |
| **Full suite command** | `npm run build` (plus the SITE-02 source grep and, on wave 2, a live-URL fetch after the deploy run) |
| **Estimated runtime** | ~10–20 seconds (single Astro build); the live deploy run adds ~1–2 min |

---

## Sampling Rate

- **After every task commit:** Run `npm run build` (exits 0 and emits `dist/`)
- **After every plan wave:** Run `npm run build` + the SITE-02 grep (`! grep -rIn -e 'github\.io' -e '/interstellar-website' src/`); on wave 2, also fetch the live GitHub Pages URL after the Actions run completes
- **Before `/gsd-verify-work`:** All four ROADMAP Phase 1 success criteria observably true (run green, live URL loads, base-path grep clean, manifesto renders)
- **Max feedback latency:** ~20s local; ~1–2 min for the live deploy run

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-1 | 01 | 1 | SITE-02, CONT-01 | T-01-SC | Blocking-human legitimacy confirm before `npm install` (never auto-approved) | checkpoint | manual (npmjs.com publisher check) | ❌ W0 (deliverable) | ⬜ pending |
| 01-01-2 | 01 | 1 | SITE-02 | T-01-03 | URL lives only in `astro.config.mjs`; caret dep + committed lockfile | build/static | `test -f astro.config.mjs && grep -q "/interstellar-website" astro.config.mjs && npx astro info` | ❌ W0 (deliverable) | ⬜ pending |
| 01-01-3 | 01 | 1 | CONT-01 | T-01-02 | Permissive ingest; loud-fail naming file on malformed content; no URL literal in `src/` | build + negative smoke | `npm run build && grep -q "2026-04-07" dist/index.html && ! grep -rIn -e 'github\.io' -e '/interstellar-website' src/` | ❌ W0 (deliverable) | ⬜ pending |
| 01-02-1 | 02 | 2 | SITE-01 | T-01-01 / T-01-SC | Least-priv permissions; pinned actions; no path filter; no PR job | static (yaml assert) | `node -e "…assert pinned tags + permissions + no path filter…"` (see 01-02-PLAN Task 1) | ❌ W0 (deliverable) | ⬜ pending |
| 01-02-2 | 02 | 2 | SITE-01 | T-01-01 | Live deploy renders manifesto (non-empty list — Pitfall 2 guard live) | checkpoint (CI + browser) | `gh run list --limit 1` + fetch live URL | ❌ W0 (deliverable) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky. "W0 (deliverable)" = the file under test does not exist yet because it is the task's own deliverable — normal for a first-code phase; no test-file scaffold is required since `astro build` is the harness.*

---

## Wave 0 Requirements

No test-framework Wave 0 work is required. This is a build-pipeline scaffolding phase with no application logic; `npm run build` (real Zod validation + the D-10 guard) is the correct-altitude check (RESEARCH.md Wave 0 Gaps). The "not-yet-existing" files (`src/content.config.ts`, `.github/workflows/deploy.yml`) are the plans' own deliverables, not test scaffolds — they are created by the tasks themselves, so `wave_0_complete: true`.

- [x] No JS test framework install (deliberate — avoids scope creep)
- [x] `astro build` confirmed as the validation harness for content correctness
- [x] D-10 negative check specified as a one-off in 01-01 Task 3 (not a committed automated test, per RESEARCH.md)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Package legitimacy confirmation before install | — (T-01-SC) | Supply-chain gate is never auto-approvable; needs a human to confirm publisher/repo on npmjs.com | 01-01 Task 1: open npmjs.com/package/astro + npmjs.com/package/typescript, confirm official publisher + repo + download volume |
| Live site renders the manifesto at the GitHub Pages URL | SITE-01 | Requires a real deploy run + a browser; a green Actions run alone does not prove content served (Pitfall 2 silent-empty signature) | 01-02 Task 2: `gh run watch`, then open `https://spoods-studios.github.io/interstellar-website/` and confirm `Devblog` + manifesto title + `2026-04-07`, non-empty list |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or are checkpoints (01-01-1 and 01-02-2 are checkpoints; 01-01-2, 01-01-3, 01-02-1 have `<automated>` commands)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (checkpoints are bracketed by build-verified tasks)
- [x] Wave 0 covers all MISSING references (N/A — no test-file references; `astro build` is the harness)
- [x] No watch-mode flags (`npm run build` is one-shot)
- [x] Feedback latency < 20s local
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-14

---
phase: 04-analytics-launch-content-deploy-hardening
fixed_at: 2026-08-08T18:22:00Z
review_path: .planning/phases/04-analytics-launch-content-deploy-hardening/04-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 4: Code Review Fix Report

**Fixed at:** 2026-08-08T18:22:00Z
**Source review:** 04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (all Warnings; fix_scope=critical_warning, the 6 Info findings are out of scope and untouched)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01: Pages deploy workflow has no `concurrency` group

**Files modified:** `.github/workflows/deploy.yml`
**Commit:** a09c316
**Applied fix:** Added a workflow-level `concurrency` block in the GitHub Pages
starter-workflow shape (`group: "pages"`, `cancel-in-progress: false`) so
concurrent runs queue in push order instead of racing — an older run's
`deploy-pages` can no longer land after a newer run's.
**Verification:** YAML parses clean (`python3 yaml.safe_load`).

### WR-02: live-probe.sh never normalizes the trailing slash it depends on

**Files modified:** `tests/live-probe.sh`
**Commit:** d24fcff
**Applied fix:** Normalized at the argument-parse site: `BASE_URL="${1%/}/"`.
A slash-terminated argument is unchanged; a slash-less one gains the slash the
route legs concatenate against, so failures can no longer point at the routes
when the base was malformed.
**Verification:** `bash -n tests/live-probe.sh` clean.

### WR-03: unset-analytics warning fires once per page (100 duplicated lines)

**Files modified:** `src/lib/site.mjs`
**Commit:** 32ad4e8
**Applied fix:** Module-level `warnedGoatcounterUnset` memo — the warn now
fires once per process instead of once per rendered page. Behavior otherwise
unchanged (still returns `null` on unset; placeholder/malformed still throw).
**Verification:** `node --check` clean; real build shows the warning **2**
times (config-load module instance + render module instance — Vite evaluates
the module in two graphs) versus 100 before, and it no longer interleaves
with Astro's page listing. The D-61 fixture in `tests/hardening.smoke.sh`
(greps the whole log for one occurrence) stays green.

### WR-04: post-nav negative assertions scoped by a `[^Z]*` content-coincidence window

**Files modified:** `tests/post.smoke.sh`
**Commit:** 410bfe9
**Applied fix:** Replaced both `grep -o 'class="post-nav">[^Z]*'` windows with
a deterministic extraction bounded at the element's own closing tag:
`grep -o 'class="post-nav">.*' | sed 's|</nav>.*|</nav>|'` (cut at the first
`</nav>` — same anchoring idea as the breadcrumbs extraction in
`tests/technical.smoke.sh`). Confirmed against the built HTML that the
post-nav element contains the neighbor links plus "Back to devblog" and that
the first `</nav>` is its own close, so the window is exactly the element.
**Verification:** `bash -n` clean; extraction verified empirically on the
fresh build (oldest window: no `&larr;`, contains `&rarr;`; newest window:
no `&rarr;`, contains `&larr;`).

## Suite Verification

After all four fixes, in the fix worktree:

- `npm run build` — exit 0, 99 pages built.
- `npm test` — exit 0, all 11 `ALL CHECKS PASSED` lines present, zero FAIL lines.
- `bash -n tests/live-probe.sh tests/post.smoke.sh` — clean.

---

_Fixed: 2026-08-08T18:22:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

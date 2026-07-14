---
phase: 01-stack-scaffolding
fixed_at: 2026-07-14T06:12:30Z
review_path: .planning/phases/01-stack-scaffolding/01-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 1: Code Review Fix Report

**Fixed at:** 2026-07-14T06:12:30Z
**Source review:** .planning/phases/01-stack-scaffolding/01-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (Critical + Warning; Info findings out of scope per fix_scope)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### CR-01: `generateId` collision silently drops devlog posts with the same slug on different dates

**Files modified:** `src/content.config.ts`
**Commit:** 2c4aded
**Applied fix:** Changed `generateId` to return `` `${match[1]}-${match[2]}` `` (date + slug) instead of `match[2]` (slug only), guaranteeing collection-id uniqueness across same-slug posts on different dates. Verified `npm run build` stays green and the rendered manifesto still shows title "Why I'm Building a Hyperrealistic Space Sim from Scratch" with date `2026-04-07` in `dist/index.html` (index.astro derives date/title from `entry.filePath`, not the collection id, so downstream rendering was unaffected by the id change). `npx tsc --noEmit` reported zero errors.

### WR-01: `build.smoke.sh` negative-check cleanup isn't guaranteed if the log assertion fails

**Files modified:** `tests/build.smoke.sh`
**Commit:** 957006f
**Applied fix:** Added `trap 'rm -f "devlog/$MARKER"' EXIT` immediately after the `MARKER` assignment, guaranteeing the fixture file is removed on any exit path (including `set -e` termination on a failed `grep -q` assertion). Kept the existing manual `rm -f` calls on the success paths (idempotent, harmless with the trap present) so the `git status --porcelain devlog/` clean-check later in the script still runs against an already-cleaned tree. Verified by running the real smoke test (passes, `devlog/` clean) and by simulating a grep-assertion failure (temporarily swapping the match string): the script now exits 1 as expected and `devlog/` remains clean, whereas before the fix this path would have left the fixture behind.

### WR-02: Deploy workflow grants `pages: write` / `id-token: write` to the `build` job, which never uses them

**Files modified:** `.github/workflows/deploy.yml`
**Commit:** 8fbf04b
**Applied fix:** Removed the workflow-level `permissions:` block and added per-job scoping: `build` now has only `contents: read`; `deploy` has `pages: write` + `id-token: write`. Verified via `python3 -c "import yaml; yaml.safe_load(...)"` (valid YAML) and re-read of the full file for structural integrity. No CLI-based Actions linter (`actionlint`) was available in this environment, so verification relied on YAML parse + manual re-read (Tier 1 + partial Tier 2).

### WR-03: `posts` in `index.astro` renders every devlog entry with no `status` filter

**Files modified:** `src/pages/index.astro`
**Commit:** 67f56cd
**Applied fix:** Added `.filter((entry) => entry.data.status !== 'draft')` before the existing `.map()` in the `posts` pipeline, with a comment documenting that entries with no `status` field (e.g. the frontmatter-less manifesto) default to published and are not filtered. Verified `npm run build` stays green, `npx tsc --noEmit` reports zero errors, the manifesto (no `status` field) still renders with its title and `2026-04-07` date, and the full `tests/build.smoke.sh` suite passes end-to-end with `devlog/` left clean.

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-07-14T06:12:30Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

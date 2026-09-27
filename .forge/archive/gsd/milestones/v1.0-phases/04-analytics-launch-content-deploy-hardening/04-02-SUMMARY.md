---
phase: 04-analytics-launch-content-deploy-hardening
plan: 02
subsystem: content
tags: [promote, devlog, m1.1, launch-post, rss, roadmap, smoke-tests]
requires: ["04-01"]
provides:
  - "M1.1 launch post live at devlog/2026-07-30-first-burn.md, first in archive and feed"
  - "All ten M1.1 deep-dives under technical/m1.1/ incl. three decimal-numbered phases"
  - "roadmap/M1.1.md detail page with resolved deep-dive links"
  - "Refreshed pages/roadmap.md presenting M1.1 closed, M1.2 next (D-64)"
  - "Corpus assertions retargeted at the 99-page post-promote corpus"
affects: [04-04, 04-05]
tech-stack:
  added: []
  patterns: ["studio-vault source-of-truth promote (D-25/D-56)", "RED corpus retarget before atomic promote"]
key-files:
  created:
    - devlog/2026-07-30-first-burn.md
    - assets/m1.1-hero-first-burn.png
    - technical/m1.1/ (10 deep-dives)
    - roadmap/M1.1.md
    - ../studio/vault/devlog/drafts/roadmap.md
  modified:
    - pages/roadmap.md
    - tests/collections.smoke.sh
    - tests/build.smoke.sh
    - tests/technical.smoke.sh
    - tests/roadmap.smoke.sh
    - tests/distribution.smoke.sh
    - tests/post.smoke.sh
    - tests/site.smoke.sh
    - ../studio/vault/project/roadmap-detail/M1.1.md
    - ../studio/vault/devlog/drafts/m1.1-spacecraft-control.md
decisions:
  - "Task 1 (user, via orchestrator): launch post slug = 2026-07-30-first-burn.md (convention option -- date + slugified title, matching all nine prior posts)"
  - "discord_post_id quoted studio-side: first draft with a real snowflake id; bare number fails the string schema and exceeds float64 exact-integer range"
  - "M1.1 hero upscaled studio-side 1139x1068 -> 1200x1125 (Lanczos) to clear the 1200x630 OG large-embed floor; logged in WINDOWS.md for author review"
metrics:
  duration: "~16 min"
  completed: "2026-08-08"
status: complete
---

# Phase 4 Plan 02: M1.1 Content Promote Summary

Full M1.1 tree promoted byte-for-byte from the studio vault: the First Burn launch post now tops the archive and the RSS feed, all ten deep-dives (incl. 53.1/53.2/53.3) render and are indexed, and the roadmap presents M1.1 as closed with M1.2 next.

## Tasks

| Task | Name | Commit(s) | Result |
|------|------|-----------|--------|
| 1 | Fix launch post slug (checkpoint:decision) | — | Pre-resolved by user: `2026-07-30-first-burn.md` (convention) |
| 2 | RED — retarget corpus assertions | `5fda018` | 4 harness files retargeted; proven red pre-promote (collections exit 1 at counts, roadmap exit 1 at m1.1 loop) |
| 3 | Studio-side roadmap transcription refresh | studio `aee1905` | drafts/roadmap.md created (M1.1 closed, M1.2 next); M1.1.md's two stale status statements corrected; committed, unpushed |
| 4 | GREEN — atomic promote | `83c429e` (+ fixes below) | 13 files promoted byte-identical; build 99 pages; `npm test` exit 0, all 11 harnesses green |

## Verification

- `npm run build` exit 0 — 99 pages: devlog 10 / technical 66 / roadmap 9 / pages 2.
- `npm test` exit 0 — all 11 smoke harnesses pass on the committed corpus.
- Every promoted markdown file `diff`-identical to its studio source; hero PNG `cmp`-identical.
- Launch post first in `dist/index.html` (byte offset 3186 < manifesto 4699) and first RSS guid (`.../devlog/2026-07-30-first-burn/`).
- `dist/roadmap/m1.1/index.html` links into `technical/m1.1/`; decimal page `phase-53.1-...` built.
- Launch post `og:image` is the hashed hero build (`m1.1-hero-first-burn.BbnsCBbo.png`, 1200x1125).
- Exclusions honored: no `how-this-gets-built.md`, no `.discord.txt` under `devlog/`; `tags:` frontmatter key survived verbatim.
- `git diff --stat package.json package-lock.json` empty (T-04-SC: zero installs).
- Studio repo: 3 commits ahead of origin, tree clean, deliberately unpushed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Launch post `discord_post_id` failed the devlog schema**
- **Found during:** Task 4 first build — `InvalidContentEntryDataError: Expected "string", received "number"`.
- **Issue:** First draft carrying a real snowflake id (`1532409509463457923`); unquoted YAML types it as a number, and the value exceeds float64's exact-integer range. Prior drafts carried the string `<set on publish>`.
- **Fix:** Quoted the value in the studio source (vault stays source of truth; promoted copy remains byte-identical). Schema untouched per plan scope.
- **Files:** `../studio/vault/devlog/drafts/m1.1-spacecraft-control.md`, re-copied to `devlog/2026-07-30-first-burn.md`.
- **Commits:** studio `10fe002`; included in `83c429e`.

**2. [Rule 3 - Blocking] M1.1 hero below the OG large-embed floor**
- **Found during:** Task 4 — `distribution.smoke.sh` DIST-02: launch post declared 1139x1068, below 1200x630 (Discord downgrades the card to a thumbnail). Prior heroes are 1920x1080 / 1900x1060.
- **Fix:** Mechanical Lanczos upscale to 1200x1125 at the studio source, no crop or recomposition; pre-resize original preserved in studio git history. Logged to `.planning/WINDOWS.md` (entry 3) so the author can opt to regenerate the plot natively instead.
- **Commits:** studio `54f30e9`; website `a90fedc`.

**3. [Rule 3 - Blocking] Corpus assertions outside the plan's four-file list went stale**
- **Found during:** Task 4 `npm test`. The plan's premise that `distribution.smoke.sh` fully self-adjusts was wrong for two absolute counts, and `post.smoke.sh` / `site.smoke.sh` were not in the Task 2 list at all.
- **Fix:** `distribution.smoke.sh` distinct og:image cards 3→4 and feed hero URLs 2→3 (`e1c612f`, `8d80094`); `post.smoke.sh` devlog count 9→10 and newest-post identity (`eec86a8`); `site.smoke.sh` total pages 86→99 (`b9f70d7`). Swept all harnesses for further absolute corpus counts — none remain stale.

### Acceptance-criterion interpretation

The criterion "`grep -rc technical-devlog dist/` … is 0" matches one pre-existing, benign occurrence: the how-to-read legend's own H1 anchor slug (`id="how-to-read-the-roadmap-detail--technical-devlogs"`), generated from its title and present in every build since Phase 2. Zero occurrences of the actual placeholder wording (`#technical-devlog` / `posted in`) survive anywhere in `dist/`, which is the criterion's intent (Pitfall 6's residual check).

## Threat Model Outcomes

- T-04-05 (promote fidelity): mitigated — every file byte-compared against source after final copies.
- T-04-06 (unpublished doc): mitigated — `how-this-gets-built.md` never copied.
- T-04-08 (binary asset): mitigated — `cmp`-identical to (corrected) studio source.
- T-04-SC (installs): mitigated — package files byte-identical, zero installs.

## Known Stubs

None.

## Flagged for Reviewer

- Task 3's second half (M1.1 detail status prose) executed as planned; phase-heading count (9) and placeholder-line count (9 `technical-devlog` occurrences: 1 generic mention + 8 markers) unchanged before/after.
- Studio repo left 3 commits ahead of origin (aee1905, 10fe002, 54f30e9) — unpushed by design (Plan 03-06 precedent).

## Self-Check: PASSED

All promoted files present on disk; all 8 website-worktree commits (5fda018…9bd4e26) and 3 studio commits verified in their respective logs.

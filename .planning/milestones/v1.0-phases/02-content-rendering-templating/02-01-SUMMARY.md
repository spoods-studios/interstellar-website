---
phase: 02-content-rendering-templating
plan: 01
subsystem: content
tags: [astro, content-collections, zod, markdown, promote-pipeline]

requires:
  - phase: 01-stack-scaffolding
    provides: Astro build pipeline, devlog content collection with glob loader + Zod schema, tests/build.smoke.sh RED/GREEN harness
provides:
  - Full M0.1-M0.8 devblog announcement archive (9 posts total incl. manifesto) in devlog/
  - New technical/ content tree (56 files: 55 phase deep-dives + _how-to-read.md)
  - New roadmap/ content tree (8 per-milestone detail docs)
  - New pages/ content tree (how-its-made.md, roadmap.md)
  - New repo-root assets/ directory for devlog hero images
  - PROMOTE-MANIFEST.md auditing every source->destination promote mapping
affects: [02-content-rendering-templating remaining plans (templates/collections consuming these trees), Phase 4 (M1.1 content promote follows this same pattern)]

tech-stack:
  added: []
  patterns:
    - "Read-only promote-drop content trees (devlog/, technical/, roadmap/, pages/) - byte-for-byte copies from ../studio/vault/, never hand-edited"
    - "Zod status enum widened additively (draft/published/final) rather than remapped, to accept vault's real frontmatter values without touching render logic"

key-files:
  created:
    - devlog/2026-04-13-before-the-galaxy-a-triangle.md (+ 7 more M0.2-M0.8 announcements)
    - assets/m0.7-hero-contrast.png
    - assets/m0.8-hero-precession.png
    - technical/_how-to-read.md
    - technical/m0.1/ ... technical/m0.8/ (55 deep-dive files)
    - roadmap/M0.1.md ... roadmap/M0.8.md
    - pages/how-its-made.md
    - pages/roadmap.md
    - PROMOTE-MANIFEST.md
  modified:
    - src/content.config.ts (devlog status enum: added 'final')
    - tests/build.smoke.sh (added nine-announcement archive assertion)
    - CLAUDE.md (extended read-only promote-drop rule to name all four trees)

key-decisions:
  - "grep -c counts matching LINES not occurrences; Astro's production build minifies dist/index.html to a single line, so the plan's literal 'grep -c <li ... -eq 9' verification command always evaluates to 1 regardless of actual post count. Used 'grep -o <li | wc -l' instead in tests/build.smoke.sh to actually count occurrences and preserve the intended nine-announcement assertion."
  - "pages/how-its-made.md status line rewritten to the bare 'status: published' (dropping the studio-side staging comment) so it satisfies the plan's grep -qx exact-line-match acceptance criterion; body and every other frontmatter field are untouched."

patterns-established:
  - "Cross-repo promote from ../studio/vault/ is an explicit named-file list per tree, never a directory glob - guards against premature publication of out-of-scope content (e.g. M1.1, drafts/how-this-gets-built.md)."

requirements-completed: [CONT-02, CONT-03, CONT-04]

coverage:
  - id: D1
    description: "9 milestone announcement posts (manifesto + M0.1-M0.8) promoted into devlog/ with permanent YYYY-MM-DD-slug.md URLs, plus the two M0.7/M0.8 hero assets"
    requirement: "CONT-02"
    verification:
      - kind: other
        ref: "npm run build && bash tests/build.smoke.sh (nine-announcement assertion)"
        status: pass
    human_judgment: false
  - id: D2
    description: "55 technical deep-dives + _how-to-read.md promoted into technical/m0.1-m0.8, byte-identical, M1.1 excluded"
    verification:
      - kind: other
        ref: "find technical -name '*.md' | wc -l (56); diff -r vs vault source"
        status: pass
    human_judgment: false
  - id: D3
    description: "8 roadmap detail docs promoted into roadmap/M0.1-M0.8.md, M1.1 excluded"
    requirement: "CONT-04"
    verification:
      - kind: other
        ref: "ls roadmap/*.md | wc -l (8); diff vs vault source"
        status: pass
    human_judgment: false
  - id: D4
    description: "pages/how-its-made.md landed (status flipped to published) and pages/roadmap.md authored in site voice from the Discord pinned overview"
    requirement: "CONT-03"
    verification:
      - kind: other
        ref: "grep -qx 'status: published' pages/how-its-made.md; grep checks on pages/roadmap.md content"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-07-22
status: complete
---

# Phase 2 Plan 01: Content Promote Summary

**Promoted all locked studio content for closed milestones M0.1-M0.8 into four new read-only content trees (devlog/, technical/, roadmap/, pages/) plus a hero-image assets/ dir, with a full audit manifest and a green build.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-22
- **Tasks:** 3
- **Files modified:** 12 (Task 1) + 65 (Task 2) + 3 (Task 3) = 80 files touched across 3 commits

## Accomplishments
- devlog/ grew from 1 file (manifesto) to 9 (full M0.1-M0.8 announcement archive), each renamed to its permanent `YYYY-MM-DD-slug.md` URL per the plan's fixed mapping
- New `technical/` tree: 56 files (55 phase deep-dives across m0.1-m0.8 + `_how-to-read.md`), milestone subdirectory structure and the one real Obsidian wikilink preserved byte-for-byte
- New `roadmap/` tree: 8 per-milestone detail docs, byte-identical to the vault source
- New `pages/` tree: `how-its-made.md` (publication-state flip only) and an authored `pages/roadmap.md` transcribing the Discord pinned overview into site voice
- `PROMOTE-MANIFEST.md` records every source->destination mapping and the four excluded sources with rationale
- `src/content.config.ts` devlog `status` enum widened to accept `final` (M0.7/M0.8's real frontmatter value)
- `tests/build.smoke.sh` extended with a RED/GREEN nine-announcement archive assertion

## Task Commits

1. **Task 1: Promote the 8 milestone announcements and their two hero assets into devlog/** - `89f725d` (feat)
2. **Task 2: Promote the 55 technical deep-dives and the 8 roadmap detail docs** - `47297b7` (feat)
3. **Task 3: Land pages/how-its-made.md and author the site-voice roadmap overview** - `f58e154` (feat)

## Files Created/Modified
- `devlog/2026-04-13-before-the-galaxy-a-triangle.md` … `devlog/2026-07-13-making-mercury-precess.md` (8 files) - promoted M0.1-M0.8 announcements
- `assets/m0.7-hero-contrast.png`, `assets/m0.8-hero-precession.png` - hero images referenced by two announcement bodies
- `src/content.config.ts` - devlog `status` Zod enum widened to `draft | published | final`
- `tests/build.smoke.sh` - added nine-announcement archive assertion (RED confirmed at count=1, GREEN at count=9)
- `technical/_how-to-read.md`, `technical/m0.1/` … `technical/m0.8/` (56 files total) - promoted technical deep-dive corpus
- `roadmap/M0.1.md` … `roadmap/M0.8.md` (8 files) - promoted roadmap detail docs
- `CLAUDE.md` - Content section extended to name all four promote-drop trees
- `pages/how-its-made.md` - promoted, `status: draft` → `status: published`
- `pages/roadmap.md` - authored transcription of the Discord pinned roadmap overview
- `PROMOTE-MANIFEST.md` - full audit record of the promote

## Decisions Made
- Widened the devlog `status` enum additively (`final` added alongside `draft`/`published`) rather than remapping M0.7/M0.8's frontmatter, preserving byte-identical copies per D-14/D-25.
- Fixed a latent bug in the plan's own verification command: `grep -c '<li'` counts matching lines, and Astro's production build minifies `dist/index.html` to one line, so the literal plan command always returns 1 regardless of true post count. Used `grep -o '<li' | wc -l` in `tests/build.smoke.sh` to actually count occurrences and preserve the RED/GREEN gate's intent.
- On `pages/how-its-made.md`, replaced `status: draft   # publishes to interstellar-website as a permanent page at M1.1 close` with the bare `status: published` line — the trailing comment was staging metadata that no longer applies once published, and the plan's own acceptance criterion (`grep -qx 'status: published'`, an exact full-line match) required the line to carry no trailing comment.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed a broken verification assertion in the plan itself**
- **Found during:** Task 1 (RED step for the nine-announcement assertion)
- **Issue:** The plan's literal verify/acceptance command `grep -c '<li' dist/index.html` outputs `9` assumes one `<li` per output line. Astro's production build minifies `dist/index.html` to a single line, so `grep -c` (count of matching *lines*) always returns `1` regardless of how many `<li` elements are actually present — the assertion could never distinguish 1 post from 9.
- **Fix:** Used `grep -o '<li' dist/index.html | wc -l` in `tests/build.smoke.sh`, which counts actual occurrences instead of matching lines. Confirmed RED (returned 1 with only the manifesto present) before promoting, then GREEN (returned 9 after all 8 announcements landed).
- **Files modified:** tests/build.smoke.sh
- **Verification:** `bash tests/build.smoke.sh` exits 0 with the nine-announcement assertion passing
- **Committed in:** 89f725d (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix in test tooling)
**Impact on plan:** Necessary correction to make the plan's own RED/GREEN gate actually discriminate — no scope creep, no change to promoted content.

## Issues Encountered
None beyond the grep -c deviation documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All four content trees (devlog/, technical/, roadmap/, pages/) are populated and byte-verified against the studio vault; subsequent plans in this phase (templates, collections, layouts) now have real content to build against instead of placeholders.
- `technical/` and `roadmap/` are not yet wired into Astro Content Collections — that is explicitly out of this plan's scope (Task 2's `read_first` notes this is mirrored from the devlog pattern in a later plan).
- `npm run build` remains green; `tests/build.smoke.sh` now asserts the full nine-post archive count as a regression guard for later plans.
- Phase 4 will follow the same promote pattern for M1.1's 5 deep-dives, `roadmap/M1.1.md`, and its announcement once that milestone closes (D-44).

---
*Phase: 02-content-rendering-templating*
*Completed: 2026-07-22*

## Self-Check: PASSED

All created files verified present on disk; all four task/summary commit hashes (89f725d, 47297b7, f58e154, bff19e5) verified in `git log`.

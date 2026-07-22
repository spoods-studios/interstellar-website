---
phase: 02-content-rendering-templating
plan: 08
subsystem: testing
tags: [astro, sitemap, canonical, dead-link-sweep, satteri, wikilink, loud-fail, requirements-doc]

requires:
  - phase: 02-content-rendering-templating
    provides: "02-01 through 02-07: the four content collections, all built routes (devlog, technical, roadmap, pages), the BaseLayout canonical/favicon emission, the D-39 mdast wikilink plugin and D-40 deep-dive-link plugin this plan's fixtures exercise end-to-end against the real build"
provides:
  - "tests/site.smoke.sh -- whole-site harness: exactly-one-canonical-per-page (base-prefixed, derived from astro.config.mjs), sitemap URL count vs. built page count, favicon coverage, zero <script> tags, a full dead-link sweep across every internal href in dist/, and the two Plan 02-03 diagnostic routes confirmed gone"
  - "Three trap-and-restore negative fixtures inside tests/site.smoke.sh: D-39 unresolvable wikilink (loud non-zero exit naming file+link), D-30 draft leak (zero survival across milestone index, full index, AND the announcement's generated deep-dive list), and unresolvable deep-dive reference (loud non-zero exit naming the roadmap file) -- all three restore the read-only content trees and assert git status --porcelain is empty afterward"
  - "Config-load-time re-validation of every technical/ and roadmap/ file through the same mdastPlugins pipeline Astro's build uses -- closes a real gap where Astro's glob loader swallows render() errors per-entry and ships an empty page with exit 0, which would have silently defeated D-39's loud-fail guarantee"
  - "REQUIREMENTS.md, ROADMAP.md, 02-UI-SPEC.md, 02-VALIDATION.md amended to match the phase's real four-content-tree scope; 02-VALIDATION.md's Manual-Only Verifications table reduced to the three genuinely manual checks (nyquist_compliant: true)"
  - "Human verification of the three Manual-Only checks recorded: rendered-text fidelity PASS, mobile/desktop legibility PASS, live post-deploy 404 PENDING (deploy-dependent, not yet checkable)"
affects: ["phase-03-distribution-analytics (RSS/OG/analytics build on the now-closed content set)", "phase-04-deploy-hardening (owns the live-404 verification this plan left pending, plus CONT-06 redirect-stub work across all three URL trees)"]

tech-stack:
  added: []
  patterns:
    - "Whole-site integration checks (canonical coverage, sitemap-vs-page-count, dead-link sweep) belong in one committed harness distinct from any single plan's slice harness, because cross-plan link breakage (Plan A generates a link into a route Plan B owns) is invisible to either plan's own tests"
    - "A negative-fixture harness that mutates a read-only promote-drop content tree must re-validate at the same pipeline stage the real failure needs to be loud at -- an assertion against an isolated helper function (tests/lib.smoke.mjs's direct markdownToHtml() calls) is not sufficient proof the real astro build fails loudly, since Astro's own content loader can catch and swallow a renderer's thrown error before it reaches the CLI exit code"
    - "Trap-and-restore fixtures against devlog/technical/roadmap/pages must assert git status --porcelain is empty for the affected tree after restoration, not just that the mutation was reverted, since a partial revert (e.g. trailing whitespace or an extra newline) is itself a violation of the read-only-promote-target contract"

key-files:
  created:
    - tests/site.smoke.sh
  modified:
    - astro.config.mjs
    - tests/collections.smoke.sh
    - tests/markdown.smoke.sh
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/phases/02-content-rendering-templating/02-UI-SPEC.md
    - .planning/phases/02-content-rendering-templating/02-VALIDATION.md
    - .planning/phases/02-content-rendering-templating/02-CONTEXT.md
  removed:
    - src/pages/collection-counts.json.ts
    - src/pages/markdown-render-check.astro

key-decisions:
  - "Live 404 under the GitHub Pages base path recorded as PENDING, not PASS -- it is empirically checkable only after these commits land on main and a GitHub Actions deploy completes; ticking it now would misrepresent an unverified claim as verified. Legitimate to close the phase with this single item outstanding per 02-VALIDATION.md's own Manual-Only table design; Phase 4's deploy hardening owns the follow-up check."
  - "Developer's post-build visual observation ('looks pretty bare, not in scope for this phase but looks good') captured as a forward-looking deferred-items entry in 02-CONTEXT.md, not as a defect or a new task -- it is D-21/D-22/D-23 (system fonts, light-only, hand-written minimal CSS) working as designed against this phase's stated 'add nothing between reader and text' philosophy, and the developer explicitly scoped it out of this phase."

patterns-established:
  - "Manual-Only Verifications recorded in a plan summary must distinguish PASS from PENDING explicitly -- a deploy-dependent check that cannot yet be exercised is not the same outcome as a check that was exercised and passed, and collapsing the two would hide a real gap from Phase 4 planning."

requirements-completed: [SITE-04, CONT-02, CONT-03, CONT-04]

coverage:
  - id: D1
    description: "Whole-site SITE-04 sweep: canonical coverage, sitemap completeness, favicon coverage, zero client JS, and a full dead-link sweep across all 86 built pages"
    requirement: "SITE-04"
    verification:
      - kind: integration
        ref: "bash tests/site.smoke.sh"
        status: pass
      - kind: integration
        ref: "npm test"
        status: pass
    human_judgment: false
  - id: D2
    description: "D-39 unresolvable wikilink, D-30 draft leak (index + announcement deep-dive list), and unresolvable deep-dive reference each fail the build loudly naming the offending file/link, with the affected content tree restored clean afterward"
    requirement: "CONT-02"
    verification:
      - kind: integration
        ref: "bash tests/site.smoke.sh (D-39/D-30/deep-dive negative fixtures)"
        status: pass
      - kind: integration
        ref: "git status --porcelain devlog/ technical/ roadmap/ pages/ (empty after run)"
        status: pass
    human_judgment: false
  - id: D3
    description: "REQUIREMENTS.md, ROADMAP.md, 02-UI-SPEC.md, and 02-VALIDATION.md amended to match the phase's real four-content-tree scope; Manual-Only table reduced to exactly the three genuinely manual checks"
    requirement: "CONT-02"
    verification:
      - kind: other
        ref: "grep -q 'technical' .planning/REQUIREMENTS.md && grep -q '02-01-PLAN.md' .planning/ROADMAP.md && grep -q 'nyquist_compliant: true' .planning/phases/02-content-rendering-templating/02-VALIDATION.md"
        status: pass
      - kind: integration
        ref: "npm test"
        status: pass
    human_judgment: false
  - id: D4
    description: "Rendered post text (announcement + technical deep-dive) matches its source .md exactly -- no duplicated title, no site-injected heading, all blockquotes/lists/code fences unrestyled"
    requirement: "CONT-02"
    verification: []
    human_judgment: true
    rationale: "Fidelity is a prose-comparison judgement call against locked VOICE content per 02-VALIDATION.md's Manual-Only table; no assertion short of a full byte-diff harness proves it, and that harness is more surface than the rule it guards. Developer performed this check 2026-07-22 and reported PASS with no issues found."
  - id: D5
    description: "Mobile (375px) and desktop (1440px) legibility across the homepage, a technical deep-dive, and /roadmap/ -- nav wrapping, TOC disclosure/sidebar switch, no unwanted horizontal scroll"
    requirement: "SITE-04"
    verification: []
    human_judgment: true
    rationale: "Responsive reading comfort at the ~65ch measure is not machine-checkable per 02-VALIDATION.md's Manual-Only table. Developer performed this check 2026-07-22 at both widths and reported PASS with no issues found."
  - id: D6
    description: "Live custom 404 renders with site chrome (not GitHub's generic 404) under the GitHub Pages base path"
    requirement: "SITE-04"
    verification: []
    human_judgment: true
    rationale: "This is the empirical resolution of 02-RESEARCH.md Pitfall 6 (docs silent, search results conflicting) and is only checkable after these commits are on main and a GitHub Actions deploy completes. NOT YET VERIFIED -- recorded honestly as pending rather than assumed passing. Phase 4's deploy hardening owns the follow-up live check."

duration: 25min
completed: 2026-07-22
status: complete
---

# Phase 2 Plan 8: Whole-Site Verification and Requirement Close-Out Summary

**Whole-site smoke harness (canonical/sitemap/dead-link/zero-JS + three loud-fail fixtures) plus the phase's requirement-doc close-out, with two of three manual verifications PASS and the live post-deploy 404 recorded honestly as PENDING**

## Performance

- **Duration:** ~25 min (Tasks 1-3 by a prior executor session; this session covers Task 4 continuation + summary/state close-out)
- **Started:** 2026-07-22T18:15:00Z
- **Completed:** 2026-07-22T18:30:00Z
- **Tasks:** 4 (+ 1 orchestrator-note task)
- **Files modified:** 10 (2 removed, 8 created/modified across this session and the prior one)

## Accomplishments
- Whole-site `tests/site.smoke.sh` proves canonical coverage, sitemap completeness, favicon coverage, zero client JS, and zero dead internal links across all 86 built pages -- the one check that catches cross-plan link breakage no single slice plan could see
- Three trap-and-restore negative fixtures (D-39 unresolvable wikilink, D-30 draft leak across indexes AND generated cross-links, unresolvable deep-dive reference) prove the loud-fail and draft-filter guarantees against the real build pipeline, not just an isolated helper function -- and surfaced a real gap (Astro's glob loader swallows render() errors) that a config-load-time re-validation pass now closes
- REQUIREMENTS.md, ROADMAP.md, 02-UI-SPEC.md, and 02-VALIDATION.md now describe the phase's real four-content-tree scope instead of the stale single-tree wording that predated the technical/roadmap series
- Both Plan 02-03 diagnostic routes (`collection-counts.json.ts`, `markdown-render-check.astro`) removed from the build; the two smoke tests that depended on them repointed at real routes with no assertion weakened
- Human verification of the phase's three genuinely manual checks: rendered-text fidelity PASS, mobile/desktop legibility PASS, live post-deploy 404 recorded honestly as PENDING (not yet deployed)
- Developer's qualitative observation on visual bareness captured as a forward-looking deferred-items entry, not treated as a defect

## Task Commits

Each task was committed atomically:

1. **Orchestrator note: remove Plan 02-03 diagnostic routes, repoint smoke tests** - `85802b6` (chore)
2. **Task 1: Whole-site SITE-04 sweep -- canonical, sitemap, dead links, zero JS** - `827526f` (test)
3. **Task 2: Loud-fail and draft-filter trap-and-restore fixtures** - `2743e1b` (fix)
4. **Task 3: Amend stale requirement wording and close phase artifacts** - `dc85e7a` (docs)
5. **Task 4: Human verification recorded + deferred-items capture** - this commit (docs)

**Plan metadata:** this commit (docs: complete plan)

## Files Created/Modified
- `tests/site.smoke.sh` - whole-site canonical/sitemap/dead-link/zero-JS sweep plus the three D-39/D-30/deep-dive negative fixtures
- `astro.config.mjs` - config-load-time re-validation of technical/ and roadmap/ files through the same mdastPlugins pipeline (Rule 1 auto-fix, see Deviations)
- `tests/collections.smoke.sh` - collection counts reasserted against real built routes instead of the deleted JSON endpoint
- `tests/markdown.smoke.sh` - wikilink/Shiki checks reasserted against the real `m0.3/phase-14.5-swapchain-acquire-fix` deep-dive page
- `.planning/REQUIREMENTS.md` - CONT-02/CONT-04/CONT-07/CONT-08 wording matches the delivered four-tree scope
- `.planning/ROADMAP.md` - Phase 2 goal, success criteria, and plan list/progress table match the real eight-plan scope
- `.planning/phases/02-content-rendering-templating/02-UI-SPEC.md` - D-16 homepage sentence recorded, sign-off block closed, meta-line placement decision recorded
- `.planning/phases/02-content-rendering-templating/02-VALIDATION.md` - `nyquist_compliant: true`, Wave 0 closed, Manual-Only table reduced to the three real manual checks
- `.planning/phases/02-content-rendering-templating/02-CONTEXT.md` - deferred-items entry appended for the "looks bare" observation
- `src/pages/collection-counts.json.ts` (removed) - Plan 02-03 diagnostic route, superseded by real collection routes
- `src/pages/markdown-render-check.astro` (removed) - Plan 02-03 diagnostic route, superseded by real deep-dive pages

## Decisions Made
- Live 404 recorded as PENDING rather than PASS -- it is genuinely unverifiable until these commits reach `main` and a GitHub Actions deploy completes; closing the phase with this one item outstanding is explicitly sanctioned by 02-VALIDATION.md's own Manual-Only table design (Phase 4 owns deploy hardening and the follow-up check)
- The developer's "looks pretty bare... not in scope for this phase but looks good" observation is captured in 02-CONTEXT.md's `<deferred>` section as a candidate topic for a future visual-polish milestone (bundling naturally with the already-deferred SITE-05 dark mode and the KaTeX half of CONT-07), explicitly noted as an observation and not an accepted requirement -- no fix task opened

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Config-load-time re-validation to make D-39/D-40 loud-fail actually loud in the real build**
- **Found during:** Task 2 (trap-and-restore fixtures against the real `astro build`, not the isolated `tests/lib.smoke.mjs` helper calls)
- **Issue:** Astro's own glob content loader (`astro@7.0.9`'s `content/loaders/glob.js`) catches every per-entry `render()` error, logs it as `[ERROR] [glob-loader] ...`, and stores the entry with empty rendered content -- it never rethrows. That meant `astro build` exited 0 and silently shipped an empty page even when a wikilink (D-39) or deep-dive placeholder (D-40) was genuinely unresolvable, defeating the "loud failure, never silent passthrough" guarantee at the one layer that actually matters end-to-end.
- **Fix:** `astro.config.mjs` now re-runs every `technical/` and `roadmap/` file through the exact same `mdastPlugins` pipeline at config-load time, before Astro's own build/dev server starts. A thrown error there crashes the process with a non-zero exit code the same way a config-load failure always does, instead of being swallowed by the glob loader's try/catch.
- **Files modified:** `astro.config.mjs`
- **Verification:** `tests/site.smoke.sh`'s D-39 and deep-dive-resolution fixture cases confirm non-zero exit naming the offending file and link/target
- **Committed in:** `2743e1b` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug in loud-fail enforcement layer)
**Impact on plan:** Necessary correctness fix -- without it, D-39's core guarantee (no silent passthrough) was not actually true against the real build pipeline, only against an isolated helper. No scope creep; the fix lives entirely inside the loud-fail mechanism the plan's Task 2 was already scoped to prove.

## Issues Encountered
None beyond the Rule 1 fix documented above.

## User Setup Required
None - no external service configuration required.

## Human Verification Results (Task 4)

Performed by the developer 2026-07-22:

1. **Rendered text fidelity (CONT-02, D-14) -- PASS.** Reviewed the announcement archive and a technical deep-dive against their source `.md` files. No issues reported.
2. **Mobile and desktop legibility (SITE-04) -- PASS.** Reviewed at 375px and 1440px. No issues reported.
3. **Live 404 under the GitHub Pages base path (SITE-04) -- PENDING DEPLOY, not verified.** Cannot be checked until these commits are on `main` and a GitHub Actions deploy completes. Recorded honestly as pending, not passed. 02-RESEARCH.md Pitfall 6 flagged this at MEDIUM confidence precisely because it is only empirically resolvable post-deploy; Phase 4 owns deploy hardening and the follow-up check.

**Developer's qualitative sign-off note (verbatim):** "looks pretty bare, not in scope for this phase but looks good" -- an observation, not a defect. The bareness is D-21 (system fonts), D-22 (light-only, one accent), and D-23 (hand-written minimal CSS) working as designed against this phase's "quiet reading surface -- add nothing between reader and text" philosophy. The developer explicitly scoped any change out of this phase. Captured as a forward-looking deferred-items entry in `02-CONTEXT.md`, cross-referenced against the already-deferred SITE-05 (dark mode) and the KaTeX half of CONT-07 since a future visual-polish milestone would naturally bundle all three.

## Next Phase Readiness
- Phase 2's four content trees (devlog, technical, roadmap, pages) are fully built, cross-linked, and verified against the whole site -- Phase 3 (RSS/OpenGraph/Discord CTA/analytics) can build directly on this closed content set
- One item carries forward explicitly: the live 404 check under the Pages base path, owned by Phase 4's deploy hardening
- Phase 4 should also pick up the deferred-items entry on visual richness beyond the locked minimal aesthetic when scoping any future visual-polish milestone (bundles with SITE-05 and CONT-07's KaTeX half)

---
*Phase: 02-content-rendering-templating*
*Completed: 2026-07-22*

## Self-Check: PASSED

- FOUND: `.planning/phases/02-content-rendering-templating/02-08-SUMMARY.md`
- FOUND commit: `85802b6` (orchestrator-note diagnostic-route removal)
- FOUND commit: `827526f` (Task 1)
- FOUND commit: `2743e1b` (Task 2)
- FOUND commit: `dc85e7a` (Task 3)
- FOUND commit: `fe6a041` (Task 4 / plan close-out)

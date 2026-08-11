---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 03
current_phase_name: RSS, OpenGraph & Discord Distribution
status: executing
stopped_at: Phase 03 complete — all 6 plans executed, deferred verification for phase 3 resolved
last_updated: "2026-08-11T14:33:50.573Z"
last_activity: 2026-08-11
last_activity_desc: Phase 03 execution started
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 21
  completed_plans: 21
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-13)

**Core value:** Every devblog post has a permanent, linkable home before the audience ramp starts — if everything else slips, the archive + launch post must be live at M1.1 close.
**Current focus:** Phase 03 — RSS, OpenGraph & Discord Distribution

## Current Position

Phase: 03 (RSS, OpenGraph & Discord Distribution) — ALL 6 PLANS COMPLETE
Plan: 6 of 6 (complete)
Status: Phase 03 plans complete — awaiting optional full-phase verification (/gsd-verify-work 3)
Last activity: 2026-08-11 — Plan 03-06 completed (studio-vault write-back verified, live deploy confirmed, human sign-off approved)

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 7
- Average duration: — min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 2 | - | - |
| 4 | 5 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01 P01 | 5min | 3 tasks | 8 files |
| Phase 01 P02 | 6min | 2 tasks | 1 files |
| Phase 02 P01 | 20min | 3 tasks | 80 files |
| Phase 02 P02 | 15min | 2 tasks | 5 files |
| Phase 02 P03 | 30min | 3 tasks | 13 files |
| Phase 02 P04 | 20min | 2 tasks | 5 files |
| Phase 02 P05 | 15min | 2 tasks | 2 files |
| Phase 02 P06 | 35min | 2 tasks | 6 files |
| Phase 02 P07 | 45min | 2 tasks | 6 files |
| Phase 02 P08 | 25min | 4 tasks | 10 files |
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 3 P01 | 12min | 4 tasks | 13 files |
| Phase 3 P05 | 35 min | 3 tasks | 1 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Stack: Astro static site on GitHub Pages via GitHub Actions (`withastro/action` + `actions/deploy-pages`); tooling confirmed in-phase per D-H.
- Structure: `devlog/` is an untouchable promote-pipeline drop target; standalone pages live in a sibling `pages/` collection, structurally excluded from archive/RSS.
- Scope: v1 adds Discord CTA + RSS + OpenGraph + cookieless analytics beyond the four D-H content pieces; OG metadata promoted to P1 (Discord-first distribution).
- [Phase 01-01]: glob() loader base path corrected to './devlog' (project-root-relative, not content.config.ts-relative) per installed astro@7.0.9 .d.ts — RESEARCH.md Pattern 1's '../devlog' pointed one directory above the repo root and silently produced an empty collection
- [Phase 01-01]: Used Astro's set:html directive for devlog post titles instead of default {expr} escaping — Default interpolation HTML-encodes apostrophes, breaking the literal manifesto-title acceptance check; titles are git-trusted content, not runtime user input
- [Phase 01-01]: Task 3 tdd RED/GREEN satisfied via committed tests/build.smoke.sh instead of a JS test framework — RESEARCH.md's Validation Architecture explicitly scoped out a JS test framework for this build-pipeline phase; npm run build is the harness
- [Phase 01]: [Phase 01-02] 01-RESEARCH.md's deploy workflow code example was used verbatim per 01-PATTERNS.md's no-local-deviation assignment
- [Phase 02-01]: grep -c counts matching lines not occurrences; used grep -o | wc -l in tests/build.smoke.sh to correctly assert the nine-announcement archive count against Astro's minified single-line build output
- [Phase 02-01]: pages/how-its-made.md status line rewritten to bare 'status: published' (staging comment dropped) to satisfy exact-line-match publication criterion
- [Phase ?]: [Phase 02-02]: Normalized import.meta.env.BASE_URL to always carry a trailing slash before appending route segments in BaseLayout.astro/404.astro -- astro.config.mjs's base has no trailing slash, so naive concatenation produced malformed nav/favicon URLs
- [Phase ?]: [Phase 02-02]: tests/shell.smoke.sh checks dist/404.html's own chrome directly rather than diffing against dist/index.html, since index.astro has not adopted BaseLayout yet (out of this plan's scope)
- [Phase 02-03]: package.json "type" flipped commonjs->module so plain .ts helpers under src/lib/ resolve as ESM under Node 24's native type-stripping
- [Phase 02-03]: milestoneSortKey compares major/minor as separate parsed integers, not parseFloat on the whole string -- parseFloat('0.10') collapses to 0.1, sorting before parseFloat('0.9')=0.9
- [Phase 02-03]: Wikilink resolver's known-ids set built by walking technical/ directly with node:fs, mirroring content.config.ts's generateId logic, independent of Astro's internal collection state
- [Phase 02-03]: No real page template renders technical/roadmap/pages bodies yet -- collection-counts.json.ts and markdown-render-check.astro are small build-time-only routes proving collection counts and the wikilink/Shiki pipeline until Plans 04-07 land real routes
- [Phase 02-04]: Meta-line renders above the slot (above the body's own H1), not below it, since D-14 forbids splitting the rendered body
- [Phase 02-04]: Prev/next link text is the neighbouring post's actual title (arrow plus title), matching UI-SPEC's worked example, not a literal 'Previous' string
- [Phase 02-04]: Astro only hoists the exported getStaticPaths() function to true module scope -- helper functions it calls must live in an imported src/lib module, not as sibling frontmatter declarations, or the build fails at prerender time
- [Phase 02-05]: D-16 homepage one-liner approved verbatim by developer 2026-07-22: 'A space engine built from scratch on real n-body physics.' (replaces all three plan candidates)
- [Phase 02-06]: how-to-read routed via a dedicated static file (src/pages/technical/how-to-read.astro) rather than special-casing the dynamic [milestone]/[slug] route -- its collection id has no slash
- [Phase 02-06]: Milestone display name and era read from each roadmap entry's H1 (Roadmap Detail prefix stripped) and Era line, not a hand-written map -- future era/milestone renames move in the vault, not the template
- [Phase 02-06]: Era grouping is data-driven even though all 8 roadmap entries currently share one era value -- observed mismatch with plan's read_first expectation, no code change needed since implementation already reads the line dynamically
- [Phase ?]: [Phase 02-07]: Extended the placeholder marker regex to cover a plain unbolded 'Deep dive: [Phase N ]post(ed) in #technical-devlog[.]' wording variant scattered across M0.5-M0.8, not shown in the plan's sampled M0.3 file
- [Phase ?]: [Phase 02-07]: M0.5-M0.8's generic intro-blockquote mention of #technical-devlog (not tied to any phase) is stripped rather than linked, since there's no single phase to point it at
- [Phase ?]: [Phase 02-07]: resolvePhase's phase-to-id map lives directly in astro.config.mjs (cached per milestone), not a new src/lib file, mirroring the existing wikilink-resolver's shape
- [Phase ?]: Live 404 under GitHub Pages base path recorded as PENDING (deploy-dependent), not PASS -- Phase 4 owns the follow-up check
- [Phase ?]: Developer's post-build 'looks bare' observation captured as a deferred-items entry in 02-CONTEXT.md, not a defect -- D-21/D-22/D-23 working as designed, explicitly scoped out of this phase
- [Phase ?]: Package legitimacy: @astrojs/rss + sanitize-html SUS/too-new verdict accepted as a recency-keyed false positive on live registry evidence (D-03-01)
- [Phase ?]: D-55 Discord invite published into shipped markup — one-way, confirmed; 03-06 must match byte-for-byte
- [Phase ?]: truncate() implements the strict D-52 reading with no minimum-length floor
- [Phase ?]: absolutize()'s a/href branch stays fixture-free; a live negative assertion in tests/distribution.smoke.sh gates it instead
- [Phase ?]: The D-48 fixture runs two legs because Astro's own ImageNotFound guard fires upstream of heroFor()

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- Studio repo carries unpushed commits from Phase 4 (aee1905, 10fe002, 54f30e9 — transcription refresh + two Rule-3 content fixes: quoted discord_post_id, upscaled M1.1 hero). Review + push studio-side when convenient.
- (Resolved 2026-08-09: timeline blocker — site launched inside the M1.1 window; Phase 1 loader and Phase 3 OG-strategy planning concerns closed in their phases.)

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Content | SITE-05 dark mode (pair with syntax themes) | v2 | 2026-07-13 |
| Content | CONT-07 syntax highlighting + KaTeX (verify Astro support in v1) | v2 | 2026-07-13 |
| Distribution | DIST-04 custom domain attachment (SITE-02 keeps it a non-event) | v2 | 2026-07-13 |
| Content | CONT-08 search / tag taxonomy (no payoff at ~9 posts) | v2 | 2026-07-13 |

## Deferred Verification

| Phase | State | Resume |
|-------|-------|--------|
| 4 (ANLT-01 only) | verification_deferred_human | Sign up at goatcounter.com → set GOATCOUNTER_CODE in src/lib/site.mjs → push → confirm dashboard records pageviews (incl. 404s per D-62) |

**Phase 4 note (2026-08-09):** phase verification PASSED (30/31; user approved). The single
deferred item is ANLT-01's live "pageviews recorded" criterion — deferred by design (D-61,
goatcounter.com unreachable during discuss). Everything else is live-verified: deploy run
31280806927 green through the new smoke job, launch post live, redirect stub live.

**Phase 3 resolved (2026-08-11).** All 6 plans executed; the two deploy-dependent checks that had
no build-time proxy are now closed. 03-06 Task 2 polled the Pages deploy to a `success` conclusion
(run `31501670084`) and re-probed the live site directly: deployed feed item count matched the
local build (10=10), the M0.7 announcement served exactly one absolute `og:image`
(`m0.7-hero-contrast`) and one non-empty `og:description`, and `/og-default.png` returned a real
1200×630 PNG. 03-06 Task 3's human checkpoint was approved, covering all six backstop checks: four
Discord embed pastes (hero post, technical deep-dive, roadmap page, longest-title truncation), W3C
feed validation with zero errors, and the default card's typography compared against the live
header. See `03-06-SUMMARY.md` for full detail. `/gsd-verify-work 3` remains available as an
optional confirmatory full-phase UAT pass but is no longer blocking on this phase.

**Why originally deferred (2026-07-22):** GitHub Actions entered `degraded_performance` and Pages
deploy run `29959774598` sat queued for 15+ minutes (this repo's deploys normally finish in ~40s).
Phase 3's three remaining checks were deploy-dependent and deliberately designed to have no
build-time proxy, so they could not be certified against the stale Phase 1 build being served at
the time.

**All code work is complete and pushed** — `main` is at `9f68a22` as of this session (previously
`79f1374`, 88 commits pushed `36b6558..79f1374`), `npm test` ends `ALL CHECKS PASSED`, clean build
produces 86 pages.

**03-06 is now fully complete.** Task 1 (D-56 studio-vault write-back) was completed and committed
in the studio repo as `92d9015` in a prior session (verified, not repeated, this session). Task 2
(live deploy freshness probe) and Task 3 (human verification checkpoint, approved) were both
completed this session — see `03-06-SUMMARY.md` for the deploy run id, all probe results, and the
exact scope of the human approval.

## Session Continuity

Last session: 2026-08-11T14:33:50.573Z
Stopped at: Phase 03 complete — all 6 plans executed, deferred verification for phase 3 resolved
Resume file: 

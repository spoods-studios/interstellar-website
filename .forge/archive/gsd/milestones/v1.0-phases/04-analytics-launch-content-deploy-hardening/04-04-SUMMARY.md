---
phase: 04-analytics-launch-content-deploy-hardening
plan: 04
subsystem: content
tags: [redirects, slug-immutability, cont-06, d-65, d-66, tdd, astro]
requires:
  - 04-02 (launch post 2026-07-30-first-burn.md promoted — the demo entry's destination)
  - 04-03 (tests/hardening.smoke.sh analytics sections in their final per-page form)
provides:
  - SLUG_REDIRECTS const in astro.config.mjs, wired to defineConfig's redirects key
  - one demonstration redirect stub at dist/devlog/2026-07-30-demo-old-slug/index.html
  - is_redirect_stub predicate in site/distribution/hardening/collections/post harnesses
  - stub-contract section in tests/hardening.smoke.sh (base-prefix + target-resolution pins)
  - slug-immutability norm documented in CLAUDE.md and vault/conventions.md (D-66)
affects:
  - 04-05 (CI smoke job probes the demo stub URL live — the key is now real)
  - studio promote flow (both doc targets now state the rename rule)
tech-stack:
  added: []
  patterns:
    - stub-exemption as page-selection predicate (skip meta-refresh files), never invariant loosening
    - harness derives redirect key + destination suffix from astro.config.mjs via sed/grep, recomposes with its own NORMALIZED_BASE
    - redirect destinations composed from NORMALIZED_BASE, never literals (Pitfall 1)
key-files:
  created: []
  modified:
    - astro.config.mjs
    - tests/hardening.smoke.sh
    - tests/site.smoke.sh
    - tests/distribution.smoke.sh
    - tests/collections.smoke.sh
    - tests/post.smoke.sh
    - CLAUDE.md
    - vault/conventions.md
decisions:
  - "A6 settled empirically: @astrojs/sitemap does NOT list redirect routes — dist/sitemap-0.xml carries 98 URLs (the 98 reader-facing non-404 pages) and zero occurrences of the stub slug, so no sitemap filter was added and the integration is untouched."
  - "Reader-facing page counts (site.smoke.sh page-count sanity, sitemap equality, collections/post devlog counts) subtract stubs by the same predicate rather than bumping expected totals — the enumerations count reader-facing pages, and the equality/exact-count form is preserved."
metrics:
  duration: ~10 minutes
  completed: 2026-08-08
  tasks: 3
  commits: 3
status: complete
---

# Phase 4 Plan 04: Slug Redirect Stubs + Immutability Norm Summary

Renamed post URLs are now a recoverable event: Astro's redirects config emits a noindexed, canonical-carrying meta-refresh stub per SLUG_REDIRECTS entry, the hardening harness pins the base-prefix landmine (verbatim string destinations) and resolves the emitted target to a real build artifact, and the slug-immutability norm is written into both CLAUDE.md and vault/conventions.md naming the map as the mechanism and Discord embeds / RSS guids / vault references as the reason.

## Tasks Completed

| Task | Name | Commits | Files |
|------|------|---------|-------|
| 1 | RED — stub contract + stub-exemption predicates | add0166 | tests/{site,distribution,hardening}.smoke.sh |
| 2 | GREEN — SLUG_REDIRECTS with demonstration entry | 569cdc0 | astro.config.mjs, tests/{collections,post}.smoke.sh |
| 3 | Document the slug-immutability norm | 8c9fdf1 | CLAUDE.md, vault/conventions.md |

## What Was Built

- **`SLUG_REDIRECTS`** (`astro.config.mjs:24-26`): one demonstration entry `'/devlog/2026-07-30-demo-old-slug'` → `` `${NORMALIZED_BASE}devlog/2026-07-30-first-burn/` ``. WHY-comment states the three load-bearing facts: keys are base-free (Astro applies the base to the match side), destinations must be base-composed (Astro emits string destinations verbatim into the stub's refresh URL), and the entry exists to keep the mechanism exercised by the harness.
- **Stub contract** (`tests/hardening.smoke.sh`, CONT-06 section): derives the map's key and destination suffix from `astro.config.mjs` (no base or slug literal in the harness), then asserts the stub file exists at the key's directory form, carries refresh + noindex + canonical, its refresh target starts with `NORMALIZED_BASE` (the Pitfall 1 pin), matches the config's composed destination, and resolves to an existing file under `dist/` (the typo pin — Astro never validates concrete-path destinations).
- **`is_redirect_stub` predicate**: any HTML file carrying `http-equiv="refresh"` is skipped, printing nothing, in every reader-facing per-page sweep — canonical, favicon, sitemap equality, and page-count (site), OG metadata and CTA/autodiscovery (distribution), stamp coverage ×3 and analytics gating ×2 (hardening), devlog collection count (collections), announcement count (post). No invariant was weakened; equalities stayed equalities.
- **Norm documentation**: CLAUDE.md gains one dense paragraph directly after the content drop-target rule; vault/conventions.md graduates from D-10 stub to its first real convention under a `## Slug immutability (D-66)` heading with the activation blockquote retained. Both name `SLUG_REDIRECTS`/`astro.config.mjs`, the same-commit rule, all three pinning consumers, and the 404-analytics trace.

## Verification

- `npm run build` exits 0; exactly one stub directory under `dist/` (`grep -rl 'http-equiv="refresh"' dist` → one file).
- TDD gates: RED confirmed (site + distribution green stub-free; hardening failed only in the new CONT-06 section), then GREEN (`npm test` exit 0, all 11 harnesses).
- `npm test` green again after Task 3's documentation edits.
- `git diff --stat package.json package-lock.json` empty — zero new dependencies (T-04-SC).
- Stub markup verified against build output: `<meta http-equiv="refresh" content="0;url=/interstellar-website/devlog/2026-07-30-first-burn/">`, `<meta name="robots" content="noindex">`, absolute canonical to the launch post.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Stub inflated devlog counts in two harnesses outside the plan's file list**
- **Found during:** Task 2 — `npm test` failed in `tests/collections.smoke.sh` (devlog:11, expected 10) and then `tests/post.smoke.sh:12` (same count form).
- **Issue:** The stub lands under `dist/devlog/`, so both harnesses' `find dist/devlog -name index.html | wc -l` counts included it. Planning identified six sweeps across three files; these two count assertions in two further files have the same exposure.
- **Fix:** Applied the same stub-exemption predicate (skip files carrying the refresh directive) to both counts, preserving the exact-count invariants (10 announcements / devlog:10). Consistent with Task 1's general instruction to exempt stubs from every reader-facing sweep.
- **Files modified:** `tests/collections.smoke.sh`, `tests/post.smoke.sh`
- **Commit:** 569cdc0 (folded into Task 2's GREEN commit — the fix is what makes GREEN green)

## Flagged-Assumption Outcomes

- **A6 (04-RESEARCH):** settled — the sitemap does **not** list redirect routes. `dist/sitemap-0.xml` carries 98 `<loc>` entries matching the 98 reader-facing non-404 pages, zero mentions of the stub slug. Sitemap integration left untouched; the sitemap-versus-pages equality in `tests/site.smoke.sh` passes with stubs subtracted from the page side.
- **Backstop truth (empty-map behaviour):** unexercised by design — the map ships seeded. Not confirmed with evidence this plan; the verifier must abstain and route to human review rather than pass it silently.

## Threat Register Outcomes

- **T-04-15 (typo'd destination → silent 404 stub):** mitigated — stub-contract section asserts base prefix and target-file resolution.
- **T-04-16 (stubs advertised to search engines):** mitigated — Astro's template emits noindex natively (asserted), and the sitemap omits the stub URL without needing a filter (A6).
- **T-04-SC (supply chain):** confirmed — `package.json`/`package-lock.json` byte-identical; redirects are core Astro 7.0.9.

## TDD Gate Compliance

RED commit `add0166` (`test(04-04): …`) precedes GREEN commit `569cdc0` (`feat(04-04): …`); no refactor commit needed. RED failed for exactly the planned reason (missing map/stub) and nowhere else.

## Known Stubs

The demonstration redirect stub (`dist/devlog/2026-07-30-demo-old-slug/`) is an intentional build artifact required by the plan — it keeps the mechanism exercised by the harness and gives Plan 04-05's live probe a real URL. It is not an implementation stub.

## Self-Check: PASSED

- astro.config.mjs SLUG_REDIRECTS: FOUND (2 occurrences)
- CLAUDE.md / vault/conventions.md norm sections: FOUND
- Commits add0166, 569cdc0, 8c9fdf1: FOUND in git log
- npm test: exit 0 (11/11 harnesses)

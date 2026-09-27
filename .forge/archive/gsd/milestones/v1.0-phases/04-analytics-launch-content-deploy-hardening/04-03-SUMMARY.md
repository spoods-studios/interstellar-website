---
phase: 04-analytics-launch-content-deploy-hardening
plan: 03
subsystem: analytics
tags: [analytics, goatcounter, privacy, tdd, anlt-01, d-60, d-61, d-62]
requires:
  - 04-01 (tests/hardening.smoke.sh harness + BaseLayout head block)
  - 04-02 (M1.1 corpus counts already settled in the suites)
provides:
  - GOATCOUNTER_CODE / GOATCOUNTER_PLACEHOLDER / assertGoatcounterConfigured in src/lib/site.mjs
  - config-load invocation of the analytics guard in astro.config.mjs
  - gated is:inline GoatCounter script in BaseLayout head (every page incl. 404)
  - state-free no-extra-JS assertions across all nine former zero-script sites
affects:
  - post-phase signup push (set GOATCOUNTER_CODE, push, confirm dashboard)
  - 04-05 (CI smoke job builds with the constant unset — warning, exit 0)
tech-stack:
  added: []
  patterns:
    - warn-if-unset / throw-if-malformed config guard (deliberate D-61 asymmetry with the D-54 invite guard)
    - state-free test assertion: script-tag count must equal analytics-tag count per page
    - fixture cleanliness as pre/post git-status snapshot equality, not emptiness
key-files:
  created: []
  modified:
    - src/lib/site.mjs
    - astro.config.mjs
    - src/layouts/BaseLayout.astro
    - tests/hardening.smoke.sh
    - tests/distribution.smoke.sh
    - tests/post.smoke.sh
    - tests/roadmap.smoke.sh
    - tests/markdown.smoke.sh
    - tests/build.smoke.sh
    - tests/technical.smoke.sh
    - tests/site.smoke.sh
decisions:
  - "ANLT-01 left unmarked in REQUIREMENTS.md: the requirement's letter (pageviews recorded) is deferred human verification per D-61 — the account does not exist yet. The phase verifier must record it as deferred, not passed."
  - "markdown.smoke.sh's zero-script assertion was converted, not left alone: its $RENDERED subject is the whole built document (BaseLayout head included), not body-scoped content, so it was a duplicate of the page-level guarantee and would have broken on the signup push."
  - "Fixture cleanliness checks (hardening D-61/ANLT-01 sections, distribution D-54 + final rebuild) compare against a pre-fixture git-status snapshot instead of demanding emptiness — a set-but-uncommitted GOATCOUNTER_CODE is legitimate dirt, and the old form made npm test unrunnable in exactly the post-signup state Task 3 exists to keep green."
metrics:
  duration: ~22 minutes
  completed: 2026-08-08
  tasks: 3
  commits: 4
status: complete
---

# Phase 4 Plan 03: Gated Cookieless Analytics (GoatCounter) Summary

GoatCounter pageview analytics gated behind a validated site-code constant that ships unset — unset warns and deploys, placeholder/malformed hard-fails the build naming the constant — with the single is:inline script rendered from the shared layout on every page including the 404, and the site's nine zero-JS assertions retightened to the state-free form "every script tag is the sanctioned analytics tag" so the suite survives the post-signup push untouched.

## Tasks Completed

| Task | Name | Commits | Files |
|------|------|---------|-------|
| 1 | Gated site-code constant + build-time guard (TDD) | 3db2ec8 (RED), 098ff3a (GREEN) | src/lib/site.mjs, astro.config.mjs, tests/hardening.smoke.sh |
| 2 | Emit the gated analytics script on every page | a805adb | src/layouts/BaseLayout.astro, tests/hardening.smoke.sh |
| 3 | Retighten the zero-JS guarantee for the signup push | 1a3dafb | tests/{post,roadmap,markdown,build,technical,site,distribution,hardening}.smoke.sh |

## What Was Proven

- **D-61 guard by fixture (5 legs)**: unset and whitespace-only both warn naming `GOATCOUNTER_CODE` and the build exits 0; the `REPLACE_ME` placeholder, an out-of-charset value (`Bad/Code`), and a space-carrying value all fail the build naming the constant; a well-formed code builds silently. Trap-and-restore idiom; placeholder derived from the module via grep, never repeated as a literal.
- **D-62 emission**: with a code set, all 99 built pages — `dist/404.html` included — carry exactly one `gc.zgo.at` occurrence; the built tag is `<script data-goatcounter="https://<code>.goatcounter.com/count" async src="//gc.zgo.at/count.js"></script>` (endpoint carries the code, async present, empty body / external src only). With the code unset, zero pages carry any analytics reference. Asserted permanently by the harness's state-derived walk plus a set-state fixture.
- **A3 settled empirically**: `is:inline` makes Astro emit the external script verbatim with the `data-goatcounter` attribute intact — the directive is required and sufficient.
- **State-free zero-JS guarantee**: `npm test` exits 0 with the constant unset AND with it temporarily set to a well-formed value (rebuilt in between); injecting a stray second script into BaseLayout makes `npm test` exit non-zero in both constant states. No dev-mode gate (`import.meta.env.DEV` count 0), no hand-rolled bot detection (`navigator.webdriver|userAgent` count 0).
- **Zero dependency change**: `git diff --stat package.json package-lock.json` empty across all four commits (threat T-04-SC satisfied — the counter is a remote script tag, not a package).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixture cleanliness checks demanded an empty tree instead of a restored one**
- **Found during:** Task 3 (set-state leg: `npm test` with the constant temporarily set)
- **Issue:** `git status --porcelain ... src/`-must-be-empty checks in `tests/distribution.smoke.sh` (D-54 fixture + final rebuild) and the two new hardening sections turned the suite red whenever `src/lib/site.mjs` carried any uncommitted change — including a legitimately set-but-not-yet-committed `GOATCOUNTER_CODE`, the exact post-signup state Task 3's core criterion requires to stay green
- **Fix:** checks now capture a pre-fixture snapshot of the watched paths and assert post-fixture equality — fixtures must leave the tree exactly as found, clean or not; on a clean checkout this degenerates to the old behavior
- **Files modified:** tests/distribution.smoke.sh, tests/hardening.smoke.sh
- **Commit:** 1a3dafb

**2. [Rule 1 - Bug] post.smoke.sh D-28 image check grabbed the page's first bare `src=` attribute**
- **Found during:** Task 3 (set-state leg — suite failed in post.smoke.sh's D-28 section)
- **Issue:** with the analytics script configured, the first `src="..."` on a devlog page is the head script's `//gc.zgo.at/count.js`, so the "embedded body image resolves to a real built asset" check tried `test -f dist//gc.zgo.at/count.js`
- **Fix:** src extraction scoped to `<img ...>` tags, preserving the check's actual intent
- **Files modified:** tests/post.smoke.sh
- **Commit:** 1a3dafb

### Deliberate

**3. ANLT-01 not marked complete in REQUIREMENTS.md** — live certification ("pageviews are recorded") is deferred human verification by D-61: the account does not exist yet. Recorded in the windows ledger as an open `unmet-truth` entry. Post-phase sequence: sign up → set `GOATCOUNTER_CODE` in `src/lib/site.mjs` → push (deploys) → confirm pageviews in the dashboard.

**4. markdown.smoke.sh converted, with reason recorded** — the plan asked to first establish what its `$RENDERED` variable points at: it is `dist/technical/m0.3/phase-14.5-swapchain-acquire-fix/index.html`, a whole built document including BaseLayout's head, not body-scoped content. It was therefore a duplicate of the page-level guarantee and was converted like the other eight (not left unchanged, not silently skipped).

No authentication gates occurred.

## Verification Results

- `npm run build` exits 0 with the code unset; combined output contains the `GOATCOUNTER_CODE` warning naming the constant and pointing at `src/lib/site.mjs`
- `bash tests/hardening.smoke.sh` exits 0 on the committed tree; `git status --porcelain src/` empty afterwards
- `npm test` exits 0 in both constant states (all 10 suites, `run-all.sh` glob discovery — no harness edit)
- `grep -rn '<script' tests/*.smoke.sh | grep -c 'eq 0'` outputs 0 — no hardcoded zero-script assertion remains
- Negative controls: removing the script element with the code set drops all 99 pages to zero tags (gating fixture would fail); a stray second script fails `npm test` in both states
- `grep -c 'assertGoatcounterConfigured()' astro.config.mjs` = 1, in the top-level validation section beside `assertInviteConfigured()`, not inside `defineConfig`

## TDD Gate Compliance

- RED: 3db2ec8 `test(04-03)` — D-61 fixture committed failing (harness exit 1: the module lacked the exports)
- GREEN: 098ff3a `feat(04-03)` — constant triple + config-load call turned the fixture green
- No refactor commit needed; Tasks 2/3 verified non-vacuous via the negative controls above

## Known Stubs

`GOATCOUNTER_CODE = ''` in `src/lib/site.mjs` is a deliberate, decision-backed unset state (D-61), not an accidental stub: the build warns loudly about it on every run, the guard validates any future value, and the resolution path (post-phase signup push) is documented here and in the windows ledger. No other placeholder values, skipped tests, or unwired data paths.

## Threat Flags

None new — the surfaces shipped (third-party script tag, pageview transmission, build-config gate) are exactly the plan's threat-model boundaries. All four `mitigate` dispositions implemented: T-04-09 (gate keeps the script out of the build until deliberately configured; SRI non-viability accepted and recorded), T-04-10 (scope locked to one pageview script — no events/dimensions/click tracking, enforced by acceptance greps), T-04-11 (placeholder and out-of-charset codes fail the build at config-load naming the constant), T-04-12 (site-wide script-count == analytics-count assertion fails on any second script in both states), T-04-SC (zero package installs; package.json byte-identical).

## Self-Check: PASSED

- FOUND: GOATCOUNTER_CODE / GOATCOUNTER_PLACEHOLDER / assertGoatcounterConfigured exported from src/lib/site.mjs (node import check exit 0)
- FOUND: assertGoatcounterConfigured() called at astro.config.mjs top level
- FOUND: gated is:inline script block in src/layouts/BaseLayout.astro
- FOUND: commits 3db2ec8, 098ff3a, a805adb, 1a3dafb on worktree-agent-a293fd3428a427d62

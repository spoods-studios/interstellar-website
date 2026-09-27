---
phase: 04-analytics-launch-content-deploy-hardening
plan: 01
subsystem: deploy-hardening
tags: [freshness, smoke-tests, tdd, site-03, d-68]
requires: []
provides:
  - build-sha meta stamp in every built page's head (D-68)
  - tests/live-probe.sh HTTP freshness probe (URL + SHA args, bounded retry)
  - tests/hardening.smoke.sh with stamp coverage and SITE-03 schema loud-fail fixture
affects:
  - 04-05 (CI smoke job calls tests/live-probe.sh and greps the build-sha meta)
tech-stack:
  added: []
  patterns:
    - process.env read in Astro frontmatter for build-time-only values (import.meta.env only exposes PUBLIC_ vars)
    - hand-rolled bounded retry over curl --retry when the failure mode is a valid 200 with stale bytes
key-files:
  created:
    - tests/live-probe.sh
    - tests/hardening.smoke.sh
  modified:
    - src/layouts/BaseLayout.astro
decisions:
  - "SITE-03 left unmarked in REQUIREMENTS.md: this plan closes only the build-side half; Plan 04-05 (also frontmattered SITE-03) wires the live probe into CI and owns the completion mark"
  - "live-probe.sh header prose reworded to avoid the literal string 'curl --retry' so the acceptance grep (zero occurrences) stays meaningful"
metrics:
  duration: ~8 minutes
  completed: 2026-08-08
  tasks: 3
  commits: 4
status: complete
---

# Phase 4 Plan 01: Freshness Contract (SHA Stamp + Live Probe + Hardening Harness) Summary

Build-sha meta stamp (GITHUB_SHA with `local` fallback) on every page including the 404, plus an HTTP probe that only accepts the deployed commit's own SHA in served bytes — never a bare 200 — and a hardening harness proving stamp coverage and the schema loud-fail path empirically.

## Tasks Completed

| Task | Name | Commits | Files |
|------|------|---------|-------|
| 1 | Tracer: stamp one page, serve it, probe it (TDD) | b86e3fc (RED), 26fc414 (GREEN) | src/layouts/BaseLayout.astro, tests/live-probe.sh |
| 2 | Build-time stamp coverage across the whole site | 05c2c30 | tests/hardening.smoke.sh |
| 3 | SITE-03 audit fixture: schema violation fails loudly | 63bb207 | tests/hardening.smoke.sh |

## What Was Proven

- **D-68 stamp**: `<meta name="build-sha" content={buildSha}>` emitted unconditionally from BaseLayout's head; `buildSha` reads `process.env.GITHUB_SHA ?? 'local'` in frontmatter (04-RESEARCH A2 proven locally by exporting the var — the CI leg self-verifies on the first real deploy). Exactly one stamp per built page across all 86, 404 included, counting occurrences not lines (Astro minifies each page to one line).
- **Probe contract**: `tests/live-probe.sh <url-with-trailing-slash> <sha>` — hand-rolled bounded retry (`PROBE_ATTEMPTS`=12 x `PROBE_DELAY`=15s defaults, env-tunable), cache-busting query built from the expected SHA, success only on finding the stamp with that exact SHA in the body. Verified over real HTTP against `astro preview`: exits 0 with the built SHA, exits 1 naming a 40-char SHA that was never built. No hardcoded base (SITE-02), no `curl --retry`.
- **Tracer feedback gate** (auto mode): full tracer verify re-run end-to-end after commit — stamped build served the expected SHA in 1 probe; wrong SHA rejected after budget exhaustion.
- **SITE-03 build-side / A5 → empirical**: a devlog fixture with conformant filename and `status: skeleton` (the studio's `how-this-gets-built.md` landmine value) crashes `astro build` with exit 1 and `[InvalidContentEntryDataError] devlog → 2026-01-01-schema-audit-fixture data does not match collection schema.` naming the file path. Fixture uses the trap-and-restore idiom; `git status --porcelain devlog/` empty afterwards.
- **Audit conclusion recorded** in the harness's SITE-03 section header: all loud classes with owning decision ids (D-10/D-33/D-38 filenames, schema enums, D-39 preflight, empty collections, D-48 heroes, D-54 invite), and the three accepted residual silent classes (unreadable-file skip, duplicate-id overwrite, harness-not-in-CI with the D-08 flaky-deploy rationale).

## Deviations from Plan

**1. [Minor] Probe header comment reworded to keep an acceptance grep meaningful**
- **Found during:** Task 1 acceptance check
- **Issue:** the probe's WHY-comment prose contained the literal `curl --retry`, tripping the criterion `grep -c 'curl --retry' == 0`
- **Fix:** reworded to "curl's built-in retry flag"; no logic change
- **Commit:** 26fc414

**2. [Deliberate] SITE-03 not marked complete in REQUIREMENTS.md**
- Plan frontmatter lists SITE-03, but the requirement's second half ("post-deploy smoke check verifies the live site actually updated") is Plan 04-05's CI smoke job, which also lists SITE-03. Marking now would record a requirement as done while its live half does not exist. 04-05 owns the mark.

No auto-fix rules (1-3) were triggered; no authentication gates.

## Verification Results

- `npm test` exits 0 with `tests/hardening.smoke.sh` auto-discovered by the `tests/*.smoke.sh` glob (no harness edit needed)
- `git diff --stat package.json package-lock.json` empty — zero dependency change (threat T-04-SC satisfied)
- Build with `GITHUB_SHA` exported stamps that value on every page; without it stamps `local`
- Probe distinguishes fresh from stale over real HTTP against `astro preview` on port 4399
- Load-bearing check: deleting the stamp line from BaseLayout made the harness exit 1 naming each offending page; restored via `git checkout -- src/layouts/BaseLayout.astro`

## TDD Gate Compliance

- RED: b86e3fc `test(04-01)` — probe committed failing against the unstamped build
- GREEN: 26fc414 `feat(04-01)` — stamp implementation turned the probe green
- Tasks 2/3 are test-only deliverables (harness sections); each was proven non-vacuous before commit (stamp-removal failure, fixture build-failure with/without)

## Known Stubs

None — no placeholder values, skipped tests, or unwired data paths introduced.

## Threat Flags

None — the probe and stamp are exactly the surfaces enumerated in the plan's threat model; all `mitigate` dispositions implemented (SHA-only success criterion, grep-only response handling, bounded retry budget, zero package installs).

## Self-Check: PASSED

- FOUND: tests/live-probe.sh (executable, 49 lines)
- FOUND: tests/hardening.smoke.sh (executable, 129 lines)
- FOUND: build-sha stamp in src/layouts/BaseLayout.astro
- FOUND: commits b86e3fc, 26fc414, 05c2c30, 63bb207

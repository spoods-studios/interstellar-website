---
phase: 04-analytics-launch-content-deploy-hardening
plan: 05
subsystem: deploy-hardening
tags: [ci, smoke-test, github-pages, live-probe, site-03]
requires: ["04-01", "04-02", "04-04"]
provides:
  - "full live route set in tests/live-probe.sh: freshness, feed, launch post, custom 404 under base, redirect stub"
  - "post-deploy smoke job in .github/workflows/deploy.yml consuming the deploy job's page_url output"
affects: []
tech-stack:
  added: []
  patterns:
    - "post-deploy freshness probe requiring the deploying commit's own build-sha stamp in served bytes"
    - "deploy-action output as the single source of the live URL (SITE-02, custom-domain-proof)"
key-files:
  created: []
  modified:
    - tests/live-probe.sh
    - .github/workflows/deploy.yml
decisions:
  - "Route legs run once each after the freshness loop succeeds — one bounded CDN wait, not five"
  - "Launch-post/feed/stub paths are optional positional args 3–5 with base-free defaults, so a future rename changes one default rather than five call sites"
  - "Route-leg fetches capture the body via command substitution with explicit || fail instead of the freshness loop's curl|grep pipe — avoids a pipefail SIGPIPE misfire from grep -q's early exit, and a failed fetch fails its leg by name rather than silently"
  - "Smoke job declares no permissions block — read-only requests against a public site under the workflow's restricted default"
metrics:
  duration: 12min
  tasks: 2 of 3 (Task 3 checkpoint pending — orchestrator owns the live leg)
  completed: 2026-08-08
status: complete
---

# Phase 4 Plan 05: Post-Deploy Smoke Probe Summary

**One-liner:** Full live route probe (freshness stamp, feed, launch post, custom 404 under base, redirect stub) wired into deploy.yml as a post-deploy smoke job that reads its URL from the deploy action's own output.

## What Was Built

### Task 1 — Probe expanded to the full live route set (`1788ee6`)

`tests/live-probe.sh` now runs four route legs after the existing bounded
freshness loop succeeds:

- **feed leg** — fetches the feed route (default `rss.xml`) and asserts the
  response is an RSS document (`<rss`).
- **launch-post leg** — fetches the launch post (default
  `devlog/2026-07-30-first-burn/`) and asserts it carries the same
  `build-sha` stamp as the homepage, proving it belongs to this deployed
  build rather than surviving from an older one.
- **custom-404 leg** — requests a certainly-dead path under the base,
  capturing status and body separately: status must be 404, body must
  contain `<h1>Page not found.</h1>` (the site's own 404 page, not a
  platform fallback), and body must carry the stamp. Closes the live
  404-under-base check deferred from Phase 2.
- **redirect-stub leg** — fetches the demonstration stub's old URL (default
  `devlog/2026-07-30-demo-old-slug/`) and asserts `http-equiv="refresh"`.

Every fetch appends the same `?probe=<sha>` cache-buster. The three route
paths are optional positional arguments 3–5 after base URL and expected SHA.
No deep-dive or roadmap page was added, per the plan's slug-immutability
liability reasoning.

### Task 2 — Smoke job in the deploy workflow (`14c3078`)

- `deploy` job gains a job-level `outputs.page_url` exposing
  `steps.deployment.outputs.page_url`; its permissions are unchanged.
- New `smoke` job: `needs: deploy`, checks out the repo, runs
  `bash tests/live-probe.sh "$PAGE_URL" "$SHA"` with the deploy output and
  `github.sha` passed via env. No permissions block. Retry knobs left at
  script defaults (12×15s ≈ 3-minute ceiling). Terse decision-id comment
  (`# D-67: …`) mirrors the existing `# D-08` trigger comment style.
- No literal Pages URL anywhere in the workflow (`grep github.io` finds
  nothing) — attaching a custom domain later needs no workflow edit.
- The build job gained no test-suite step, per the plan's audit conclusion.

## Verification Evidence

- Full probe against `npm run preview` on port 4398 exits 0 and names each
  leg passed (freshness after 1 probe, then feed, launch-post, custom-404,
  redirect-stub).
- Negative checks: renaming `dist/devlog/2026-07-30-first-burn/` fails the
  probe on the launch-post leg (exit 1); removing
  `dist/devlog/2026-07-30-demo-old-slug/` fails it on the redirect-stub leg
  (exit 1). Both restored afterwards.
- `! grep -qF 'interstellar-website' tests/live-probe.sh` — passes (no
  hardcoded base).
- `grep -c 'curl --retry' tests/live-probe.sh` — 0 (retry loop stays
  hand-written; a valid-200-stale-content failure is invisible to curl's
  retry).
- No captured value defaults to a comparable fallback — every fetch is
  `VALUE=$(curl …) || fail` or a checked `curl -w '%{http_code}'` capture.
- Workflow greps: `smoke:` job present, `needs.deploy.outputs.page_url`
  consumed, `live-probe.sh` invoked, `github.io` absent. File parses as
  YAML (python3 yaml.safe_load OK).
- `npm test` ends `ALL CHECKS PASSED`.
- `git diff --stat package.json package-lock.json` — empty (T-04-SC: zero
  new dependencies).

## Task 3 — Checkpoint: PENDING (awaiting orchestrator)

Task 3 (`checkpoint:human-verify`, gate=blocking — "First live deploy —
verify or honestly defer") was **not executed** in this worktree. The deploy
fires only after the orchestrator merges to `main` and pushes; the live site
cannot be observed from a pre-merge worktree. Recorded honestly per the
plan's own instruction: a check marked passed without evidence is the exact
silent failure this phase exists to eliminate.

**Owed by the orchestrator/human after merge + push:**

1. Watch the workflow run build → deploy → smoke to green (SITE-03 live
   criterion).
2. Confirm launch post first on the archive homepage with hero image.
3. Confirm launch post first in the deployed feed.
4. Confirm roadmap overview lists M1.1 detail link (M1.1 closed, M1.2
   next); M1.1 detail deep-dive links resolve.
5. Confirm the demo redirect stub's old URL lands on the launch post.
6. If GitHub Actions cannot be observed green (it was degraded when Phase 3
   deferred), record the live legs as deferred in STATE.md per the Phase 3
   precedent — never marked passed.

**Two deferrals expected regardless of workflow health:**

- **ANLT-01 live criterion** ("pageviews recorded") — deferred by design
  (D-61: `GOATCOUNTER_CODE` ships unset until the account exists).
  Post-phase sequence: create account, set the code in `src/lib/site.mjs`,
  push, confirm dashboard.
- **Phase 3's three deferred live checks** (Discord embeds, W3C feed
  validation, deploy freshness) — NOT claimed here; `/gsd-verify-work 3`
  owns their resumption. This plan built the mechanism the third one needs.

## Deviations from Plan

**1. [Minor] `04-PATTERNS.md` referenced but absent** — the plan's context
and Task 2 read_first cite
`.planning/phases/04-analytics-launch-content-deploy-hardening/04-PATTERNS.md`,
which does not exist on disk. The CI style guidance it was cited for
(minimal permissions, dependency style, terse decision-id comments) was
taken from the existing `deploy.yml` jobs and 04-RESEARCH Pattern 4
directly. No code impact.

Otherwise: none — plan executed as written.

## Known Stubs

None.

## Threat Flags

None beyond the plan's own threat model — the new CI job holds no
permissions, the probe only fetches and greps (temporary file via `mktemp`
with EXIT trap for the 404 body), and the retry budget is bounded.

## Self-Check: PASSED

- `tests/live-probe.sh` — FOUND
- `.github/workflows/deploy.yml` smoke job — FOUND
- Commit `1788ee6` — FOUND
- Commit `14c3078` — FOUND

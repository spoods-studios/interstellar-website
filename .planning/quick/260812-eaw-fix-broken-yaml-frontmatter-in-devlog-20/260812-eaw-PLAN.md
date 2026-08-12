---
phase: quick-260812-eaw
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - devlog/2026-08-11-the-line-you-fly.md
autonomous: true
requirements: [QT-YAML-01]

must_haves:
  truths:
    - "npx astro build completes successfully with zero errors (previously failed with a js-yaml 'bad indentation of a mapping entry' error at devlog/2026-08-11-the-line-you-fly.md:8:159)"
    - "The hero_visual frontmatter value is byte-identical to its pre-fix content except for the two added double-quote characters wrapping it — no rewording, no reflow, no punctuation changes"
    - "The GitHub Pages deploy workflow triggered by the push to main completes with conclusion=success (build + deploy + smoke jobs), replacing the three prior failed runs (31517540694, 31517719587, 31523956886)"
  artifacts:
    - path: "devlog/2026-08-11-the-line-you-fly.md"
      provides: "Valid YAML frontmatter — hero_visual scalar quoted so its embedded ': ' sequences no longer parse as a nested mapping"
      contains: "hero_visual: \"assets/m1.2-hero-predicted-vs-flown.png"
  key_links:
    - from: "devlog/2026-08-11-the-line-you-fly.md"
      to: ".github/workflows/deploy.yml (push-to-main trigger)"
      via: "git push origin main"
      pattern: "on:\\s*\\n\\s*push:\\s*\\n\\s*branches: \\[main\\]"
---

<objective>
Fix the broken YAML frontmatter in `devlog/2026-08-11-the-line-you-fly.md` that has been
failing `npx astro build` (and, consequently, the last 3 GitHub Pages deploy runs), then push
the fix to main so the deploy pipeline runs green again and the live site catches up.

Root cause (diagnosed, do not re-diagnose): line 9's `hero_visual:` value is an unquoted YAML
scalar containing an embedded `: ` sequence (`...against libinterstellar: DE441 Sun/Earth/Moon
seed...`), which js-yaml parses as an illegal nested mapping — "bad indentation of a mapping
entry" at 8:159 during Astro's content collection sync. The value contains zero double-quote
characters (verified), so wrapping it in double quotes is a clean, unambiguous fix with no
escaping required.

Purpose: unblock the deploy pipeline — the live site is currently stale, missing "The Line You
Fly" and `roadmap/M1.2.md` (which is also why the technical index shows "Unmapped era" for
M1.2).
Output: one corrected frontmatter line, a green `astro build`, and a green GitHub Pages deploy
run on main.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

@devlog/2026-08-11-the-line-you-fly.md
@.github/workflows/deploy.yml

<interfaces>
<!-- Contracts extracted from the codebase. No exploration required. -->

**devlog/2026-08-11-the-line-you-fly.md** — frontmatter lines 1-10, YAML block delimited by
`---`. Line 9 is the sole broken line:
  `hero_visual: assets/m1.2-hero-predicted-vs-flown.png — predicted trajectory vs flown burn,
  real engine output (PRED-04 family-6 harness against libinterstellar: DE441 Sun/Earth/Moon
  seed, e=0.15 orbit at 400 km periapsis, 669.43 m/s prograde-axis burn over 600 s, 6,300 s
  span; 300 s physics step, 1,024-substep preview tier vs 16,384-substep flight tier — all
  shipped values, no smoothing; max predicted-vs-flown separation 1.67e-2 m ≈ 17 mm; harness →
  CSV → matplotlib)`
  All other frontmatter lines (1-8, 10) are already valid and must not change.

**.github/workflows/deploy.yml** — `on.push.branches: [main]` triggers `build` →
`withastro/action@v6` (which itself runs the equivalent of `npx astro build`) → `deploy` →
`smoke`. `concurrency.group: "pages"` with `cancel-in-progress: false` means pushes queue and
deploy in order — the fix's run will run after the 3 prior failed runs, not replace them.
</interfaces>
</context>

<tasks>

<task type="tracer">
  <name>Task 1: Quote the broken hero_visual scalar and prove the build is green</name>
  <files>devlog/2026-08-11-the-line-you-fly.md</files>
  <action>
    On line 9 of `devlog/2026-08-11-the-line-you-fly.md`, wrap the entire `hero_visual` scalar
    value in double quotes: change `hero_visual: <value>` to `hero_visual: "<value>"`. The
    `<value>` text itself (everything after `hero_visual: ` through the closing `matplotlib)`)
    must remain byte-for-byte identical — same em dashes, same arrows, same punctuation, same
    spacing — only the two double-quote characters are added, one immediately after the space
    following the colon and one at the very end of the line. Do not touch any other line in the
    frontmatter block (lines 1-8, 10) or the post body. Since the value contains zero
    double-quote characters (pre-verified), no internal escaping is needed.

    Run `npx astro build` and confirm it completes with no js-yaml parse error and no other
    error — this is the exact command that was failing (error previously at 8:159) and the same
    command GitHub Actions' `withastro/action@v6` runs in CI.
  </action>
  <verify>
    <automated>cd /home/spoods/Projects/spoods-studios/interstellar-website && npx astro build</automated>
  </verify>
  <done>
    `npx astro build` exits 0 with no YAML/content-collection error, and `git diff --stat --
    devlog/2026-08-11-the-line-you-fly.md` shows exactly one changed line.
  </done>
</task>

<task type="auto">
  <name>Task 2: Commit, push to main, confirm the deploy run goes green</name>
  <files>devlog/2026-08-11-the-line-you-fly.md</files>
  <action>
    Stage only `devlog/2026-08-11-the-line-you-fly.md` and commit with a single-concern
    conventional commit, e.g. `fix(devlog): quote hero_visual to fix broken YAML frontmatter`.
    Push directly to `origin main` (current branch is already `main`; this is a hotfix for a
    live, currently-broken deploy pipeline — pushing to main is the explicit intent of this
    task, not a PR-merge action) to trigger `.github/workflows/deploy.yml`.

    After the push, poll the newly queued run to confirm it completes successfully — GitHub
    Pages deploys are serialized (`concurrency.group: "pages"`, `cancel-in-progress: false`) so
    this run queues behind the 3 prior failed runs and may take a few minutes to start.
  </action>
  <verify>
    <automated>cd /home/spoods/Projects/spoods-studios/interstellar-website && git push origin main && RUN_ID=$(gh run list --workflow=deploy.yml --branch=main --limit=1 --json databaseId --jq '.[0].databaseId') && gh run watch "$RUN_ID" --exit-status</automated>
  </verify>
  <done>
    The commit is pushed to origin/main, and `gh run view "$RUN_ID"` reports
    `conclusion: success` for the build, deploy, and smoke jobs — the live site is caught up
    with "The Line You Fly" and `roadmap/M1.2.md`.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| devlog `.md` frontmatter → Astro content collection parser | Studio-authored frontmatter is parsed by js-yaml at build time; malformed YAML here already took down 3 consecutive production deploys |
| local push → GitHub Actions | `git push origin main` triggers an unattended CI/CD pipeline that publishes directly to the public site |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-eaw-01 | Denial of Service | Astro content collection build | low | mitigate | Fix is a minimal, verified byte-scoped quoting change; Task 1's `astro build` gate must pass locally before Task 2 pushes, so a still-broken build never reaches CI |
| T-eaw-02 | Tampering | devlog frontmatter content | low | accept | Content itself is unchanged (quotes only); the post's factual claims are studio-authored and out of scope for this fix |
| T-eaw-SC | Tampering | npm/pip/cargo installs | n/a | accept | No package installs in this plan — `npx astro build` uses the already-installed project toolchain |
</threat_model>

<verification>
1. `npx astro build` exits 0 (Task 1).
2. `git diff --stat -- devlog/2026-08-11-the-line-you-fly.md` shows exactly one line changed.
3. `gh run view "$RUN_ID"` (the run triggered by the push) shows `conclusion: success` for
   build, deploy, and smoke jobs.
4. Spot-check the live site after deploy: the devlog index lists "The Line You Fly" and the
   technical index no longer shows "Unmapped era" for M1.2.
</verification>

<success_criteria>
- `devlog/2026-08-11-the-line-you-fly.md` has valid YAML frontmatter with the `hero_visual`
  value unchanged apart from quoting.
- `npx astro build` passes locally.
- The push to main produces a GitHub Pages deploy run with `conclusion: success`, ending the
  streak of 3 failed deploys.
</success_criteria>

<output>
Create `.planning/quick/260812-eaw-fix-broken-yaml-frontmatter-in-devlog-20/260812-eaw-SUMMARY.md` when done.
</output>

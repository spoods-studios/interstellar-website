---
phase: 04-analytics-launch-content-deploy-hardening
reviewed: 2026-08-08T18:20:00Z
depth: deep
files_reviewed: 21
files_reviewed_list:
  - assets/m1.1-hero-first-burn.png
  - devlog/2026-07-30-first-burn.md
  - .github/workflows/deploy.yml
  - pages/roadmap.md
  - roadmap/M1.1.md
  - src/layouts/BaseLayout.astro
  - src/lib/site.mjs
  - ../studio/vault/devlog/drafts/m1.1-spacecraft-control.md
  - ../studio/vault/devlog/drafts/roadmap.md
  - ../studio/vault/project/roadmap-detail/M1.1.md
  - tests/build.smoke.sh
  - tests/collections.smoke.sh
  - tests/distribution.smoke.sh
  - tests/hardening.smoke.sh
  - tests/live-probe.sh
  - tests/markdown.smoke.sh
  - tests/post.smoke.sh
  - tests/roadmap.smoke.sh
  - tests/site.smoke.sh
  - tests/technical.smoke.sh
  - vault/conventions.md
findings:
  critical: 0
  warning: 4
  info: 6
  total: 10
status: fixes_applied
fixed: 2026-08-08T18:22:00Z
fix_report: 04-REVIEW-FIX.md
---

# Phase 4: Code Review Report

**Reviewed:** 2026-08-08T18:20:00Z
**Depth:** deep
**Files Reviewed:** 21
**Status:** issues_found

## Summary

Deep review of the Phase 4 surface: the deploy workflow + live probe (SITE-03),
the gated analytics chain (site.mjs → BaseLayout → hardening harness), the M1.1
content promote, and the smoke-test edits. Cross-file tracing was verified
against a real `npm run build` (exit 0, 99 pages), not just by reading:

- **Content fidelity confirmed byte-for-byte** — `devlog/2026-07-30-first-burn.md`,
  `pages/roadmap.md`, and `roadmap/M1.1.md` are identical to their studio-vault
  sources (`diff` clean on all three).
- **Every edited count assertion validated against the build**: 99 reader-facing
  pages (100 HTML − 1 redirect stub), exactly 4 distinct og:image values
  (default + 3 heroes incl. m1.1), exactly 3 absolute hero `.webp` URLs in the
  feed, 10 feed items, 10 devlog reader pages, 65 deep-dives, 9 roadmap
  overview links, m1.1 detail page present.
- **Probe/site contract traced end-to-end**: the live probe's grep targets
  (`<h1>Page not found.</h1>`, `name="build-sha" content=...`, refresh
  directive) all match the built bytes; the stub's refresh target is
  base-prefixed (`/interstellar-website/devlog/2026-07-30-first-burn/`) and
  resolves; the probe's default paths match `SLUG_REDIRECTS` and the launch
  post slug; `github.sha` in the workflow matches the `GITHUB_SHA` the layout
  stamps.
- **Security checked**: GoatCounter code is regex-validated before host-name
  interpolation (no injection); Astro attribute interpolation escapes the OG
  block; the RSS sanitizer allow-list excludes script/style/event handlers;
  workflow inputs reach the probe via quoted env vars (no shell injection);
  build/deploy jobs carry least-privilege permissions.
- **Hero PNG verified**: valid 1200x1125 RGBA PNG, above the 1200x630 embed
  threshold, resolved by the hero glob (its `_astro` PNG is one of the 4
  og:image values).

No Critical findings. Four Warnings (one real deployment race, one probe
robustness gap, one build-log noise defect, one flaky test pattern) and six
Info items.

## Warnings

### WR-01: Pages deploy workflow has no `concurrency` group — concurrent runs can race

**File:** `.github/workflows/deploy.yml:2-5`
**Issue:** D-08 makes every push to main deploy, so two pushes in quick
succession produce two concurrent workflow runs with no serialization. GitHub's
own Pages starter workflows all include a `concurrency` group for exactly this
reason: without it, an older run's `actions/deploy-pages` can complete after a
newer run's, leaving the live site serving the older commit while the newer
run is green. The smoke job compounds the confusion: the superseded run's
probe then correctly fails freshness (its SHA is no longer served), turning a
run whose deploy actually succeeded red, while the run serving stale content
stays green — an inverted signal for the "turns the workflow red unattended"
goal stated at line 32.
**Fix:**
```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: pages
  cancel-in-progress: false
```
(`cancel-in-progress: false` queues runs so every push still deploys, in
order; `true` would skip superseded deploys — either resolves the race.)

### WR-02: live-probe.sh never normalizes/validates the trailing slash it depends on

**File:** `tests/live-probe.sh:41,65,79`
**Issue:** The usage text demands `<base-url-ending-with-slash>` but the script
only checks the argument is non-empty. If `PAGE_URL` ever arrives without the
trailing slash (deploy-pages output format is an external contract, and manual
invocations are documented at line 37), the failure mode is misleading: the
freshness leg still passes — `curl -L` follows the `301` from
`.../interstellar-website?probe=…` — but every route leg concatenates into
garbage (`…interstellar-websiterss.xml`) and fails with errors that point at
the routes, not at the malformed base. A three-minute retry budget was also
spent proving the wrong thing fresh.
**Fix:** normalize once after the argument check:
```bash
BASE_URL="${1%/}/"
```

### WR-03: unset-analytics warning fires once per page — 100 duplicated lines corrupt build output

**File:** `src/lib/site.mjs:64-70` (called from `src/layouts/BaseLayout.astro:40`)
**Issue:** `assertGoatcounterConfigured()` warns on every call, and BaseLayout
calls it in frontmatter, i.e. once per rendered page. Verified against a real
build: the warning appears **100 times** (config-load + 99 pages) and
interleaves mid-line with Astro's page listing
(`├─ /404.htmlGOATCOUNTER_CODE is unset — …`). A warning designed to be seen
(D-61's whole point) becomes noise that can bury any other real warning in the
CI log, and it mangles the build's page listing.
**Fix:** warn once per process:
```js
let warnedUnset = false;
export function assertGoatcounterConfigured() {
  const code = typeof GOATCOUNTER_CODE === 'string' ? GOATCOUNTER_CODE.trim() : '';
  if (code === '') {
    if (!warnedUnset) {
      warnedUnset = true;
      console.warn('GOATCOUNTER_CODE is unset — …');
    }
    return null;
  }
  ...
}
```
(The D-61 fixture in `tests/hardening.smoke.sh:164` greps the whole build log
for one occurrence, so it stays green.)

### WR-04: post-nav negative assertions scoped by a `[^Z]*` content-coincidence window

**File:** `tests/post.smoke.sh:44,50`
**Issue:** `grep -o 'class="post-nav">[^Z]*'` bounds the "post-nav region" at
the first literal `Z` character after the nav (measured 407 bytes on the
current newest post — an arbitrary content coincidence). Two flaky directions:
if future post content places a `Z` immediately after the nav markup, the
negative checks ("oldest has no previous", "newest has no next") pass
vacuously on a near-empty window; if arrow entities ever appear after the nav
but before a `Z`, they false-fail. Today the invariants happen to hold
page-wide (newest: 1×`&larr;`/0×`&rarr;`; oldest: inverse — verified on the
fresh build), so the hack currently does nothing but add fragility.
Pre-existing from Phase 2, but this file was retargeted at the ten-post corpus
this phase (`eec86a8`) and the newest-post leg now runs against new content.
**Fix:** anchor the window on the nav's own closing tag instead of a content
byte, e.g. `grep -o 'class="post-nav">.*</nav>' | head -1` (the pattern the
same repo already uses in `tests/technical.smoke.sh:57` for breadcrumbs), or
extract the element with `sed -E 's/.*(<nav class="post-nav">.*<\/nav>).*/\1/'`.

## Info

### IN-01: stale success message contradicts the assertion it follows

**File:** `tests/distribution.smoke.sh:150`
**Issue:** The check at lines 132-136 requires exactly **4** distinct og:image
values ("default card + 3 hero plots" — updated for the M1.1 hero), but the
success line still prints `card images OK (3 distinct, …)`. Misleading when
scanning a green log.
**Fix:** `echo "card images OK ($DISTINCT_IMAGE_COUNT distinct, default card $DEFAULT_CARD_DIMENSIONS)"`.

### IN-02: probe curls have no transfer timeout; smoke job has no `timeout-minutes`

**File:** `tests/live-probe.sh:65,80,86,97,108`; `.github/workflows/deploy.yml:31-41`
**Issue:** No `--max-time`/`--connect-timeout` on any curl. A wedged CDN
connection (stalled transfer, not a fast failure) hangs a leg far past the
documented ~3-minute ceiling, up to the 6-hour default job timeout.
**Fix:** add `--max-time 30` to each curl (or a `CURL="curl --max-time 30"`
variable), and/or `timeout-minutes: 10` on the smoke job.

### IN-03: protocol-relative analytics script URL

**File:** `src/layouts/BaseLayout.astro:90`
**Issue:** `src="//gc.zgo.at/count.js"` is the legacy protocol-relative idiom.
The site is HTTPS-only on Pages so it resolves correctly, but GoatCounter's
own snippet uses the explicit `https://` form, and protocol-relative breaks
under `file://` previews.
**Fix:** `src="https://gc.zgo.at/count.js"`.

### IN-04: site-code regex accepts a leading/trailing hyphen — an invalid hostname passes the malformed-code guard

**File:** `src/lib/site.mjs:71`
**Issue:** `/^[a-z0-9-]+$/` accepts `-foo` / `foo-`, which are invalid DNS
labels: `https://-foo.goatcounter.com/count` never resolves, so the build
passes the "malformed code fails loudly" guard while silently sending
pageviews nowhere — the exact adjacent-state collapse D-61 exists to prevent.
Low likelihood (the code is pasted once from GoatCounter, which won't issue
such a code).
**Fix:** `/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/`.

### IN-05: smoke job inherits default token permissions

**File:** `.github/workflows/deploy.yml:31-41`
**Issue:** `build` and `deploy` declare least-privilege `permissions`, but
`smoke` declares none and inherits the repository default (which can be
write-all on older repos). The job only checks out and curls.
**Fix:** add `permissions: contents: read` to the smoke job (or set a
workflow-level default).

### IN-06: stub-exemption predicate keys on a string a reader page could legitimately contain

**File:** `tests/hardening.smoke.sh:49-51` (same predicate in `tests/site.smoke.sh:35-37`, `tests/distribution.smoke.sh:52-54`, `tests/post.smoke.sh:17`, `tests/collections.smoke.sh:23`)
**Issue:** `is_redirect_stub()` classifies any page whose HTML contains
`http-equiv="refresh"` as a machine-facing stub. A future technical deep-dive
quoting that literal in a code sample (Shiki does not entity-escape `"` inside
code text) would be silently exempted from every per-page invariant sweep.
Partially self-detecting — `site.smoke.sh`'s sitemap-equality check would then
fail loudly on the count mismatch — but the other harnesses would just
under-sweep.
**Fix:** none required now; if it ever fires, tighten the predicate to Astro's
actual stub shape (e.g. `grep -q '<meta http-equiv="refresh"' && ! grep -q 'build-sha'`).

## Verified Clean (deep-pass evidence)

- **Promote fidelity:** all three promoted files byte-identical to their
  `../studio/vault/` sources (`diff` clean).
- **Assertion validity:** every count edited this phase (99 pages, 10 devlog,
  65 deep-dives, 9 roadmap links, 4 og:images, 3 feed hero URLs, 10 feed
  items) reproduced exactly against a fresh local build.
- **Probe/site contract:** probe grep literals match built bytes (404 heading,
  build-sha stamp shape, refresh directive); default probe paths match
  `SLUG_REDIRECTS` and the launch-post slug; stub refresh target is
  base-prefixed and resolves to a built file.
- **Fixture hygiene:** trap chains in `distribution.smoke.sh` and
  `hardening.smoke.sh` traced — every trap replacement occurs only after the
  prior fixture's file is already restored; `PRE_SRC_STATUS` snapshot
  correctly tolerates a legitimately-dirty post-signup `site.mjs`.
- **Injection surfaces:** validated GoatCounter code before hostname
  interpolation; Astro `{expr}` attribute escaping for the OG block (the
  escape-html.ts caveat comment at BaseLayout.astro:49-58 is correct);
  sanitize-html allow-list excludes script/iframe/event handlers; workflow
  values reach bash via quoted env vars.
- **PNG asset:** valid 1200x1125 8-bit RGBA PNG, 317 KB, resolved by the hero
  glob into the og:image set.

---

_Reviewed: 2026-08-08T18:20:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_

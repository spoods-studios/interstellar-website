---
phase: 04-analytics-launch-content-deploy-hardening
verified: 2026-08-08T22:35:00Z
status: passed
score: 30/31 must-haves verified (1 deferred by design — ANLT-01 live criterion, D-61)
human_approved: 2026-08-09 — user approved 7 judgment prohibitions + backstop evidence in-session (autonomous --interactive); empty-SLUG_REDIRECTS backstop verified by orchestrator (build exit 0, 99 pages, no stub dir, trap-and-restore); ANLT-01 live cert recorded as Deferred Verification in STATE.md
behavior_unverified: 1
overrides_applied: 0
behavior_unverified_items:
  - truth: "Pageviews are recorded via the analytics dashboard (ANLT-01 live criterion)"
    test: "Create the GoatCounter account, set GOATCOUNTER_CODE in src/lib/site.mjs, push (deploys), open the dashboard"
    expected: "Pageviews appear in the GoatCounter dashboard; every page including the 404 counts"
    why_human: "Deferred by design (D-61) — the account does not exist yet, so the constant ships unset and the script renders nowhere. The mechanism is fully implemented and behaviorally proven in both states; only the live recording cannot exist yet."
human_verification:
  - test: "ANLT-01 live criterion — sign up for GoatCounter, set GOATCOUNTER_CODE in src/lib/site.mjs, push, confirm pageviews in the dashboard (and that the dashboard shows dead-link 404 traffic per D-62)"
    expected: "Pageviews recorded; no cookie set (verify in devtools Application tab); no consent banner needed"
    why_human: "Deferred by design (D-61): the account does not exist yet. Post-phase sequence documented in 04-03/04-05 SUMMARYs; REQUIREMENTS.md correctly leaves ANLT-01 Pending."
  - test: "Backstop truth (04-04): with an EMPTY redirects map, npm run build exits 0 and emits no stub directories under dist/"
    expected: "Empty SLUG_REDIRECTS builds green with zero meta-refresh stub files"
    why_human: "Tagged verification: backstop in 04-04 PLAN. The map ships seeded, so no assertion exercises the empty-map state; per the honest-verifier protocol I abstain (insufficient_spec) rather than false-pass. A 30-second manual check: temporarily empty SLUG_REDIRECTS, build, confirm, restore."
  - test: "Prohibition (04-01/04-05, judgment): MUST NOT report a deploy successful on evidence weaker than the deploying commit's own marker in served bytes"
    expected: "Human confirms the probe design holds this line"
    why_human: "Judgment-tier prohibition requires explicit human resolution. NON-AUTHORITATIVE assessment: SATISFIED — probe succeeds only on grep of build-sha=<expected SHA> in the body (tests/live-probe.sh:57,67); negative run against the live site with a wrong SHA exited 1 naming the SHA; 200-with-stale-bytes cannot pass."
  - test: "Prohibition (04-02, judgment): MUST NOT alter/reformat/paraphrase promoted VOICE-locked prose"
    expected: "Human confirms fidelity"
    why_human: "Judgment-tier. NON-AUTHORITATIVE assessment: SATISFIED — all 13 promoted markdown files diff byte-identical against their studio-vault sources and the hero PNG is cmp-identical (verified this session, exit 0 on every compare)."
  - test: "Prohibition (04-02, judgment): MUST NOT publish studio content marked unpublished"
    expected: "Human confirms no unpublished document reached the site"
    why_human: "Judgment-tier. NON-AUTHORITATIVE assessment: SATISFIED — devlog/how-this-gets-built.md does not exist, no *.discord.txt exists under devlog/, and the out-of-enum status value that document carries is empirically proven to crash the build (SITE-03 fixture)."
  - test: "Prohibition (04-03, judgment): MUST NOT ship any analytics mechanism that sets a cookie, stores a client identifier, or transmits PII"
    expected: "Human confirms after signup (devtools: no cookies, no localStorage from count.js)"
    why_human: "Judgment-tier. NON-AUTHORITATIVE assessment: SATISFIED in the shipped state — the live site serves ZERO script tags and zero cookie/consent markup (curled this session). Post-signup, GoatCounter's cookieless claim is a vendor property; confirm alongside the ANLT-01 dashboard check."
  - test: "Prohibition (04-03, judgment): MUST NOT expand analytics beyond a single pageview script"
    expected: "Human confirms scope"
    why_human: "Judgment-tier. NON-AUTHORITATIVE assessment: SATISFIED — BaseLayout emits exactly one external-src script with no inline body, no event/dimension/click code; the state-free harness assertion (script-count == analytics-count per page and site-wide) makes any second script red in both states, proven in the harness run."
  - test: "Prohibition (04-04, judgment): MUST NOT rename/remove a published post URL without a redirect stub"
    expected: "Human confirms the norm holds going forward"
    why_human: "Judgment-tier and inherently forward-looking (governs future behavior). NON-AUTHORITATIVE assessment: mechanism + norm in place — SLUG_REDIRECTS wired, demo stub proven live, norm documented in CLAUDE.md and vault/conventions.md naming the same-commit rule; no rename occurred this phase."
---

# Phase 4: Analytics, Launch Content & Deploy Hardening — Verification Report

**Phase Goal:** The site measures traffic without cookies, the M1.1 launch post is live, and the pipeline is safe against silent failure and dead links as the site enters its low-attention steady state.
**Verified:** 2026-08-08T22:35:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

**Mode note:** ROADMAP marks every phase `Mode: mvp` but no phase goal in this project is a User Story (the goal fails `user-story.validate`); phases 1–2 were verified against standard Success Criteria under the same marking (01/02-VERIFICATION.md precedent). Standard goal-backward verification applied; flagging the marking for cleanup, not blocking on it.

**Push-state note:** main is 8 commits ahead of origin (WR-01..WR-04 post-review fixes + docs). The live site serves `681c1ea` — the commit the green smoke run verified. The WR fixes (deploy concurrency group, probe base-URL normalization, memoized warn, nav windowing) are verified in the working tree but not yet deployed; pushing is gated on the user per repo convention.

## Goal Achievement

### Observable Truths (Roadmap Success Criteria — the contract)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC1a | Cookieless, privacy-respecting analytics mechanism on all pages, no consent banner | ✓ VERIFIED | Gated `gc.zgo.at/count.js` tag in BaseLayout.astro:85-91 (is:inline, async, external src only, data-goatcounter endpoint, renders on every page incl. 404 via shared layout). Harness run this session behaviorally proved both states: unset → 0 tags on all 99 pages; configured fixture → exactly 1 tag everywhere incl. 404, endpoint carries the code. Live homepage curled: 0 `<script` tags, 0 cookie/consent markup — nothing to consent to. |
| SC1b | Pageviews ARE recorded | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Deferred by design (D-61): `GOATCOUNTER_CODE = ''` (site.mjs:50), account does not exist yet; build warns loudly naming the constant (observed in harness log, memoized once per WR-03). Post-signup sequence documented. Routed to human verification; REQUIREMENTS.md correctly leaves ANLT-01 Pending. |
| SC2 | M1.1 launch post live, top of archive and RSS feed | ✓ VERIFIED | Live: CI smoke job log (run 31280806927) launch-post leg passed; my own probe run against the live site this session passed all legs. Build: `First Burn` at byte offset 3186 vs manifesto 4699 in dist/index.html (first archive entry); `<item><title>First Burn</title>` is the first rss.xml item with permalink guid. |
| SC3 | Malformed post fails build loudly; post-deploy smoke confirms live site served new content | ✓ VERIFIED | Behavioral, both halves: (a) SITE-03 fixture in my hardening.smoke.sh run — out-of-enum `status` crashed `astro build` non-zero naming the file, devlog/ left clean; (b) smoke job green on the real deploy (build→deploy→smoke, freshness after 1 probe of SHA 681c1ea); probe negative path run by me against the live site with a bogus SHA exited 1 — a 200 alone is never accepted. |
| SC4 | Slug-immutability norm documented; redirect-stub mechanism exists | ✓ VERIFIED | `SLUG_REDIRECTS` wired to `redirects:` (astro.config.mjs:25-27,141) with base-composed destination; stub contract behaviorally proven in harness run (base-prefixed target, noindex, canonical, destination resolves); live redirect-stub leg passed against the deployed site; norm in CLAUDE.md:21-29 and vault/conventions.md "Slug immutability (D-66)" — both name the mechanism, the same-commit rule, and ≥2 pinning consumers. |

### Plan-Level Truths (merged; deduped against SCs)

| # | Truth (plan) | Status | Evidence |
|---|--------------|--------|----------|
| 1 | Every built page carries exactly one build-sha stamp; CI SHA / literal `local` (04-01) | ✓ VERIFIED | Harness run: "stamp coverage OK", "local fallback OK", "SHA tracking OK" across all 99 pages incl. 404. Stamp unconditional at BaseLayout.astro:76. |
| 2 | Probe exits 0 on expected SHA, non-zero on mismatch; 200 never sufficient (04-01) | ✓ VERIFIED | Both paths run live this session: positive exit 0 (all 5 legs), negative exit 1 after bounded budget naming the missing SHA. No `curl --retry`; no hardcoded base. |
| 3 | 404 page carries the stamp (04-01) | ✓ VERIFIED | Live custom-404 leg asserts status 404 + custom heading + stamp — passed in CI and in my run. |
| 4 | All ten M1.1 deep-dives render incl. three decimal phases; indexed in full + milestone indexes (04-02) | ✓ VERIFIED | 10 files in technical/m1.1/; build log lists all ten routes incl. phase-53.1/53.2/53.3 plus technical/m1.1/index.html; 99 pages built. |
| 5 | M1.1 roadmap detail renders with resolved deep-dive links; overview links to it (04-02) | ✓ VERIFIED | dist/roadmap/m1.1/index.html carries hrefs into technical/m1.1/phase-*; overview links `m1.1/` and shows "M1.1 Spacecraft Control ✅ … (21 phases)" with "M1.2 … next". |
| 6 | Hero resolves to built asset and becomes the OG card (04-02) | ✓ VERIFIED | Launch post og:image = `.../_astro/m1.1-hero-first-burn.BbnsCBbo.png` (hashed build of the promoted PNG). |
| 7 | No promoted file differs by a byte from its studio source (04-02) | ✓ VERIFIED | diff/cmp of all 13 markdown files + hero PNG against ../studio/vault sources: RC=0 on every compare. |
| 8 | Site never shows M1.1 in progress while the launch post tops the archive (04-02) | ✓ VERIFIED | Overview: M1.1 ✅ closed, M1.2 🔨 next; roadmap/M1.1.md byte-matches the corrected studio detail doc. |
| 9 | Zero Discord-era placeholder wording in built site (04-02) | ✓ VERIFIED | `grep -rl "posted in #" dist/` = 0. (The single `technical-devlog` match is the legend page's own heading slug `how-to-read-the-roadmap-detail--technical-devlogs`, not placeholder wording.) |
| 10 | Unset code → no script, warning naming constant, exit 0 (04-03) | ✓ VERIFIED | Behavioral: harness "D-61 fixture OK: unset/blank warn and build"; warning text observed in log. |
| 11 | Whitespace ≈ unset; placeholder/malformed → non-zero naming constant; states never collapse (04-03) | ✓ VERIFIED | Behavioral: same fixture — placeholder and malformed values fail loudly, valid value silent, src/ restored. |
| 12 | Identical analytics-tag count on every page incl. 404 (04-03) | ✓ VERIFIED | Behavioral: "analytics gating OK (expected 0 per page, 404 covered)"; configured fixture: "one tag everywhere incl. 404". |
| 13 | Every script tag in dist/ is the sanctioned tag; no other client JS (04-03) | ✓ VERIFIED | Live site: 0 scripts. State-free equality (script count == analytics count) asserted per page and site-wide in the green harness. |
| 14 | Embed sets no cookie, needs no consent banner (04-03) | ✓ VERIFIED (shipped state) | Shipped state has zero JS and zero consent surface (live curl). Post-signup cookieless confirmation rides the ANLT-01 human item + prohibition P3. |
| 15 | Redirect entry → stub at old URL with noindex, absolute canonical, base-prefixed resolving target (04-04) | ✓ VERIFIED | Harness: "redirect stub contract OK (/devlog/2026-07-30-demo-old-slug -> /interstellar-website/devlog/2026-07-30-first-burn/)"; live stub leg serves the refresh directive. |
| 16 | Base-less destination mistake cannot ship (04-04) | ✓ VERIFIED | Stub-contract section asserts emitted target starts with the configured base and resolves to an existing dist/ file — green in run; destination composed from NORMALIZED_BASE, never a literal. |
| 17 | One entry covers slash and slash-less URL shapes (04-04) | ✓ VERIFIED | Key is byte-exact base-free path without trailing slash (astro.config.mjs:26); live stub served at directory form. |
| 18 | Norm documented in both files (04-04) | ✓ VERIFIED | CLAUDE.md + vault/conventions.md; neither a weaker paraphrase; both name mechanism + same-commit rule + pinning consumers. |
| 19 | Reader-facing sweeps exclude stubs by explicit predicate, invariants unweakened (04-04) | ✓ VERIFIED | Harness green with the stub present; predicate keys on the refresh directive (page-selection change only). |
| 20 | Empty redirects map builds green, no stubs (04-04, `verification: backstop`) | ? UNCERTAIN (abstain) | No assertion exercises the empty-map state (map ships seeded). Honest-verifier protocol: abstain, `insufficient_spec` → human item. |
| 21 | Deploy that never lands turns the workflow red unattended (04-05) | ✓ VERIFIED | Smoke job (deploy.yml:39-49) requires the deploying commit's stamp; probe negative behavior proven live; non-zero exit reds the workflow → default GitHub notification. WR-01 concurrency group (deploy.yml:11-13) closes the out-of-order-deploy stale window. |
| 22 | Probe URL comes from the deploy action's own output; no literal Pages URL (04-05) | ✓ VERIFIED | `outputs.page_url` on deploy job consumed via `needs.deploy.outputs.page_url`; `grep github.io deploy.yml` empty; CI log shows PAGE_URL injected from the output. |
| 23 | Dead URL under base → HTTP 404 + custom 404 page (closes Phase 2 deferral) (04-05) | ✓ VERIFIED | Live custom-404 leg passed in CI and in my run (status 404 + `<h1>Page not found.</h1>` + stamp). |
| 24 | Launch post, feed, redirect stub each confirmed live (04-05) | ✓ VERIFIED | CI smoke log + my live probe run, all legs named and passed. |
| 25 | Bounded retry; fails rather than loops (04-05) | ✓ VERIFIED | PROBE_ATTEMPTS×PROBE_DELAY ceiling; negative run exhausted its budget and exited 1. |

**Score:** 29/31 truths verified (1 present-behavior-unverified: ANLT-01 live criterion, deferred by design; 1 abstained backstop truth)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/layouts/BaseLayout.astro` | build-sha stamp + gated analytics in shared head | ✓ VERIFIED | Lines 30/76 (stamp), 40/85-91 (gated script); wired into every page incl. 404. |
| `tests/live-probe.sh` | full live route set, ≥60 lines, bounded retry | ✓ VERIFIED | 115 lines, executable, 5 legs, WR-02 base normalization (line 43); ran green live. |
| `tests/hardening.smoke.sh` | stamp coverage, SITE-03 fixture, D-61 legs, gating, stub contract | ✓ VERIFIED | Ran end-to-end this session: exit 0, ALL CHECKS PASSED. |
| `devlog/2026-07-30-first-burn.md` | launch post, `milestone: M1.1` | ✓ VERIFIED | Byte-identical to studio source; extra frontmatter key preserved. |
| `assets/m1.1-hero-first-burn.png` | hero, eager-glob pickup | ✓ VERIFIED | cmp-identical; hashed build referenced as og:image. |
| `technical/m1.1/*.md` | 10 deep-dives | ✓ VERIFIED | 10 files, all byte-identical, all built. |
| `roadmap/M1.1.md`, `pages/roadmap.md` | detail page + refreshed overview | ✓ VERIFIED | Byte-identical to studio sources; M1.1 closed, M1.2 next. |
| `src/lib/site.mjs` | GOATCOUNTER_CODE / GOATCOUNTER_PLACEHOLDER / assertGoatcounterConfigured | ✓ VERIFIED | All three exported (lines 50/54/66); guard shape per D-61 incl. WR-03 memoized warn. |
| `astro.config.mjs` | guard call + SLUG_REDIRECTS wired | ✓ VERIFIED | Bare call at line 136 (config-load layer); redirects at 141. |
| `.github/workflows/deploy.yml` | page_url output + smoke job + concurrency | ✓ VERIFIED | Valid YAML; smoke job has no permissions block; build job gained no test step; WR-01 concurrency group present. |
| `CLAUDE.md`, `vault/conventions.md` | slug-immutability norm | ✓ VERIFIED | Both carry the full norm; conventions stub blockquote retained with new heading below. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| BaseLayout.astro | tests/live-probe.sh | probe greps the exact meta name | ✓ WIRED | `name="build-sha" content=` grep (probe:57) matches layout emission; proven live. |
| tests/hardening.smoke.sh | tests/run-all.sh | `tests/*.smoke.sh` auto-discovery | ✓ WIRED | run-all.sh:12 glob loop (tool's regex-escaped pattern miss was a false negative). |
| roadmap/M1.1.md | technical/m1.1/ | resolvePhase placeholder resolution | ✓ WIRED | dist/roadmap/m1.1/index.html carries technical/m1.1/phase-* hrefs. |
| devlog launch post | hero PNG | body image ref → assetImports → heroFor() | ✓ WIRED | Body ref at post:14; hashed asset is the page's og:image. |
| astro.config.mjs | src/lib/site.mjs | bare guard call at config load | ✓ WIRED | astro.config.mjs:136 (tool pattern-escape false negative). |
| BaseLayout.astro | src/lib/site.mjs | imports code, renders script only when set | ✓ WIRED | Import line 3, call line 40, conditional render 85. |
| astro.config.mjs | dist/<old-slug>/index.html | redirects → meta-refresh stub | ✓ WIRED | Stub built and served live. |
| deploy.yml | tests/live-probe.sh | smoke job invokes repo script | ✓ WIRED | deploy.yml:49 `bash tests/live-probe.sh "$PAGE_URL" "$SHA"` (tool false negative). |
| deploy.yml | actions/deploy-pages | smoke consumes page_url output | ✓ WIRED | outputs:34, consumed:47; CI log shows the real URL flowing through. |

### Behavioral Spot-Checks & Probe Execution

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full hardening harness (stamp coverage, SHA tracking, SITE-03 fixture, D-61 legs, gating both states, stub contract) | `bash tests/hardening.smoke.sh` | exit 0, ALL CHECKS PASSED (single full run this verification) | ✓ PASS |
| Live probe, positive path, real deployed site | `PROBE_ATTEMPTS=3 bash tests/live-probe.sh <pages-url> 681c1ea…` | exit 0, all 5 legs passed | ✓ PASS |
| Live probe, negative path (stale-deploy simulation) | `PROBE_ATTEMPTS=2 bash tests/live-probe.sh <pages-url> deadbeef…` | exit 1, names the SHA never served | ✓ PASS |
| Live homepage ships zero JS / zero consent surface | `curl … \| grep -c '<script'` / `grep -ciE 'cookie\|consent'` | 0 / 0 | ✓ PASS |
| CI smoke job on the real deploy | run 31280806927 job 93161706491 (log read directly) | build 20s → deploy 11s → smoke 5s, all green; all 5 legs named | ✓ PASS |
| site.mjs exports | `node -e import(...)` (via harness legs) | exports present, guard behaves per D-61 | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SITE-03 | 04-01, 04-05 | Loud build failure + post-deploy smoke verifying the live site updated | ✓ SATISFIED | Both halves behaviorally proven (fixture crash + green live smoke + negative probe). REQUIREMENTS.md: Complete. |
| CONT-05 | 04-02 | M1.1 devblog post published as launch post | ✓ SATISFIED | Live at top of archive + feed, byte-faithful. REQUIREMENTS.md: Complete. |
| CONT-06 | 04-04 | Slug-immutability norm + redirect-stub mechanism | ✓ SATISFIED | Mechanism live-proven; norm in both doc targets. REQUIREMENTS.md: Complete. |
| ANLT-01 | 04-03 | Cookieless pageview analytics on all pages, no consent banner | ? NEEDS HUMAN | Mechanism fully implemented and behaviorally proven in both states; "pageviews recorded" deferred by design (D-61). REQUIREMENTS.md: Pending — consistent and honest. |

No orphaned requirements: REQUIREMENTS.md maps exactly ANLT-01, CONT-05, CONT-06, SITE-03 to Phase 4, and every ID appears in a plan's frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | none | — | No TBD/FIXME/XXX/TODO/HACK markers in phase-modified files; no empty-implementation or hardcoded-empty-prop patterns; `package.json`/`package-lock.json` untouched all phase (zero new dependencies, per T-04-SC). |

### Human Verification Required

1. **ANLT-01 live criterion (deferred by design, D-61)** — Sign up for GoatCounter, set `GOATCOUNTER_CODE` in `src/lib/site.mjs`, push (deploys), confirm pageviews in the dashboard and no cookie in devtools. The suite is already proven green in the configured state, so this push needs no test edits.
2. **Backstop truth: empty redirects map** — Temporarily empty `SLUG_REDIRECTS`, `npm run build`, confirm exit 0 and no stub directories under dist/, restore. Abstained per honest-verifier (no assertion exercises this state).
3. **Seven judgment-tier prohibitions** — each carries a NON-AUTHORITATIVE assessment of SATISFIED with evidence (see frontmatter); explicit human resolution required per item at the end-of-phase checkpoint.

### Gaps Summary

No gaps. Every roadmap Success Criterion except ANLT-01's live "pageviews recorded" clause is verified with behavioral evidence — most of it generated fresh this session (full hardening-harness run, live probe positive + negative runs against the deployed site, CI job log read directly) rather than taken from SUMMARY claims. The two non-verified items are honest, by-design deferrals the phase's own plans mandated recording as deferred rather than passed: ANLT-01's dashboard confirmation (account doesn't exist yet) and the 04-04 backstop truth (empty-map behavior, tagged for abstention at planning time). Phase 3's three deferred live checks remain owned by `/gsd-verify-work 3` and were not counted here.

---

_Verified: 2026-08-08T22:35:00Z_
_Verifier: Claude (gsd-verifier)_

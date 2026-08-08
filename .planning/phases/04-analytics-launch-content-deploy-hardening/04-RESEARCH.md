# Phase 4: Analytics, Launch Content & Deploy Hardening - Research

**Researched:** 2026-08-08
**Domain:** Cookieless analytics embed (GoatCounter), Astro static redirects, GitHub Actions post-deploy smoke checks, content-tree promote mechanics
**Confidence:** HIGH (codebase + installed-package facts verified directly; external service facts CITED from official repos; goatcounter.com itself unreachable this session)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

Numbering continues from Phase 3 (which ended at D-59).

#### Analytics
- **D-60:** **GoatCounter hosted** (stack-research pick): free non-commercial
  tier, cookieless, no consent banner needed. Single script tag emitted from
  `BaseLayout.astro`'s `<head>` so every page — 404 included — is covered.
  This is deliberately the site's **first client JS**; scope stays one
  pageview script, nothing more.
- **D-61:** The GoatCounter site code is a **config constant that ships
  optional-if-unset**: while unset, the script does not render and the build
  emits a **loud warning naming the constant** (not a failure); once set, a
  malformed or placeholder value **hard-fails the build** (D-54 pattern).
  Rationale: the user chose "create account now" during discuss but
  goatcounter.com failed to load (2026-08-08), so signup is **deferred to
  after the phase** — a D-54-style hard block while unset would freeze every
  deploy (D-08: every push deploys) and make the phase unable to execute to
  green. **Consequence:** ANLT-01's live "pageviews recorded" criterion cannot
  be certified until the user sets the real code — record it as deferred
  human verification, not as passed.
- **D-62:** **The 404 page counts pageviews.** Dead-link radar: stale Discord
  links are precisely the CONT-06 threat, and 404 traffic in the dashboard is
  the cheapest way to see them. Falls out of the script living in BaseLayout.

#### Launch content
- **D-63:** Phase 4 promotes the **full M1.1 tree**, not just the
  announcement: `m1.1-spacecraft-control.md` → `devlog/` (as
  `2026-07-30-….md` per the established filename convention) plus its hero
  `assets/m1.1-hero-first-burn.png`, all **10** deep-dives →
  `technical/m1.1/`, and `roadmap-detail/M1.1.md` → `roadmap/M1.1.md`.
  Exclusions: `.discord.txt` siblings (never posts) and
  `how-this-gets-built.md` (**`status: skeleton`**, dated "M1.1 close + a few
  days", VOICE pass still required — it is not part of this phase).
  Decimal phase filenames (53.1–53.3) ride on D-34's numeric-aware sort —
  planner should verify `phase-sort.ts` handles the `53.1` alongside `53`
  case and that cross-links (D-35) pick up the new milestone automatically.
- **D-64:** `pages/roadmap.md` (the D-37 site-voice overview transcription)
  is **refreshed in-phase**: rewritten studio-side against the updated pinned
  overview (M1.1 closed, M1.2 next) and promoted with the tree — D-25/D-56
  cross-repo precedent. The site must not show M1.1 in-progress while its
  launch post tops the archive.

#### Slug immutability & redirects
- **D-65:** Redirect stubs use **Astro's `redirects` config** in
  `astro.config.mjs` — build-time meta-refresh stub pages, zero new
  dependencies, one map entry per renamed slug, covers all three URL trees.
  Stub markup details (canonical link to the new URL, noindex) are Claude's
  discretion.
- **D-66:** The slug-immutability norm is documented in **both** the repo
  `CLAUDE.md` (content section, beside the existing untouchability rule) and
  `vault/conventions.md` — the two places agents and the studio promote flow
  actually read. — **Reversibility:** one-way in effect once URLs are
  published — the norm exists because Discord embeds, RSS items, and vault
  references all pin URLs; a renamed slug without a stub breaks published
  links permanently.

#### Deploy hardening
- **D-67:** The post-deploy smoke check is a **CI job appended to
  `deploy.yml`**, running after `actions/deploy-pages`: it curls the live
  site and asserts freshness plus key routes. Failure turns the workflow red
  (GitHub notifies by default) — automation suited to the site's
  low-attention steady state, replacing the silent-failure window. The probe
  also absorbs the **deferred Phase 2 live-404-under-base check** (STATE.md:
  "Phase 4 owns the follow-up check").
- **D-68:** Freshness marker: the build **stamps the commit SHA into page
  markup** via BaseLayout (meta tag or HTML comment — discretion), sourced
  from `GITHUB_SHA` (with a local fallback value). The smoke job greps the
  live HTML for the SHA it just deployed — one source of truth, present on
  every page, no extra route. Planner note: Pages CDN propagation is not
  instant; the probe needs a bounded retry/backoff before declaring failure.

### Claude's Discretion
- GoatCounter script attributes (endpoint URL shape, `async`, localhost/dev
  suppression, bot handling — GoatCounter filters bots server-side).
- Smoke-check URL set beyond home + 404 + rss.xml (e.g. one deep-dive, one
  roadmap page), retry/backoff parameters, curl-vs-harness style.
- SITE-03 audit: whether existing loud-fails (D-10/D-33/D-39/D-54/D-58)
  already cover "schema/content errors" or a gap needs closing — planner
  verifies rather than assumes.
- Whether the redirects map ships empty (mechanism + docs + test) or seeded
  with a demonstration entry.
- Exact wording of the slug-immutability norm; SHA stamp placement.
- How the M1.1 promote is sequenced across plans (cross-repo read from
  `../studio/vault/`, same in-phase promote flow as D-25/D-43).

### Deferred Ideas (OUT OF SCOPE)
- **GoatCounter account signup** — user-only action; goatcounter.com failed
  to load during discuss (2026-08-08). After the phase: sign up, set the site
  code constant, push (deploy fires), then certify ANLT-01 live.
- **Phase 3 deferred human verification** — Discord embed paste test, W3C
  feed validation, deploy freshness probe — resume only via
  `/gsd-verify-work 3`.
- **`how-this-gets-built.md`** — publishes studio-side after VOICE pass;
  arrives via normal promote flow post-v1, no site work needed.
- **Analytics on outbound Discord CTA clicks** — carried from Phase 3's
  deferred list; likely never (cookieless + no invasive tracking).
- **Dark mode (SITE-05), KaTeX (CONT-07 half), search (CONT-08), custom
  domain (DIST-04)** — v2, unchanged.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ANLT-01 | Cookieless privacy-respecting pageview analytics (GoatCounter-class) on all pages; no consent banner needed | GoatCounter snippet + count.js filter behavior (Pattern 1); D-61 gated config constant mirrors `assertInviteConfigured()` (`src/lib/site.mjs:47-55`); zero-`<script>` test assertions enumerated in Pitfall 2 must be updated |
| CONT-05 | M1.1 devblog post published as the launch post | Full promote map (Pattern 5); frontmatter/schema compatibility verified; hero pipeline confirmed via `assetImports` (`src/lib/hero-assets.ts:24-26`); newest-first ordering puts 2026-07-30 on top of archive + feed automatically (`src/lib/devlog-meta.ts:26-35`, `src/pages/rss.xml.ts:61-62`) |
| CONT-06 | Slug-immutability norm documented; redirect-stub mechanism exists | Astro 7.0.9 `redirects` semantics verified from installed source (Pattern 3) — stub already emits noindex + canonical; **base-path landmine on destination strings** (Pitfall 1); doc targets: repo `CLAUDE.md` + `vault/conventions.md` |
| SITE-03 | Build fails loudly on schema/content errors; post-deploy smoke check verifies live site updated | Loud-fail coverage audit (dedicated section below) — schema errors DO fail loudly (glob loader source verified); smoke-job YAML + SHA stamp + bounded-retry pattern (Patterns 2 & 4) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **GSD workflow enforcement:** file changes go through `/gsd-execute-phase` / `/gsd-quick` — planner output feeds executors, no raw edits.
- **Content trees are untouchable:** `devlog/`, `technical/`, `roadmap/`, `pages/` are promote drop targets — never restyle/rename their `.md` files; the site renders them as-is (VOICE.md locked studio-side). The M1.1 promote *adds* files to these trees (established D-25/D-43 promote flow); it never edits existing ones.
- **Privacy:** no cookies, no invasive tracking (PROJECT.md) — GoatCounter satisfies this; Google Analytics is disqualified.
- **Gate tier t3:** bugs/broken pages block; cosmetic nits don't.
- **No comments unless WHY-comments; match surrounding code** — the codebase has a strong WHY-comment idiom (see `astro.config.mjs`, `src/lib/site.mjs`); new constants/guards should mirror it.
- **Test-first:** repo convention is bash smoke harnesses (`tests/*.smoke.sh` via `npm test` → `tests/run-all.sh`), with trap-and-restore fixtures for loud-fail paths (Phase 3 precedent, commit `3f6b3dc`).
- **Vendor-conservative:** no new dependencies needed this phase — and none should be added.

## Summary

This phase has four independent work streams that converge on two files (`BaseLayout.astro`, `deploy.yml`) plus a content promote. All mechanisms are either already in the repo (config-constant gating, smoke harness idioms, promote flow) or built into installed tooling (Astro's `redirects`, GitHub's `page_url` output). **Zero new npm dependencies are required** — GoatCounter is a script tag served from `gc.zgo.at`, redirects are core Astro, and the smoke job is curl in YAML.

Three findings materially shape planning. First, **Astro's redirect stubs already emit `<meta name="robots" content="noindex">` and `<link rel="canonical">`** (verified in installed source), so D-65's discretionary stub markup comes for free — but the redirect **destination string must carry the `/interstellar-website` base prefix manually**, because Astro passes string destinations through verbatim into the meta-refresh URL; a base-free destination produces a stub that redirects to a 404 on GitHub Pages. Second, **nine zero-`<script>` assertions across seven test files** currently enforce the site's zero-JS guarantee — the GoatCounter embed invalidates every one of them the moment the site code is configured, and since the constant ships *unset* this phase (D-61), the tests must be written conditional on the constant's state or they'll break on the user's post-phase signup push. Third, the **existing loud-fail lattice already covers schema/content errors** — frontmatter schema violations propagate uncaught out of Astro's glob loader (verified in installed source at `glob.js:101`), filename violations throw in `generateId`, and render-time errors are pre-flighted by `validateContentLoudFail()` — so SITE-03's build-side criterion is mostly an *audit + prove-with-fixture* task, not new mechanism; the genuinely new mechanism is the post-deploy smoke job.

The M1.1 promote is mechanically clean: the launch post's frontmatter passes the devlog schema (its `tags` key is silently stripped by the non-strict schema — acceptable), the 10 deep-dives have no frontmatter (passes the strict-but-all-optional technical schema), decimal phases 53.1–53.3 parse correctly through `parsePhaseNumber`/`resolvePhase` (both use `parseFloat`, already proven for 10.5/27.5/46.1), and `M1.1.md`'s deep-dive placeholders all match the existing `MARKER_RE` wording variants. The trap is downstream: **six-plus test count/pattern assertions hardcode the pre-M1.1 corpus** (exact counts 9/56/8, and `m0.*`-only glob patterns that silently ignore `m1.1`) and must be updated in the same plan as the promote.

**Primary recommendation:** structure plans as (1) analytics constant + BaseLayout script + SHA stamp + conditional test updates, (2) redirects mechanism + seeded demo entry + docs (CLAUDE.md/conventions.md) + stub smoke test, (3) M1.1 promote + count/pattern test updates + refreshed roadmap overview, (4) deploy.yml smoke job + live probes. Streams 1–3 are parallelizable; stream 4's live verification is deploy-dependent and lands last.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Pageview counting (ANLT-01) | Browser / Client (GoatCounter's `count.js` + hosted dashboard) | Static build (emits the script tag) | Counting must observe real visitors; the static build only decides *whether* to emit the tag (D-61 gate) |
| Analytics gating / validation | Static build (config-load time, `site.mjs` + `astro.config.mjs`) | — | Config evaluation is the one layer nothing downstream swallows (D-54 precedent, `astro.config.mjs:113-116`) |
| Launch content (CONT-05) | Static build (content collections) | Studio vault (source of truth, cross-repo read) | Promote copies files; rendering/ordering/RSS all fall out of existing collection queries with zero code change |
| Redirect stubs (CONT-06) | Static build (Astro `redirects` → meta-refresh HTML) | CDN/Pages (serves the stub) | GitHub Pages offers no server-side redirect config; build-time stubs are the only mechanism available |
| Slug-immutability norm | Docs (repo `CLAUDE.md`, `vault/conventions.md`) | — | A norm agents read at promote time, not runtime behavior |
| Freshness stamp (D-68) | Static build (BaseLayout `<head>`, `process.env.GITHUB_SHA`) | CI (supplies the env var) | Stamp must be *in the artifact* so the probe compares deployed bytes against the deploying commit |
| Post-deploy smoke check (D-67) | CI (GitHub Actions job after `deploy-pages`) | Live site (probe target) | Only CI knows which SHA was just deployed and can turn the workflow red unattended |

## Standard Stack

### Core

**No new packages are installed this phase.** Everything runs on the already-installed stack:

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Astro `redirects` config | astro@7.0.9 (installed) | Build-time meta-refresh redirect stubs | Core Astro feature since 2.9 — config docs and stub template verified directly in `node_modules/astro/dist/types/public/config.d.ts:218-267` and `node_modules/astro/dist/core/routing/3xx.js` `[VERIFIED: installed package source]` |
| GoatCounter hosted + `count.js` | script from `//gc.zgo.at/count.js` | Cookieless pageview analytics | Official snippet: `<script data-goatcounter="https://MYCODE.goatcounter.com/count" async src="//gc.zgo.at/count.js"></script>` `[CITED: github.com/arp242/goatcounter README — goatcounter.com itself was unreachable 2026-08-08, fallback per phase context]` |
| `actions/deploy-pages@v5` | already in `deploy.yml:27` | Deploy + exposes `page_url` output | Single documented output `page_url`; consumed cross-job via job-level `outputs:` + `needs.deploy.outputs.page_url` `[CITED: github.com/actions/deploy-pages README]` |
| `withastro/action@v6` | already in `deploy.yml:14` | Build in CI | Composite action running `npm run build` in-job — default GitHub env vars (incl. `GITHUB_SHA`) are visible to the build process with **no workflow changes needed** `[CITED: raw.githubusercontent.com/withastro/action/main/action.yml]` |
| curl | 8.18.0 (runner + local) | Smoke probes | Ubiquitous; bounded retry loop hand-written in bash (curl's `--retry` doesn't cover content-mismatch, see Don't Hand-Roll) |

### Supporting

| Item | Purpose | When to Use |
|------|---------|-------------|
| `src/lib/site.mjs` config-constant pattern | Home for `GOATCOUNTER_CODE` (or similar) + its D-61 assert/warn function | Mirror `DISCORD_INVITE_URL` + `assertInviteConfigured()` (`src/lib/site.mjs:14-18,47-55`) exactly, with the one deliberate difference: unset ⇒ warn (not throw), set-but-malformed/placeholder ⇒ throw |
| `tests/*.smoke.sh` + `tests/run-all.sh` harness | New build-time assertions (stub present, SHA stamp present, analytics gating) | `run-all.sh` auto-discovers `tests/*.smoke.sh` — add e.g. `tests/hardening.smoke.sh`, no shared file edits (`tests/run-all.sh:2-5`) |
| Trap-and-restore fixture idiom | Prove loud-fail paths empirically (SITE-03 audit) | Phase 3 precedent (commit `3f6b3dc`); use for "schema violation fails the build" proof |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Astro `redirects` config | Hand-written stub `.astro`/`.html` pages | Locked out by D-65; would also re-implement noindex/canonical that Astro's template already emits |
| `//gc.zgo.at/count.js` (CDN) | Self-hosting `count.js` in `public/` | Removes a third-party fetch but freezes the script version (misses bot-filter updates); official snippet is the documented path and keeps scope at one tag. Not recommended for v1 |
| `needs.deploy.outputs.page_url` in the smoke job | Hardcoding `https://spoods-studios.github.io/interstellar-website/` | Violates SITE-02's "URL config-driven in one place"; `page_url` costs one `outputs:` line |
| SHA via `process.env.GITHUB_SHA` in frontmatter | `astro:env` schema, or `PUBLIC_`-prefixed var | `astro:env` adds config surface for one build-time string; `import.meta.env` only auto-exposes `PUBLIC_`-prefixed vars — plain `process.env` read in `.astro` frontmatter (build-time server context) is the minimal correct mechanism `[ASSUMED — standard Vite/Astro behavior from training; trivially confirmed by the build-time smoke assertion the plan will add]` |

**Installation:** none. `package.json` dependencies are unchanged this phase (`package.json:25-31`).

## Package Legitimacy Audit

**No external packages are installed this phase** — the analytics embed is a remote script tag, redirects are built into the installed `astro@7.0.9`, and the smoke job uses curl on the GitHub runner. No `npm install` occurs.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

*Third-party runtime script note (supply-chain, not npm):* `//gc.zgo.at/count.js` is loaded at page-view time from GoatCounter's CDN. This is the officially documented integration `[CITED: github.com/arp242/goatcounter]`. Subresource Integrity is not viable (the script updates server-side); the exposure is bounded — the script has no cookies, no third-party data sharing, and the D-61 gate means it ships only after the user deliberately sets the site code.

## Architecture Patterns

### System Architecture Diagram

```
                       push to main (github.sha = X)
                                  │
                                  ▼
                    ┌──────────  CI: build job  ──────────────┐
                    │ withastro/action@v6 → npm run build     │
                    │  ├─ astro.config.mjs config-load:       │
                    │  │    validateContentLoudFail()  ─┐     │
                    │  │    assertInviteConfigured()    ├─ throw ⇒ red build
                    │  │    assertGoatcounter…() (D-61) ─┘     │
                    │  │       └─ unset ⇒ console warn only    │
                    │  ├─ content sync: glob loaders           │
                    │  │    schema violation ⇒ throw ⇒ red     │
                    │  ├─ pages render via BaseLayout:         │
                    │  │    <meta sha=X> stamp (D-68)          │
                    │  │    GoatCounter <script> iff code set  │
                    │  └─ redirects map ⇒ dist/<old>/index.html│
                    │       (meta-refresh + noindex + canonical)│
                    └───────────────┬──────────────────────────┘
                                    ▼
                    CI: deploy job (actions/deploy-pages@v5)
                      outputs.page_url ────────────┐
                                    │              │
                                    ▼              ▼
                    CI: smoke job (needs: deploy)  — NEW (D-67)
                      retry loop: curl page_url pages, grep for X
                      probe: /  /rss.xml  /404-path  deep-dive  redirect stub
                      fail ⇒ workflow red ⇒ GitHub notifies
                                    │
                                    ▼
                    Live site (Pages CDN) ──▶ visitor browser
                      count.js POSTs pathname ──▶ GoatCounter dashboard
                      (localhost/bots filtered; 404 paths counted = D-62 radar)

  Studio vault (../studio/vault/) ──promote (file copy, atomic commit)──▶
    devlog/2026-07-30-first-burn.md + assets/m1.1-hero-first-burn.png
    technical/m1.1/phase-{48..54,53.1,53.2,53.3}-*.md   (10 files)
    roadmap/M1.1.md          pages/roadmap.md (refreshed, D-64)
```

### Recommended Project Structure (delta only)

```
src/lib/site.mjs              # + GOATCOUNTER code constant + D-61 assert/warn fn
src/layouts/BaseLayout.astro  # + analytics <script> (gated) + SHA stamp in <head>
astro.config.mjs              # + call the D-61 assert; + redirects: {...} map
.github/workflows/deploy.yml  # + outputs: on deploy job; + smoke job
tests/hardening.smoke.sh      # NEW: stub/stamp/gating build-time assertions
CLAUDE.md, vault/conventions.md  # + slug-immutability norm (D-66)
devlog/, technical/m1.1/, roadmap/, pages/, assets/   # promoted content (D-63/D-64)
```

### Pattern 1: Gated GoatCounter embed (D-60/D-61/D-62)

**What:** One constant, one guard, one conditional script tag.

```js
// src/lib/site.mjs — mirrors DISCORD_INVITE_URL/assertInviteConfigured (site.mjs:14-55)
export const GOATCOUNTER_CODE = ''; // unset until the user signs up (post-phase)
export const GOATCOUNTER_PLACEHOLDER = 'REPLACE_ME';

// D-61: unset ⇒ loud warning naming the constant (build proceeds);
// set-but-malformed/placeholder ⇒ throw (D-54 pattern). Called from
// astro.config.mjs top level beside assertInviteConfigured().
export function assertGoatcounterConfigured() {
  const code = typeof GOATCOUNTER_CODE === 'string' ? GOATCOUNTER_CODE.trim() : '';
  if (code === '') {
    console.warn(
      'GOATCOUNTER_CODE is unset — the site builds and deploys WITHOUT analytics. ' +
      'Set it in src/lib/site.mjs after creating the GoatCounter account (ANLT-01).'
    );
    return null;
  }
  if (code === GOATCOUNTER_PLACEHOLDER || !/^[a-z0-9-]+$/.test(code)) {
    throw new Error(
      `GOATCOUNTER_CODE: "${code}" is the placeholder or not a valid GoatCounter site code`
    );
  }
  return code;
}
```

```astro
{/* BaseLayout.astro <head> — renders on every page incl. 404 (D-62) */}
{goatcounterCode && (
  <script
    data-goatcounter={`https://${goatcounterCode}.goatcounter.com/count`}
    async
    src="//gc.zgo.at/count.js"
  ></script>
)}
```

Snippet shape `[CITED: github.com/arp242/goatcounter README]`. Script attribute facts, read from the actual `public/count.js` source `[CITED: raw.githubusercontent.com/arp242/goatcounter/master/public/count.js]`:
- **Localhost/dev suppression is built in:** `count.js` refuses to count when `location.hostname` matches localhost/127.x/10.x/172.16-31.x/192.168.x/0.0.0.0 or `location.protocol === 'file:'` (unless `allow_local` is set). **No dev-mode conditional is needed in the layout.**
- **Bot handling:** client-side detection of `navigator.webdriver`/Phantom/Nightmare/Selenium, plus GoatCounter's server-side bot filtering. Nothing to configure.
- **404 counting (D-62):** `count.js` records `location.pathname` — on GitHub Pages the 404 page is served *at the dead URL's own path*, so the dashboard shows the actual dead link, which is exactly the CONT-06 radar the decision wants.
- Protocol-relative `//gc.zgo.at/count.js` resolves to https on Pages. `async` is part of the official snippet.

**One integration wrinkle:** Astro treats bare `<script>` tags in `.astro` files as its own processed scripts. A plain inline `<script src>` with custom attributes should be emitted with `is:inline` semantics — external scripts with attributes like `data-goatcounter` are rendered as-is when marked `is:inline` (or when Astro detects non-processable attributes). The plan should assert the built HTML contains the exact `data-goatcounter` attribute — that smoke assertion settles the directive question empirically. `[ASSUMED — Astro script-processing behavior from training; the build-time grep assertion is the verification]`

### Pattern 2: SHA stamp (D-68)

```astro
---
// BaseLayout.astro frontmatter — build-time server context, so process.env
// is available; GITHUB_SHA is a default env var in every Actions step and
// withastro/action runs the build as a composite step in-job.
const buildSha = process.env.GITHUB_SHA ?? 'local';
---
<meta name="build-sha" content={buildSha} />
```

- `withastro/action@v6` is a composite action that runs `npm run build` inside the job, so `GITHUB_SHA` reaches the build with **zero workflow changes** `[CITED: raw.githubusercontent.com/withastro/action/main/action.yml — composite action, build step runs "$PACKAGE_MANAGER run build"]`.
- `import.meta.env.GITHUB_SHA` would NOT work (only `PUBLIC_`-prefixed vars are exposed there); `process.env` in frontmatter is the correct read. `[ASSUMED — verified indirectly by the smoke assertion]`
- A `<meta>` tag is preferable to an HTML comment: `astro.config.mjs` doesn't disable `compressHTML`, and while Astro preserves comments inconsistently across versions, a meta tag is structurally guaranteed and greppable (`grep -o 'name="build-sha" content="[0-9a-f]*"'`).
- Local fallback `'local'` keeps local builds green and makes the CI-vs-local distinction greppable in tests.

### Pattern 3: Redirect stubs via `redirects` config (D-65)

**Verified against installed astro@7.0.9 source — this is the load-bearing pattern of the phase.**

What Astro generates for a static build (no adapter): a stub HTML file at `dist/<from>/index.html` containing `[VERIFIED: node_modules/astro/dist/core/routing/3xx.js:12-19]`:

```html
<!doctype html>
<title>Redirecting to: {relativeLocation}</title>
<meta http-equiv="refresh" content="0;url={relativeLocation}">
<meta name="robots" content="noindex">
<link rel="canonical" href="{absoluteLocation}">
<body>
	<a href="{relativeLocation}">Redirecting from <code>{from}</code> to <code>{relativeLocation}</code></a>
</body>
```

**D-65's discretionary items (canonical + noindex) are already in Astro's template — no custom markup needed.** Delay is `0` for the default 301 status (`3xx.js:8`).

**Semantics verified from source:**

- **Keys (the old URL) are written WITHOUT the base prefix** — Astro applies `config.base` to the match pattern itself (`node_modules/astro/dist/core/routing/create-manifest.js:370` — `getPattern(segments, settings.config.base, trailingSlash)`), and the output file lands at `dist/<from>/index.html`, which Pages serves under the base. Key `'/devlog/old-slug'` ⇒ stub served at `https://spoods-studios.github.io/interstellar-website/devlog/old-slug/`.
- **String destinations pass through VERBATIM into the Location header and meta-refresh URL** (`node_modules/astro/dist/core/redirects/render.js:16-34` — `resolveRedirectTarget` returns the raw string when the destination doesn't match a route pattern; `node_modules/astro/dist/core/build/generate.js:260-269` uses it as `relativeLocation` unmodified). **⇒ the destination MUST carry the base prefix** — see Pitfall 1.
- The canonical URL is composed as `new URL(location, config.site)` (`generate.js:261-262`), so a base-prefixed destination also yields the correct absolute canonical.
- Concrete-path destinations are **not validated against existing routes** (the `InvalidRedirectDestination` check only fires for dynamic-param redirects, `create-manifest.js:387-404`) — a typo'd destination builds fine and redirects to a 404. The demo entry therefore needs a build-time smoke assertion that the stub's target resolves in `dist/` (the existing dead-link sweep in `tests/site.smoke.sh:79+` may already cover the stub's `<a href>` — planner should confirm it walks stub pages, which are plain HTML in `dist/`).
- External `https://` destinations are rejected for static output with `UnsupportedExternalRedirect` (`create-manifest.js:380-385`) — irrelevant here (all three URL trees are internal) but worth knowing.
- `build.redirects` defaults to `true` (`config.d.ts:1155-1175`) — no config needed to enable stub emission.
- Config comment `// '/product1/', '/product1' // Note, this is not supported` (`config.d.ts:256`) — trailing-slash *variants as separate keys* are unsupported; use the canonical no-trailing-slash key form. Pages itself 301s `/old-slug` → `/old-slug/` for directory-format output, so both live URL shapes reach the stub.

**Recommended config shape** (composes the base once, from the existing `NORMALIZED_BASE` at `astro.config.mjs:14`):

```js
// astro.config.mjs — D-65/CONT-06. Keys are base-free old paths; destinations
// MUST be base-prefixed because Astro emits string destinations verbatim into
// the stub's meta-refresh URL (redirects/render.js resolveRedirectTarget).
const SLUG_REDIRECTS = {
  // demonstration entry proving the mechanism end-to-end (D-65):
  '/devlog/2026-07-30-demo-old-slug': `${NORMALIZED_BASE}devlog/2026-07-30-first-burn/`,
};

export default defineConfig({
  site: 'https://spoods-studios.github.io',
  base: BASE,
  redirects: SLUG_REDIRECTS,
  // ...existing config unchanged
});
```

**Seeded vs empty map (discretion):** recommend **seeded with one demonstration entry** — the mechanism has never been exercised in this repo, string destinations are unvalidated (typo ⇒ silent 404 stub), and a live entry gives the smoke harness and the D-67 probe a real URL to assert against. An empty map tests nothing. The demo entry can point a plausible-but-never-published old slug at the launch post, clearly labeled as the mechanism demo in the map's WHY-comment.

### Pattern 4: Post-deploy smoke job (D-67/D-68)

```yaml
# deploy.yml — deploy job gains job-level outputs; smoke job appended.
  deploy:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    outputs:
      page_url: ${{ steps.deployment.outputs.page_url }}   # NEW — exposes to smoke
    steps:
      - id: deployment
        uses: actions/deploy-pages@v5

  smoke:
    needs: deploy
    runs-on: ubuntu-latest
    # no permissions needed — read-only curl against the public site
    steps:
      - name: Probe live site for freshness and key routes
        env:
          PAGE_URL: ${{ needs.deploy.outputs.page_url }}
          SHA: ${{ github.sha }}
        run: |
          set -euo pipefail
          # Bounded retry: Pages CDN propagation is not instant (D-68 note).
          # ~12 x 15s = 3 min ceiling; cache-buster query defeats stale CDN hits.
          fresh() {
            curl -fsSL "${PAGE_URL}?smoke=${SHA}" | grep -q "content=\"${SHA}\""
          }
          for i in $(seq 1 12); do
            if fresh; then echo "fresh after $i probes"; break; fi
            if [ "$i" -eq 12 ]; then echo "live site never served SHA ${SHA}"; exit 1; fi
            sleep 15
          done
          # Key routes (all must serve the same SHA / expected content):
          curl -fsSL "${PAGE_URL}rss.xml?smoke=${SHA}" | grep -q "<rss"
          curl -fsSL "${PAGE_URL}devlog/2026-07-30-first-burn/?smoke=${SHA}" | grep -q "content=\"${SHA}\""
          # Deferred Phase 2 check absorbed here (D-67): custom 404 under base.
          STATUS=$(curl -s -o /tmp/404.html -w '%{http_code}' "${PAGE_URL}definitely-not-a-page-${SHA}/")
          [ "$STATUS" = "404" ]
          grep -q "Page not found" /tmp/404.html          # 404.astro's H1 (src/pages/404.astro:15)
          grep -q "content=\"${SHA}\"" /tmp/404.html      # 404 carries the stamp too (BaseLayout)
          # Redirect stub live check (CONT-06 demo entry):
          curl -fsSL "${PAGE_URL}devlog/2026-07-30-demo-old-slug/?smoke=${SHA}" | grep -q 'http-equiv="refresh"'
```

Facts underpinning this:
- `page_url` is deploy-pages' only output; cross-job consumption requires the job-level `outputs:` declaration `[CITED: github.com/actions/deploy-pages README]`. For a project site it is the full base-inclusive URL with trailing slash (`https://<owner>.github.io/<repo>/`) `[ASSUMED — standard Pages behavior; the probe's own success/failure verifies it, and `${PAGE_URL}rss.xml` composition tolerates the trailing slash]`.
- `github.sha` in the smoke job equals the `GITHUB_SHA` the build stamped — same workflow run, same commit. `[VERIFIED: both are the workflow run's commit by definition of a push-triggered run]`
- `curl --retry` alone is insufficient: it retries transport errors, not "200 but stale content" — the grep-in-loop is required (see Don't Hand-Roll).
- Failure exits non-zero ⇒ job red ⇒ workflow red ⇒ GitHub default notification — no extra alerting config (D-67's low-attention requirement).
- URL set beyond home + 404 + rss.xml (discretion): the launch post (proves CONT-05 live), one redirect stub (proves CONT-06 live). A deep-dive/roadmap page adds little beyond the launch post (same pipeline) — keep the probe list short; every URL is a future maintenance liability if slugs churn.

### Pattern 5: M1.1 promote map (D-63/D-64)

All sources verified on disk this session:

| Source (`../studio/vault/`) | Destination (repo) | Verified facts |
|---|---|---|
| `devlog/drafts/m1.1-spacecraft-control.md` | `devlog/2026-07-30-first-burn.md` | Frontmatter: `milestone: M1.1`, `title: First Burn`, `date: 2026-07-30`, `status: published`, `discord_post_id`, `audience`, `hero_visual` (prose), **`tags: [...]`** — see Pitfall 5. Body hero ref `../assets/m1.1-hero-first-burn.png` matches the M0.7/M0.8 pattern. Filename convention: date + title-derived slug (precedent: `2026-07-13-making-mercury-precess.md` from "Making Mercury Precess") |
| `devlog/assets/m1.1-hero-first-burn.png` | `assets/m1.1-hero-first-burn.png` | File exists studio-side; `hero-assets.ts`'s eager `../../assets/*.png` glob picks it up with zero code change (`src/lib/hero-assets.ts:18`); hero detection is via `entry.assetImports`, NOT `hero_visual` (`hero-assets.ts:24-26`) — the prose `hero_visual` value is harmless |
| `devlog/technical/m1.1/phase-{48,49,50,51,52,53,53.1,53.2,53.3,54}-*.md` (10 files) | `technical/m1.1/` (same filenames) | No frontmatter (all start `# H1`) ⇒ passes the strict-but-all-optional technical schema (`src/content.config.ts:65`). Filenames match `TECHNICAL_RE` incl. decimals (`content.config.ts:39`). Only `[[...]]` occurrences are C++ `[[nodiscard]]` inside code blocks — structurally safe (see Pitfall 7) |
| `project/roadmap-detail/M1.1.md` | `roadmap/M1.1.md` | H1 `# Roadmap Detail — M1.1 Spacecraft Control` + `**Era:** Era 1 (playable prototype).` — matches the D-38 H1-strip + Era-line reads; **Era 1 is a new era group**, which the era grouping already handles data-driven (STATE.md Phase 02-06 decision). Deep-dive placeholders analyzed in Pitfall 6 |
| `devlog/discord/roadmap-overview.pinned.md` (reference text) | `pages/roadmap.md` (refreshed, D-64) | Current `pages/roadmap.md:39` still says `**M1.1 Spacecraft Control** 🔨 — in progress`; pin shows M1.1 ✅ / M1.2 🔨. Rewrite happens studio-side (site-voice transcription), promoted with the tree |
| **Excluded:** `m1.1-spacecraft-control.discord.txt`, `how-this-gets-built.md` | — | Per D-63. Note: if `how-this-gets-built.md` (`status: skeleton`) were ever promoted by mistake, the `z.enum(['draft','published','final'])` schema **hard-fails the build loudly** — the landmine flagged in CONTEXT is already covered (see SITE-03 audit) |

**Ordering/sort verification (CONTEXT asked the planner to verify — done here):**
- `parsePhaseNumber('phase-53.1-…')` → `parseFloat('53.1')` = 53.1; sorts 53 < 53.1 < 53.2 < 53.3 < 54 (`src/lib/phase-sort.ts:5-13`). Same mechanism already proven for 10.5/27.5/46.1 in the live corpus.
- `resolvePhase` keys its map with `parseFloat(match[1])` and the heading tracker stores `parseFloat` too (`astro.config.mjs:42`, `src/lib/mdast-deepdive-links.mjs:62`) — decimal join is consistent end-to-end.
- `normalizeMilestone('M1.1')` → `m1.1`; `milestoneSortKey` → 1·100000+1 = 100001, sorting after every m0.x (`src/lib/milestone-key.ts:8-26`).
- Archive/RSS top slot: `2026-07-30` is the newest devlog date (current newest is `2026-07-13`) ⇒ `sortEntriesNewestFirst` puts it first in both automatically (`src/lib/devlog-meta.ts:26-35`; shared query `src/pages/rss.xml.ts:61-62`).
- **Atomicity requirement:** `roadmap/M1.1.md`'s placeholders resolve against `technical/m1.1/` files via `resolvePhase`, and `validateContentLoudFail()` runs at config-load over all trees (`astro.config.mjs:100-111`) — promoting the roadmap file without the deep-dives (or vice versa with wikilinks) fails the build. **Promote the whole tree in one commit.**

### Anti-Patterns to Avoid

- **Base-free redirect destinations** — verbatim pass-through means the stub redirects to the apex domain root; see Pitfall 1.
- **Hand-editing promoted content to "fix" anything** (e.g. stripping the `tags` key) — trees are read-only drop targets; the schema already tolerates what's there.
- **Making the analytics constant hard-fail while unset** — explicitly rejected by D-61 (would freeze every deploy until the user can sign up).
- **Unconditional script-presence test assertions** — the constant is unset during this phase and set after; tests must derive expectations from the constant's state (Pitfall 2).
- **Adding probe URLs generously** — each hardcoded URL in the smoke job is a slug-immutability dependency of its own.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Redirect stub pages | Custom `.astro` routes / hand-written HTML stubs | Astro `redirects` config | Locked (D-65); Astro's template already handles noindex, canonical, refresh delay, and escaping (`3xx.js`) |
| Dev/localhost analytics suppression | `import.meta.env.DEV` conditionals around the script | Nothing — `count.js` filters localhost/private IPs by default | Verified in count.js source; extra gating adds a code path that can silently disable production counting |
| Bot filtering | User-agent checks, honeypots | Nothing — count.js + GoatCounter server-side | Already handled both client- and server-side `[CITED: count.js source]` |
| Pageview endpoint | Any self-hosted counter | GoatCounter hosted | Locked (D-60); zero-infra constraint |
| CDN-propagation wait | `curl --retry N` alone | Bash loop: fetch → grep SHA → sleep → retry, bounded | `--retry` only fires on transport/5xx errors — a 200 serving *stale* content is the exact failure mode being probed |
| Deployed-URL discovery | Hardcoded Pages URL in the smoke job | `needs.deploy.outputs.page_url` | SITE-02: URL config-driven in one place; survives a future custom domain (DIST-04) untouched |

**Key insight:** every mechanism this phase needs already exists in the installed stack or the repo's own idioms — the work is wiring and proving, not building. Any plan task that invents new machinery should be treated as a smell.

## SITE-03 Loud-Fail Coverage Audit

The phase context asks whether existing loud-fails already cover "schema/content errors" or a gap needs closing. Audit result, verified against installed `astro@7.0.9` source and repo code:

### Already loud (no action needed)

| Error class | Mechanism | Evidence |
|---|---|---|
| Bad devlog filename | `generateId` throws | `src/content.config.ts:17-22` (D-10); throw propagates — `generateId` is called outside the loader's only try/catch (`node_modules/astro/dist/content/loaders/glob.js:82`) |
| Bad technical/roadmap filename | `generateId` throws | `content.config.ts:49-55,75-78` (D-33/D-38) |
| **Frontmatter schema violation** (e.g. `status: skeleton`) | `parseData` → Zod → `InvalidContentEntryDataError` | **`glob.js:101` — `parseData` is NOT inside the loader's try/catch** (only `render` at `glob.js:129` is); the rejection propagates through `Promise.all` (`glob.js:200-210`) out of `collection.loader.load()` (`node_modules/astro/dist/content/content-layer.js:265`), which has no surrounding catch. The `skeleton`-status landmine flagged in CONTEXT is therefore **already a loud failure**: `z.enum(['draft','published','final'])` rejects it (`content.config.ts:32`) before `isVisible` could ever see it. `[VERIFIED: installed source; recommend the plan prove it with a trap-and-restore fixture per the Phase 3 idiom]` |
| Unknown frontmatter key in technical/roadmap | `.strict()` schemas | `content.config.ts:65,82` |
| Unresolvable wikilink / deep-dive placeholder | config-load preflight re-runs the full mdast pipeline and lets throws crash the process | `astro.config.mjs:100-111` (`validateContentLoudFail`), covering the glob loader's known render-error swallowing (`glob.js:129-131`, documented at `astro.config.mjs:86-99`) |
| Empty collection (misconfigured loader base) | `assertNonEmpty` at every query site | `src/lib/content-guards.ts:4-11` |
| Missing hero asset referenced in a body | `lookupHero` throws; Astro's own ImageNotFound fires upstream | `src/lib/hero-image.ts:29-33`; STATE.md Phase 3 D-48 fixture note |
| Unset/placeholder Discord invite | config-load assert | `src/lib/site.mjs:47-55`, called at `astro.config.mjs:116` |
| Non-absolutizable URL in feed content | `absolutize` throws | `src/pages/rss.xml.ts:33-39` |
| Corpus count drift | exact-count smoke assertions | `tests/collections.smoke.sh:28` et al. (build-time, local only — see gap 3) |

### Remaining silent classes (gaps for the planner to weigh)

1. **Unreadable file → silent skip.** `glob.js:70-73` catches read errors, logs, and skips the entry. Practically near-impossible in a clean git checkout, and the exact-count smoke assertions would catch the disappearance locally. **Verdict: accept; no mechanism needed.**
2. **Duplicate collection id → warn-only overwrite.** `glob.js:106-112` logs a warning and last-write-wins. Structurally impossible here: every collection derives its id from the file's unique path/filename. **Verdict: accept; document in the audit note.**
3. **`npm test` never runs in CI.** `deploy.yml` builds and deploys; the smoke harness (count assertions, zero-JS sweep, dead-link sweep) runs only on developer machines. The config-load preflight and schema errors DO fail the CI build, so SITE-03's letter is satisfied — but the count/dead-link classes are local-only. **Verdict: planner's call — adding `npm test` after build in the build job is a one-line hardening that fits SITE-03's "low-attention steady state" spirit; it does require the build job to keep `dist/` (the harness greps `dist/`), which withastro/action produces in-place. Modest scope add; flag, don't assume.**
4. **The new D-68/D-61/redirect mechanisms themselves need build-time assertions** — stamp present in built HTML, script gated correctly, demo stub emitted with base-prefixed target. New `tests/hardening.smoke.sh` covers these (the new-mechanism half of SITE-03).

## Common Pitfalls

### Pitfall 1: Redirect destination without the base prefix (CRITICAL)
**What goes wrong:** `'/devlog/old': '/devlog/new/'` builds cleanly, but the stub's meta-refresh sends browsers to `https://spoods-studios.github.io/devlog/new/` — missing `/interstellar-website` — which 404s.
**Why it happens:** Astro passes string destinations verbatim into the Location header and stub URL (`node_modules/astro/dist/core/redirects/render.js:16-34`, `generate.js:260-269`); base is applied only to the *match* side (`create-manifest.js:370`). Destinations are also unvalidated for concrete paths — no build error.
**How to avoid:** compose destinations from `NORMALIZED_BASE` (`astro.config.mjs:14`); keys stay base-free. Add a smoke assertion that the demo stub's `url=` value starts with the base.
**Warning signs:** stub HTML in `dist/` whose `content="0;url=/devlog/..."` lacks the base segment.

### Pitfall 2: Nine zero-`<script>` assertions break when analytics goes live
**What goes wrong:** the moment `GOATCOUNTER_CODE` is set (user's post-phase push), `npm test` fails across the board even though the site is correct.
**Why it happens:** the zero-JS guarantee is asserted at `tests/post.smoke.sh:55`, `tests/roadmap.smoke.sh:43,75,76`, `tests/markdown.smoke.sh:28`, `tests/build.smoke.sh:45`, `tests/technical.smoke.sh:39,40,97`, and site-wide at `tests/site.smoke.sh:75` — all `-eq 0`.
**How to avoid:** rewrite these to a state-aware expectation: read the constant (e.g. `node -e "import('./src/lib/site.mjs').then(m => ...)"` or grep the built pages for `data-goatcounter`) and assert `<script` count equals the GoatCounter script count exactly — i.e. "no client JS *other than* the one sanctioned analytics tag." While the constant is unset this collapses to the current zero assertion, so the suite stays green in both states. `tests/markdown.smoke.sh:28` guards *rendered body content* — likely unaffected, but verify what `$RENDERED` is before leaving it untouched.
**Warning signs:** a green suite this phase that goes red on the first post-signup push — the exact "silent failure while nobody is watching" SITE-03 exists to prevent.

### Pitfall 3: Corpus-count and `m0.*`-pattern assertions go stale on promote
**What goes wrong:** exact counts fail loudly (good, but must be updated); `m0.*`-scoped patterns *silently under-assert* — they keep passing while ignoring the entire new milestone.
**Specifics:** `tests/collections.smoke.sh` expects devlog 9 / technical 56 / roadmap 8 / pages 2 → becomes 10 / 66 / 9 / 2. `tests/build.smoke.sh:27` expects 9 archive links → 10. `tests/technical.smoke.sh:13` counts `dist/technical/m0.*/phase-*` `-eq 55` — the glob **excludes m1.1**, so it passes unchanged; broaden to `m*` and bump to 65. Same for `technical.smoke.sh:62` (`m0\.[0-9]*` href pattern, `-eq 55`) and `tests/roadmap.smoke.sh:51` (`roadmap/m0\.[0-9]*` `-eq 8`). `tests/distribution.smoke.sh`'s checks are relative (baseline-vs-mutated) and self-adjust.
**How to avoid:** the promote plan updates counts *and* widens `m0`-anchored patterns in the same commit; treat any `m0` literal in `tests/` as a review checklist item (`grep -rn 'm0' tests/`).

### Pitfall 4: Promote must be atomic across trees
**What goes wrong:** promoting `roadmap/M1.1.md` before `technical/m1.1/` (or splitting across commits/plans that could deploy independently) makes `resolvePhase` return null for its placeholders ⇒ `validateContentLoudFail()` crashes the build (`src/lib/mdast-deepdive-links.mjs:91-95`, `astro.config.mjs:100-111`).
**How to avoid:** one commit carries the full D-63 tree (announcement + hero + 10 deep-dives + roadmap detail + refreshed overview). D-08 means every push deploys — a half-promoted push is a red deploy.

### Pitfall 5: The launch post's `tags` key — tolerated, don't "fix" it
**What goes wrong (if mishandled):** someone either strips `tags` from the promoted file (violates read-only drop-target rule) or adds `tags` to the schema / makes it strict (scope creep, and `.strict()` would then reject other vault-side additions later).
**Reality:** the devlog schema is non-strict (`src/content.config.ts:26-36`), so Zod silently strips the unknown `tags` key — the post loads fine as-is. `[VERIFIED: schema shape read this session; Zod non-strict default strips unknown keys]`
**How to avoid:** promote verbatim; note the stripping behavior in the plan so the executor doesn't "helpfully" adjust either side.

### Pitfall 6: `M1.1.md` deep-dive placeholder wording variants
**What goes wrong (if unverified):** an uncovered wording variant would either hard-fail the build (marker with no phase heading) or leak literal `#technical-devlog` text onto the page.
**Verified this session:** all placeholders in `../studio/vault/project/roadmap-detail/M1.1.md` match existing handling: bold `**Deep-dive:** posted in #technical-devlog` (line 79 — the strong-label split leaves ` posted in #technical-devlog`, matched by `MARKER_RE`), plain `Deep dive: posted in #technical-devlog.` (line 159), and `Deep dive: Phase N post in #technical-devlog.` (lines 289–624, incl. decimals 53.1–53.3). The intro blockquote's generic `Deep-dives:\nposted in #technical-devlog.` mention is stripped by `GENERIC_MENTION_RE` (`src/lib/mdast-deepdive-links.mjs:34,41`). Phase 50 and 54 sections carry **no** marker at all — that renders without a deep-dive link (content-as-is; not an error, not this repo's problem to fix).
**Residual check for the plan:** after promote, `grep -c technical-devlog dist/ -r` should be 0 (matches the Phase 2 acceptance idiom).

### Pitfall 7: `[[nodiscard]]` in deep-dive code blocks
**What goes wrong (if the pipeline were naive):** the wikilink plugin would try to resolve `nodiscard` and hard-fail.
**Reality:** the plugin visits `text` nodes only; Sätteri routes `code`/`inlineCode` elsewhere (`src/lib/mdast-wikilinks.mjs:1-5`), and the live corpus already contains `[[nodiscard]]` in `technical/m0.2/phase-07-core-vector-types.md:62-63` building green. Four M1.1 deep-dives contain it, all inside code blocks. **No action needed — but do not add any escaping to the promoted files.**

### Pitfall 8: Stale-CDN false confidence in the smoke probe
**What goes wrong:** the probe fetches immediately after `deploy-pages` returns, gets a cached pre-deploy page (or transiently the old build), and either flakes red or — worse with a naive "HTTP 200 = pass" check — passes against stale content.
**Why it happens:** Pages CDN propagation lags the API-level deploy completion; `curl --retry` doesn't help because the response is a valid 200.
**How to avoid:** grep for the D-68 SHA stamp inside a bounded retry loop with a cache-busting query param (Pattern 4). Budget ~3 minutes; this repo's deploys normally finish in ~40s (STATE.md), so 12×15s is generous without masking a real failure for long.

### Pitfall 9: GoatCounter service unavailability shapes verification, not implementation
**What goes wrong:** a plan that requires a live GoatCounter dashboard check blocks on a service that was down on 2026-08-08 (unreachable again this session — `goatcounter.com/help/start` fetch failed, GitHub repo used as the documented fallback).
**How to avoid:** implementation and tests run entirely against the *unset* state (script absent, warning emitted, gating proven by fixture with a temporary valid/invalid code). ANLT-01's live certification is **deferred human verification** by D-61 — the phase's verifier must record it as deferred, not passed.

## Code Examples

All load-bearing examples are inline in Architecture Patterns 1–5 above (gated embed, SHA stamp, redirects map, smoke job YAML, promote map). Additional test-side idioms:

### Build-time hardening assertions (new `tests/hardening.smoke.sh`)
```bash
# SHA stamp present on every page (local build stamps 'local')
grep -q 'name="build-sha" content="local"' dist/index.html
grep -q 'name="build-sha" content="local"' dist/404.html

# Redirect demo stub emitted, base-prefixed, pointing at a real page
STUB=dist/devlog/2026-07-30-demo-old-slug/index.html
test -f "$STUB"
grep -q 'http-equiv="refresh"' "$STUB"
grep -q 'url=/interstellar-website/devlog/2026-07-30-first-burn/' "$STUB"
grep -q 'name="robots" content="noindex"' "$STUB"
TARGET=dist/devlog/2026-07-30-first-burn/index.html
test -f "$TARGET"   # unvalidated destination made real (Pitfall 1)

# Analytics gating: while the constant is unset, zero data-goatcounter output
# (flip this assertion's expectation off the constant once set — Pitfall 2)
test "$(grep -rl 'data-goatcounter' dist/ | wc -l)" -eq 0
```

### D-61 hard-fail fixture (trap-and-restore idiom, Phase 3 precedent)
```bash
# Prove: a placeholder GoatCounter code crashes the build at config load.
# (sed the constant to REPLACE_ME, expect non-zero exit + the constant's name
# in stderr, restore via trap — mirrors tests/ fixtures from commit 3f6b3dc.)
```

### Schema loud-fail fixture (SITE-03 proof)
```bash
# Prove: a devlog file with `status: skeleton` fails the build loudly.
# Drop a fixture .md into devlog/ (trap-and-restore), run astro build,
# expect non-zero exit and the filename in the error output.
# Verifies the glob.js:101 parseData propagation claim empirically.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Server-side redirects (.htaccess / `_redirects`) | Build-time meta-refresh stubs via `redirects` config | Astro 2.9+ (2023), unchanged through 7.x | Only option on GitHub Pages (no server config); stubs carry noindex+canonical natively |
| Cookie-based analytics + consent banners | Cookieless counters (GoatCounter/Plausible class) | Industry norm for privacy-first sites since ~2020 | No banner needed — satisfies ANLT-01's "nothing needs consent" by construction |
| Deploy = done | Post-deploy verification jobs chained via `needs` + environment outputs | Standard GitHub Actions practice | `page_url` output (deploy-pages v1+) makes the probe URL config-free |

**Deprecated/outdated:** nothing relevant this phase; all mechanisms are current stable features of already-installed tooling.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `page_url` for a project site is the full base-inclusive URL with trailing slash | Pattern 4 | Probe URLs mis-compose ⇒ smoke job red on first run; trivially diagnosed from the job log and fixed in YAML |
| A2 | `process.env.GITHUB_SHA` is readable in `.astro` frontmatter during `astro build` (Vite SSR/node context) | Pattern 2 | Stamp renders the fallback in CI ⇒ smoke freshness grep fails visibly on first CI run; fallback is `astro:env` or `PUBLIC_` var |
| A3 | Astro emits the external `data-goatcounter` script tag as-is (with `is:inline` if needed) | Pattern 1 | Build-time grep assertion catches it immediately; fix is adding/removing `is:inline` |
| A4 | GoatCounter free non-commercial hosted tier still available at signup time | Deferred signup | User-side only; D-61's unset path means the site is unaffected either way (carried `[ASSUMED]` from stack research — goatcounter.com unreachable to re-verify) |
| A5 | Loader `load()` rejection fails `astro build` (not just logs) | SITE-03 audit | Source chain verified to the sync `Promise.all` (`content-layer.js:265`); the final await-in-build hop is standard observed Astro behavior. The recommended trap-and-restore fixture converts this to empirical proof in-phase |
| A6 | `@astrojs/sitemap` handling of redirect routes (may include stub URLs in sitemap.xml) | Pattern 3 | Stubs carry `noindex`, so SEO impact ≈ 0 even if listed; optionally assert/inspect `dist/sitemap-*.xml` in the hardening smoke |

## Open Questions

1. **Should `npm test` run in CI (build job)?**
   - What we know: schema/content errors already fail the CI build; the smoke harness's count/dead-link/zero-JS classes run only locally (SITE-03 audit gap 3).
   - What's unclear: whether the user considers this in-scope for SITE-03 or scope creep (t3 gate, "do exactly what is asked").
   - Recommendation: planner surfaces it as a one-line optional task; default to including it only if it doesn't complicate the withastro/action job (harness needs `dist/` + `node`, both present post-build).
2. **Exact slug for the promoted launch post** (`2026-07-30-first-burn.md` assumed from the title-derived-slug precedent).
   - Recommendation: planner fixes it early — the redirect demo entry, smoke probe URL, and archive assertions all reference it. Once deployed it is immutable (D-66).
3. **goatcounter.com availability** — down during discuss and again this session.
   - Recommendation: nothing in-phase depends on it (D-61 unset path); keep the deferred-verification record explicit so `/gsd-verify-work 4` doesn't mark ANLT-01 passed.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | Astro build, smoke harness | ✓ | v24.15.0 (fnm default) | — |
| curl | smoke probes (CI + local) | ✓ | 8.18.0 local; preinstalled on ubuntu-latest | — |
| bash | tests harness, CI job | ✓ | repo standard | — |
| GitHub Actions / Pages | deploy + smoke | ✓ (was `degraded_performance` 2026-07-22 — Phase 3 verification deferred for that reason) | — | live checks defer, build-time checks unaffected |
| goatcounter.com | account signup only (user action, post-phase) | ✗ this session | — | D-61 unset path; GitHub repo docs used for integration facts |
| `../studio/vault/` (cross-repo read) | M1.1 promote sources | ✓ (all files verified on disk this session) | — | — |

**Missing dependencies with no fallback:** none that block execution.
**Missing dependencies with fallback:** goatcounter.com (signup deferred by design, D-61).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash smoke harness + Node assertion script (no JS test framework — Phase 1 decision, STATE.md) |
| Config file | none — `tests/run-all.sh` auto-discovers `tests/*.smoke.sh` |
| Quick run command | `bash tests/hardening.smoke.sh` (after `npm run build`) |
| Full suite command | `npm test` (runs `tests/run-all.sh`; requires a fresh `npm run build` first) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ANLT-01 | Unset code ⇒ no script + loud warning; malformed code ⇒ build fails; set code ⇒ exactly one script per page | smoke + trap-fixture | `bash tests/hardening.smoke.sh` (+ fixture leg) | ❌ Wave 0 |
| ANLT-01 | Live pageviews recorded in dashboard | manual-only | — (deferred human verification per D-61 — GoatCounter account doesn't exist yet) | n/a |
| CONT-05 | Launch post tops archive + RSS; hero resolves; counts updated | smoke | `bash tests/build.smoke.sh && bash tests/collections.smoke.sh && bash tests/distribution.smoke.sh` (updated counts) | ✅ (needs count/pattern updates — Pitfall 3) |
| CONT-06 | Demo stub emitted with base-prefixed target, noindex, canonical; norm documented in both files | smoke + grep | `bash tests/hardening.smoke.sh`; `grep -q 'slug' CLAUDE.md vault/conventions.md` | ❌ Wave 0 |
| SITE-03 | Schema violation fails build loudly | trap-fixture | fixture leg in `tests/hardening.smoke.sh` (or `collections.smoke.sh`) | ❌ Wave 0 |
| SITE-03 | Live site serves deployed SHA; 404-under-base; workflow red on failure | CI job (live) | smoke job in `deploy.yml` — verified on first real deploy | ❌ Wave 0 (YAML) |

### Sampling Rate
- **Per task commit:** `npm run build && bash tests/hardening.smoke.sh` (~fast; build dominates)
- **Per wave merge:** `npm run build && npm test`
- **Phase gate:** full suite green + one live deploy with green smoke job before `/gsd-verify-work 4` (live legs that depend on GitHub Actions health may defer, Phase 3 precedent)

### Wave 0 Gaps
- [ ] `tests/hardening.smoke.sh` — covers ANLT-01 gating, CONT-06 stub, D-68 stamp, SITE-03 schema fixture
- [ ] Count/pattern updates in `tests/{collections,build,technical,roadmap}.smoke.sh` — land WITH the promote commit, not before (they'd fail against the pre-promote corpus)
- [ ] Smoke job YAML in `deploy.yml`

## Security Domain

### Applicable ASVS Categories (L1)

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | static site, no auth |
| V3 Session Management | no | no sessions, no cookies (by requirement) |
| V4 Access Control | no | public content only |
| V5 Input Validation | yes | content pipeline: Zod schemas + `.strict()` where applicable, `sanitize-html` allow-list in feed (`rss.xml.ts:42-50`) — all pre-existing; promoted content is git-trusted |
| V6 Cryptography | no | none needed |
| V14 Config | yes | CI least-privilege: smoke job needs **no** permissions block (read-only public curl); deploy job keeps `pages: write, id-token: write` only |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Third-party script compromise (`gc.zgo.at`) | Tampering | Bounded exposure: one script, no cookies/PII on the site, D-61 gate keeps it out until deliberately enabled; SRI infeasible (script auto-updates) — accepted, documented risk |
| Open-redirect abuse of stubs | Spoofing | Not applicable: redirect map is a build-time constant; external destinations are rejected by Astro for static output (`create-manifest.js:380-385`) |
| Stub HTML injection via slug | Injection | Astro escapes template values with `html-escaper` (`3xx.js:1,9-11`); slugs are repo-controlled constants anyway |
| Workflow privilege creep | Elevation | Smoke job declared with no `permissions:` (defaults to restricted read for the added job; the existing jobs' explicit blocks are unchanged) |
| Analytics as tracking vector | Info disclosure | GoatCounter is cookieless/aggregate; no events, no custom dimensions (D-60's "one pageview script, nothing more") |

## Sources

### Primary (HIGH confidence — direct observation this session)
- Installed `astro@7.0.9` source: `node_modules/astro/dist/core/routing/3xx.js` (stub template), `dist/types/public/config.d.ts:190-267,1155-1175` (redirects/trailingSlash docs), `dist/core/routing/create-manifest.js:361-425` (redirect route creation, base handling, validation), `dist/core/redirects/render.js:16-34` (verbatim destination pass-through), `dist/core/build/generate.js:255-275` (stub emission, canonical composition), `dist/content/loaders/glob.js` (error-handling map: parseData at :101 uncaught, render at :129 caught, generateId at :82 uncaught, read-skip at :70, dup-id warn at :106), `dist/content/content-layer.js:230-280` (loader rejection propagation)
- Repo files: `astro.config.mjs`, `src/lib/site.mjs`, `src/layouts/BaseLayout.astro`, `.github/workflows/deploy.yml`, `src/content.config.ts`, `src/lib/{content-guards,phase-sort,milestone-key,hero-assets,hero-image,entry-order,devlog-meta}.ts`, `src/lib/{mdast-deepdive-links,mdast-wikilinks,wikilink-resolver}.mjs`, `src/pages/rss.xml.ts`, `src/pages/404.astro`, `pages/roadmap.md`, `tests/*.smoke.sh`, `package.json`
- Studio vault (cross-repo, on disk): `devlog/drafts/m1.1-spacecraft-control.md`, `devlog/technical/m1.1/` (10 files), `devlog/assets/m1.1-hero-first-burn.png`, `project/roadmap-detail/M1.1.md`, `devlog/discord/roadmap-overview.pinned.md`

### Secondary (MEDIUM confidence — official project sources, fetched this session)
- `github.com/arp242/goatcounter` README — integration snippet (goatcounter.com/help/start unreachable, per phase-context fallback instruction)
- `raw.githubusercontent.com/arp242/goatcounter/master/public/count.js` — filter behavior (localhost, bots, prerender, skipgc)
- `github.com/actions/deploy-pages` README — `page_url` output, permissions, wiring
- `raw.githubusercontent.com/withastro/action/main/action.yml` — composite action, build command, inputs

### Tertiary (LOW confidence)
- GoatCounter free-tier terms — carried `[ASSUMED]` from Phase 1 stack research; not re-verifiable this session (site down); does not gate any in-phase work

## Metadata

**Confidence breakdown:**
- Redirects semantics: HIGH — read from installed package source, line-cited; empirical smoke assertion recommended as belt-and-braces
- Analytics integration: MEDIUM-HIGH — snippet and count.js behavior from official repo/source; live behavior unverifiable until signup (deferred by D-61 anyway)
- CI wiring (outputs, env, smoke): MEDIUM-HIGH — official action docs + action.yml; A1/A2 self-verify on first deploy
- Promote mechanics: HIGH — every source file and every consuming code path read directly this session
- SITE-03 audit: HIGH on covered classes (source-verified), with one deliberate empirical-proof recommendation (A5 fixture)

**Research date:** 2026-08-08
**Valid until:** ~2026-09-08 (stable installed tooling; re-check only if astro/withastro-action majors bump or GoatCounter's hosted service changes)

# Phase 4: Analytics, Launch Content & Deploy Hardening - Context

**Gathered:** 2026-08-08
**Status:** Ready for planning

<domain>
## Phase Boundary

The site measures traffic without cookies (ANLT-01), the M1.1 launch post is
live at the top of the archive and the RSS feed (CONT-05), the pipeline fails
loudly on bad content and a post-deploy smoke check confirms the live site
actually served the new build (SITE-03), and the slug-immutability norm is
documented with a working redirect-stub mechanism (CONT-06).

This is the final v1 phase. It touches site chrome (`<head>` script, build
stamp), CI (`.github/workflows/deploy.yml`), config (`astro.config.mjs`,
`src/lib/site.mjs`), docs (repo `CLAUDE.md`, `vault/conventions.md`), and
promotes the M1.1 content tree — it does not change how any content renders.
The four content trees stay read-only promote drop targets; D-14's "body
renders untouched" is unaffected.

**Engine status ground truth (2026-08-08):** M1.1 closed studio-side. The
announcement `m1.1-spacecraft-control.md` is `status: published`, posted to
Discord 2026-07-30 (`discord_post_id: 1532409509463457923`), with a real
engine-output hero (`assets/m1.1-hero-first-burn.png`). The technical series
for m1.1 grew to **10 deep-dives** (phase-48…54 including decimal phases
53.1–53.3) — D-44's "5 deep-dives" count is superseded by what actually
exists. `roadmap-detail/M1.1.md` exists, and the Discord pinned overview
already shows M1.1 ✅ / M1.2 🔨 next.

**Phase 3 interplay:** Phase 3 sits in `verification_deferred_human` (STATE.md
Deferred Verification — resume via `/gsd-verify-work 3` only). This phase's
freshness probe (D-67/D-68) provides exactly the mechanism that deferred
check needs, but Phase 4 does NOT claim Phase 3's checks — do not mark them
verified here.

</domain>

<decisions>
## Implementation Decisions

Numbering continues from Phase 3 (which ended at D-59).

### Analytics
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

### Launch content
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

### Slug immutability & redirects
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

### Deploy hardening
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase ground truth
- `.planning/ROADMAP.md` — Phase 4's four success criteria
- `.planning/REQUIREMENTS.md` — ANLT-01, CONT-05, CONT-06, SITE-03 definitions
- `.planning/PROJECT.md` — constraints: privacy ("no cookies, no invasive
  tracking"), quiet content-first, D-G no generative imagery
- `.planning/STATE.md` — **Deferred Verification section**: Phase 3's three
  deploy-dependent checks are owned by `/gsd-verify-work 3`, not this phase
- `.planning/phases/03-rss-opengraph-discord-distribution/03-CONTEXT.md` —
  D-45–D-59, especially D-50 (OG on every page), D-54/D-55 (config-constant
  loud-fail precedent + invite URL), D-59 (hero via `entry.assetImports`)
- `.planning/phases/02-content-rendering-templating/02-CONTEXT.md` —
  D-31–D-44, especially D-33 (technical filename rules), D-34 (numeric phase
  sort incl. decimals), D-35 (generated cross-links), D-37 (roadmap overview
  transcription), D-43/D-44 (promote scope; D-44's M1.1 rider lands now)
- `.planning/phases/01-stack-scaffolding/01-CONTEXT.md` — D-01–D-10 (filename
  fallback, loud-fail norm, D-08 every-push deploys)

### Launch content sources (studio vault)
- `../studio/vault/devlog/drafts/m1.1-spacecraft-control.md` — the launch
  post, `status: published`, hero + tags frontmatter (`.discord.txt` sibling
  excluded)
- `../studio/vault/devlog/technical/m1.1/` — the 10 deep-dives (phase-48 …
  phase-54, incl. 53.1/53.2/53.3)
- `../studio/vault/project/roadmap-detail/M1.1.md` — roadmap detail doc
- `../studio/vault/devlog/discord/roadmap-overview.pinned.md` — updated pin
  (M1.1 ✅, M1.2 🔨) — reference text for the D-64 re-transcription
- `../studio/vault/devlog/VOICE.md` — locked voice; transcription register
- `../studio/vault/decisions/Decision Log.md` — [D-F]/[D-G]/[D-H]/[D-K]/
  [D-M]/[D-N] as in prior phases

### Analytics
- `https://www.goatcounter.com/help/start` — official integration snippet
  (fetch at research time; site was intermittently unreachable 2026-08-08)

### Implementation surfaces
- `astro.config.mjs` — `site`+`base` single URL source; `redirects` config
  lands here; `validateContentLoudFail()` is the loud-fail precedent
- `src/lib/site.mjs` — existing config constants (`DISCORD_INVITE_URL` with
  D-54 validation); the GoatCounter code constant belongs beside them
- `src/layouts/BaseLayout.astro` — `<head>` where the analytics script and
  SHA stamp land (every page inherits, 404 included)
- `.github/workflows/deploy.yml` — build+deploy jobs; smoke job appends here
- `src/lib/content-guards.ts` — `isVisible` filter; planner must verify how a
  non-`draft` unknown status like `skeleton` is treated (landmine if it
  renders)
- `tests/` — smoke-harness conventions (`run-all.sh`, grep-idiom notes in
  STATE.md decisions)
- `CLAUDE.md` (repo root) + `vault/conventions.md` — D-66 doc targets

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/lib/site.mjs` — config-constant home with existing build-time
  validation pattern (D-54); GoatCounter code constant + warning/hard-fail
  logic mirrors `DISCORD_INVITE_URL`'s.
- `src/layouts/BaseLayout.astro` — single `<head>` shared by all pages;
  analytics script + SHA stamp are one-file changes.
- `src/lib/phase-sort.ts`, `entry-order.ts`, `milestone-key.ts` — existing
  numeric-aware ordering; M1.1 content should slot in with zero code change
  (verify decimals 53.1–53.3 and the M1.x milestone key).
- `src/lib/hero-assets.ts` / `hero-image.ts` — D-48/D-59 hero pipeline; the
  M1.1 hero PNG should be picked up automatically once promoted alongside
  the post.
- `tests/*.smoke.sh` + `tests/run-all.sh` — harness for new build-time
  assertions (redirect stubs present, SHA stamp present, analytics gating).

### Established Patterns
- Loud-fail over silent skip (D-10/D-33/D-39/D-54/D-58) — D-61's
  malformed-value hard-fail and SITE-03's audit extend it; config-load-time
  validation is the proven mechanism.
- Read-only promote drop targets — all M1.1 content arrives via promote;
  nothing in `devlog/`, `technical/`, `roadmap/`, `pages/` is hand-edited
  in-repo.
- RSS/archive share one collection query (D-45) — the launch post tops both
  automatically once promoted; no feed work needed beyond the existing
  absolutize path (note: STATE.md logs an href-branch coverage gap in
  `tests/distribution.smoke.sh` — live negative assertion gates it).

### Integration Points
- `deploy.yml` currently: build (withastro/action@v6) → deploy
  (deploy-pages@v5). Smoke job chains off `needs: deploy` with the deployed
  SHA available as `github.sha`.
- GoatCounter script + SHA stamp join OG metadata in the same `<head>` block
  Phase 3 filled (D-50).
- Redirects config lives beside `site`/`base` — stub URLs must respect the
  base path (the Phase 2 trailing-slash landmine applies).

</code_context>

<specifics>
## Specific Ideas

- "Boring is correct" holds: the analytics embed is the site's first and only
  client JS, one script tag, no events, no custom dimensions.
- SITE-03's spirit is "the site enters low-attention steady state safely" —
  every mechanism here (red CI on stale deploy, loud warning on unset
  analytics, redirect stubs) is designed to work while nobody is watching.
- The launch post is the milestone the whole roadmap aimed at: archive +
  launch post live before the audience ramp (Core Value). After this phase,
  v1 requirements are complete except the deferred human verifications.

</specifics>

<deferred>
## Deferred Ideas

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

</deferred>

---

*Phase: 4-Analytics, Launch Content & Deploy Hardening*
*Context gathered: 2026-08-08*

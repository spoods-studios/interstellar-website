---
phase: 3
slug: rss-opengraph-discord-distribution
status: draft
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (high)
threats_open: 1
asvs_level: 1
created: 2026-08-11
---

# Phase 3 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| npm registry → build machine | Two new packages enter the build at install time | Third-party code |
| Markdown source → `<meta>` attribute value | Developer-authored prose interpolated into HTML attribute context site-wide | Public prose |
| Site-rendered HTML → third-party feed reader | Full post HTML crosses into clients this project does not control | Public post HTML |
| Built asset URL → absolute URL rewrite | The feed endpoint rewrites attribute values it did not author | Asset URLs |
| Markdown body image reference → built asset URL | A content-file path selects which image the site advertises to embedding clients | Asset selection |
| Built page → external client (`target="_blank"`) | The Discord CTA hands control to a third-party origin | Navigation |
| Test fixture → read-only content tree | The harness deliberately mutates otherwise never-hand-edited trees | Repo files |
| Website repository → sibling studio repository (Plan 03-06) | Cross-repo vault writes with their own history and review | Invite URL |
| Deployed site → third-party scrapers/validators (Plan 03-06) | Discord and W3C fetch published pages | Public pages |

No auth, no session, no user input, no database, no server — statically prerendered site on
GitHub Pages. Content is git-tracked via the studio-side promote pipeline.

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-03-SC | Tampering | npm install of `@astrojs/rss`, `sanitize-html` | high | mitigate | Legitimacy audit + blocking human checkpoint (03-01 Task 1); exact pins verified in package.json (`4.0.19`, `2.17.6`) | closed |
| T-03-01 | Tampering | `BaseLayout.astro` interpolated `content=` values | medium | mitigate | Plain Astro `{expr}` attribute interpolation; `escapeHtml` absent from BaseLayout (grep 0) | closed |
| T-03-02 | Tampering / EoP | `content:encoded` payload in `src/pages/rss.xml.ts` | high | mitigate | `sanitize-html@2.17.6`, defaults + `img` only; style/script/iframe/object/embed and event handlers excluded (verified `rss.xml.ts:42-49`) | closed |
| T-03-03 | Tampering | Discord links, first `target="_blank"` | medium | mitigate | `rel="noopener noreferrer"` on both links; harness asserts 2 per page across 86 pages | closed |
| T-03-04a | Spoofing | Published invite URL (03-01) | low | accept | Git-tracked constant, reviewed at checkpoint, public by design | closed |
| T-03-04b | Spoofing | `transformTags` URL rewriter (03-02) | medium | mitigate | Rebases only `/`-prefixed values against config site; passes through absolute/fragment; throws naming the entry otherwise | closed |
| T-03-05 | Info disclosure | New 03-01 artifacts | low | accept | No secret, env var, or user data read; invite intentionally public | closed |
| T-03-06 | Tampering | Channel `customData` interpolation | low | mitigate | Only `FEED_LANGUAGE` constant + `new URL`-composed `feedUrl` (verified `rss.xml.ts:94`) | closed |
| T-03-07 | Info disclosure | Feed exposing draft content | medium | mitigate | Shared `isVisible` guard on the same collection query (verified `rss.xml.ts:61`); trap-and-restore draft fixture in harness | closed |
| T-03-08 | DoS | Unbounded feed growth | low | accept | Uncapped by decision at 9 items; static file, no per-request cost | closed |
| T-03-09 | Spoofing | `lookupHero` path-to-URL resolution | medium | mitigate | Basename-keyed map over fixed eager glob; no filesystem read; miss throws (verified `hero-image.ts:30`) | closed |
| T-03-10 | Tampering | Mistaken promote silently switching advertised image | medium | mitigate | D-48 loud-fail names post + path; never downgrades to default card; harness fixture, two legs | closed |
| T-03-11 | Info disclosure | Eager glob emitting all asset-dir PNGs | low | accept | Directory holds two already-public engine plots | closed |
| T-03-12 | Tampering | Extractor output reaching attributes (03-04) | medium | mitigate | Extractor strips markers, never emits HTML; single site-wide escaping site unchanged | closed |
| T-03-13 | Repudiation | Fabricated publication timestamps | medium | mitigate | `article:published_time` on exactly 9 announcement pages; negative checks over both dateless trees | closed |
| T-03-14 | Tampering | Fixtures mutating `devlog/` and `src/lib/site.mjs` | high | mitigate | EXIT trap installed before mutation; explicit restore on both branches; 4 porcelain assertions + final clean rebuild | closed |
| T-03-15 | Tampering | Silent embed blanking passing presence greps | high | mitigate | `og:image` resolved to a real dist/ file; mutation check 2 exits 1 | closed |
| T-03-16 | DoS | Network-dependent local assertion | medium | mitigate | Zero network clients in harness (grep 0 for curl/wget/validator.w3.org) | closed |
| T-03-17 | Repudiation | Vacuous harness | high | mitigate | Four mutation checks with recorded non-zero exits in 03-05 SUMMARY | closed |
| T-03-18 | Tampering | Cross-repo writes into `../studio` (Plan 03-06) | high | mitigate | Three literal-matched single-line replacements + numstat assertion — **deferred: plan 03-06 not executed** | open |
| T-03-19 | Spoofing | Vault invite diverging from site constant (Plan 03-06) | medium | mitigate | Byte-identical comparison against module export — **deferred: plan 03-06 not executed** | open — below high threshold (non-blocking) |
| T-03-20 | Info disclosure | Network probes from automated task (Plan 03-06) | low | accept | Public static assets only, no credential | closed |
| T-03-21 | Repudiation | Stale deployment certifying wrong build (Plan 03-06) | medium | mitigate | Deploy-run polling to `success` + live feed item-count re-probe — **deferred: plan 03-06 not executed** | open — below high threshold (non-blocking) |
| T-03-22 | DoS | Harness depending on third-party validator | low | mitigate | W3C run stays a human step; offline half automated in 03-05 (verified) | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on (high) count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Deferred Threats (Plan 03-06)

T-03-18, T-03-19 and T-03-21 guard actions that only exist inside Plan 03-06 (studio-vault
invite recording, cross-repo commit hygiene, deploy-freshness polling). The plan is
`autonomous: false` and has no SUMMARY — the guarded components do not exist yet, so there is
nothing to verify. Decision (user, 2026-08-11): defer verification to 03-06 execution; the
mitigations are baked into that plan's own acceptance criteria. Re-run `/gsd-secure-phase 3`
after 03-06 executes to close them.

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-03-01 | T-03-04a | Invite URL is a reviewed, git-tracked, intentionally public constant with no runtime substitution path | plan 03-01 register (user-approved) | 2026-08-11 |
| AR-03-02 | T-03-05 | No secret, env var, or user data in scope | plan 03-01 register (user-approved) | 2026-08-11 |
| AR-03-03 | T-03-08 | Feed uncapped by decision at 9 items; static file | plan 03-02 register (user-approved) | 2026-08-11 |
| AR-03-04 | T-03-11 | Asset directory holds only already-public engine plots | plan 03-03 register (user-approved) | 2026-08-11 |
| AR-03-05 | T-03-20 | Probes hit public static assets only, no credential used | plan 03-06 register (user-approved) | 2026-08-11 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-11 | 24 | 21 | 3 (1 blocking; 3 deferred to Plan 03-06) | secure-phase L1 orchestrator audit |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [ ] `threats_open: 0` confirmed — 1 blocking threat (T-03-18) deferred to Plan 03-06
- [ ] `status: verified` set in frontmatter

**Approval:** pending — re-run `/gsd-secure-phase 3` after Plan 03-06 executes

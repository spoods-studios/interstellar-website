# Milestones

## v1.0 Launch (Shipped: 2026-08-11)

**Phases completed:** 4 phases, 21 plans, 57 tasks
**Stats:** 186 commits, 250 files, ~48.9k insertions (mostly promoted content), 3,776 LOC site + test code
**Timeline:** 2026-07-13 (bootstrap) → 2026-08-11 (repo's first commit 2026-04-06, pre-activation content drop)
**Audit:** passed with tech debt (`milestones/v1.0-MILESTONE-AUDIT.md`) — 13/14 requirements satisfied, integration 10/10, E2E flows 10/10
**Closeout:** override_closeout — ANLT-01 live cert deliberately deferred (D-61), accepted at close

**Delivered:** The Interstellar Engine website live on GitHub Pages — permanent, linkable home for the full devblog before the audience ramp, with distribution and deploy hardening in place.

**Key accomplishments:**

- Astro 7 static site live at spoods-studios.github.io/interstellar-website — config-driven site/base URL, permissive devlog ingestion (filename-derived date/slug, frontmatter-less manifesto tolerated), least-privilege version-pinned GitHub Actions deploy on every push to main
- Full content archive rendered VOICE-untouched: 10 announcements (manifesto + M0.1–M0.8 + M1.1), 55 technical deep-dives + how-to-read legend, roadmap overview + 8 milestone detail pages, How It's Made AI-transparency page — 99 pages with bidirectional generated cross-links
- Distribution wired: RSS feed structurally drift-proof against the archive (shared collection query), full OpenGraph/Twitter metadata with per-post hero images on every route, Discord CTA in header + footer of every page — W3C feed validation zero errors, Discord embeds human-approved
- M1.1 launch post "First Burn" live at the top of archive and feed
- Deploy hardened against silent failure: build-sha freshness stamp in every page, post-deploy live-probe smoke job in deploy.yml (homepage, feed, launch post, 404-under-base, redirect stub), loud-fail schema fixtures, slug-immutability norm + `SLUG_REDIRECTS` stub mechanism
- Cookieless GoatCounter analytics mechanism shipped gated on `GOATCOUNTER_CODE` (D-61) — proven in both configured/unconfigured states

### Known Gaps

- **ANLT-01** (Phase 4): live "pageviews recorded" certification deferred by design (D-61) — GoatCounter signup → set `GOATCOUNTER_CODE` in `src/lib/site.mjs` → push → confirm dashboard (incl. 404 traffic per D-62). Mechanism fully shipped and test-proven.
- Nyquist VALIDATION.md for Phases 3–4 left `draft` (never reconciled by validate-phase) — coverage TODO, not a compliance failure.

---

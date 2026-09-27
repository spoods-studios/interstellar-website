# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Launch

**Shipped:** 2026-08-11
**Phases:** 4 | **Plans:** 21 | **Commits:** 186

### What Was Built

- Astro 7 static site on GitHub Pages: 99 pages — full devblog archive (manifesto + M0.1–M0.8 + M1.1 "First Burn"), 55 technical deep-dives + legend, roadmap tree (overview + 8 milestone pages), How It's Made
- Distribution layer: drift-proof RSS (shared collection query with the archive), OG/Twitter cards with per-post hero images, Discord CTA on every page
- Deploy hardening: build-sha freshness stamp, post-deploy live-probe smoke job, loud-fail schema fixtures, slug-immutability norm + redirect stubs
- Cookieless GoatCounter mechanism, gated on `GOATCOUNTER_CODE` (D-61)

### What Worked

- Shared-module reuse as a structural guarantee: `isVisible`/`sortEntriesNewestFirst` shared between archive and feed made drift impossible rather than tested-against — the integration audit scored 10/10 largely on this pattern.
- Bash smoke harness instead of a JS test framework: `npm test` runs whole-site suites (canonical/sitemap/dead-link/zero-JS/distribution/hardening) with trap-and-restore loud-fail fixtures; zero test-framework dependency churn for a build-pipeline site.
- Honest-verifier discipline: deploy-dependent checks recorded PENDING instead of falsely passed (Phase 2's live 404, Phase 3's embed checks), then explicitly closed when deploys were provable (03-06 polled run 31501670084). Deferrals stayed visible in STATE.md instead of silently dropping.
- Content promoted byte-faithfully from studio vault with diff/cmp verification — VOICE lock held across 4 content trees and 13 promoted files without incident.

### What Was Inefficient

- GitHub Actions `degraded_performance` (2026-07-22) stalled Phase 3's deploy-dependent verification for ~3 weeks; the phase's checks were deliberately proxy-free, so nothing could close until a live deploy was provable. Mitigation existed (honest deferral), but the gap between "code done" and "phase closed" was long.
- Several Phase 3/4 SUMMARY files carry deviation text in their `one_liner` frontmatter field, which polluted the CLI-generated MILESTONES.md accomplishments list (hand-curated at close). Executor should keep `one_liner` a true one-liner.
- Phases 3–4 VALIDATION.md files were seeded but never reconciled by validate-phase (left `draft`) — Nyquist coverage TODO discovered only at milestone audit.

### Patterns Established

- Config-driven `site`/`base` in one place (`astro.config.mjs`), `NORMALIZED_BASE` for all URL composition — no literal hostnames anywhere in src/.
- Loud-fail over graceful degradation: schema violations, unresolvable hero refs, and misconfigured constants stop the build naming the offender.
- Slug immutability: promoted URLs are permanent; renames require a `SLUG_REDIRECTS` entry in the same commit (documented in CLAUDE.md + vault/conventions.md).
- Deploy success = the deploying commit's own SHA served in live bytes; a 200 is never sufficient (tests/live-probe.sh).

### Key Lessons

1. Make invariants structural (shared modules, separate collections) instead of asserted — the checks then exist to prove wiring, not to hold it together.
2. Design deploy-dependent success criteria with a build-time proxy where possible, or accept that external outages block phase close; record honest deferrals in STATE.md so they resurface.
3. Run validate-phase reconciliation at phase close, not milestone close — draft VALIDATION.md files are cheap to promote in-phase and noisy to discover later.

### Cost Observations

- Model mix (config): opus planning, sonnet execution/review/research, haiku mapping/docs; fable-5 debug.
- Sessions: multi-session across 2026-07-13 → 2026-08-11 (~29 days wall clock).
- Notable: zero runtime JS shipped; zero new dependencies in Phase 4; content promotion (~48.9k insertions) dwarfed site code (3,776 LOC).

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v1.0 | 4 | 21 | First milestone — established bash smoke-harness + honest-deferral workflow |

### Cumulative Quality

| Milestone | Test Suites | Zero-Dep Additions |
|-----------|-------------|-------------------|
| v1.0 | 9 smoke suites + unit suite (`npm test`) | Phase 4 shipped with zero new dependencies |

### Top Lessons (Verified Across Milestones)

1. (Single milestone so far — candidates above await cross-validation.)

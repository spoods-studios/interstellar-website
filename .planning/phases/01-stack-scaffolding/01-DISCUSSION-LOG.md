# Phase 1: Stack & Scaffolding - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 1-Stack & Scaffolding
**Areas discussed:** Manifesto frontmatter, Scaffold starting point, Repo layout, Phase-1 page content, Deploy trigger scope, Malformed-filename policy, CI beyond deploy, Astro version pinning

---

## Manifesto frontmatter

| Option | Description | Selected |
|--------|-------------|----------|
| Filename fallback only | Never touch the file; date/slug from filename, title from first H1; keeps devlog/ untouchable absolute | ✓ |
| Backfill frontmatter | One-time edit adding _TEMPLATE.md frontmatter to the manifesto | |
| Backfill upstream in studio | Re-promote from studio with frontmatter; adds cross-repo coordination | |

**User's choice:** Filename fallback only
**Notes:** Follow-up on schema breadth — user chose mirroring the FULL studio _TEMPLATE.md field set as optional fields (validated when present, nothing required) over a minimal title/date-only schema.

---

## Scaffold starting point

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal + manual collections | Empty create-astro template, Content Collections wired by hand — only code the phase demands | ✓ |
| Blog template, strip down | Ships posts collection/RSS/layouts but with sample content and opinions to delete | |
| You decide | Claude picks at planning time | |

**User's choice:** Minimal + manual collections
**Notes:** Follow-up on package manager — npm chosen over pnpm (zero extra CI setup, default withastro/action path).

---

## Repo layout

| Option | Description | Selected |
|--------|-------------|----------|
| Repo root | Astro files beside devlog/, vault/, .planning/; loader reads ./devlog/ directly; zero Actions path config | ✓ |
| site/ subdirectory | Cleaner content/code separation but adds path input + ../devlog/ relative seam | |

**User's choice:** Repo root
**Notes:** User paused to ask what Astro is before answering — explained (static site generator locked at bootstrap). No change to the decision.

---

## Phase-1 page content

| Option | Description | Selected |
|--------|-------------|----------|
| Ingestion proof list | Unstyled list of devlog entries (title + fallback date) — proves CONT-01 live | ✓ |
| Bare placeholder | Static "coming soon"; proves deploy only | |
| Mini pre-archive | Placeholder + rendered manifesto; pulls Phase-2 templating forward | |

**User's choice:** Ingestion proof list

---

## Deploy trigger scope

| Option | Description | Selected |
|--------|-------------|----------|
| Every push to main | No path filters; zero filter-miss risk; wasted Actions minutes on planning commits accepted | ✓ |
| Path-filtered | Saves minutes; forgotten path = silent non-deploy | |
| Filtered + manual dispatch | Filters plus force-deploy button; still a silent-failure mode | |

**User's choice:** Every push to main

---

## Malformed-filename policy

| Option | Description | Selected |
|--------|-------------|----------|
| Fail build loudly now | Loader throws naming the file; pulls one SITE-03 slice forward | ✓ |
| Skip with build warning | Green build, warning nobody reads — silent-skip anti-goal | |
| You decide | Claude picks at planning time | |

**User's choice:** Fail build loudly now
**Notes:** Corollary captured — non-post .md files (e.g. _TEMPLATE.md strays) need explicit exclusion rules.

---

## CI beyond deploy

| Option | Description | Selected |
|--------|-------------|----------|
| Deploy-only | Single build+deploy workflow; solo push-to-main flow has nothing for a PR check to guard | ✓ |
| Also PR build check | Unused until a PR flow exists | |

**User's choice:** Deploy-only

---

## Astro version pinning

| Option | Description | Selected |
|--------|-------------|----------|
| Caret + lockfile | ^7.x ranges, package-lock.json, npm ci in CI; deliberate upgrades only | ✓ |
| Exact pin | Redundant with npm ci; manual bumps for patches | |

**User's choice:** Caret + lockfile

## Claude's Discretion

- Content Collections loader mechanics (glob loader config, slug derivation) — verify against current Astro docs at planning time
- Astro config details: TypeScript strictness, .gitignore additions, dist/ handling

## Deferred Ideas

- PR build-check workflow — only if a PR flow to this repo ever starts
- Full loud-fail hardening + post-deploy smoke check — Phase 4 (SITE-03)
- Syntax highlighting / KaTeX — v2 (CONT-07); verify Astro support during setup, implement later

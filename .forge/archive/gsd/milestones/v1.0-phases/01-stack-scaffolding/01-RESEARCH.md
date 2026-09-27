# Phase 1: Stack & Scaffolding - Research

**Researched:** 2026-07-14
**Domain:** Astro static-site scaffolding, Content Layer API (glob loader), GitHub Actions → GitHub Pages deploy
**Confidence:** MEDIUM (core facts VERIFIED via registry/API tools this session; API mechanics CITED from official docs via WebFetch since the Context7 MCP tool was unavailable in this environment — no exa/brave/tavily/firecrawl providers configured either, per `.planning/config.json`)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Manifesto frontmatter & schema**
- D-01: Filename fallback only — never edit `devlog/` files. The frontmatter-less manifesto stays as-is; date and slug derive from the `YYYY-MM-DD-slug.md` filename, title from the first `# H1`. No backfill, local or upstream.
- D-02: Content schema mirrors the FULL studio `_TEMPLATE.md` frontmatter set (`milestone`, `title`, `date`, `status`, `discord_post_id`, `audience`, `hero_visual`) with every field optional. Fields validate when present (typos caught); nothing is required. Later phases get typed access to `hero_visual` etc. for free.

**Scaffold**
- D-03: Minimal/empty `create astro` template; Content Collections, layout, and pages wired manually — only code the phase demands, nothing to strip. NOT the blog template.
- D-04: npm as package manager (`package-lock.json` committed). Default `withastro/action` path, zero extra CI setup.
- D-05: Caret version ranges + committed lockfile; CI installs via `npm ci`. Upgrades happen only by deliberate `npm update`. No exact pins.

**Repo layout**
- D-06: Astro project lives at repo root — `package.json`, `astro.config.mjs`, `src/` beside existing `devlog/`, `vault/`, `.planning/`. Content loader reads `./devlog/` directly (external-path loader, since content is outside `src/content/`). No `site/` subdirectory, no path inputs in the Actions workflow.

**Phase-1 page content**
- D-07: The deployed trivial page is an unstyled ingestion-proof list: every devlog collection entry rendered as title + date (exercising the filename fallback live). Throwaway markup (~20 lines), replaced wholesale by Phase 2 templating. Not a bare placeholder, not an early archive.

**Deploy trigger & CI**
- D-08: Deploy workflow triggers on EVERY push to main — no path filters. GSD's frequent `.planning/`/`vault/` commits will each burn ~1-2 min of free Actions quota; accepted. Rationale: a forgotten path filter = silent non-deploy, the exact failure mode Phase 4 exists to prevent.
- D-09: Deploy-only CI in Phase 1 — single workflow (build + deploy on push to main). No PR build check; solo push-to-main flow has nothing for it to guard. Revisit if PR flow ever starts.

**Malformed-content policy**
- D-10: A `devlog/*.md` file with neither frontmatter nor a parseable `YYYY-MM-DD-slug.md` filename date FAILS THE BUILD LOUDLY in Phase 1, with an error naming the offending file. This pulls one slice of SITE-03 forward deliberately. Corollary: non-post `.md` files (e.g. a stray `_TEMPLATE.md`) need an explicit exclusion rule, not silent tolerance.

### Claude's Discretion
- Exact Content Collections loader mechanics (glob loader config, slug derivation implementation) — verify against current Astro docs at planning time; the research example in stack docs is illustrative, not canonical.
- Astro config details (TypeScript strictness, `.gitignore` additions, `dist/` handling) — standard defaults, planner's call.

### Deferred Ideas (OUT OF SCOPE)
- PR build-check workflow — add only if a PR flow to this repo ever starts (D-09)
- Loud-fail hardening beyond the malformed-filename case + post-deploy smoke check — Phase 4 (SITE-03)
- Syntax highlighting / KaTeX support check — v2 (CONT-07), verify Astro support during setup but implement later
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SITE-01 | Site builds with Astro and deploys to GitHub Pages via GitHub Actions on every push to main | Verified official `withastro/action` + `actions/deploy-pages` workflow shape; confirmed current action tags via GitHub Releases API; **confirmed this session that GitHub Pages was NOT yet enabled on the repo and enabled it via `gh api -X POST repos/.../pages -f build_type=workflow`** — the manual "Settings → Pages → Source: GitHub Actions" prerequisite is already done, planner does not need a task for it |
| SITE-02 | Site URL/base path config-driven in one place, no hardcoded `github.io` strings | Confirmed `site`/`base` are both single `astro.config.mjs` keys; confirmed `import.meta.env.BASE_URL` (or `Astro.url`) is the documented mechanism for base-aware links so templates never hardcode the domain; confirmed the exact target URL is `https://spoods-studios.github.io/interstellar-website/` (base `/interstellar-website`) |
| CONT-01 | Permissive devlog ingestion — full frontmatter honored, missing frontmatter tolerated via filename-derived date/slug | Confirmed `glob()` loader `generateId({entry, base, data})` signature for filename-based slug/date derivation; confirmed all-`.optional()` Zod schema pattern; identified a load-bearing pitfall (silent empty collection on bad `base` path) that directly threatens D-10's loud-fail requirement if not explicitly guarded against |

</phase_requirements>

## Summary

Phase 1 is infrastructure, not content: stand up an Astro project at the repo root, wire a Content Layer `glob()` loader that reads `./devlog/` directly (external to `src/content/`), define an all-optional Zod schema mirroring the studio template's frontmatter fields, derive date/slug from the `YYYY-MM-DD-slug.md` filename when frontmatter is absent, render a throwaway list page, and deploy via the official `withastro/action` + `actions/deploy-pages` GitHub Actions workflow on every push to `main`.

The stack choice (Astro 7.0.9) was already locked in a prior research session and is recorded in this repo's `.claude/CLAUDE.md` — this research does not re-litigate it, only fills in the Content Layer API mechanics and deploy-pipeline details flagged as open questions in `STATE.md`. Two verified findings materially change the plan: (1) **GitHub Pages was not yet enabled on this repo** — it has been enabled this session via the GitHub API with `build_type=workflow`, confirming the exact live target URL will be `https://spoods-studios.github.io/interstellar-website/`; (2) **`npm create astro@latest .` will hit a "directory not empty" prompt** because the repo root already contains `CLAUDE.md`, `README.md`, `RUNBOOK.md`, `devlog/`, `vault/`, `.planning/` — the planner should route around the CLI's empty-directory scaffold entirely and use Astro's documented manual-install steps instead (which is also a closer match to D-03's "wired manually" intent).

The single highest-risk technical fact for CONT-01/D-10 is that Astro's `glob()` loader does **not** error on a misconfigured `base` path — it silently returns an empty collection with only a console warning. Because D-10 requires loud failure on malformed content, the plan must include an explicit guard (e.g., assert the collection is non-empty, or assert the known manifesto file is present) rather than relying on Astro's default behavior to catch a broken loader path.

**Primary recommendation:** Scaffold Astro manually at repo root (skip `create-astro`'s CLI entirely — see pitfall below), define a single all-optional content schema with `generateId`-based filename fallback reading `./devlog/`, add an explicit non-empty-collection assertion, and use the official `withastro/action`+`actions/deploy-pages` two-job workflow with `site: 'https://spoods-studios.github.io'` / `base: '/interstellar-website'` — both values live only in `astro.config.mjs`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Markdown ingestion & schema validation | Build tier (Astro Content Layer, build-time) | — | No server exists; Content Collections resolve entirely during `astro build`, not at request time |
| Static HTML generation | Build tier (Astro SSG) | CDN/Static (GitHub Pages) | Astro emits fully pre-rendered HTML; GitHub Pages only serves the resulting static files, it does no rendering |
| Hosting & serving | CDN/Static (GitHub Pages) | — | Confirmed via `gh api repos/.../pages`: `build_type: "workflow"`, static file serving only, no origin compute |
| CI build+deploy orchestration | CI/Build tier (GitHub Actions) | — | `withastro/action` runs `npm ci && astro build` on the runner; `actions/deploy-pages` uploads the artifact — no app-tier or DB involved anywhere in this pipeline |
| URL/base-path resolution | Build tier (`astro.config.mjs`) | Browser (consumes the baked-in `import.meta.env.BASE_URL` value at render time) | Single source of truth set once at build time; the browser only ever sees the already-resolved static links |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|---------------|
| astro | 7.0.9 `[VERIFIED: npm registry, npm view astro version, this session]` | Static site generator / Content Layer | Already locked in `.claude/CLAUDE.md` from prior stack research; re-verified current this session |
| Node.js | 24.15.0 (already installed, matches user's fnm default) `[VERIFIED: node --version, this session]` | Astro build runtime | Confirmed installed and satisfies Astro's engine floor with large margin |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| typescript | 5.9.x current `[VERIFIED: npm registry, npm view typescript version, this session]` | Optional type-checking for `astro.config.mjs`/`tsconfig.json` | Discretion item per CONTEXT.md; if added, `tsconfig.json` extending `astro/tsconfigs/base` is the documented minimal setup `[CITED: docs.astro.build/en/install-and-setup/]` |

### Alternatives Considered
Not re-explored — the stack choice (Astro over Eleventy/Hugo/Jekyll/Zola) was already made and documented in `.claude/CLAUDE.md` from a prior research session; CONTEXT.md does not reopen it.

**Installation (manual — see Pitfall 1 for why NOT to use `npm create astro@latest .`):**
```bash
npm init --yes
npm install astro
# then hand-write astro.config.mjs, src/pages/index.astro, tsconfig.json (see Code Examples)
```

**Version verification:** confirmed this session —
```bash
npm view astro version        # 7.0.9
npm view typescript version   # 5.9.x (current at research time)
```

## Package Legitimacy Audit

| Package | Registry | Age (latest publish) | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|----|-----------|-------------|---------|-------------|
| astro | npm | latest version published 2026-07-13 `[VERIFIED: package-legitimacy seam]` | 3.92M/week `[VERIFIED: package-legitimacy seam]` | github.com/withastro/astro | SUS ("too-new") | **Flagged — false positive, see note** |
| typescript | npm | latest version published 2026-07-08 `[VERIFIED: package-legitimacy seam]` | 226.1M/week `[VERIFIED: package-legitimacy seam]` | github.com/microsoft/TypeScript | SUS ("too-new") | **Flagged — false positive, see note** |

**Note on the "too-new" verdicts:** the `package-legitimacy check` seam's "too-new" signal fires on the *latest version's* publish recency, not the package's first-published date or overall trust profile. Both `astro` (withastro org, ~3.9M weekly downloads) and `typescript` (Microsoft, 226M weekly downloads) are extremely well-established packages that happen to have shipped a routine release in the last ~1-2 weeks — this is normal for actively-maintained tooling, not a slopsquat signal. Per protocol, both are kept but tagged `astro` [WARNING: flagged as suspicious by the legitimacy gate — "too-new" here reflects a routine recent release of a well-established package (3.9M weekly downloads, official withastro/astro repo), not package age; low-risk, but the planner should still add a lightweight `checkpoint:human-verify` before `npm install astro` per protocol.] and `typescript` similarly.

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** `astro`, `typescript` — both false-positive "too-new," planner must still add a `checkpoint:human-verify` before install per protocol (recommend making it a fast one-line confirmation, not a deep audit, given the note above).

## Architecture Patterns

### System Architecture Diagram

```
[Author] --commits--> devlog/*.md (git, untouched by site layer)
                              |
                              v
[git push to main] --triggers--> [GitHub Actions: build job]
                              |
                              v
                   withastro/action (npm ci + astro build)
                              |
                    +---------+---------+
                    |                   |
         [Content Layer: glob()   [src/pages/index.astro
          loader reads ./devlog/]  renders collection --
                    |               title + date list]
                    v                   |
         [Zod schema: all fields   <----+
          optional; generateId()
          derives slug/date from
          filename when frontmatter
          absent; assert non-empty
          collection or throw]
                    |
                    v
          dist/ (static HTML/CSS/JS)
                    |
                    v
       [GitHub Actions: deploy job]
                    |
                    v
         actions/deploy-pages (uploads
         artifact to Pages environment)
                    |
                    v
   https://spoods-studios.github.io/interstellar-website/
                    |
                    v
              [Visitor's browser]
```

### Recommended Project Structure
```
/ (repo root — D-06: no site/ subdirectory)
├── package.json           # npm, caret ranges (D-05)
├── package-lock.json      # committed (D-04)
├── astro.config.mjs       # site + base, the ONLY URL config location (SITE-02)
├── tsconfig.json          # extends astro/tsconfigs/base (discretion)
├── .gitignore             # node_modules/, dist/, .astro/
├── src/
│   ├── content.config.ts  # defineCollection: glob loader -> ../devlog, schema, generateId
│   └── pages/
│       └── index.astro    # throwaway proof list (D-07)
├── devlog/                 # EXISTING, untouched, read-only input (D-01, D-06)
├── vault/                  # EXISTING, unrelated to Astro
├── .planning/               # EXISTING, unrelated to Astro
└── .github/
    └── workflows/
        └── deploy.yml       # build + deploy on every push to main (D-08, D-09)
```

### Pattern 1: External-path Content Collection with permissive schema
**What:** A single `devlog` collection whose loader reads `./devlog/` (outside `src/content/`), with every schema field optional and a filename-based fallback for date/slug.
**When to use:** Exactly this phase's CONT-01 requirement — frontmatter-less files must ingest without failing.
**Example:**
```typescript
// src/content.config.ts
// Source: docs.astro.build/en/reference/content-loader-reference/ (glob loader signature),
// docs.astro.build/en/guides/content-collections/ (defineCollection/schema pattern)
// [CITED: docs.astro.build — generateId({entry, base, data}) signature confirmed;
//  exact regex/derivation logic below is this session's synthesis, not copied from docs]
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const FILENAME_RE = /^(\d{4}-\d{2}-\d{2})-(.+)\.md$/;

const devlog = defineCollection({
  loader: glob({
    pattern: ['**/*.md', '!_TEMPLATE.md'], // negation excludes stray template files
    base: '../devlog',                      // relative to src/content.config.ts's dir
    generateId: ({ entry }) => {
      const match = entry.match(FILENAME_RE);
      if (!match) {
        // D-10: loud failure naming the offending file
        throw new Error(
          `devlog/${entry}: filename must match YYYY-MM-DD-slug.md (no valid frontmatter date/slug fallback found)`
        );
      }
      return match[2]; // slug
    },
  }),
  schema: z.object({
    milestone: z.string().optional(),
    title: z.string().optional(),
    date: z.coerce.date().optional(),
    status: z.enum(['draft', 'published']).optional(),
    discord_post_id: z.string().optional(),
    audience: z.string().optional(),
    hero_visual: z.string().optional(),
  }),
});

export const collections = { devlog };
```

### Pattern 2: Base-path-safe links (SITE-02)
**What:** Never hardcode `/interstellar-website` or `github.io` in a template; always resolve through the build config.
**When to use:** Every internal `<a href>` and asset reference in `src/pages/index.astro`.
**Example:**
```astro
---
// Source: docs.astro.build/en/reference/configuration-reference/ [CITED]
const base = import.meta.env.BASE_URL;
---
<a href={`${base}/`}>Home</a>
```

### Anti-Patterns to Avoid
- **Hardcoding `https://spoods-studios.github.io/interstellar-website` in a template string:** defeats SITE-02 outright — must resolve via `import.meta.env.BASE_URL` / `astro.config.mjs` so a future custom-domain switch (DIST-04, v2) touches one file.
- **Trusting the glob loader to error on a bad `base` path:** it doesn't (see Pitfall 2) — add an explicit assertion.
- **Scaffolding with `npm create astro@latest .` in this repo:** the directory already has `CLAUDE.md`, `devlog/`, `vault/`, `.planning/` — see Pitfall 1.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Markdown/frontmatter parsing | Custom `gray-matter` + manual glob-and-parse loop | Astro's built-in Content Layer `glob()` loader | Handles caching, the Astro dev-server data store, and typed `getCollection()` access for free; a hand-rolled loader reimplements this with none of the tooling integration |
| Deploying to GitHub Pages | Custom `gh-pages` branch push script / rsync | `withastro/action` + `actions/deploy-pages` | Official, actively maintained, handles the artifact upload API correctly (including the `pages: write`/`id-token: write` OIDC flow) — a hand-rolled branch-push deploy is a common source of stale-cache and permission bugs |
| Base-path-aware link generation | Manual string concatenation of `/interstellar-website` into every href | `import.meta.env.BASE_URL` / `Astro.url` | This IS the mechanism SITE-02 requires — hand-rolling it as a template-local constant recreates the exact hardcoding problem SITE-02 exists to prevent |

**Key insight:** every "don't hand-roll" item here maps directly to a phase requirement (CONT-01 → loader, SITE-01 → deploy action, SITE-02 → base-path helper) — this phase is small enough that hand-rolling any of them would be net-negative code for zero benefit.

## Common Pitfalls

### Pitfall 1: `create-astro` CLI refuses to scaffold into this repo's root
**What goes wrong:** `npm create astro@latest .` prompts "Directory not empty. Continue?" (and in at least one documented case on Windows, answering `y` throws) because `create-astro` expects an empty target directory.
**Why it happens:** The repo root already contains `CLAUDE.md`, `README.md`, `RUNBOOK.md`, `devlog/`, `vault/`, `.planning/`, `.claude/`, `.impeccable/` `[VERIFIED: this session, ls -la /home/spoods/Projects/spoods-studios/interstellar-website/]` — D-06 requires the Astro project at repo root, not a subdirectory, so this collision is guaranteed, not hypothetical.
**How to avoid:** Skip the CLI. Use Astro's documented manual-install steps (`npm init --yes && npm install astro`, then hand-write `astro.config.mjs`, `src/pages/index.astro`, `tsconfig.json`) `[CITED: docs.astro.build/en/install-and-setup/]`. This is also closer to D-03's intent ("wired manually... only code the phase demands").
**Warning signs:** Any plan task that literally runs `npm create astro@latest .` in this repo should be treated as a planning defect, not "run and see."

### Pitfall 2: A misconfigured loader `base` path fails silently, not loudly
**What goes wrong:** If the `glob()` loader's `base` option points at the wrong directory (e.g. a typo, or a relative-path miscalculation from `src/content.config.ts`), Astro does not throw — it returns an empty collection and logs a warning that ("collection does not exist or is empty") is misleading about the actual cause.
**Why it happens:** Documented as a known weak-validation gap in the Content Layer glob loader `[LOW confidence — GitHub issue withastro/astro#12795, single WebSearch round, not independently cross-verified against a second source]`.
**How to avoid:** Add an explicit runtime assertion after the loader resolves (e.g. in `src/pages/index.astro` or a build-time check: `if (collection.length === 0) throw new Error(...)`), since D-10 requires the build to fail loudly on malformed/absent content and Astro's default behavior for this specific failure mode does not satisfy that on its own.
**Warning signs:** `astro build` succeeds but the deployed page shows zero devlog entries — this is the silent-failure signature to test for explicitly during phase verification, not just "build exits 0."

### Pitfall 3: Hardcoded `base`/URL strings creeping into templates
**What goes wrong:** A developer writes `<a href="/interstellar-website/about">` directly instead of using `import.meta.env.BASE_URL`, which technically works today but violates SITE-02 and breaks silently the moment the base path or domain changes.
**Why it happens:** `import.meta.env.BASE_URL` isn't the obvious first instinct coming from other frameworks; Astro's own docs show absolute-domain examples first.
**How to avoid:** Standardize on `import.meta.env.BASE_URL` (or `new URL('./relative', Astro.url)`) from the very first page (`src/pages/index.astro`, this phase's only page) so there is no precedent to "clean up later."
**Warning signs:** `grep -rn "github.io\|/interstellar-website" src/` returning any hits outside `astro.config.mjs` is a direct SITE-02 violation — recommend this grep as an explicit verification step.

### Pitfall 4: GitHub Pages not enabled / wrong deploy job permissions
**What goes wrong:** `actions/deploy-pages` fails at deploy time (not build time) if the repo's Pages feature isn't enabled with `build_type: workflow`, or if the workflow's `permissions` block is missing `pages: write` / `id-token: write`.
**Why it happens:** GitHub Pages has two independent "sources" (legacy branch-based vs. Actions-based); a repo can exist for a long time with Pages simply never turned on.
**How to avoid:** **Already resolved this session** — confirmed via `gh api repos/spoods-studios/interstellar-website` that `has_pages` was `false`, then enabled it via `gh api -X POST repos/spoods-studios/interstellar-website/pages -f build_type=workflow`, which returned `html_url: "https://spoods-studios.github.io/interstellar-website/"` `[VERIFIED: GitHub API, this session]`. The planner does not need a task to enable Pages; it only needs the workflow's `permissions` block to match the official example (see Code Examples) and `astro.config.mjs` to use `site: 'https://spoods-studios.github.io'` / `base: '/interstellar-website'`.
**Warning signs:** A deploy job that succeeds on `actions/checkout`/`withastro/action` but fails specifically on the `actions/deploy-pages` step with a permissions or "Pages not enabled" error would indicate this regressed somehow (e.g., Pages got disabled again) — not expected, but worth a glance on first real deploy.

## Code Examples

### GitHub Actions deploy workflow
```yaml
# .github/workflows/deploy.yml
# Source: docs.astro.build/en/guides/deploy/github/ [CITED]
# Action versions verified this session via GitHub Releases API [VERIFIED]:
#   withastro/action v6.1.2, actions/checkout v7.0.0, actions/deploy-pages v5.0.0
name: Deploy to GitHub Pages
on:
  push:
    branches: [main]   # D-08: no path filters, every push deploys
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: withastro/action@v6

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v5
```

### astro.config.mjs (SITE-02 — the one config location)
```javascript
// Source: docs.astro.build/en/reference/configuration-reference/ [CITED]
// Target URL confirmed this session by enabling GitHub Pages via GitHub API [VERIFIED]
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://spoods-studios.github.io',
  base: '/interstellar-website',
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-------------------|---------------|--------|
| Legacy Content Collections (`src/content/config.ts`, files required to live under `src/content/`) | Content Layer API (`src/content.config.ts`, `loader:` property, external-path support via `glob()`) | Astro 5 introduced Content Layer; legacy collections removed entirely in Astro 6 `[CITED: docs.astro.build error-reference notes "legacy content collections... removed in Astro 6"]` | Directly enables D-06 (reading `./devlog/` from outside `src/content/`) — this would not have been straightforward on the pre-5 API |

**Deprecated/outdated:** The `InvalidContentEntryFrontmatterError` reference page itself is documented as applying only to the removed legacy collections system — not relevant to this phase's `glob()`-loader-based approach, which instead surfaces `InvalidContentEntryDataError`-style Zod validation failures.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | `glob()` pattern array negation (`['**/*.md', '!_TEMPLATE.md']`) is supported by Astro's loader the same way plain micromatch supports it | Architecture Patterns, Pattern 1 | If wrong, the exclusion silently doesn't exclude (or throws at config-parse time) — low blast radius since there is currently no `_TEMPLATE.md` inside `devlog/` to trigger it yet, but should be smoke-tested once any non-post file lands in `devlog/` |
| A2 | `InvalidContentEntryDataError` (Content Layer) causes `astro build` to exit non-zero, not just log a warning | Common Pitfalls, State of the Art | If wrong, D-10's "fails the build loudly" requirement is not actually satisfied by schema validation alone and needs an explicit build-script check; recommend the planner add a smoke-test task that intentionally breaks a fixture file and confirms non-zero exit, rather than trusting this claim uncross-checked |
| A3 | `import.meta.env.BASE_URL` is available and correctly populated in both `astro dev` and `astro build` (not build-only) | Architecture Patterns, Pattern 2 | If wrong (dev works but base differs from what deploys), a broken-link bug could ship unnoticed locally; low risk since D-07's page is trivial and Phase 1's success criteria include loading the actual deployed URL |
| A4 | `typescript` as a supporting dependency is worth adding in Phase 1 (vs. deferring type-checking entirely) | Standard Stack | Pure discretion item per CONTEXT.md; if the planner skips it, no requirement is at risk — noted only because the package-legitimacy audit covers it either way |

**If this table is empty:** N/A — see rows above.

## Open Questions (RESOLVED)

> Resolution note (2026-07-14, plan-checker pass): Question 1's residual risk (Zod schema-violation exit behavior for populated frontmatter) is SITE-03 territory — explicitly Phase 4 scope. Phase 1's D-10 negative test exercises only the custom `generateId` throw path (bad filename), which is independent of Astro's Zod error propagation, so Phase 1's claims are verified without settling this. Question 2 is dormant — `devlog/` has no non-post file to exclude yet; smoke-test the negation pattern when one first appears. Both carried as scope-boundary deferrals, not blockers.

1. **Does `InvalidContentEntryDataError` reliably produce a non-zero exit code in CI (not just a dev-server warning)?**
   - What we know: Astro's error-reference docs describe the error and name the offending collection/file; general WebSearch consensus says schema violations "throw" and block builds.
   - What's unclear: No official doc excerpt fetched this session explicitly states "the CI process exits non-zero" for this specific error class under `astro build` (as opposed to `astro dev` or `astro check`).
   - Recommendation: Treat as UNCONFIRMED (see Assumption A2) and have the planner include a verification task that deliberately introduces a bad fixture (e.g. a temp copy with garbage frontmatter or an unparseable filename) and confirms `npm run build` exits non-zero before relying on this behavior for D-10.

2. **Exact micromatch negation syntax accepted by Astro's `glob()` `pattern` option (leading `!` per array entry vs. some other exclusion syntax)**
   - What we know: micromatch itself supports `!`-prefixed negation entries in a pattern array; Astro's docs confirm micromatch is the underlying matcher.
   - What's unclear: No Astro-specific code example was found demonstrating this combination end-to-end.
   - Recommendation: Low priority for Phase 1 — `devlog/` currently contains only the one valid manifesto file, no template/non-post file to exclude yet (D-10's "corollary" about non-post files is forward-looking). If the plan needs the exclusion now for defensiveness, smoke-test it locally with a throwaway file before committing to the pattern.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|--------------|-----------|---------|----------|
| Node.js | Astro build runtime | ✓ | v24.15.0 `[VERIFIED]` | — |
| npm | Package manager (D-04) | ✓ | 11.14.0 `[VERIFIED]` | — |
| git | Version control, repo already initialized | ✓ | 2.55.0 `[VERIFIED]` | — |
| gh (GitHub CLI) | Repo/Pages API operations | ✓ | 2.94.0, authenticated as `jushyi` `[VERIFIED]` | — |
| GitHub Pages (repo feature) | SITE-01 deploy target | ✓ (enabled this session) | `build_type: workflow`, `html_url: https://spoods-studios.github.io/interstellar-website/` `[VERIFIED: GitHub API, this session]` | — |
| Repo visibility | Pages availability (public repos get Pages on any plan) | ✓ public `[VERIFIED: gh api repos/spoods-studios/interstellar-website]` | — | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none — everything needed for this phase is already present and confirmed working.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None installed `[VERIFIED: no test config/framework files found in repo listing]` — this phase is build-pipeline infrastructure, not application logic |
| Config file | none — see Wave 0 |
| Quick run command | `npm run build` (Astro's own Zod schema validation + the D-10 loud-fail guard act as the "test" for content correctness) |
| Full suite command | `npm run build` (same — there is no separate unit-test layer for a Phase 1 static scaffold) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|--------------|
| SITE-01 | Push to main triggers Actions build+deploy | smoke (CI-observed) | `git push` then `gh run watch` / `gh run list --limit 1` to confirm the workflow ran and succeeded | ❌ Wave 0 (workflow file itself is the deliverable) |
| SITE-02 | No hardcoded `github.io` string outside `astro.config.mjs` | static-check | `grep -rn "github.io\|/interstellar-website" src/ \| grep -v astro.config` (expect zero output) | ❌ Wave 0 (no `src/` yet) |
| CONT-01 | Frontmatter-less manifesto ingests without failing the build, with correct filename-derived date/slug | build-time (Zod + loader) + manual | `npm run build` (expect exit 0) then visually confirm the deployed page shows the manifesto's title + `2026-04-07` | ❌ Wave 0 (content config doesn't exist yet) |
| D-10 (malformed-content) | A file with neither frontmatter nor parseable filename date fails the build loudly, naming the file | negative smoke test | Deliberately copy a garbage-named fixture into a scratch dir (never into real `devlog/`), point a throwaway loader config at it, confirm `npm run build` exits non-zero and names the file — **do this as a one-off manual check, not a committed automated test**, since introducing a JS test framework for one assertion would be scope creep beyond what D-03/D-09 call for | N/A — deliberately not automated per MVP mode |

### Sampling Rate
- **Per task commit:** `npm run build` (fast — single Astro build, no separate test runner to install)
- **Per wave merge:** `npm run build` + the SITE-02 grep check + a live fetch of the deployed URL after the Actions run completes
- **Phase gate:** All four ROADMAP.md success criteria manually confirmed true (Actions run green, live URL loads, base-path grep clean, manifesto renders) before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `src/content.config.ts` — doesn't exist yet, is the CONT-01 deliverable itself
- [ ] `.github/workflows/deploy.yml` — doesn't exist yet, is the SITE-01 deliverable itself
- [ ] No JS test framework install needed — per MVP mode and the user's explicit "do exactly what is asked, no unrequested features" preference, introducing Vitest/etc. for a build-pipeline phase with no application logic would be scope creep. `npm run build` (which runs Astro's real Zod validation) is the correct-altitude test for this phase.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|----------------|---------|--------------------|
| V2 Authentication | No | Static site, no auth surface at all |
| V3 Session Management | No | No sessions — no server |
| V4 Access Control | No | No access-controlled resources |
| V5 Input Validation | Partial — build-time only | Zod schema on Content Collections (already the CONT-01 mechanism) validates *shape*; the actual "input" (`devlog/*.md`) is git-controlled/trusted content, not untrusted runtime user input, so this is a much lower-stakes instance of V5 than a typical web app |
| V6 Cryptography | No | No secrets, no crypto operations in this phase (Pages/Actions handle TLS transparently) |
| V10 Malicious Code / Supply Chain | Yes | Pin GitHub Actions to the tags verified this session (`withastro/action@v6`, `actions/checkout@v7`, `actions/deploy-pages@v5`) rather than `@main`; run the Package Legitimacy Audit on any new npm dependency before install (done above for `astro`/`typescript`) |
| V14 Configuration | Yes | Least-privilege Actions `permissions:` block (`contents: read`, `pages: write`, `id-token: write` — nothing broader) as shown in the official workflow; no secrets are needed for this deploy path (GitHub's OIDC token handles Pages auth) |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|-----------------------|
| Overly-broad `GITHUB_TOKEN` permissions on the deploy workflow (e.g. `permissions: write-all`) | Elevation of Privilege | Explicit least-privilege `permissions:` block, exactly as shown in Code Examples — never default to `write-all` |
| Unpinned third-party Actions (`uses: withastro/action@main`) | Tampering (supply-chain) | Pin to the verified release tags (`@v6`, `@v7`, `@v5`) rather than a floating branch ref |
| A slopsquatted/typosquatted npm package sneaking into `package.json` | Tampering | Package Legitimacy Audit (above) run for every new dependency before `npm install` |
| Content Collections schema silently accepting malformed data (relevant given all fields are `.optional()` per D-02) | Tampering / Information Disclosure (low severity here) | D-10's explicit loud-fail-on-unparseable-filename requirement is the deliberate counterbalance to an otherwise fully-permissive schema — do not weaken this in implementation |

## Sources

### Primary (HIGH confidence)
- `npm view astro version` / `npm view typescript version` — this session, npm registry
- `node --version`, `npm --version`, `git --version`, `gh --version`, `gh auth status` — this session, direct tool output
- `gh api repos/spoods-studios/interstellar-website` and `gh api -X POST .../pages -f build_type=workflow` — this session, GitHub REST API (confirmed Pages was disabled, then enabled it, confirmed the exact live URL)
- `api.github.com/repos/{withastro/action,actions/checkout,actions/deploy-pages,actions/configure-pages}/releases/latest` — this session, GitHub Releases API
- `ls -la` of repo root and `devlog/`/`vault/` — this session, direct filesystem observation (grounds Pitfall 1 and confirms D-01's manifesto file has no frontmatter)
- `gsd-tools query package-legitimacy check --ecosystem npm astro typescript` — this session

### Secondary (MEDIUM confidence)
- `docs.astro.build/en/guides/content-collections/` — fetched via WebFetch this session (glob loader base example, all-optional schema pattern)
- `docs.astro.build/en/reference/content-loader-reference/` — fetched via WebFetch this session (glob loader full parameter list, generateId signature)
- `docs.astro.build/en/reference/configuration-reference/` — fetched via WebFetch this session (site/base config, `import.meta.env.BASE_URL`)
- `docs.astro.build/en/guides/deploy/github/` — fetched via WebFetch this session (official workflow YAML shape)
- `docs.astro.build/en/install-and-setup/` and `github.com/withastro/astro/blob/main/packages/create-astro/README.md` — fetched via WebFetch this session (manual install steps, CLI flags)
- **Note on confidence tier:** the project's `classify-confidence` seam does not currently register `webfetch` as an "official" authority provider (only `context7`/`ref` get that), so it technically returns LOW for these fetches; this research applies the `[CITED: url]`/MEDIUM convention instead because the fetched content is verifiably from `docs.astro.build` (Astro's own official documentation domain), consistent with how the prior stack-research session in this same repo's `.claude/CLAUDE.md` tagged equivalent official-docs WebFetch results. Context7/Ref/Exa/Brave/Tavily/Firecrawl MCP tools were unavailable in this session and `.planning/config.json` has all of `exa_search`/`brave_search`/`firecrawl`/`tavily_search` set to `false`, so WebFetch/WebSearch were the only available fetch mechanisms.

### Tertiary (LOW confidence)
- WebSearch: "Astro content collections build fails schema validation error exit code CI" — single round, general consensus only, not independently re-verified against an official source (see Open Question 1 / Assumption A2)
- WebSearch: "micromatch negation pattern array exclude file glob" — single round, corroborated by micromatch's own README/issues but not by an Astro-specific worked example (see Open Question 2 / Assumption A1)
- `github.com/withastro/astro/issues/12795` (weak glob-loader base-path validation) — single WebSearch-sourced GitHub issue, not cross-checked against a second independent source, but directly informs Pitfall 2

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versions and environment facts directly tool-verified this session
- Architecture: MEDIUM — official docs fetched and quoted, but via WebFetch (not the Context7/Ref MCP path this harness treats as full "official" authority) since no docs-MCP providers were configured/available
- Pitfalls: MEDIUM/LOW mixed — Pitfall 1 and 4 are HIGH-confidence (directly observed this session); Pitfall 2 and 3 rest on a single WebSearch round each and are flagged accordingly in the Assumptions Log

**Research date:** 2026-07-14
**Valid until:** 2026-08-13 (30 days — Astro ships frequently but the Content Layer API and GitHub Pages deploy mechanics are stable; re-verify action tags/astro version if planning is delayed past this window)

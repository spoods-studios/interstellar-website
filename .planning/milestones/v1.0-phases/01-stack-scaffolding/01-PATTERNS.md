# Phase 1: Stack & Scaffolding - Pattern Map

**Mapped:** 2026-07-14
**Files analyzed:** 6 (new)
**Analogs found:** 0 in-repo / 6 — repo is greenfield for code (no `src/`, no build config exists). All patterns anchor to RESEARCH.md's verified/cited excerpts instead of codebase analogs, per task instructions.

## Repo State (why there are no in-repo analogs)

```
/home/spoods/Projects/spoods-studios/interstellar-website
├── CLAUDE.md, README.md, RUNBOOK.md
├── .claude/  (CLAUDE.md, settings.json, skills/)
├── .planning/  (GSD state — not code)
├── devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md  (the ONLY content file, no frontmatter)
└── vault/  (context.md, conventions.md, decisions/, learnings/)
```

No `src/`, no `package.json`, no `astro.config.mjs`, no `.github/workflows/`. This is the first phase that introduces code into the repo — there is nothing upstream to copy structural conventions from. `vault/conventions.md` was checked and is empty ("Conventions not yet established"), confirming no repo-local coding conventions predate this phase either.

Since there is zero prior Astro/JS code in this repo or in sibling `spoods-studios/*` repos worth surveying (per `.claude/CLAUDE.md`, this is "the only live code repo" alongside `interstellar-engine`, which is C++/Vulkan — not a JS analog source), every pattern below is sourced directly from RESEARCH.md's already-cited official-docs excerpts (`docs.astro.build`) and this session's direct verification (`gh api`, `npm view`, `ls`). The planner should treat RESEARCH.md's Code Examples section as canonical, not illustrative — CONTEXT.md's discretion note ("the research example... is illustrative, not canonical") applies only to the exact loader mechanics, not the deploy workflow/config shape, which RESEARCH.md marks `[CITED]`/`[VERIFIED]`.

## File Classification

| New File | Role | Data Flow | Analog | Match Quality |
|----------|------|-----------|--------|----------------|
| `package.json` | config | — | none in-repo | no analog — use RESEARCH.md "Installation" section |
| `astro.config.mjs` | config | request-response (build-time URL resolution) | none in-repo | no analog — use RESEARCH.md "astro.config.mjs" code example verbatim |
| `tsconfig.json` | config | — | none in-repo | no analog — Astro's documented `astro/tsconfigs/base` extend, discretion item |
| `src/content.config.ts` | model (content schema/loader) | file-I/O + transform (Markdown → typed collection) | none in-repo | no analog — use RESEARCH.md Pattern 1 as the base implementation, extended per D-10 |
| `src/pages/index.astro` | component (page) | CRUD (read-only: render collection query) | none in-repo | no analog — use RESEARCH.md Pattern 2 (base-path-safe links) + D-07 shape |
| `.github/workflows/deploy.yml` | config (CI) | event-driven (push trigger → build → deploy) | none in-repo | no analog — use RESEARCH.md "GitHub Actions deploy workflow" code example verbatim, action versions already pinned |

One existing asset is directly relevant as **live test input**, not a code analog:

| Existing File | Role | Relevance |
|----------------|------|-----------|
| `devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md` | content fixture | The single real content.config.ts must ingest — no frontmatter, starts with `# Why I'm Building a Hyperrealistic Space Sim from Scratch` (line 1), filename matches `YYYY-MM-DD-slug.md`. This is the CONT-01 acceptance fixture; do not edit it (D-01). |

## Pattern Assignments

### `src/content.config.ts` (model, file-I/O + transform)

**Source:** RESEARCH.md "Pattern 1: External-path Content Collection with permissive schema" (already `[CITED: docs.astro.build/en/reference/content-loader-reference/, docs.astro.build/en/guides/content-collections/]`)

```typescript
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const FILENAME_RE = /^(\d{4}-\d{2}-\d{2})-(.+)\.md$/;

const devlog = defineCollection({
  loader: glob({
    pattern: ['**/*.md', '!_TEMPLATE.md'],
    base: '../devlog',
    generateId: ({ entry }) => {
      const match = entry.match(FILENAME_RE);
      if (!match) {
        throw new Error(
          `devlog/${entry}: filename must match YYYY-MM-DD-slug.md (no valid frontmatter date/slug fallback found)`
        );
      }
      return match[2];
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

**Deviations the plan must add beyond this base pattern** (per CONTEXT.md D-10 and RESEARCH.md Pitfall 2/Assumption A2 — the loader/schema alone is NOT proven sufficient):
1. Title-from-H1 fallback: schema's `title` is optional but D-07 requires rendering title for the frontmatter-less manifesto — needs a post-load transform (e.g., in the page, or via a computed field) that reads the first `# H1` when `data.title` is absent. RESEARCH.md does not supply this exact code; it is listed as a Claude's Discretion item.
2. Non-empty-collection assertion (Pitfall 2) — glob's `base` misconfiguration fails silently, so add an explicit `if (collection.length === 0) throw new Error(...)` guard, per RESEARCH.md's own recommendation, since it is not in the base Pattern 1 snippet.

### `src/pages/index.astro` (component, CRUD read-only)

**Source:** RESEARCH.md "Pattern 2: Base-path-safe links (SITE-02)" `[CITED: docs.astro.build/en/reference/configuration-reference/]`

```astro
---
const base = import.meta.env.BASE_URL;
---
<a href={`${base}/`}>Home</a>
```

**Extend per D-07:** query `getCollection('devlog')`, render each entry as title + date (~20 lines, throwaway). No analog exists for the list-rendering loop itself — standard Astro `getCollection()` + `.map()` frontmatter loop, not distinct enough to require a separate cited excerpt; RESEARCH.md's Architecture Diagram confirms `src/pages/index.astro renders collection -- title + date list` is the intended shape.

**Anti-pattern to avoid (SITE-02):** never hardcode `github.io` or `/interstellar-website` in this file — verify with `grep -rn "github.io\|/interstellar-website" src/ | grep -v astro.config` (RESEARCH.md Pitfall 3 / Test Map).

### `astro.config.mjs` (config)

**Source:** RESEARCH.md "astro.config.mjs (SITE-02 — the one config location)" `[CITED: docs.astro.build/en/reference/configuration-reference/]`, target URL `[VERIFIED: GitHub API, this session — Pages already enabled with build_type=workflow]`

```javascript
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://spoods-studios.github.io',
  base: '/interstellar-website',
});
```

This is the ONLY file allowed to contain the domain/base strings (SITE-02).

### `.github/workflows/deploy.yml` (config, event-driven CI)

**Source:** RESEARCH.md "GitHub Actions deploy workflow" `[CITED: docs.astro.build/en/guides/deploy/github/]`, action versions `[VERIFIED: GitHub Releases API, this session]`

```yaml
name: Deploy to GitHub Pages
on:
  push:
    branches: [main]   # D-08: no path filters
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

Use verbatim — no local deviation needed; D-08/D-09 are already satisfied by this shape (single workflow, no path filter, no PR job).

### `package.json` / scaffold install (config)

**Source:** RESEARCH.md "Installation" section + Pitfall 1

```bash
npm init --yes
npm install astro
```

**Critical deviation from typical Astro onboarding:** do NOT run `npm create astro@latest .` — it will hit "Directory not empty" against this repo's existing `CLAUDE.md`/`devlog/`/`vault/`/`.planning/` (RESEARCH.md Pitfall 1, `[VERIFIED: this session, ls -la]`). Manual `npm init` + `npm install astro` is both required and matches D-03's "wired manually" intent.

Package versions to install: `astro` caret `^7.0.9` (D-05, caret ranges), optionally `typescript` caret `^5.9.x` (discretion item A4). Both flagged `SUS`/"too-new" by the legitimacy gate as a **false positive** (routine recent release of an established package — 3.92M/wk and 226M/wk downloads respectively) — RESEARCH.md recommends a lightweight `checkpoint:human-verify` before `npm install`, not a deep audit.

### `tsconfig.json` (config, discretion item)

**Source:** RESEARCH.md, cited but not fully reproduced — `docs.astro.build/en/install-and-setup/` documents `tsconfig.json` extending `astro/tsconfigs/base` as the minimal setup. No further excerpt captured in RESEARCH.md; planner should fetch the exact extend syntax at implementation time if this discretion item is taken up, or skip entirely (D-06/RESEARCH.md confirm TypeScript is optional, not requirement-bearing).

## Shared Patterns

### Base-path resolution (SITE-02)
**Source:** `astro.config.mjs` `site`/`base` keys + `import.meta.env.BASE_URL`
**Apply to:** `astro.config.mjs` (sets it) and `src/pages/index.astro` (consumes it) — the only two files in this phase that touch URLs at all.

### Loud-fail-on-malformed-content (D-10)
**Source:** `src/content.config.ts`'s `generateId` throw (filename regex mismatch) + the non-empty-collection assertion (Pitfall 2 mitigation)
**Apply to:** `src/content.config.ts` only in Phase 1 — but the pattern (explicit throw naming the offending file, don't trust silent Astro defaults) should inform any future collection added in later phases (`pages/` sibling collection, per RESEARCH.md's Integration Points).

### Least-privilege CI permissions
**Source:** `.github/workflows/deploy.yml` `permissions:` block (`contents: read`, `pages: write`, `id-token: write`)
**Apply to:** This is the only workflow file in Phase 1; carry this exact block forward if/when a PR-check workflow is added later (deferred, D-09).

## No Analog Found

All 6 new files have no in-repo analog — this is expected and explicit for a first-code phase. Do not search further; RESEARCH.md's Code Examples section (already `[CITED]`/`[VERIFIED]` this session) is the correct and sufficient substitute source.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `package.json` | config | — | No JS tooling exists anywhere in this repo yet |
| `astro.config.mjs` | config | request-response | First build-config file in repo |
| `tsconfig.json` | config | — | First build-config file in repo |
| `src/content.config.ts` | model | file-I/O + transform | First `src/` file in repo — Content Layer API has no precedent here |
| `src/pages/index.astro` | component | CRUD | First page/template in repo |
| `.github/workflows/deploy.yml` | config | event-driven | No `.github/workflows/` directory exists yet |

## Metadata

**Analog search scope:** Full repo root (non-`.git`, non-`.planning`) via `find`/`ls`; `vault/conventions.md` checked (empty); sibling `spoods-studios/*` repos not surveyed for JS analogs (only `interstellar-engine` is described as active code, and it's C++, not a transferable pattern source for Astro/TS)
**Files scanned:** 6 top-level entries + `devlog/` (1 content file) + `vault/` (4 subpaths)
**Pattern extraction date:** 2026-07-14

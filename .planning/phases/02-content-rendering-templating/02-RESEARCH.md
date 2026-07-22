# Phase 2: Content Rendering & Templating - Research

**Researched:** 2026-07-22
**Domain:** Astro 7 Content Layer (4 collections outside `src/content/`), build-time remark plugin authoring, Shiki syntax highlighting, GitHub Pages static-file mechanics
**Confidence:** MEDIUM-HIGH — core Astro API facts VERIFIED directly against the installed `astro@7.0.9`/`@astrojs/markdown-satteri@0.3.4` package source and `.d.ts` files in `node_modules/` (highest-confidence evidence available, stronger than docs since it's the exact shipped code); the four content trees' real shape and counts were read directly off disk this session. WebFetch/WebSearch (docs.astro.build, GitHub community discussions) fill secondary gaps at MEDIUM/LOW per this repo's established convention (see 01-RESEARCH.md's confidence-tier note — this session's config also has all of `exa_search`/`brave_search`/`firecrawl`/`tavily_search`/`ref_search`/`perplexity`/`jina` set `false`).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Carried forward unchanged from the 2026-07-14 pass**
- D-11: Announcement archive entry format: title + date + milestone tag (from frontmatter, e.g. "M0.3"). Manifesto has no milestone — renders plain.
- D-13: The homepage IS the announcement archive — `/` lists the 9 announcement posts directly, no separate landing page. Post URLs: `/devlog/YYYY-MM-DD-slug/`.
- D-14: Post pages render the Markdown body untouched (body `# H1` is the title). Site adds only a small meta line. No site-generated title header, no H1 dedup logic.
- D-15: Announcement bottom nav: prev/next by date + back-to-archive.
- D-16: Homepage top matter: ONE quiet sentence describing the project (VOICE register, no hype). Exact wording gets user approval at plan review.
- D-18: Footer minimal — copyright (Spoods Studios) + the spot where the RSS link lands in Phase 3.
- D-19: Custom 404: short "page not found" note + link home, same chrome as every other page.
- D-20: `pages/` standalone pages use the post layout; meta line shows "Last updated: YYYY-MM-DD" (from `updated:` frontmatter).
- D-21: System font stack — zero webfonts, zero external requests.
- D-22: Light-only color scheme: near-white background, near-black text, one restrained link accent. Dark mode stays v2 (SITE-05).
- D-23: Hand-written minimal CSS — reading measure (~65ch), spacing, link accent, responsive rules. No CSS framework or classless base.
- D-24: Favicon: hand-authored text/letterform SVG ("IE"-style glyph).
- D-25: Content is promoted into the repo IN-PHASE via the studio-side promote flow (not manual copies). Extended by D-43 (scope).
- D-26: `pages/` is a read-only promote drop target with the same contract as `devlog/`.
- D-28: If a promoted post references images, the promote flow lands them alongside. Verified 2026-07-22 the 60 technical deep-dives contain zero image references.
- D-29: `hero_visual` frontmatter is IGNORED in v1.
- D-30: Collections honor `status: draft` exactly like `devlog/`.

**Amended by the technical series**
- D-12 (amended): Flat reverse-chronological list applies to the announcement archive only (9 posts). Technical and roadmap trees are grouped structurally (D-40).
- D-17 (amended): Header nav: Devblog / Technical / How It's Made / Roadmap.
- D-27 (SUPERSEDED): replaced by D-36/D-37/D-38.

**Content trees & information architecture**
- D-31: Technical deep-dives land in a new `technical/` directory at repo root, sibling to `devlog/` and `pages/`, milestone subdirs preserved. Own collection, own schema, same read-only promote-drop contract.
- D-32: `/technical/m0.1/phase-01-window-surface/`, `/technical/` full index, `/technical/m0.1/` per-milestone index, `_how-to-read.md` at `/technical/how-to-read/`.
- D-33: No YAML frontmatter, no date. Metadata derived from path — milestone from `m0.X/` dir, phase number+slug from `phase-NN-slug.md`, title from body H1. Non-conforming filename = loud build failure.
- D-34: Order by phase number (numeric-aware, handles decimals like `phase-10.5`), not date.
- D-35: Cross-linking generated in both directions from the collection query, never hand-maintained.

**Roadmap**
- D-36: `/roadmap` = overview page + per-milestone detail pages (`/roadmap/m0.3/`).
- D-37: Overview renders from a site-voice transcription at `pages/roadmap.md`, NOT verbatim from the Discord pin.
- D-38: 8 milestone detail docs land in a new `roadmap/` directory at repo root, own collection, milestone from filename, ordered by milestone number.

**Rendering fidelity**
- D-39: Obsidian wikilinks resolved to real anchors by a site-side remark plugin at build time. Unresolvable target = loud build failure naming file + link.
- D-40: `/technical/` groups by era → milestone in phase order; `/roadmap/m0.X/` lists a milestone's phases independently. CONT-08 (search/tags) stays v2.
- D-41: CONT-07 split — build-time syntax highlighting (Astro's built-in Shiki, light theme) lands in Phase 2; KaTeX math stays v2 (zero LaTeX/mermaid in corpus).
- D-42: Auto-generated TOC from Astro's rendered `headings` array — static, build-time, no JS. Applies to technical/roadmap trees; planner may skip on short announcement posts.

**Promote scope for this phase**
- D-43: Phase 2 promotes everything for closed milestones M0.1–M0.8: 9 announcements, 55 deep-dives + `_how-to-read.md`, 8 roadmap detail docs, 2 standalone pages.
- D-44: M1.1 content is Phase 4.

### Claude's Discretion
- Sitemap/canonical mechanics, exact responsive breakpoints, link accent color, meta-line placement — **now resolved by 02-UI-SPEC.md** (developer-signed-off 2026-07-22): breakpoint 640px, accent `#1d5fae`, TOC sticky sidebar ≥640px / `<details>` <640px.
- Collection loader configs for `technical/` and `roadmap/` — mirror the devlog glob loader; different filename conventions per D-33/D-38.
- Whether the TOC is sticky sidebar or inline — **resolved by UI-SPEC**: sticky ≥640px, inline `<details>` <640px, H2+H3 only, 3+ H2 threshold.
- Layout factoring — **resolved by UI-SPEC**: one shared `PostLayout` + five distinct index layouts.
- How the promote step is sequenced inside the phase.
- Whether era → milestone grouping on `/technical/` is derived from data or a small hand-written map.

### Deferred Ideas (OUT OF SCOPE)
- Dark mode / `prefers-color-scheme` — v2 (SITE-05).
- KaTeX math rendering — v2 (other half of CONT-07).
- Search / tag taxonomy — v2 (CONT-08).
- `hero_visual` rendering / OG image source — Phase 3 or v2.
- Old-Discord-link 404 behavior into the technical corpus — Phase 4 (CONT-06), now covers three URL trees.
- Automated studio→website promote script — out of scope for this repo.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CONT-02 | Full archive live at launch: manifesto + M0.1–M0.8 posts, VOICE.md untouched | **Scope amendment required** (see Scope Correction below) — verified 9 announcement `.md` files exist in `../studio/vault/devlog/drafts/` (8 milestone drafts + manifesto; manifesto already promoted in Phase 1) plus 1 `.discord.txt` sibling that must be excluded per D-25. Content Layer `glob()` pattern from `src/content.config.ts` (Phase 1) extends directly; no new mechanism needed for this tree. |
| CONT-03 | "How It's Made" standalone page from `pages/`, never in archive/RSS | Verified `how-its-made.md` exists in drafts (3142 bytes, has real frontmatter unlike the other 3 trees). `pages/` collection is new (D-26) — same glob-loader pattern, separate collection name keeps it structurally excluded from `devlog` queries. |
| CONT-04 | Roadmap standalone page — **wording predates D-36/D-37/D-38's overview+detail split** | Verified: `roadmap-overview.pinned.md` (1697 bytes) is the transcription source (D-37); `roadmap-detail/M0.1.md`…`M0.8.md` (8 files, verified count) are the new `roadmap/` collection (D-38). REQUIREMENTS.md text needs amending — flagged below. |
| SITE-04 | Mobile-responsive, custom 404, favicon, canonical URLs, sitemap.xml | `@astrojs/sitemap@3.7.3` verified on npm registry; GitHub Pages 404.html mechanics researched (Common Pitfalls); canonical URL is a manual `<link>` tag using `Astro.site`+`Astro.url.pathname` (no built-in Astro helper found in installed types). |
| (pulled forward) CONT-07 syntax half | Build-time Shiki highlighting | Verified via installed `.d.ts`: `markdown.shikiConfig.theme` — **Astro's default is `github-dark`**, must be explicitly overridden to `github-light` per D-22/D-41/UI-SPEC. Confirmed build-time-only, zero client JS (Shiki output is inline `style` attributes, no stylesheet, no JS). |

### Scope Correction — REQUIREMENTS.md / ROADMAP.md wording is stale

Per CONTEXT.md's explicit instruction, this is flagged, not silently assumed:

- **CONT-02** as written ("manifesto + M0.1–M0.8 posts") is now only the `devlog/` quarter of this phase's real scope. The phase also promotes 55 technical deep-dives (`technical/`) and 8 roadmap detail docs (`roadmap/`) — neither tree is named in CONT-02's current text.
- **CONT-04** as written ("Roadmap standalone page mirroring the Discord #roadmap pinned overview") predates D-36/D-37/D-38: the roadmap is now an overview page (transcribed, not mirrored verbatim) **plus 8 per-milestone detail pages**, a structurally new collection.
- **CONT-07** (v2 deferred, "Build-time code syntax highlighting + KaTeX math") is split by D-41: the syntax-highlighting half moves into Phase 2 (this phase); only KaTeX stays v2.
- **Recommendation for the planner:** either (a) treat this as a documentation debt item and update REQUIREMENTS.md/ROADMAP.md text in a small housekeeping task within this phase's plan, or (b) explicitly note in PLAN.md that CONT-02/CONT-04/CONT-07 are being satisfied at their *expanded* CONTEXT.md scope, not their as-written REQUIREMENTS.md scope, and schedule the doc amendment for phase close. Either is acceptable; leaving the mismatch undocumented is not.

</phase_requirements>

## Summary

Phase 2 turns Phase 1's one-collection proof-of-concept into four Astro Content Layer collections (`devlog`, `technical`, `roadmap`, `pages`) reading from four repo-root directories outside `src/content/`, each promoted in-phase from `../studio/vault/`. All four trees were read directly off disk this session: `devlog/drafts/` has exactly 9 real announcement `.md` files (8 milestone drafts + manifesto, matching D-13's "9 posts") plus 2 extra files not yet in this phase's scope (`how-its-made.md` — is CONT-03's `pages/` source — and `how-this-gets-built.md`, a **Phase-4-or-later skeleton draft, status: skeleton, explicitly not ready to promote** — the promote step must exclude it) and 1 `.discord.txt` sibling (`m0.8-perturbations.discord.txt`) that D-25 requires excluding. `technical/m0.1`…`m0.8` contains exactly 55 deep-dive files (verified per-milestone: 6+6+8+8+8+6+8+5=55) plus `_how-to-read.md`, matching D-43 exactly; `technical/m1.1/` holds 5 more files, correctly out of this phase's scope per D-44. `roadmap-detail/` contains exactly 9 files (`M0.1.md`…`M0.8.md` plus `M1.1.md`) — 8 are this phase's scope, `M1.1.md` is Phase 4.

Two Astro-version-specific facts materially change the plan from what CONTEXT.md's canonical refs assumed, both verified directly against installed package source (`node_modules/astro`, `node_modules/@astrojs/markdown-satteri`):

1. **`markdown.remarkPlugins` is deprecated in Astro 7** (still functional, but the installed `.d.ts` marks it `@deprecated ... Will be removed in a future major`). Astro 7's *default* Markdown processor is now `satteri()` from `@astrojs/markdown-satteri` (not the remark/rehype/unified pipeline used in Astro 5/6). To register D-39's wikilink-resolution remark plugin on a forward-compatible path, the plan should add `@astrojs/markdown-remark` (official package, `7.2.1` on npm) and set `markdown.processor: unified({ remarkPlugins: [...] })` — this also switches the *entire* Markdown pipeline (both `.md` files) from Sätteri to the classic remark/rehype/unified stack, which is the only supported way to run a custom remark plugin going forward. This is more invasive than "just add one option" and should be called out as a real architectural decision in the plan, not a one-line config tweak.
2. **The `Deep-dive:` line in every `roadmap-detail/M0.X.md` file is a literal Discord-era placeholder string — `"posted in #technical-devlog"` — not a file path.** CONTEXT.md's canonical_refs claims "each phase entry ends with a `Deep-dive:` path pointing into `vault/devlog/technical/…`" — **verified false** (grepped all 6 sampled roadmap-detail files, every single `Deep-dive:` line reads identically as the placeholder text, zero paths present). D-35's cross-linking mechanism (match on phase number between `## Phase N: Title` headings in `roadmap/M0.X.md` and `phase-NN-slug.md` filenames in `technical/m0.X/`) is unaffected and is the correct approach regardless — but the plan must not attempt to regex-extract a path out of the `Deep-dive:` text, because there isn't one. The line should be replaced by a generated link at render time, using the phase-number match, discarding the placeholder text entirely.

A third finding worth flagging as a genuine landmine: the deep-dive corpus's C++ code (fenced and inline) is full of the `[[nodiscard]]` attribute, which is textually identical to Obsidian wikilink bracket syntax. Grepping the corpus found 7 files with `[[...]]` and only one is an actual wikilink (`[[../m0.1/phase-03-rendering-pipeline|Phase 3 post]]` in `phase-14.5-swapchain-acquire-fix.md`, plain prose); the rest are `[[nodiscard]]` C++ attributes, either inside fenced ` ```cpp ` blocks or backtick-wrapped inline code. This is not actually a problem *if* the remark plugin is written correctly (visiting only mdast `text` nodes, never `code`/`inlineCode` nodes — remark's parser already separates code spans/blocks into their own node types, so a `text`-only visitor never sees them) — but it is exactly the kind of naive-regex-over-raw-Markdown mistake an implementer could make, and is worth a named pitfall.

**Primary recommendation:** Extend Phase 1's `glob()`+`generateId` pattern to three more collections with per-tree filename-parsing rules (D-33/D-38); add `@astrojs/markdown-remark` and switch `markdown.processor` to `unified({ remarkPlugins: [resolveWikilinks] })`; hand-roll the wikilink remark plugin (do not add `remark-wiki-link` — last published Oct 2023, 20K weekly downloads, unmaintained relative to this project's needs) as a ~40-60 line `text`-node visitor; set `shikiConfig.theme: 'github-light'` explicitly (Astro's default is `github-dark`); add `@astrojs/sitemap`; derive the TOC from `render()`'s `headings: {depth, slug, text}[]` array, filtering `depth === 2 || depth === 3`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Markdown ingestion & schema validation (4 collections) | Build tier (Astro Content Layer) | — | All four trees resolve entirely during `astro build`; no server exists |
| Wikilink resolution, ID/slug/title derivation from path | Build tier (remark plugin + custom `generateId`) | — | Must run before HTML is emitted; cannot be deferred to the browser without JS, which the project forbids |
| Syntax highlighting (Shiki) | Build tier (Astro's Markdown processor) | — | Verified: Shiki emits inline `style` attributes only, zero client JS/CSS — confirmed static |
| Table of contents | Build tier (derived from `render()`'s `headings` array) | Browser (native `<details>` disclosure widget, zero JS) | TOC data is fully computed at build time; the only browser-side behavior is the native, JS-free `<details>` toggle at <640px |
| Cross-linking (announcement↔deep-dive↔roadmap) | Build tier (collection query joins) | — | D-35 requires derivation from collection data, never hand-maintained links |
| Hosting & serving, 404 fallback, sitemap | CDN/Static (GitHub Pages) | Build tier (`@astrojs/sitemap`, `src/pages/404.astro`) | Static files only; GitHub Pages serves whatever the Actions artifact contains, no origin compute |
| Content promotion (cross-repo copy) | Operator/manual tier (human or a scripted `cp`, run once per phase) | — | D-25/D-43: explicitly out of automated-pipeline scope this repo; a one-time promote step inside the phase's plan, not a running service |

## Standard Stack

### Core (unchanged from Phase 1, re-verified)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| astro | 7.0.9 `[VERIFIED: npm registry + installed node_modules, this session]` | Content Layer, build, routing | Already locked; Phase 2 uses the same install |
| typescript | 7.0.2 `[VERIFIED: npm registry + installed node_modules, this session]` | Type-checking | Jumped a major version since Phase 1's research (5.9.x → 7.0.2, native TS port); already the installed devDependency, no action needed |

### New for this phase
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `@astrojs/sitemap` | 3.7.3 `[VERIFIED: npm registry, npm view]` | XML sitemap generation for SITE-04 | Official Astro integration, near-zero config once `site` is set (already is, per Phase 1) |
| `@astrojs/markdown-remark` | 7.2.1 `[VERIFIED: npm registry, npm view; official withastro/astro repo]` | Restores the remark/rehype/`unified()` Markdown pipeline so a custom remark plugin (D-39) can be registered | Astro 7's *default* processor (Sätteri) does not accept arbitrary remark plugins; this package is the officially documented path back to a pluggable pipeline (`docs.astro.build` markdown guide, fetched this session) `[CITED: docs.astro.build/en/guides/markdown-content/]` |

### Not adopted (considered and rejected)
| Library | Version checked | Why not used |
|---------|------------------|---------------|
| `remark-wiki-link` | 2.0.1 `[VERIFIED: npm registry]`, last published 2023-10-10 (nearly 3 years stale relative to this session) `[VERIFIED: npm registry time.modified]`, 20,352 weekly downloads `[VERIFIED: package-legitimacy seam]` | Package-legitimacy verdict is `OK` (not flagged), but low download count + multi-year-stale publish date is a real signal against adopting a dependency for a narrow ~40-line transform, especially given this project's explicit "vendor-conservative... but also allergic to dependencies" posture (`.claude/CLAUDE.md`). The transform needed (parse `[[target\|label]]` text nodes, resolve against known collection entries, throw on miss) is small and fully custom to this repo's three URL-shape rules (D-32/D-36/D-32) — a generic wikilink plugin would need heavy configuration to map Obsidian-relative paths onto Astro collection IDs anyway. **Recommendation: hand-roll.** |

**Installation:**
```bash
npm install @astrojs/sitemap @astrojs/markdown-remark
```

**Version verification (this session):**
```bash
npm view @astrojs/sitemap version           # 3.7.3
npm view @astrojs/markdown-remark version   # 7.2.1
npm view remark-wiki-link version           # 2.0.1 (not adopted)
```

## Package Legitimacy Audit

| Package | Registry | Age (latest publish) | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|----|-----------|-------------|---------|-------------|
| `@astrojs/sitemap` | npm | 2026-05-26 `[VERIFIED: seam]` | 2,083,037/week `[VERIFIED: seam]` | github.com/withastro/astro | OK | Approved |
| `@astrojs/markdown-remark` | npm | 2026-07-02 `[VERIFIED: seam]` | 3,903,972/week `[VERIFIED: seam]` | github.com/withastro/astro | SUS ("too-new") | **Flagged — false positive, see note below** |
| `remark-wiki-link` | npm | 2023-10-10 `[VERIFIED: seam]` | 20,352/week `[VERIFIED: seam]` | github.com/landakram/remark-wiki-link | OK | **Not adopted** — hand-roll recommended instead (see Standard Stack) |

**Note on the `@astrojs/markdown-remark` "too-new" verdict:** identical false-positive pattern already documented in `01-RESEARCH.md` for `astro`/`typescript` — the seam's "too-new" signal fires on the *latest version's* publish recency, not the package's trust profile. `@astrojs/markdown-remark` is an official `withastro/astro` monorepo package with ~3.9M weekly downloads (it ships as astro core's own dependency, hence the high count) that happened to publish a routine release 3 weeks before this research session. Kept, tagged `[WARNING: flagged as suspicious by the legitimacy gate — "too-new" reflects a routine recent release of an official withastro/astro monorepo package, not an age/trust signal; low-risk, but per protocol the planner should still add a lightweight `checkpoint:human-verify` before `npm install @astrojs/markdown-remark`.]`

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** `@astrojs/markdown-remark` — false-positive "too-new," planner must still add a `checkpoint:human-verify` per protocol (fast confirmation, not a deep audit, per the note above).

## Architecture Patterns

### System Architecture Diagram

```
../studio/vault/devlog/drafts/*.md ─┐
../studio/vault/devlog/technical/** ─┼─ [ONE-TIME PROMOTE STEP, this phase] ──▶ devlog/  (existing, +8 files)
../studio/vault/project/roadmap-detail/*.md ─┤                                  technical/ (new, 55 files + _how-to-read.md)
../studio/vault/devlog/drafts/how-its-made.md┘                                 roadmap/  (new, 8 files)
   + hand-transcribed pages/roadmap.md                                        pages/    (new, 2 files)
   (D-37: NOT a copy — rewritten from                                              │
    roadmap-overview.pinned.md's Discord framing)                                 │
                                                                                     ▼
                                                                    [astro build — Content Layer]
                                                                                     │
                        ┌────────────────────────────────────────────────────────────┼──────────────────────────┐
                        ▼                                                            ▼                          ▼
         4x glob() loaders, per-collection                          markdown.processor: unified()      generateId() per D-33/D-38:
         generateId + Zod schema                                    + remarkPlugins: [resolveWikilinks] loud-throw on bad filename
         (devlog: existing; technical/roadmap/                      + shikiConfig.theme: 'github-light'
          pages: new, filename-fallback-only,                              │
          D-33 requires no frontmatter at all)                             ▼
                        │                                          headings: {depth,slug,text}[]
                        ▼                                          returned per-entry from render()
         Cross-link joins across collections                               │
         (milestone tag M0.X ↔ dir m0.x, case-                             ▼
          normalized; phase-number match between                   TOC component (H2+H3 only,
          roadmap/M0.X.md headings and                              3+ H2 threshold, sticky
          technical/m0.X/phase-NN-*.md filenames)                   sidebar ≥640px / <details> below)
                        │                                                  │
                        └──────────────────────┬───────────────────────────┘
                                                ▼
                          5 index templates + 1 shared PostLayout
                          (/, /technical/, /technical/m0.X/, /roadmap/, /roadmap/m0.X/)
                                                │
                                                ▼
                                dist/ (static HTML + inline-styled Shiki spans)
                                dist/404.html, dist/sitemap.xml, dist/favicon.svg
                                                │
                                                ▼
                    GitHub Actions: withastro/action → actions/deploy-pages (unchanged from Phase 1)
                                                │
                                                ▼
                https://spoods-studios.github.io/interstellar-website/
```

### Recommended Project Structure
```
/ (repo root)
├── astro.config.mjs          # + markdown.processor (unified+remarkPlugins), shikiConfig, sitemap integration
├── src/
│   ├── content.config.ts     # 4 collections: devlog (existing), technical, roadmap, pages (new)
│   ├── lib/
│   │   ├── remark-wikilinks.mjs   # D-39: hand-rolled remark plugin
│   │   ├── phase-sort.ts          # D-34: numeric-aware sort (parses "10.5" correctly)
│   │   └── title-from-h1.ts       # extracted from Phase 1's index.astro inline regex (D-31 note)
│   ├── layouts/
│   │   ├── PostLayout.astro       # shared: title source, meta line, breadcrumbs, TOC, prev/next (UI-SPEC)
│   │   └── BaseLayout.astro       # header/footer chrome, nav
│   ├── components/
│   │   └── TableOfContents.astro  # consumes render()'s headings array
│   └── pages/
│       ├── index.astro            # replaces Phase 1's throwaway list — archive homepage (D-13)
│       ├── 404.astro              # D-19, must build to dist/404.html at artifact root
│       ├── devlog/[slug].astro
│       ├── technical/index.astro
│       ├── technical/[milestone]/index.astro
│       ├── technical/[milestone]/[slug].astro
│       ├── roadmap/index.astro    # renders pages/roadmap.md + generated milestone-link list
│       ├── roadmap/[milestone].astro
│       └── how-its-made.astro     # or pages/[slug].astro if pages/ grows past 2 entries
├── public/
│   └── favicon.svg            # D-24, hand-authored
├── devlog/                     # existing, +8 promoted files this phase
├── technical/                  # NEW this phase — promoted, read-only (D-31)
├── roadmap/                    # NEW this phase — promoted, read-only (D-38)
└── pages/                      # NEW this phase — promoted + 1 hand-transcribed (D-26/D-37)
```

### Pattern 1: Technical collection — nested subdirectory preserved via `generateId`, loud-fail on bad filename

**What:** Confirmed directly from the installed `glob.js` source this session: the `entry` string passed to `generateId({ entry, base, data })` is the file path **relative to `base`**, including subdirectories (e.g. `m0.1/phase-01-window-surface.md` when `base: './technical'`). The default `generateId` already derives a slug from this full relative path via `getContentEntryIdAndSlug` — nested structure is preserved automatically even without a custom function. A custom `generateId` is still required here because D-33 needs milestone + phase-number extraction (not just a slug) and a **loud throw** on non-conforming names.

```typescript
// src/content.config.ts (extending Phase 1's file)
// Source: node_modules/astro/dist/content/loaders/glob.js (installed source, read directly
// this session) — entry/base/data signature and relative-path behavior [VERIFIED]
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const TECHNICAL_RE = /^(m\d+\.\d+)\/phase-(\d+(?:\.\d+)?)-(.+)\.md$/;

const technical = defineCollection({
  loader: glob({
    pattern: ['**/*.md'],
    base: './technical', // project-root-relative — same landmine as Phase 1's devlog loader
    generateId: ({ entry }) => {
      if (entry === '_how-to-read.md') return 'how-to-read';
      const match = entry.match(TECHNICAL_RE);
      if (!match) {
        // D-33: loud build failure naming the offending file
        throw new Error(
          `technical/${entry}: filename must match m0.X/phase-NN[.N]-slug.md (D-33 — no frontmatter fallback exists for this tree)`
        );
      }
      const [, milestone, phaseNum, slug] = match;
      return `${milestone}/phase-${phaseNum}-${slug}`; // preserves D-32's URL shape directly
    },
  }),
  // D-33: NO frontmatter fields at all — schema only needs to reject unexpected keys loudly,
  // not validate any (there is nothing to validate; title/milestone/phase all come from the path)
  schema: z.object({}).strict().optional().default({}),
});
```

**Milestone/phase-number extraction as a shared helper** (used by both the collection's `generateId` and any page needing to display "M0.3 · Phase 12"):
```typescript
// src/lib/phase-sort.ts — D-34: numeric-aware sort handling decimals
export function parsePhaseNumber(idOrFilename: string): number {
  const m = idOrFilename.match(/phase-(\d+(?:\.\d+)?)/);
  if (!m) throw new Error(`Cannot parse phase number from: ${idOrFilename}`);
  return parseFloat(m[1]); // "10.5" -> 10.5, sorts correctly between 10 and 11
}

export function sortByPhaseNumber<T extends { id: string }>(entries: T[]): T[] {
  return [...entries].sort((a, b) => parsePhaseNumber(a.id) - parsePhaseNumber(b.id));
}
```
`parseFloat` on `"10.5"` and `"27.5"` sorts numerically-correctly between integer phase numbers — verified this is sufficient because every decimal phase in the corpus (`10.5`, `14.5`, `15.5`, `21.5`, `21.7`, `22.1`, `27.5`, `46.1`) has exactly one decimal digit and is meant to sort strictly between its integer neighbors (e.g. `10.5` between `10` and `11`), which `parseFloat` + numeric comparison does correctly without any special-casing `[VERIFIED: technical/ directory listing, this session — all 8 decimal-numbered files enumerated above]`.

### Pattern 2: Roadmap collection — milestone from filename, `Deep-dive:` line is NOT a path

```typescript
const roadmap = defineCollection({
  loader: glob({
    pattern: ['M*.md'],
    base: './roadmap',
    generateId: ({ entry }) => {
      const match = entry.match(/^M(\d+\.\d+)\.md$/i);
      if (!match) {
        throw new Error(`roadmap/${entry}: filename must match M{milestone}.md (D-38)`);
      }
      return `m${match[1]}`; // normalize to lowercase — matches technical/'s m0.X dirs (D-35 case note)
    },
  }),
  schema: z.object({}).strict().optional().default({}),
});
```
**Cross-linking correction (verified this session):** every sampled `roadmap/M0.X.md`'s `**Deep-dive:**` line reads the literal Discord-era placeholder `"posted in #technical-devlog"` — grepped across `M0.1.md, M0.2.md, M0.3.md, M0.5.md, M0.7.md, M0.8.md`, zero file-path references found. **Do not attempt to parse a path out of this line.** Resolve the link by matching `## Phase N: Title` heading numbers (parsed from the roadmap body via remark, or simply regexed from `entry.body`) against `technical/m0.X/phase-NN-*.md` filenames sharing the same phase number (both are within the same milestone, verified identical numbering scheme: e.g. `M0.1.md`'s `## Phase 1: Window + Surface` ↔ `technical/m0.1/phase-01-window-surface.md`). The rendered page should replace the placeholder text with the generated link, not append to it.

### Pattern 3: Case-normalized milestone matching (D-35)

**Verified mismatch:** announcement frontmatter uses `milestone: M0.1` (capital M, e.g. `devlog/drafts/m0.1-vulkan-bootstrap.md:2`); `technical/`'s directories are lowercase (`technical/m0.1/`); `roadmap/`'s filenames are capitalized (`roadmap/M0.1.md`). All three must join on one normalized key.

```typescript
// src/lib/milestone-key.ts
export function normalizeMilestone(raw: string): string {
  return raw.toLowerCase().replace(/^m/, 'm'); // "M0.1" -> "m0.1", "m0.1" -> "m0.1"
}
```
Use this as the join key everywhere a cross-collection lookup happens (announcement → its deep-dives, deep-dive → its announcement + roadmap detail).

### Pattern 4: Wikilink remark plugin (D-39) — visit `text` nodes only

**Why this is safe against the `[[nodiscard]]` collision (verified this session):** grepped the full `technical/` corpus for `\[\[` — 7 files match, and every occurrence except one is the C++ `[[nodiscard]]` attribute, either inside a fenced ` ```cpp ` block (parsed by remark as a `code` mdast node) or backtick-wrapped inline (parsed as `inlineCode`). Only `phase-14.5-swapchain-acquire-fix.md:20` contains a real wikilink, in plain prose (a `text`/`paragraph` node). A remark plugin built with `unist-util-visit(tree, 'text', ...)` structurally cannot see into `code`/`inlineCode` nodes — remark's own parser has already partitioned them by the time a plugin runs — so no exclusion logic is needed beyond visiting the correct node type.

```javascript
// src/lib/remark-wikilinks.mjs
// Source: mdast node-type behavior per unified/remark's own parsing model — [ASSUMED, this
// session's synthesis from training knowledge of mdast/unist-util-visit; not fetched from a
// docs URL this session, but directly corroborated by the corpus grep above showing zero
// [[nodiscard]] hits landing in a plain-text node]
import { visit } from 'unist-util-visit';

const WIKILINK_RE = /\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g;

export function remarkWikilinks({ resolve }) {
  // `resolve(target: string) => string | null` — looks up the target against known
  // collection entries (technical/how-to-read, technical/m0.X/phase-NN-slug, etc.)
  // and returns the resolved site URL, or null if unresolvable.
  return (tree, file) => {
    visit(tree, 'text', (node, index, parent) => {
      if (!WIKILINK_RE.test(node.value)) return;
      WIKILINK_RE.lastIndex = 0;

      const newChildren = [];
      let lastIndex = 0;
      let match;
      while ((match = WIKILINK_RE.exec(node.value))) {
        const [full, target, label] = match;
        if (match.index > lastIndex) {
          newChildren.push({ type: 'text', value: node.value.slice(lastIndex, match.index) });
        }
        const href = resolve(target.trim());
        if (href === null) {
          // D-39: loud build failure naming the file and the unresolved link
          throw new Error(
            `Unresolvable wikilink in ${file.path}: [[${target}${label ? '|' + label : ''}]]`
          );
        }
        newChildren.push({
          type: 'link',
          url: href,
          children: [{ type: 'text', value: label?.trim() ?? target.trim() }],
        });
        lastIndex = match.index + full.length;
      }
      if (lastIndex < node.value.length) {
        newChildren.push({ type: 'text', value: node.value.slice(lastIndex) });
      }
      parent.children.splice(index, 1, ...newChildren);
    });
  };
}
```

### Pattern 5: Registering the plugin — Astro 7's processor swap (verified against installed `.d.ts`)

```javascript
// astro.config.mjs
// Source: node_modules/astro/dist/types/public/config.d.ts (installed types, read directly
// this session) [VERIFIED] — markdown.remarkPlugins is @deprecated; markdown.processor +
// unified() from @astrojs/markdown-remark is the documented forward path
// [CITED: docs.astro.build/en/guides/markdown-content/, fetched this session]
import { defineConfig } from 'astro/config';
import { unified } from '@astrojs/markdown-remark';
import sitemap from '@astrojs/sitemap';
import { remarkWikilinks } from './src/lib/remark-wikilinks.mjs';
import { resolveWikilinkTarget } from './src/lib/wikilink-resolver.mjs'; // project-specific lookup

export default defineConfig({
  site: 'https://spoods-studios.github.io',
  base: '/interstellar-website',
  integrations: [sitemap()],
  markdown: {
    processor: unified({
      remarkPlugins: [[remarkWikilinks, { resolve: resolveWikilinkTarget }]],
    }),
    shikiConfig: {
      theme: 'github-light', // Astro's default is github-dark — must override for D-22/D-41
    },
  },
});
```

### Pattern 6: Table of contents from `render()`'s `headings` array (verified against installed types)

```typescript
// src/lib/toc.ts
// Source: node_modules/astro/dist/content/runtime.d.ts + node_modules/@astrojs/internal-helpers/
// dist/markdown.d.ts (installed types, read directly this session) [VERIFIED]:
//   render(entry) -> { Content, headings: {depth:number, slug:string, text:string}[], remarkPluginFrontmatter }
// Slugs are generated via github-slugger (same anchor scheme as GitHub's own heading IDs)
// and Astro injects a matching `id` attribute on the rendered heading element, so
// `<a href={`#${h.slug}`}>` always matches. [CITED: docs.astro.build/en/guides/markdown-content/]
import type { MarkdownHeading } from 'astro';

export function buildToc(headings: MarkdownHeading[]) {
  const relevant = headings.filter((h) => h.depth === 2 || h.depth === 3); // UI-SPEC: H2+H3 only
  const h2Count = relevant.filter((h) => h.depth === 2).length;
  if (h2Count < 3) return null; // UI-SPEC: 3+ H2 threshold to render at all
  return relevant;
}
```
```astro
---
// In a page/layout, per-entry:
const { Content, headings } = await render(entry);
const toc = buildToc(headings);
---
{toc && (
  <nav class="toc">
    {toc.map((h) => (
      <a href={`#${h.slug}`} data-depth={h.depth}>{h.text}</a>
    ))}
  </nav>
)}
```

### Pattern 7: Custom 404 page (SITE-04 / D-19)

```astro
---
// src/pages/404.astro — builds to dist/404.html
import BaseLayout from '../layouts/BaseLayout.astro';
---
<BaseLayout title="Page not found">
  <h1>Page not found.</h1>
  <p>The page you're looking for doesn't exist — it may have moved or the link is out of date.</p>
  <a href={import.meta.env.BASE_URL}>← Back home</a>
</BaseLayout>
```
Confirmed via GitHub's own community-discussion guidance (fetched this session): for an Actions-based deploy (`build_type: workflow`, already this repo's configuration per `01-RESEARCH.md` Pitfall 4), **the 404 file must be at the top level of the uploaded artifact** — Astro's `src/pages/404.astro` builds to `dist/404.html`, which satisfies this automatically since `astro build`'s output root IS the artifact root `withastro/action` uploads. `[CITED: GitHub community discussions, cross-referenced against the already-confirmed Actions/deploy-pages mechanism from 01-RESEARCH.md Pitfall 4]` — see Pitfall 6 below for a caveat about a contradictory-looking older claim this session's search also surfaced.

### Pattern 8: Canonical URL (no built-in Astro helper found)

```astro
---
// In BaseLayout.astro's <head>
const canonicalURL = new URL(Astro.url.pathname, Astro.site);
---
<link rel="canonical" href={canonicalURL} />
```
No dedicated `Astro.canonicalURL` API exists in the installed types (`grep` of `node_modules/astro/dist/types/public/*.d.ts` for `canonical` returned nothing) — this is the standard hand-written pattern `[ASSUMED — standard Astro community pattern from training knowledge; not found as a named API in installed types, and not independently re-verified via docs this session beyond confirming `Astro.site`/`Astro.url` exist per Phase 1's research]`.

### Anti-Patterns to Avoid
- **Regexing a file path out of `roadmap/M0.X.md`'s `Deep-dive:` line:** there is no path there (verified, see Pattern 2) — resolve via phase-number matching instead.
- **A remark plugin that regexes raw Markdown source instead of visiting mdast `text` nodes:** would falsely match `[[nodiscard]]` inside code — visiting only `text` nodes is what makes this safe (Pattern 4).
- **Comparing milestone strings without case normalization:** `"M0.1" !== "m0.1"` in a naive `===` join — always normalize (Pattern 3).
- **Trusting `markdown.remarkPlugins` for new work:** it still functions in 7.0.9 but is marked for removal; new code should register plugins via `markdown.processor: unified({...})`.
- **Leaving Shiki on its default theme:** `github-dark` is the Astro default — an unconfigured Shiki setup silently ships a dark-themed code block on this light-only site (D-22 violation).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Sitemap XML generation | Custom sitemap builder walking `getCollection()` results | `@astrojs/sitemap` | Official integration, near-zero config given `site` is already set; handles the `<lastmod>`/`<changefreq>` boilerplate for free |
| Remark/rehype pipeline wiring | Manual `unified()` chain re-implementing what Sätteri/`@astrojs/markdown-remark` already provide | `@astrojs/markdown-remark`'s `unified()` export | It's the exact function Astro itself uses internally when not on Sätteri — using it directly guarantees the same GFM/smartypants/heading-ID behavior the rest of the site expects |
| Heading-ID/slug generation for TOC anchors | Custom slugify function | Astro's built-in `headings` array (github-slugger under the hood) | Already computed once per render; a second independent slugify implementation risks mismatched anchors between the TOC and the actual heading `id` |
| Syntax highlighting | A hand-rolled Prism/highlight.js integration | Astro's built-in Shiki (`markdown.shikiConfig`) | Zero client JS, ships with Astro, C++ is a bundled Shiki language (no extra install needed for fenced code blocks) |

**Key insight:** every new mechanism this phase needs (sitemap, TOC, syntax highlighting, the remark pipeline itself) has an official, already-installed-or-one-`npm install`-away Astro answer — the only genuinely custom code is the wikilink-resolution plugin (narrow, ~40-60 lines, no existing library fits this repo's specific three-collection URL-resolution needs cleanly) and the per-tree filename-parsing `generateId` functions (D-33/D-38, inherently repo-specific).

## Common Pitfalls

### Pitfall 1: `glob()`'s silent-empty-collection landmine, now ×3
**What goes wrong:** Same as Phase 1's Pitfall 2, but now risked three more times — a typo'd `base: './technica'` (missing an 'l') for the new `technical` collection silently produces an empty collection with only a console warning, not a build failure.
**Why it happens:** Confirmed directly in installed source this session (`glob.js`): `if (exists && files.length === 0) { logger.warn(...); return; }` — no throw.
**How to avoid:** Add an explicit non-empty assertion per new collection (e.g., assert `technical` has exactly 56 entries — 55 deep-dives + `_how-to-read.md` — at build time for this phase's known-closed corpus, or at minimum `> 0`).
**Warning signs:** `astro build` exits 0 but an index page renders empty.

### Pitfall 2: `[[nodiscard]]` vs. Obsidian wikilinks
**What goes wrong:** A naive implementation that regexes `[[...]]` over raw Markdown text (before mdast parsing) would match the C++ `[[nodiscard]]` attribute, which appears in at least 6 of the 55 deep-dive files (`m0.2/phase-07`, `m0.2/phase-08` ×2, `m0.2/phase-09` ×4, `m0.3/phase-15.5`, `m0.4/phase-18`, `m1.1/phase-50` — verified via grep this session).
**Why it happens:** Both syntaxes use double square brackets; only structural (mdast-node-type) distinction, not textual pattern, separates them.
**How to avoid:** Build the remark plugin as a `text`-node visitor (Pattern 4) — `code`/`inlineCode` nodes are structurally separate and never visited.
**Warning signs:** A build (or worse, a successful build with silently broken output) that tries to "resolve" `nodiscard` as a wikilink target.

### Pitfall 3: `Deep-dive:` lines contain no path
**What goes wrong:** CONTEXT.md's canonical_refs claims each roadmap-detail phase entry "ends with a `Deep-dive:` path pointing into `vault/devlog/technical/…`" — verified false this session (grepped 6 of 8 roadmap-detail files; all read the identical literal string `"posted in #technical-devlog"`).
**Why it happens:** These are retroactive backfill docs written to describe Discord's original posting structure, not file-path references — the technical-devlog directory tree came later (D-M, 2026-07-21) and the roadmap-detail text was never updated to match.
**How to avoid:** Resolve deep-dive links via phase-number matching (verified consistent: `## Phase N: Title` headings in `roadmap/M0.X.md` correspond 1:1 to `phase-NN-slug.md` filenames in `technical/m0.X/` sharing phase number N), not by parsing the placeholder text.
**Warning signs:** Any implementation task that tries to `.match(/Deep-dive:\s*(.+)/)` and expects a path.

### Pitfall 4: Astro 7's default Markdown processor doesn't take `remarkPlugins` the old way
**What goes wrong:** Adding `markdown.remarkPlugins: [remarkWikilinks]` alone (without also installing `@astrojs/markdown-remark` and setting `markdown.processor: unified({...})`) still *works* in 7.0.9 (deprecated fields are still read), but is on a removal path and mixing it with an otherwise-Sätteri-processed site is confusing to future maintainers.
**Why it happens:** Astro 7 switched its default Markdown processor to `@astrojs/markdown-satteri`; the classic remark/rehype/`unified()` pipeline (where third-party remark plugins slot in) is now opt-in via `markdown.processor`.
**How to avoid:** Explicitly install `@astrojs/markdown-remark` and use `unified({ remarkPlugins: [...] })` as shown in Pattern 5 — the forward-compatible, non-deprecated path.
**Warning signs:** A `@deprecated` JSDoc warning surfacing in editor tooling on `markdown.remarkPlugins`; grep `node_modules/astro/dist/types/public/config.d.ts` for `@deprecated` near `remarkPlugins` to confirm this is still accurate on any future Astro upgrade.

### Pitfall 5: Shiki's default theme is dark, this site is light-only
**What goes wrong:** Leaving `markdown.shikiConfig` unset ships `github-dark`-themed code blocks (Astro's documented default) on a page whose entire palette is near-white/near-black (D-22).
**Why it happens:** Astro's Shiki default optimizes for the common dark-mode-first blog aesthetic, not this project's explicit light-only constraint.
**How to avoid:** Set `shikiConfig: { theme: 'github-light' }` explicitly in `astro.config.mjs` (Pattern 5).
**Warning signs:** A rendered technical deep-dive page with a visually jarring dark code block against the light body — should be caught by a UI review pass, but is worth calling out as an easy build-config miss.

### Pitfall 6: GitHub Pages 404 + base path — search results were contradictory, resolve empirically
**What goes wrong:** One round of WebSearch surfaced an older/lower-quality claim that a custom 404 page on a GitHub Pages *project* site (not user/org root site) "requires a custom domain" to work at all. A second, more targeted round (searching specifically for the Actions/`deploy-pages` artifact-based deploy this repo already uses) found the accurate, current mechanism: the 404 file must sit at the **top level of the uploaded artifact**, with no custom-domain requirement — which is exactly what `astro build`'s `dist/404.html` output already satisfies.
**Why it happens:** The stale claim likely describes the legacy Jekyll/branch-based Pages publishing model (a different `has_pages`/`build_type` configuration than this repo's confirmed `build_type: workflow`, per `01-RESEARCH.md` Pitfall 4), not the modern Actions-based artifact deploy.
**How to avoid:** Trust the Actions-artifact mechanism (matches this repo's already-verified deploy pipeline) — but because this is a genuine two-search-round conflict rather than a single clean source, **verify empirically at phase end**: after deploy, fetch a deliberately-nonexistent URL under `https://spoods-studios.github.io/interstellar-website/` and confirm the custom 404 page (not GitHub's generic 404) renders.
**Warning signs:** The live nonexistent-URL check (recommended above) returning GitHub's default 404 page instead of this project's styled one.

### Pitfall 7: The unreadied "extra" draft in `devlog/drafts/`
**What goes wrong:** `../studio/vault/devlog/drafts/` contains 11 `.md` files, not 9 — the two extras are `how-its-made.md` (CONT-03's real source, in scope) and `how-this-gets-built.md` (frontmatter `status: skeleton`, `date: TBD`, explicit process-foregrounding post scheduled for **after M1.1 close**, not this phase). A promote step that naively globs `drafts/*.md` would wrongly pull `how-this-gets-built.md` into `devlog/`.
**Why it happens:** Both files live in the same `drafts/` directory as the 8 milestone announcements; only frontmatter (`status: skeleton` vs `status: published`/`draft`) distinguishes readiness, and `how-this-gets-built.md` isn't even a milestone-tagged post (`milestone: (extra — between M1.1 and M1.2)`).
**How to avoid:** The promote step's file selection must be an explicit named list (9 announcement files + `how-its-made.md`), not a directory glob — matches D-25/D-43's framing of promotion as a manual, deliberate step this phase, not automation.
**Warning signs:** A `technical:` frontmatter-scan promote script that includes any file with `status: skeleton` — should be treated as a promote-script bug, not tolerated content.

## Code Examples

See Architecture Patterns 1–8 above — all code in this research is either read directly from installed package source (`generateId`/`glob()` mechanics, `render()`'s return shape) or synthesized this session against those verified signatures; none is copied verbatim from a fetched doc page except where explicitly marked `[CITED: url]`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-------------------|---------------|--------|
| `markdown.remarkPlugins` / `markdown.rehypePlugins` / `markdown.remarkRehype` / `markdown.gfm` / `markdown.smartypants` (flat config keys, remark/rehype/unified pipeline as the only processor) | `markdown.processor: satteri()` (new default) or `markdown.processor: unified({...})` (opt-in, for custom remark/rehype plugins) | `markdown.processor` introduced in Astro `6.4.0` per the installed `.d.ts`'s `@version` tag `[VERIFIED: node_modules/astro/dist/types/public/config.d.ts]`; the flat keys are now `@deprecated` | Directly affects D-39 — the plan must add `@astrojs/markdown-remark` and use the `unified()` factory, not the flat `remarkPlugins` array, to stay on Astro's supported path |
| Shiki language support requiring explicit per-language config in older tooling | Shiki bundles ~100+ languages by default (including C++) for standard fenced-code-block Markdown; explicit `embeddedLangs` is only needed for the separate `<Code />` component's dynamic-language use case | Ongoing Shiki default (not an Astro-version-specific change) | No extra config needed for this phase's ` ```cpp ` fences — only relevant if a future phase adopts the `<Code />` component directly |

**Deprecated/outdated:** `markdown.remarkPlugins`/`rehypePlugins`/`remarkRehype`/`gfm`/`smartypants` as direct `astro.config.mjs` keys — still functional in 7.0.9 but explicitly slated for removal; new plugin work should go through `markdown.processor`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A remark plugin visiting only `text` mdast nodes will never see `code`/`inlineCode` node content, based on training knowledge of mdast's parsing model (not independently re-fetched from a remark/unist docs URL this session) | Architecture Patterns, Pattern 4 / Pitfall 2 | If wrong, the `[[nodiscard]]` collision (verified present in the real corpus) would need an additional guard; low risk because this is extremely well-established mdast/unist behavior, not a fringe claim, and is indirectly corroborated by the corpus grep showing zero false-positive text-node matches in the sample read |
| A2 | Canonical URL emission has no dedicated Astro API (`Astro.canonicalURL` or similar) and the manual `new URL(Astro.url.pathname, Astro.site)` pattern is the standard approach | Architecture Patterns, Pattern 8 | If wrong (a built-in helper exists that this session's `grep` of installed `.d.ts` files missed), the plan would use slightly more verbose code than necessary — no functional risk, just a missed convenience |
| A3 | The GitHub Pages Actions-artifact 404 mechanism (top-level `404.html` in the uploaded artifact, no custom-domain requirement) is correct for this repo's confirmed `build_type: workflow` configuration | Architecture Patterns Pattern 7 / Common Pitfalls, Pitfall 6 | Explicitly flagged as needing empirical verification at phase end (fetch a nonexistent URL on the live deployed site) — a genuine two-search-round conflict, not a clean single-source claim |
| A4 | `parseFloat` numeric sort is sufficient for D-34's decimal phase numbers with no additional tie-breaking logic needed | Architecture Patterns, Pattern 1 | If a future phase number needs two decimal places (e.g. `10.55`) the same logic still works (parseFloat handles arbitrary decimal precision) — risk is effectively nil given the verified corpus only ever uses one decimal digit |
| A5 | Era→milestone grouping data (`Era 0`, `Era 1`, etc.) for `/technical/`'s index (D-40) should be sourced from `roadmap/M0.X.md`'s own `**Era:**` line (verified present, e.g. `M0.1.md`'s `**Era:** Era 0 (engine foundations).`) rather than a separately hand-written map, to keep one source of truth | Claude's Discretion item (era grouping mechanism) | Low risk either way — CONTEXT.md explicitly left this to discretion; a hand-written map is the simpler fallback if cross-collection era lookup proves awkward in practice, and both were verified as viable given the actual data shape |

**If this table is empty:** N/A — see rows above.

## Open Questions

1. **Exact `getContentEntryIdAndSlug` slugification behavior for nested paths without a custom `generateId`**
   - What we know: the installed `glob.js` source confirms `entry` is the base-relative path (subdirectories included) and the default `generateId` calls `getContentEntryIdAndSlug` with that full relative path — nested structure is preserved in principle.
   - What's unclear: this phase's plan uses custom `generateId` functions for all three new collections specifically to get milestone/phase-number extraction and loud-fail behavior, so the *default* slugification path is never actually exercised in practice — this is a non-blocking curiosity, not a risk to this phase.
   - Recommendation: no action needed; flagged only for completeness since Pattern 1's summary asserts the default preserves nesting.

2. **Whether `@astrojs/markdown-remark`'s `unified()` factory preserves Astro's default GFM/smartypants/heading-ID behavior identically to Sätteri, or whether switching processors changes any existing rendering subtly (e.g. table syntax, smart quotes)**
   - What we know: the official docs example shows `unified({ remarkPlugins: [...] })` as a drop-in `markdown.processor` value; Astro's own migration docs frame it as the supported alternative to Sätteri, implying feature parity for standard Markdown.
   - What's unclear: no explicit fetched-doc statement this session confirms 1:1 output parity for every corpus file (55 deep-dives + 9 announcements + 8 roadmap docs is a lot of surface area for a subtle rendering regression to hide in, e.g. a GFM table in a deep-dive rendering slightly differently).
   - Recommendation: the plan should include a verification step — diff-render a sample of files (at minimum `phase-12-force-model.md`, which has GFM tables in its "Seven pins" list format, and one file with a real wikilink) before/after the processor switch, or simply eyeball the built output for the whole corpus once, given the corpus is finite and closed (D-43) for this phase.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|--------------|-----------|---------|----------|
| `../studio/vault/` (sibling repo, read access) | Promote step (D-25/D-43) | ✓ `[VERIFIED: this session, all four source trees read directly]` | n/a (filesystem access, not a package) | — |
| Node.js / npm | Astro build | ✓ (unchanged from Phase 1) | v24.15.0 / 11.14.0 | — |
| `@astrojs/sitemap`, `@astrojs/markdown-remark` | SITE-04, D-39 | Not yet installed — new for this phase | 3.7.3 / 7.2.1 confirmed available on npm registry `[VERIFIED]` | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none — both new packages are confirmed available and versioned; installation is a planned task, not a blocker.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None installed `[VERIFIED: no test config/framework files found in repo listing beyond Phase 1's build.smoke.sh]` — consistent with Phase 1's precedent; this phase is templating/content-ingestion, still no application logic warranting a JS test runner |
| Config file | none — see Wave 0 Gaps |
| Quick run command | `npm run build` (exercises all 4 collections' Zod schemas + custom `generateId` throws + the remark plugin's loud-fail path in one pass) |
| Full suite command | `npm run build` + a post-build grep/count assertion script (see Wave 0 Gaps) — same reasoning as Phase 1: no separate unit-test layer exists or is warranted at this altitude |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CONT-02 | Homepage lists all 9 announcements; each opens and renders the untouched body | build-time + manual | `npm run build` (exit 0) then visually confirm `/` lists 9 entries and one full post matches its source `.md` byte-for-byte in the body | ❌ Wave 0 (content doesn't exist in repo yet — promote step is this phase's own deliverable) |
| CONT-03 | How It's Made page renders, absent from archive listing | build-time + manual | `npm run build`; `grep -c "how-its-made" dist/index.html` expect 0 | ❌ Wave 0 |
| CONT-04 | Roadmap overview + 8 milestone detail pages render, cross-link correctly | build-time + manual | `npm run build`; manually click through overview → each `/roadmap/m0.X/` → each phase's resolved deep-dive link | ❌ Wave 0 |
| SITE-04 | Mobile-responsive, 404, favicon, canonical, sitemap.xml | build-time + manual + live-fetch | `npm run build`; `test -f dist/404.html && test -f dist/favicon.svg && test -f dist/sitemap.xml`; live fetch a nonexistent URL post-deploy (Pitfall 6) | ❌ Wave 0 |
| D-33 (loud fail, technical) | A malformed `technical/` filename fails the build naming the file | negative smoke test | Deliberately stage a bad-named fixture in a scratch copy (never real `technical/`), point a throwaway loader at it, confirm non-zero exit + filename in error output — manual one-off, not committed, per Phase 1's established precedent for this class of test | N/A — deliberately manual per MVP mode |
| D-39 (loud fail, wikilink) | An unresolvable wikilink target fails the build naming file + link | negative smoke test | Same manual-fixture approach as above, applied to the remark plugin | N/A — deliberately manual |
| D-34 (numeric sort) | `/technical/` index lists phases in correct numeric order including decimals | build-time + manual | Visually confirm `phase-10.5` appears between `phase-10` and `phase-11` in the rendered `/technical/m0.2/` and `/technical/m0.3/` (etc.) index pages | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `npm run build` (fast, single Astro build; now exercises 4 collections + the remark plugin instead of 1)
- **Per wave merge:** `npm run build` + the file-existence checks above + a manual click-through of at least one full path per content tree (announcement → its deep-dives → roadmap detail → back)
- **Phase gate:** All four ROADMAP.md success criteria manually confirmed true, plus the live post-deploy 404 check (Pitfall 6) and the promoted-file-count sanity check (9 announcements, 55+1 technical, 8 roadmap, 2 pages) before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `technical/`, `roadmap/`, `pages/` directories — don't exist in the repo yet; created by the promote step, which is itself a Wave 0/1 deliverable of this phase
- [ ] Three new collection definitions in `src/content.config.ts` — extend Phase 1's file
- [ ] `src/lib/remark-wikilinks.mjs`, `src/lib/phase-sort.ts`, `src/lib/milestone-key.ts` — new shared helpers
- [ ] No JS test framework install needed — same MVP-mode reasoning as Phase 1

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|----------------|---------|--------------------|
| V2 Authentication | No | Static site, no auth surface |
| V3 Session Management | No | No sessions — no server |
| V4 Access Control | No | No access-controlled resources |
| V5 Input Validation | Partial, build-time only | Zod schemas (now on 4 collections) validate shape; content is git-controlled/trusted, promoted from a sibling repo the same operator controls — not untrusted runtime input. The wikilink resolver and `generateId` throws are themselves a *content-correctness* gate (D-33/D-39), not a security boundary, but they do prevent malformed/unexpected data from silently reaching rendered HTML |
| V6 Cryptography | No | No secrets, no crypto operations |
| V10 Malicious Code / Supply Chain | Yes | Run the Package Legitimacy Audit (above) on `@astrojs/sitemap` and `@astrojs/markdown-remark` before install (done); pin any new GitHub Actions the same way Phase 1 already pinned `withastro/action`/`actions/deploy-pages` (no new Actions needed this phase) |
| V14 Configuration | Yes | No new secrets or permissions needed this phase — the deploy workflow is unchanged from Phase 1 |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| A malicious or malformed wikilink target used to construct an arbitrary `href` (e.g. `javascript:` scheme or an absolute external URL disguised as an internal link) | Tampering | The resolver (Pattern 4) only ever returns a resolved *internal* site path derived from known collection IDs, or `null` (which throws) — it never passes the raw wikilink target through to the `href` unresolved, so there is no injection surface. Content is also git-trusted/promoted-by-the-same-operator, not third-party/untrusted input |
| A slopsquatted/typosquatted npm package sneaking into `package.json` | Tampering | Package Legitimacy Audit (above) run for both new dependencies before `npm install` |
| Cross-collection data leaking a `status: draft` entry into a generated cross-link list (e.g. a draft technical deep-dive showing up in an announcement's "deep-dives for this milestone" list) | Information Disclosure | D-30 already requires collections to honor `status: draft` like `devlog/` — the plan's cross-link-generation code (D-35) must filter on the same draft check the index pages use, not bypass it because it's "just chrome, not the main index" |

## Sources

### Primary (HIGH confidence)
- `node_modules/astro/dist/content/loaders/glob.js`, `glob.d.ts` — installed package source, read directly this session (generateId/entry/base signature, silent-empty-collection behavior, `../`/`/` pattern-prefix guards)
- `node_modules/astro/dist/types/public/config.d.ts` — installed types, read directly this session (`markdown.remarkPlugins`/`rehypePlugins`/`remarkRehype`/`gfm`/`smartypants` all marked `@deprecated`; `markdown.processor` introduced `@version 6.4.0`; `shikiConfig`/`syntaxHighlight` shape)
- `node_modules/astro/dist/content/runtime.d.ts`, `node_modules/astro/dist/types/public/content.d.ts`, `node_modules/@astrojs/internal-helpers/dist/markdown.d.ts` — installed types, read directly this session (`render()` return shape `{Content, headings, remarkPluginFrontmatter}`; `MarkdownHeading = {depth, slug, text}`)
- `node_modules/@astrojs/markdown-satteri/package.json`, `dist/index.d.ts` — installed package, read directly this session (confirms Sätteri is a real installed dependency, Astro 7's actual default processor)
- `npm view @astrojs/sitemap version`, `npm view @astrojs/markdown-remark version`, `npm view remark-wiki-link version`, `npm view typescript version` — this session, npm registry
- `gsd-tools query package-legitimacy check --ecosystem npm @astrojs/sitemap @astrojs/markdown-remark remark-wiki-link` — this session
- Direct filesystem reads this session, all four content trees: `../studio/vault/devlog/drafts/` (11 files enumerated, ls -la), `../studio/vault/devlog/technical/` (61 files total, per-milestone counts 6+6+8+8+8+6+8+5=55 for m0.1–m0.8, 5 for m1.1, verified via `find`), `../studio/vault/project/roadmap-detail/` (9 files: M0.1–M0.8 + M1.1), `../studio/vault/devlog/discord/roadmap-overview.pinned.md` (read in full)
- Two sampled deep-dives read in full: `technical/m0.1/phase-01-window-surface.md`, `technical/m0.3/phase-12-force-model.md`; plus `technical/_how-to-read.md`, `drafts/how-this-gets-built.md`, `drafts/m0.1-vulkan-bootstrap.md` (frontmatter), `roadmap-detail/M0.1.md` (head + full `Deep-dive:` grep)
- `grep -rn '\[\[' technical/` and `grep -rn '\[\[' roadmap-detail/` — this session, direct corpus scan (grounds the `[[nodiscard]]` collision finding and confirms only 1 real wikilink + 1 real wikilink-adjacent reference across both trees)
- `01-RESEARCH.md` (this repo, Phase 1) — re-used directly for the already-confirmed GitHub Pages `build_type: workflow` configuration and deploy pipeline, not re-derived

### Secondary (MEDIUM confidence)
- `docs.astro.build/en/guides/markdown-content/` — fetched via WebFetch this session (confirms `markdown.processor`/`unified()` recommended path, `MarkdownHeading` shape narrative, github-slugger heading-ID generation)
- `docs.astro.build/en/guides/syntax-highlighting/` — fetched via WebFetch this session (confirms `github-dark` default theme, zero-client-JS Shiki output, `embeddedLangs` scope)
- GitHub community discussions on Actions-based Pages 404 handling (`docs.github.com/en/pages/...troubleshooting-404...`, various `github.com/orgs/community/discussions/*`) — fetched via WebSearch this session, second round, cross-referenced against this repo's already-confirmed `build_type: workflow` config

### Tertiary (LOW confidence)
- WebSearch round 1 on "GitHub Pages custom 404.html project page repo subpath base" — surfaced an apparently outdated/Jekyll-era "requires a custom domain" claim, superseded by round 2's more targeted, Actions-specific result; kept in Pitfall 6 as an explicitly-flagged unresolved tension pending empirical phase-end verification
- WebFetch of `docs.astro.build/en/basics/astro-pages/#custom-404-error-page` — confirmed the basic `src/pages/404.astro` mechanism but explicitly stated it does not address GitHub-Pages-specific base-path routing
- WebFetch of `docs.astro.build/en/guides/integrations-guide/sitemap/` — confirmed minimal `site`+`integrations: [sitemap()]` setup but explicitly stated the docs don't address `base`-path prefixing behavior; not independently verified beyond the docs' own silence on the topic — recommend the planner spot-check `dist/sitemap.xml` for correctly base-prefixed URLs during Wave 0/1 verification rather than assuming it "just works"

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versions verified via npm registry this session; processor/deprecation facts verified directly against installed package source, which is stronger evidence than docs (it's the exact code that will run)
- Architecture: HIGH for Content Layer mechanics (installed source), MEDIUM for GitHub Pages 404/sitemap-base-path interaction (docs silent, community-discussion-sourced, explicitly flagged for empirical verification)
- Pitfalls: HIGH for the `[[nodiscard]]` collision and the `Deep-dive:` placeholder-text correction (both verified by direct corpus grep, not inference); MEDIUM/LOW for the GitHub Pages 404 mechanism (Pitfall 6, explicitly flagged as needing phase-end empirical confirmation)

**Research date:** 2026-07-22
**Valid until:** 2026-08-21 (30 days — Astro's Content Layer/Markdown-processor APIs are the fastest-moving surface touched here; re-verify the `markdown.remarkPlugins` deprecation status and `@astrojs/markdown-remark` version against installed `node_modules` if planning is delayed past this window, since this is exactly the kind of API that could complete its removal in a subsequent major)

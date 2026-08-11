# Phase 2: Content Rendering & Templating - Pattern Map

**Mapped:** 2026-07-22
**Files analyzed:** ~24 new/modified files (3 new collections + shared layouts/components/helpers + 9 page routes + config + promoted content dirs)
**Analogs found:** 3 exact in-repo analogs (config/collection/index) covering the extension pattern for everything else; all net-new file *shapes* (layouts, components, plugin, helpers, routes) have **no in-repo analog** — mapped to RESEARCH.md's verified Architecture Patterns instead, per this phase's explicit instruction.

**Correction carried from CONTEXT.md/RESEARCH.md banner:** D-39 is Sätteri
`mdastPlugins`, NOT remark/`unified()`. RESEARCH.md's Pattern 4/5 code
(`src/lib/remark-wikilinks.mjs`, `@astrojs/markdown-remark`, `unified({remarkPlugins})`)
is **superseded** — do not name any new file `remark-*` or install
`@astrojs/markdown-remark`. The binding shape is `markdown.processor:
satteri({ mdastPlugins: [wikilinkPlugin] })` using `defineMdastPlugin` from
the already-installed `satteri` package. The underlying mdast mechanics
RESEARCH.md verified (visit `text` nodes only, `[[nodiscard]]` collision,
loud-fail on unresolved target) are unaffected — only the registration API
and file name change. Name the file `src/lib/mdast-wikilinks.mjs` (or
equivalent), not `remark-wikilinks.mjs`.

## Repo State (why most of this phase has no in-repo analog)

Phase 1 left exactly one collection (`devlog`), one throwaway page
(`index.astro`), and one config file (`astro.config.mjs`) — no layouts, no
components, no `src/lib/`, no multi-collection cross-linking, no Markdown
plugin registration. This phase is the first to need any of those shapes.
Per the phase's `<important>` instruction: for the 3 mirrored collections,
extract `src/content.config.ts`'s **full current code** (read above) as the
excerpt; for `src/pages/index.astro`, extract its title/date-fallback and
draft-filter logic to be pulled into shared helpers; for everything else
(layouts, TOC, wikilink plugin, sort/normalize helpers, new routes, 404,
favicon), state plainly there is no analog and point at the relevant
RESEARCH.md Architecture Pattern instead of inventing one.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `src/content.config.ts` (extended: +3 collections) | model | file-I/O + transform | **itself** (Phase 1's `devlog` collection block, same file) | exact — same file, same pattern, 3x repetition with per-tree `generateId`/schema |
| `astro.config.mjs` (extended: +Sätteri mdastPlugins, +Shiki theme, +sitemap) | config | request-response (build-time) | **itself** (Phase 1's `site`/`base` block, same file) | exact — same file, additive keys only |
| `src/pages/index.astro` (REPLACED wholesale) | route/component (index) | CRUD, read-only | **itself, pre-replacement** — title/H1-fallback regex + `status !== 'draft'` filter + non-empty assert are extracted into shared helpers and reused | role-match (source of the logic being extracted, not the file being kept) |
| `src/lib/title-from-h1.ts` | utility | transform | `src/pages/index.astro`'s inline `H1_RE`/title-fallback block (lines 6, 30-31 pre-replacement) | exact — direct extraction of existing logic into a helper |
| `src/lib/draft-filter.ts` (or inlined per-query) | utility | transform | `src/pages/index.astro`'s inline `.filter((entry) => entry.data.status !== 'draft')` (line 24) | exact — direct extraction |
| `src/lib/phase-sort.ts` | utility | transform | none in-repo | no analog — RESEARCH.md Pattern 1 (`parsePhaseNumber`/`sortByPhaseNumber`) |
| `src/lib/milestone-key.ts` | utility | transform | none in-repo | no analog — RESEARCH.md Pattern 3 (`normalizeMilestone`) |
| `src/lib/mdast-wikilinks.mjs` (renamed from RESEARCH.md's `remark-wikilinks.mjs`) | utility (mdast plugin) | transform | none in-repo | no analog — RESEARCH.md Pattern 4's `text`-node-visitor logic ports directly; registration API changes per D-39 amendment (see below) |
| `src/lib/wikilink-resolver.mjs` | utility | transform (lookup) | none in-repo | no analog — new, resolves against collection IDs per D-32/D-35/D-38 URL shapes |
| `src/lib/toc.ts` | utility | transform | none in-repo | no analog — RESEARCH.md Pattern 6 (`buildToc`) |
| `src/layouts/BaseLayout.astro` | component (layout) | request-response | none in-repo | no analog — header/footer/nav chrome is entirely new; UI-SPEC "Page shell" section is the contract |
| `src/layouts/PostLayout.astro` | component (layout) | request-response | none in-repo, conceptually closest to pre-replacement `index.astro`'s render body (lines 42-54) for `<html>`/`<head>` shape only | no analog for the reading-layout structure itself — UI-SPEC "Layout factoring" section is the contract |
| `src/components/TableOfContents.astro` | component | transform + request-response | none in-repo | no analog — RESEARCH.md Pattern 6's `<nav class="toc">` markup |
| `src/pages/index.astro` (new archive homepage) | route/component | CRUD, read-only | pre-replacement version of the same file (query shape: `getCollection` + non-empty assert + filter + sort) | role-match — same file path, same query skeleton, new render target (list, not just ingestion proof) |
| `src/pages/404.astro` | route/component | request-response | none in-repo | no analog — RESEARCH.md Pattern 7 |
| `src/pages/devlog/[slug].astro` | route/component | CRUD, read-only | pre-replacement `index.astro`'s `getCollection('devlog')` + non-empty assert pattern | role-match |
| `src/pages/technical/index.astro` | route/component (index) | CRUD, read-only | pre-replacement `index.astro`'s list-render shape (query → filter → sort → map) | role-match, different sort key (phase number vs. date, per D-34) |
| `src/pages/technical/[milestone]/index.astro` | route/component (index) | CRUD, read-only | same as above, scoped to one milestone | role-match |
| `src/pages/technical/[milestone]/[slug].astro` | route/component (detail) | CRUD, read-only | pre-replacement `index.astro`'s query pattern; extends via `PostLayout` | role-match |
| `src/pages/roadmap/index.astro` | route/component | CRUD, read-only (renders `pages` collection entry + generated link list) | none in-repo — mixed prose+generated-list shape is new | no analog — UI-SPEC "Index/list contract, `/roadmap/`" |
| `src/pages/roadmap/[milestone].astro` | route/component (detail) | CRUD, read-only | pre-replacement `index.astro`'s query pattern | role-match |
| `src/pages/how-its-made.astro` (or `pages/[slug].astro`) | route/component (detail) | CRUD, read-only | pre-replacement `index.astro`'s query pattern | role-match |
| `public/favicon.svg` | asset | — | none in-repo | no analog — hand-authored per D-24, no code pattern applies |
| `technical/`, `roadmap/`, `pages/` (promoted content dirs) | content (data) | file-I/O (one-time promote copy) | `devlog/` (existing promote-drop target, untouched-by-repo-code contract) | exact — same read-only contract, same "never hand-edited" rule (repo CLAUDE.md) |

## Pattern Assignments

### `src/content.config.ts` — extend in place (model, file-I/O + transform)

**Analog:** the file's own existing `devlog` block (full current content read
this session):

```typescript
// src/content.config.ts — current state, Phase 1
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const FILENAME_RE = /^(\d{4}-\d{2}-\d{2})-(.+)\.md$/;

const devlog = defineCollection({
  loader: glob({
    pattern: ['**/*.md', '!_TEMPLATE.md'],
    // NOTE: glob()'s `base` resolves relative to the project root (config.root),
    // not relative to this file's directory — confirmed against the installed
    // astro package's own type declarations this session (Astro 7.0.9).
    base: './devlog',
    generateId: ({ entry }) => {
      const match = entry.match(FILENAME_RE);
      if (!match) {
        // D-10: loud failure naming the offending file
        throw new Error(
          `devlog/${entry}: filename must match YYYY-MM-DD-slug.md (no valid frontmatter date/slug fallback found)`
        );
      }
      return `${match[1]}-${match[2]}`; // keep date in the id — guarantees uniqueness
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

**Pattern to copy for the 3 new collections:** same 4-part shape every time —
`base: './<tree>'` (project-root-relative, per the comment's landmine note),
a `generateId` that throws a `<tree>/${entry}: <rule>` message naming the file
on any non-conforming filename (D-10's loud-fail convention extended by
D-33/D-38), a Zod `schema`, and a final `export const collections = { ... }`
merging all four. `technical`/`roadmap` need `z.object({}).strict().optional().default({})`
per D-33 (zero frontmatter fields exist) — see RESEARCH.md Pattern 1/2 for the
exact `generateId` regexes (`TECHNICAL_RE`, roadmap's `^M(\d+\.\d+)\.md$/i`).
`pages` should follow `devlog`'s permissive-optional-schema shape (it has
real frontmatter, confirmed: `how-its-made.md` carries real fields; `roadmap.md`
is hand-transcribed with at least `updated:` per D-20).

**Shared non-empty-collection assertion (Pitfall 1, ×4 now):** copy the
pattern from pre-replacement `index.astro` lines 15-19 (`if (entries.length
=== 0) throw new Error(...)`) once per collection query site, or centralize
in a `assertNonEmpty(entries, treeName)` helper in `src/lib/`.

### `src/pages/index.astro` — REPLACE wholesale, but harvest 3 blocks first (route/component)

**Analog:** the file's own pre-replacement content (full current content read
this session, 54 lines).

**Blocks to extract into `src/lib/` before deleting the inline versions:**

1. **Title-from-H1 fallback** (`src/lib/title-from-h1.ts`), lines 6, 30-31:
```typescript
const H1_RE = /^#\s+(.+)$/m;
// usage: entry.data.title ?? entry.body?.match(H1_RE)?.[1] ?? entry.id;
```
Needed by all three no-frontmatter/optional-title trees (`devlog`'s manifesto,
all 55 `technical/` deep-dives per D-33, `roadmap/` detail docs).

2. **Draft filter** (inline, reuse verbatim per collection query), line 24:
```typescript
.filter((entry) => entry.data.status !== 'draft')
```
Per D-30, apply identically to `technical`/`roadmap`/`pages` queries and to
D-35's generated cross-link lists (RESEARCH.md's Known Threat Patterns flags
this as a correctness requirement, not just style).

3. **Filename-date fallback**, lines 5, 26-29, 33-35 — stays specific to
`devlog`/`pages` (technical/roadmap have no dates, D-33/D-38); keep local to
those two collections' query sites rather than over-generalizing into a
shared helper.

4. **Non-empty-collection assert**, lines 15-19 — generalize into a 1-line
reusable helper (see above), used ×4.

**New archive-homepage render target:** query shape (`getCollection` →
assert non-empty → filter draft → map to `{title, date, milestone}` → sort by
date) is a direct continuation of the existing pattern; only the render body
changes (D-11's milestone tag + D-16's one-liner + D-13's flat list, per
UI-SPEC "Homepage" index contract) — no new query mechanism needed.

### `astro.config.mjs` — extend in place, D-39 corrected (config)

**Analog:** the file's own current content (7 lines, read this session):
```javascript
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://spoods-studios.github.io',
  base: '/interstellar-website',
});
```

**Additive keys this phase (corrected per the amended D-39 — do NOT use
RESEARCH.md's `unified`/`@astrojs/markdown-remark` code verbatim):**
```javascript
import { defineConfig } from 'astro/config';
import { satteri, defineMdastPlugin } from 'satteri'; // already installed — verify exact export names against node_modules/satteri before writing this
import sitemap from '@astrojs/sitemap';
import { wikilinkPlugin } from './src/lib/mdast-wikilinks.mjs';

export default defineConfig({
  site: 'https://spoods-studios.github.io',
  base: '/interstellar-website',
  integrations: [sitemap()],
  markdown: {
    processor: satteri({ mdastPlugins: [wikilinkPlugin] }),
    shikiConfig: {
      theme: 'github-light', // Astro/Shiki default is github-dark — must override (D-22/D-41)
    },
  },
});
```
Only `@astrojs/sitemap` is a genuinely new dependency this phase — `satteri`
is already Astro 7's installed default processor package (confirmed in
RESEARCH.md's own installed-source audit of `node_modules/@astrojs/markdown-satteri`).
**Do not** `npm install @astrojs/markdown-remark` — that package and the
`unified({remarkPlugins})` registration path are the superseded RESEARCH.md
proposal.

### `src/lib/mdast-wikilinks.mjs` — new, no analog (utility, transform)

RESEARCH.md Pattern 4's `text`-node-visitor body (using `unist-util-visit`)
is the correct underlying logic and should port with the file renamed and its
export/registration shape adapted to `defineMdastPlugin` (Sätteri's plugin
factory) instead of a bare `unified` remark-plugin function. Keep:
- Visit `text` nodes ONLY — never `code`/`inlineCode` (verified safe against
  the `[[nodiscard]]` collision, RESEARCH.md Pitfall 2, corpus-grep confirmed).
- Loud throw naming `file.path` and the unresolved `[[target|label]]` on a
  `resolve()` miss (D-39).
- `resolve(target: string) => string | null` delegated to a separate
  `src/lib/wikilink-resolver.mjs` (project-specific lookup against known
  collection IDs per D-32's URL shapes) — kept as its own file per RESEARCH.md's
  Pattern 5 import structure, just re-imported into the Sätteri registration
  instead of `unified`'s.

No in-repo analog exists for either file — first Markdown-AST-level code in
the repo.

### `src/lib/phase-sort.ts`, `src/lib/milestone-key.ts` — new, no analog (utility, transform)

Port RESEARCH.md's Pattern 1 (`parsePhaseNumber`/`sortByPhaseNumber`, D-34
numeric-aware sort) and Pattern 3 (`normalizeMilestone`, D-35 case-join key)
verbatim — both are pure functions, version-independent of the D-39
Sätteri/remark correction, and already verified against the real corpus's
decimal phase numbers and case-mismatched milestone strings this session.

### `src/layouts/BaseLayout.astro`, `src/layouts/PostLayout.astro`, `src/components/TableOfContents.astro` — new, no analog

No layout or component file exists anywhere in the repo yet (Phase 1 shipped
one flat page, no `src/layouts/` or `src/components/` directories). Do not
invent an analog — build directly from:
- **UI-SPEC.md** "Page shell", "Layout factoring", "TOC placement and depth"
  sections for the concrete contract (header/nav/footer markup, ~65ch column,
  breakpoint, sticky-sidebar-vs-`<details>` TOC).
- **RESEARCH.md Pattern 6** (`buildToc`, the `MarkdownHeading` shape, the
  `<a href={\`#${h.slug}\`}>` anchor-matching guarantee) for `TableOfContents.astro`'s
  data contract.
- Pre-replacement `index.astro`'s `<html>`/`<head>`/`canonicalUrl` block
  (lines 42-47) is the only reusable fragment — the canonical-URL computation
  (`Astro.site` + `import.meta.env.BASE_URL`) moves into `BaseLayout.astro`'s
  `<head>` verbatim (RESEARCH.md Pattern 8 confirms no built-in Astro helper
  exists beyond this manual pattern).

### `src/pages/404.astro` — new, no analog

RESEARCH.md Pattern 7's code is the direct implementation (adjust the import
to `BaseLayout` once it exists):
```astro
---
import BaseLayout from '../layouts/BaseLayout.astro';
---
<BaseLayout title="Page not found">
  <h1>Page not found.</h1>
  <p>The page you're looking for doesn't exist — it may have moved or the link is out of date.</p>
  <a href={import.meta.env.BASE_URL}>← Back home</a>
</BaseLayout>
```
Copy must match UI-SPEC's exact 404 copy (D-19): heading "Page not found.",
body text, link text "← Back home".

### Detail/index route files (`devlog/[slug]`, `technical/**`, `roadmap/**`, `how-its-made`) — role-match only

None of these route files exist yet, but all share one query skeleton
already established by pre-replacement `index.astro`:
```
const entries = await getCollection('<tree>');
if (entries.length === 0) throw new Error('<tree> collection resolved to zero entries — check the glob loader base path');
const visible = entries.filter((e) => e.data.status !== 'draft');
```
— reuse this exact skeleton per new route/index, varying only the sort key
(date for `devlog`/`pages`; `sortByPhaseNumber` for `technical`; milestone
number for `roadmap`) and the cross-link joins (`normalizeMilestone`, D-35).

## Shared Patterns

### Loud-fail-on-malformed-content (D-10, extended by D-33/D-39)
**Source:** `src/content.config.ts`'s existing `generateId` throw + pre-replacement
`index.astro`'s non-empty-collection assert.
**Apply to:** all 3 new `generateId` functions (technical/roadmap/pages),
every new collection's non-empty assertion, and `mdast-wikilinks.mjs`'s
unresolved-target throw. Every throw message must name the offending file
(and, for wikilinks, the unresolved target) — never a silent skip.

### `set:html` for titles (git-trusted content)
**Source:** pre-replacement `index.astro` line 51 (`<li set:html={...} />`).
**Apply to:** any new template rendering a derived title string (avoids
double-escaping apostrophes in real titles like "Before the Galaxy, a
Triangle" and "How It's Made") — same reasoning holds for all four trees'
content, all still git-trusted/promoted-by-the-same-operator.

### `glob()`'s project-root-relative `base` landmine
**Source:** `src/content.config.ts`'s existing inline comment (lines 9-13).
**Apply to:** all 3 new collection loader configs — `base: './technical'`,
`base: './roadmap'`, `base: './pages'`, not `'../technical'` etc.

### Case-normalized milestone join key (D-35)
**Source:** RESEARCH.md Pattern 3, `src/lib/milestone-key.ts` (new).
**Apply to:** every cross-collection lookup — announcement→deep-dives,
deep-dive→announcement+roadmap-detail, roadmap-overview→milestone-detail
links. Never compare raw `"M0.1"` vs `"m0.1"` with `===`.

### Draft-status filtering, including in generated chrome (D-30)
**Source:** pre-replacement `index.astro` line 24.
**Apply to:** all 4 collections' index/detail queries AND D-35's generated
cross-link lists (RESEARCH.md's Security Domain explicitly flags a draft
technical deep-dive leaking into an announcement's "deep-dives for this
milestone" list as an information-disclosure-class bug if the cross-link
code bypasses this filter).

## No Analog Found

Files/directories with no close in-repo match — build from RESEARCH.md's
cited Architecture Patterns and UI-SPEC.md's concrete contract, not from
invented precedent:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `src/layouts/BaseLayout.astro` | component | request-response | First layout file in repo — no `src/layouts/` dir exists |
| `src/layouts/PostLayout.astro` | component | request-response | First layout file in repo |
| `src/components/TableOfContents.astro` | component | transform | First component file in repo — no `src/components/` dir exists |
| `src/lib/mdast-wikilinks.mjs` | utility | transform | First mdast/Markdown-AST-level code in repo; also the file RESEARCH.md's proposal for this is superseded (D-39 amendment) |
| `src/lib/wikilink-resolver.mjs` | utility | transform | New, repo-specific collection-ID resolution logic |
| `src/lib/phase-sort.ts` | utility | transform | First numeric-aware sort helper in repo |
| `src/lib/milestone-key.ts` | utility | transform | First cross-collection join-key helper in repo |
| `src/lib/toc.ts` | utility | transform | First TOC-derivation helper in repo |
| `src/pages/404.astro` | route | request-response | First error page in repo |
| `src/pages/roadmap/index.astro` | route | CRUD | Mixed prose+generated-list shape has no prior template in repo |
| `public/favicon.svg` | asset | — | Hand-authored artwork (D-24), no code pattern applies |

## Metadata

**Analog search scope:** full `src/` tree (`content.config.ts`, `pages/index.astro`,
`astro.config.mjs` — the only 3 code files that exist), repo root directory
listing (confirms no `src/layouts/`, `src/components/`, `src/lib/` yet), and
`../studio/vault/` samples read directly this session
(`technical/m0.1/phase-01-window-surface.md`, `project/roadmap-detail/M0.1.md`,
`devlog/drafts/m0.1-vulkan-bootstrap.md` frontmatter, `technical/_how-to-read.md`)
to ground the content-shape claims underlying the schema/generateId patterns above.
**Files scanned:** 3 existing code files (full read) + 4 vault content samples (partial read) + 01-PATTERNS.md (Phase 1's map, reused for repo-state framing)
**Pattern extraction date:** 2026-07-22

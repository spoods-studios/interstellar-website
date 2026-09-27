---
phase: 03-rss-opengraph-discord-distribution
reviewed: 2026-08-11T14:47:41Z
depth: deep
files_reviewed: 19
files_reviewed_list:
  - src/assets/og-default.svg
  - src/layouts/BaseLayout.astro
  - src/layouts/PostLayout.astro
  - src/lib/describe-entry.ts
  - src/lib/devlog-meta.ts
  - src/lib/entry-order.ts
  - src/lib/hero-assets.ts
  - src/lib/hero-image.ts
  - src/lib/site.mjs
  - src/pages/404.astro
  - src/pages/devlog/[slug].astro
  - src/pages/how-its-made.astro
  - src/pages/index.astro
  - src/pages/roadmap/index.astro
  - src/pages/roadmap/[milestone].astro
  - src/pages/rss.xml.ts
  - src/pages/technical/how-to-read.astro
  - src/pages/technical/[milestone]/[slug].astro
  - tests/distribution.smoke.sh
  - tests/lib.smoke.mjs
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-08-11T14:47:41Z
**Depth:** deep
**Files Reviewed:** 19
**Status:** issues_found

## Summary

Reviewed the RSS/OpenGraph/Discord-distribution phase at deep depth, including
one cross-file trace outside the formal file list (`src/content.config.ts`)
that was necessary to verify a claim made inline by `hero-assets.ts` and to
check the draft-visibility guard's behavior across all four content
collections it's applied to. No Critical-severity defects were found — the
code is deliberately defensive (loud-fail guards for the invite constant,
hero resolution, empty collections, malformed GoatCounter codes) and the
distribution smoke harness exercises those failure paths directly rather than
just asserting the happy path.

The Warning-tier findings are all **latent** — none currently manifest against
today's content set, which is exactly why they survived UAT and live-deploy
verification: none of the nine devlog posts, four standalone/roadmap trees,
or 55 technical deep-dives happen to exercise the gap. They are real code
defects, not hypotheticals invented for the sake of finding something: each
is reproducible by pointing to the specific line(s) responsible and the
specific future/edge-case input that would trip it.

Most notable: `src/content.config.ts`'s `roadmap` collection schema is
`z.object({}).strict()` — no `status` field — while `roadmap/index.astro`,
`roadmap/[milestone].astro`, and `technical/[milestone]/[slug].astro` all
call `.filter(isVisible)` against that same collection. `isVisible()` reads
`entry.data.status`, which can never be anything but `undefined` for a
roadmap entry (the strict empty schema rejects any frontmatter at all), so
the draft-hiding guard is dead code for that one tree — silently, with no
build failure and no existing test that would catch it. The `technical`
collection schema's own comment (content.config.ts:60-64) explicitly names
this exact failure mode ("a structural no-op") as the reason `status` was
added there; the same reasoning was not carried over to `roadmap`.

## Warnings

### WR-01: Draft-hiding guard is a structural no-op for the roadmap collection

**File:** `src/content.config.ts:82` (root cause), consumed by `src/pages/roadmap/index.astro:14,30`, `src/pages/roadmap/[milestone].astro:15-16`, `src/pages/technical/[milestone]/[slug].astro:20`
**Issue:** The `roadmap` collection's schema is `z.object({}).strict()` — it has no `status` field, unlike `devlog`, `technical`, and `pages`, which all carry `status: z.enum(['draft', 'published', 'final']).optional()`. Every one of the three call sites above runs `.filter(isVisible)` (from `src/lib/content-guards.ts`) against `getCollection('roadmap')` results, but since `entry.data` for a roadmap entry can only ever be `{}` (any frontmatter key would fail the strict schema at build time), `isVisible()`'s `entry.data.status !== 'draft'` check is always `true`. There is no way to draft a roadmap milestone page — the guard that's supposed to make that possible silently never fires. The `technical` schema's own comment (lines 60-64) names this exact failure mode ("a structural no-op") as the reason `status` was deliberately added there; the identical fix was not applied to `roadmap`.
**Fix:**
```diff
 const roadmap = defineCollection({
   loader: glob({
     pattern: ['M*.md'],
     base: './roadmap',
     generateId: ({ entry }) => {
       const match = entry.match(ROADMAP_RE);
       if (!match) {
         throw new Error(`roadmap/${entry}: filename must match M{milestone}.md (D-38)`);
       }
       return `m${match[1]}`;
     },
   }),
-  schema: z.object({}).strict(),
+  schema: z.object({ status: z.enum(['draft', 'published', 'final']).optional() }).strict(),
 });
```

### WR-02: `describe-entry.ts`'s chrome-skip allowlist misses several valid Markdown block types, letting non-prose content leak into the public description and RSS feed

**File:** `src/lib/describe-entry.ts:6-13`
**Issue:** `firstProseBlock()`'s `BLOCK_SKIP` only recognizes ATX headings, a leading image, blockquotes, `-`/`*`/`+`/`N.` lists, tables, and `---`/`***`-style thematic breaks. It does not skip: raw HTML blocks or HTML comments (`<!-- internal note -->`), `___`-style thematic breaks (a valid CommonMark horizontal rule the current `/^(-{3,}|\*{3,})$/` regex does not match), ordered lists using `)` instead of `.` (`1)` is valid CommonMark), or footnote definitions (`[^1]: ...`). If any future devblog/technical/roadmap entry opens its body with one of these block types immediately after the H1 (e.g. an editorial `<!-- TODO: rewrite this intro -->` comment, common practice when drafting), `firstProseBlock()` returns that block verbatim as the entry's `og:description`, `<meta name="description">`, and RSS item `<description>` — i.e. an internal note or a stray `___` literal ships as the public-facing description with no error, no test failure, and no visual indicator anywhere in the pipeline. This directly undercuts the stated D-51/D-58 intent ("never hand-written, never omitted... a loud failure naming the entry" for the *no-prose* case) because the *wrong-prose* case has no equivalent guard at all.
**Fix:** Extend `BLOCK_SKIP` (or better, delegate to the same Markdown block-type detection the render pipeline already uses) to also skip HTML blocks/comments and `___` thematic breaks at minimum:
```diff
 const BLOCK_SKIP = [
   /^#/,
   /^!\[/,
   /^>/,
   /^[-*+]\s|^\d+[.)]\s/,
   /^\|/,
-  /^(-{3,}|\*{3,})$/,
+  /^(-{3,}|\*{3,}|_{3,})$/,
+  /^<!--/,
+  /^</, // raw HTML block
 ];
```

### WR-03: `heroFor()` depends on Astro's undocumented internal `assetImports` field — an Astro upgrade could silently disable hero-image resolution

**File:** `src/lib/hero-assets.ts:24-26`
**Issue:** `heroFor()` reads `entry.assetImports?.[0]`. `assetImports` is not part of Astro's public `CollectionEntry<T>` type surface — it only appears in `astro/dist/content/data-store.d.ts` and `runtime.d.ts` as an internal `DataEntry`/loader-metadata field (confirmed by grepping the installed `astro@7.0.9` package: it is absent from the public content type declarations under `astro/dist/types/public/`). Because `heroFor()`'s parameter type is a structural subset (`{ id: string; assetImports?: string[] }`) rather than the real `CollectionEntry<'devlog'>` type, TypeScript raises no warning about relying on an unexported field. If a future Astro version renames, restructures, or removes this internal field, `entry.assetImports?.[0]` silently becomes `undefined` — `lookupHero()` never throws (its "no ref" branch is designed for exactly this case: "no body image means the default card, not an error," see `hero-image.ts:27`), so every devlog post's hero image quietly reverts to the generic default OG card with zero build-time or test-time signal. This is precisely the "silent fall-through... hide a bad promote behind a plausible embed" failure mode D-48 was written to prevent, just triggered by a dependency upgrade instead of a bad promote.
**Fix:** At minimum, add a comment flagging this as a private-API dependency to check on every Astro major-version bump, or better, add a build-time assertion (e.g. in `astro.config.mjs`'s `validateContentLoudFail()`) that at least one devlog entry with a known body image resolves a non-null hero, so an Astro upgrade that breaks this trips a loud failure instead of a silent one.

### WR-04: `absolutize()` in the RSS route doesn't rewrite the `srcset` attribute — a latent broken-image risk in feed readers

**File:** `src/pages/rss.xml.ts:27-51`
**Issue:** `sanitize-html`'s default `allowedAttributes` for `img` includes `srcset` (verified against the installed `sanitize-html@2.17.6` package: `defaults.allowedAttributes.img = ['src', 'srcset', 'alt', 'title', 'width', 'height', 'loading']`). `absolutize()`'s `transformTags` only rewrites `src` (via `toAbsolute('src')`) and, for `a`, `href` — it never touches `srcset`. Today this is harmless because Astro currently emits `srcset=""` for every built hero image (confirmed against `dist/devlog/*/index.html`), so there's no relative URL to leak. But `srcset` passes through `sanitize-html` unmodified whenever it's non-empty, and the moment Astro's image pipeline (or a future responsive-image change) starts populating real `srcset` candidates, those candidate URLs will ship into the RSS feed exactly as authored — typically root-relative `_astro/...` paths — which are broken links in every feed reader, the same failure class `absolutize()` exists to prevent for `src`/`href`.
**Fix:**
```diff
   const toAbsolute =
     (attr: 'src' | 'href') => (tagName: string, attribs: Record<string, string>) => {
       const value = attribs[attr];
       if (value && value.startsWith('/')) {
         attribs[attr] = new URL(value, site).href;
       } else if (value && !/^https?:/i.test(value) && !value.startsWith('#')) {
         throw new Error(...);
       }
       return { tagName, attribs };
     };
+  // srcset carries one-or-more "<url> <descriptor>," candidates and needs the
+  // same absolutize treatment per-candidate, or must be stripped if empty.
```
At minimum, add an assertion (mirroring the D-48 fixture style already used elsewhere in this phase) that fails the build loudly if any built `img` ever carries a non-empty `srcset`, so a future regression is caught before a broken feed ships rather than discovered by a reader's dead image.

### WR-05: No TypeScript type-checking gate in the build or test pipeline

**File:** `package.json` (scripts), demonstrated by `src/pages/technical/[milestone]/[slug].astro:64-73`
**Issue:** `npm run build` runs only `astro build` and `npm test` runs `bash tests/run-all.sh` (Node assertions + shell smoke tests) — neither invokes `tsc` or `astro check`, and `@astrojs/check` is not a devDependency (confirmed: `package.json` only lists `typescript` under `devDependencies`; running `astro check` interactively prompts to install `@astrojs/check`, meaning it has never been run in this repo/CI). Astro's Vite-based `.astro` compilation only strips types at build time — it does not type-check them. As a concrete example of what this gap misses: `technical/[milestone]/[slug].astro`'s `breadcrumbs` array is built as
```ts
const breadcrumbs = [
  announcementEntry && { href: ..., label: ... },
  roadmapEntry && { href: ..., label: ... },
].filter((b) => b !== undefined && b !== null && b !== false);
```
`.filter()` with a manual boolean predicate (rather than a type-predicate function `(b): b is LinkRef => ...`) does not narrow the array's type — under `tsc --strict` this expression is `(LinkRef | false)[]`, which is not assignable to `PostLayout`'s `breadcrumbs?: LinkRef[]` prop. The code is runtime-correct today (the filter genuinely removes every falsy entry), so this is not a functional bug — but it, and any other type mismatch introduced anywhere in this phase's `.ts`/`.astro` files, would currently ship undetected by any automated gate.
**Fix:** Add `@astrojs/check` + `typescript` to a `typecheck` script (`"typecheck": "astro check"`) and wire it into `npm test` or CI, and use a type predicate at the breadcrumbs call site:
```ts
).filter((b): b is LinkRef => Boolean(b));
```

## Info

### IN-01: `src/assets/og-default.svg` is an orphaned file — never imported or built

**File:** `src/assets/og-default.svg`
**Issue:** `OG_DEFAULT.file` in `src/lib/site.mjs:41` points at `og-default.png`, which is served from `public/og-default.png` (a plain static asset, outside Astro's build pipeline). `src/assets/og-default.svg` is not referenced by any `.astro`, `.ts`, or `.mjs` file in the repo (confirmed by grep across `src/`), and `hero-assets.ts`'s glob only picks up `*.png` from the repo-root `assets/` directory, not `src/assets/`. Both files were added in the same commit (`6f0bbef`); the SVG appears to be the source design the PNG was manually rendered from, but nothing in the build documents or enforces that relationship, and the SVG itself ships no value dead in the tree.
**Fix:** Either delete `src/assets/og-default.svg` if it's truly unused, or add a one-line comment at the top of the file (or in `site.mjs` near `OG_DEFAULT`) noting it's the manual-render source for `public/og-default.png` and is not build-referenced, so a future reader doesn't assume it's live.

### IN-02: `absolutize()`'s href guard only accepts `http(s)`, root-relative, or fragment URLs — rejects valid `mailto:`/`tel:` links with a hard build failure

**File:** `src/pages/rss.xml.ts:33-38`
**Issue:** Any anchor `href` that isn't root-relative, `http(s)://`, or `#`-prefixed throws, crashing the entire `astro build` (this is a deliberate loud-fail design per the comment on line 34, and today's content has no such link, so nothing breaks). But the allowlist is narrower than valid Markdown/HTML permits — `mailto:`, `tel:`, and other legitimate schemes all throw. Given this is a loud, named failure (not a silent one), the severity is low, but the failure mode is surprising: an author adding a perfectly ordinary `[email me](mailto:x@y.com)` link to a devblog post would break the site-wide build with an error message about `absolutize()`, not about the actual cause.
**Fix:** Extend the allowlist to include known-safe non-http schemes, e.g. `!/^(https?|mailto|tel):/i.test(value)`.

### IN-03: `entryDate()` has an unreachable dead-code fallback

**File:** `src/lib/devlog-meta.ts:13-17`
**Issue:** `entryDate()` falls back to `new Date(0)` when `entry.id` doesn't match `FILENAME_DATE_RE`. But `src/content.config.ts`'s devlog loader's `generateId` (lines 15-23) throws at build time for any devlog filename that doesn't match `/^(\d{4}-\d{2}-\d{2})-(.+)\.md$/`, which guarantees every `entry.id` that reaches `entryDate()` already starts with a valid `YYYY-MM-DD` prefix. The `new Date(0)` branch can never execute in practice.
**Fix:** No action required — this is reasonable defensive coding, just worth a one-line comment noting it's unreachable-by-construction so a future reader doesn't spend time trying to find a devlog entry that hits it.

### IN-04: `distribution.smoke.sh` hardcodes content-count magic numbers that will need manual upkeep as the devblog grows

**File:** `tests/distribution.smoke.sh:132, 158`
**Issue:** The harness asserts `DISTINCT_IMAGE_COUNT -ne 4` (default card + exactly 3 hero plots) and `DISTINCT_DESCRIPTIONS -le 60` (currently far above 60 across ~64+ pages). Both are golden/canary values tied to today's exact content inventory. This is arguably intentional (a canary that fails loudly is safer than a silent pass), but it means every time a new hero image or a large batch of new deep-dives lands, this test will fail until the constants are bumped — worth a short comment at each assertion noting it's expected to need updating, so a future contributor doesn't mistake the failure for a real regression.
**Fix:** No functional change needed; consider a comment at each hardcoded threshold noting it must be bumped when new hero images/content land.

---

_Reviewed: 2026-08-11T14:47:41Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_

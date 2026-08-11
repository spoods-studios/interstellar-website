---
phase: 02-content-rendering-templating
reviewed: 2026-07-22T14:40:00Z
depth: deep
files_reviewed: 33
files_reviewed_list:
  - astro.config.mjs
  - package.json
  - src/content.config.ts
  - src/lib/mdast-wikilinks.mjs
  - src/lib/wikilink-resolver.mjs
  - src/lib/mdast-deepdive-links.mjs
  - src/lib/content-guards.ts
  - src/lib/devlog-meta.ts
  - src/lib/milestone-key.ts
  - src/lib/phase-sort.ts
  - src/lib/title-from-h1.ts
  - src/lib/toc.ts
  - src/layouts/BaseLayout.astro
  - src/layouts/PostLayout.astro
  - src/components/TableOfContents.astro
  - src/pages/index.astro
  - src/pages/404.astro
  - src/pages/how-its-made.astro
  - src/pages/devlog/[slug].astro
  - src/pages/roadmap/index.astro
  - src/pages/roadmap/[milestone].astro
  - src/pages/technical/index.astro
  - src/pages/technical/how-to-read.astro
  - src/pages/technical/[milestone]/index.astro
  - src/pages/technical/[milestone]/[slug].astro
  - src/styles/global.css
  - public/favicon.svg
  - tests/run-all.sh
  - tests/lib.smoke.mjs
  - tests/build.smoke.sh
  - tests/shell.smoke.sh
  - tests/collections.smoke.sh
  - tests/markdown.smoke.sh
  - tests/post.smoke.sh
  - tests/technical.smoke.sh
  - tests/roadmap.smoke.sh
  - tests/site.smoke.sh
findings:
  critical: 2
  warning: 2
  info: 4
  total: 8
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-07-22T14:40:00Z
**Depth:** deep
**Files Reviewed:** 33 (source) + all `tests/*` harness files read for context
**Status:** issues_found

## Summary

Reviewed the whole content-rendering/templating layer: the four content
collections, the two custom mdast plugins, the wikilink resolver, the
decimal-aware sort/key helpers, all page routes, and the shared layouts. I
also ran the committed test suite (`bash tests/run-all.sh`, exit 0, all
green) and then reproduced two defects live against the actual `astro build`
pipeline (not just the isolated `markdownToHtml()` calls the unit harness
uses) by injecting fixtures and reverting them afterward; the working tree
was left clean (`git status --porcelain` empty) after every experiment.

The stateful heading→text handling in `mdast-deepdive-links.mjs` (focus item
1) is **not** a leak risk: `@astrojs/markdown-satteri`'s `render()` (and the
config-load preflight's own direct `markdownToHtml()` calls) construct a
fresh `data` bag per document, so `ctx.data.deepDiveCurrentPhase` cannot
survive between files. Base-path handling (focus item 2) is consistently
correct everywhere `import.meta.env.BASE_URL` is read — every one of the
eight call sites re-derives the trailing-slash-safe `base` locally; no repeat
of the previously-fixed defect was found. `phase-sort.ts`'s naive
`parseFloat` subtraction is also *not* a version of the `milestoneSortKey`
"M0.10 vs M0.9" bug — the corpus's decimal phase numbers (10.5, 14.5, 21.5,
21.7, 27.5, 46.1) are true decimal fractions by design (confirmed against
`technical/_how-to-read.md`'s own description: "Decimal numbers... are
phases inserted after the fact"), so `21.5 < 21.7 < 22` sorts correctly under
plain numeric comparison.

However, the **loud-fail guarantee** (focus item 3) and **draft-visibility
filtering** (focus item 4) both have real, reproducible gaps — one of them a
live, verified silent-content-loss regression matching exactly the failure
mode `astro.config.mjs`'s own preflight comment says it exists to prevent.

## Critical Issues

### CR-01: Loud-fail preflight validates only `technical/` and `roadmap/` — `devlog/` and `pages/` can still silently ship empty content

**File:** `astro.config.mjs:69-93` (`validateContentLoudFail`)
**Issue:** The wikilink mdast plugin (`createWikilinkPlugin`) is registered
globally via `markdown: { processor: satteri({ mdastPlugins }) }`
(`astro.config.mjs:104`), so it runs on **every** Markdown text node across
all four content collections — `devlog`, `technical`, `roadmap`, and `pages`.
`validateContentLoudFail()`, whose entire purpose (per its own inline
comment) is to force any plugin-thrown error to crash config load instead of
being silently swallowed by Astro's glob loader, only walks `TECHNICAL_ROOT`
and `ROADMAP_ROOT`. It never reads `devlog/` or `pages/` files.

I reproduced the gap live: appended a dangling `[[m9.9/phase-99-does-not-exist]]`
wikilink to `devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md`
and ran `npm run build`.

- Exit code: **0** (success).
- Build log contained only a swallowed line:
  `[ERROR] [glob-loader] Error rendering 2026-04-07-...md: Unresolvable wikilink in ...`
- The built page still existed and still carried its title (read via
  `titleFromH1(entry.body, ...)`, which reads the raw, unrendered
  frontmatter/body string, so the H1 fallback still worked), but its
  `<Content />` body was rendered empty:
  - Broken build: `dist/devlog/.../index.html` = **2311 bytes**
  - Clean rebuild: same file = **10147 bytes**

This is precisely the "log it, store empty content, never rethrow, `astro
build` exits 0" behavior the preflight function was built to prevent — it
just doesn't cover two of the four trees it needs to. `tests/site.smoke.sh`'s
D-39 fixture only injects the same kind of dangling link into a
`technical/` file, so this gap is untested as well as unguarded. Currently
latent only because no `devlog/`/`pages/` file happens to contain `[[...]]`
today — a single typo or an accidental Obsidian-style paste in a future
devlog post silently ships a blank announcement.

**Fix:**
```js
const DEVLOG_ROOT = fileURLToPath(new URL('./devlog', import.meta.url));
const PAGES_ROOT = fileURLToPath(new URL('./pages', import.meta.url));

function validateContentLoudFail() {
  // ...existing technicalFiles / roadmapFiles collection...
  const devlogFiles = fs
    .readdirSync(DEVLOG_ROOT)
    .filter((file) => file.endsWith('.md') && file !== '_TEMPLATE.md')
    .map((file) => nodePath.join(DEVLOG_ROOT, file));
  const pagesFiles = fs
    .readdirSync(PAGES_ROOT)
    .filter((file) => file.endsWith('.md'))
    .map((file) => nodePath.join(PAGES_ROOT, file));

  for (const filePath of [...technicalFiles, ...roadmapFiles, ...devlogFiles, ...pagesFiles]) {
    const source = fs.readFileSync(filePath, 'utf8');
    markdownToHtml(source, { mdastPlugins, fileURL: pathToFileURL(filePath) });
  }
}
```
Also add a `tests/site.smoke.sh` (or dedicated) fixture that injects a
dangling wikilink into a `devlog/` file and asserts the build fails loudly,
mirroring the existing D-39 technical/ fixture.

### CR-02: `technical/how-to-read.astro` bypasses the site's only draft-filter, unlike every other single-entry route

**File:** `src/pages/technical/how-to-read.astro:10`
**Issue:** Every other "fetch one specific entry and 404/throw if it's not
visible" route in the codebase follows the same pattern:
`assertNonEmpty(await getCollection(...), name).filter(isVisible).find(...)`
followed by a thrown error if not found (see `src/pages/how-its-made.astro:10-14`
and `src/pages/roadmap/index.astro:13-17`). `how-to-read.astro` instead calls
`getEntry('technical', 'how-to-read')` directly with no `isVisible` check at
all.

Reproduced live: added `status: draft` frontmatter to
`technical/_how-to-read.md` and ran `npm run build`.

- Exit code: **0**.
- `dist/technical/how-to-read/index.html` **was still built** and rendered
  the full page content ("How to Read..." heading present).
- `technical/index.astro`'s "How to read these entries" link
  (`technical/index.html`) still pointed at it.

This directly violates `content-guards.ts`'s documented invariant: *"D-30:
the single draft-filter implementation the whole site shares... a drafted
target must not be linked"* (echoed in `technical/[milestone]/[slug].astro`'s
own comment). The `technical` collection's schema does support `status`
(`z.object({ status: z.enum([...]).optional() }).strict()`), so this is a
live, currently-reachable gap, not a schema-blocked one.

**Fix:**
```js
import { getCollection, render } from 'astro:content';
import { assertNonEmpty, isVisible } from '../../lib/content-guards';
// ...
const technicalEntries = assertNonEmpty(await getCollection('technical'), 'technical').filter(isVisible);
const entry = technicalEntries.find((e) => e.id === 'how-to-read');
if (!entry) {
  throw new Error("technical collection has no visible 'how-to-read' entry");
}
```

## Warnings

### WR-01: `set:html` used on plain-text, content-derived titles/labels with no escaping

**File:** `src/pages/index.astro:47`, `src/layouts/PostLayout.astro:37-38`
**Issue:** `post.title` (`index.astro`) and `prevNext.prev.label` /
`prevNext.next.label` (`PostLayout.astro`) are plain-text strings — either a
frontmatter `title` or the result of `titleFromH1()`, a raw regex-extracted
line of Markdown source. None of these are meant to carry markup. Rendering
them via `set:html` bypasses Astro's normal auto-escaping entirely: any
future title containing `&`, `<`, or `>` (very plausible for a devblog about
a C++ engine — e.g. a post referencing `std::vector<T>` or using "&") would
render as broken/mismatched HTML instead of the literal characters, or in
the worst case inject unintended markup into the page. No currently
committed title contains such characters, so this hasn't fired yet, but it's
an unforced escape-bypass with no compensating benefit — the only reason
`set:html` is used at all is to splice a literal `&larr;`/`&rarr;` HTML
entity next to an interpolated label in the same attribute value.

**Fix:** Render the entity and the label as separate nodes instead of one
concatenated `set:html` string, so the label stays auto-escaped:
```astro
{prevNext?.prev && <a href={prevNext.prev.href}>&larr; {prevNext.prev.label}</a>}
{prevNext?.next && <a href={prevNext.next.href}>{prevNext.next.label} &rarr;</a>}
```
(Astro's template parser treats bare `&larr;`/`&rarr;` text outside `{}` as
literal HTML, same as any `.html` file — no `set:html` needed.) Same fix
applies to `index.astro:47`: just `<a href={post.href}>{post.title}</a>`.

### WR-02: `technical/[milestone]/index.astro` fetches its roadmap entry without the shared `isVisible` filter

**File:** `src/pages/technical/[milestone]/index.astro:32`
**Issue:** `const roadmapEntry = await getEntry('roadmap', milestoneKey);`
reads the roadmap entry directly to build `milestoneDisplay`, unlike
`technical/index.astro` (which uses `roadmapEntries.filter(isVisible)`) and
`technical/[milestone]/[slug].astro` (same). I verified this is **currently
inert**: the `roadmap` collection's schema is `z.object({}).strict()`
(`content.config.ts:82`), which rejects any `status` key outright —
confirmed live by adding `status: draft` to a roadmap file, which fails the
build with `Unrecognized key: "status"`. So no roadmap entry can be drafted
today, and this bypass can't currently leak anything.

It's still a real inconsistency: the moment `status` is ever added to the
roadmap schema (a plausible future change, since `devlog`/`technical`/`pages`
all already have it), this route silently starts leaking a drafted
milestone's roadmap title into the per-milestone technical index heading,
with no test anywhere that would catch it (the D-30 fixture in
`tests/site.smoke.sh` only exercises a `technical/` entry).

**Fix:** Mirror the pattern used one file over in
`technical/[milestone]/[slug].astro`:
```js
const roadmapEntries = assertNonEmpty(await getCollection('roadmap'), 'roadmap').filter(isVisible);
// ...
const roadmapEntry = roadmapEntries.find((e) => e.id === milestoneKey);
```

## Info

### IN-01: The phase-filename shape is duplicated verbatim across three files

**File:** `src/content.config.ts:39` (`TECHNICAL_RE`), `src/lib/wikilink-resolver.mjs:9`
(`TECHNICAL_RE`), `astro.config.mjs:24` (`PHASE_FILE_RE`)
**Issue:** All three independently encode
`m\d+(?:\.\d+)?/phase-(\d+(?:\.\d+)?)-(.+)` (or the equivalent without the
milestone segment). They currently agree, but nothing enforces that they
stay in sync if the filename convention ever changes — a maintainer fixing
one could easily miss the other two.
**Fix:** Export one shared regex (or a small parse helper) from a single
`lib/` module and import it in all three call sites.

### IN-02: Newest-first sort comparator duplicated between the archive and the post route

**File:** `src/pages/index.astro:18-20`, `src/pages/devlog/[slug].astro:23-25`
**Issue:** Both files independently write
`(a, b) => entryDate(b).getTime() - entryDate(a).getTime()`, each with a
comment noting they must never disagree. A shared `sortByDateDesc()` helper
in `devlog-meta.ts` (alongside `entryDate`/`formatDate`) would make that
invariant structural instead of comment-enforced.
**Fix:** Extract to `devlog-meta.ts`:
```ts
export function sortByDateDesc(entries: CollectionEntry<'devlog'>[]) {
  return [...entries].sort((a, b) => entryDate(b).getTime() - entryDate(a).getTime());
}
```

### IN-03: `entryDate()`'s filename-fallback branch is structurally unreachable

**File:** `src/lib/devlog-meta.ts:12-16`
**Issue:** `entryDate` falls back to `new Date(0)` if `entry.id` doesn't
match `FILENAME_DATE_RE`. But `entry.id` is only ever produced by
`content.config.ts`'s devlog `generateId`, which already throws at ingestion
time for any filename not matching `^(\d{4}-\d{2}-\d{2})-(.+)\.md$` — so by
the time `entryDate` runs, the date prefix is guaranteed present. Harmless,
but dead defensive code that could mask a real bug if it were ever
triggered (silently rendering "January 1, 1970" instead of failing loudly,
inconsistent with the project's loud-fail convention elsewhere).
**Fix:** Optional — could assert/throw instead of silently defaulting, for
consistency with the rest of the codebase's loud-fail posture. Low priority.

### IN-04: `titleFromH1` has no structural guarantee it reads the *first* line

**File:** `src/lib/title-from-h1.ts:5`
**Issue:** `H1_RE = /^#\s+(.+)$/m` matches the first line **anywhere** in the
raw Markdown source that starts with `# `, not specifically line 1. It
happens to work today because every committed `technical/`/`roadmap/`
document's real title is the literal first line, and JS `.match()` returns
the earliest match. There's no code-level guarantee of that ordering, so a
future document that opens with a blockquote/preamble before its H1 would
silently pick up whatever "# " line comes first, and a document with no H1
at all silently falls back to displaying its raw collection id
(`m0.1/phase-01-window-surface`) as the title rather than failing the build
— inconsistent with D-33's stated "no frontmatter fallback exists for this
tree" and the project's general loud-fail posture for structural content
issues.
**Fix:** Low priority given the current corpus is uniform; if it's ever
worth hardening, restrict the match to the start of the string
(`/^#\s+(.+)/`, no `m` flag) and/or throw when no title is found for trees
that have no frontmatter fallback.

---

_Reviewed: 2026-07-22T14:40:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_

# Phase 3: RSS, OpenGraph & Discord Distribution - Pattern Map

**Mapped:** 2026-07-22
**Files analyzed:** 11 (7 new, 4 modified — 2 of them cross-repo)
**Analogs found:** 9 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `src/pages/rss.xml.ts` (NEW) | route / build-time endpoint | transform (collection → XML) | **none surviving** — `src/pages/index.astro` (same query shape), `src/pages/devlog/[slug].astro` (same `render()` usage) | partial (role gap: no `APIRoute` exists in-repo today) |
| `src/lib/describe-entry.ts` (NEW) | utility (pure body-derived helper) | transform | `src/lib/title-from-h1.ts` | exact |
| `src/lib/hero-image.ts` (NEW) | utility (asset lookup + loud-fail) | transform | `src/lib/title-from-h1.ts` + `src/lib/content-guards.ts` (throw shape) | role-match |
| `src/lib/site.ts` or `.mjs` (NEW, D-54 invite constant) | config | n/a | `astro.config.mjs:12-13` (`BASE`/`NORMALIZED_BASE`) + `astro.config.mjs:99-110` (`validateContentLoudFail`) | exact |
| `src/assets/og-default.svg` (NEW) | asset (authoring master) | file-I/O | `public/favicon.svg` | exact |
| `public/og-default.png` (NEW) | asset (published raster) | file-I/O | `public/favicon.svg` (same `public/` verbatim-copy mechanism) | role-match |
| `tests/distribution.smoke.sh` (NEW) | test | batch/assertion | `tests/site.smoke.sh` | exact |
| `src/layouts/BaseLayout.astro` (MOD) | layout | request-response (SSG render) | itself — extend in place | exact |
| `tests/lib.smoke.mjs` (MOD) | test | batch/assertion | itself — append cases in existing style | exact |
| `package.json` (MOD) | config | n/a | itself | exact |
| `../studio/vault/community/*.md` (MOD, cross-repo) | doc | file-I/O | none (vault prose, not code) | n/a |

**Note:** `src/lib/feed-content.ts` (RESEARCH's suggested structure) is optional — if the
planner keeps `absolutize()` inline in `rss.xml.ts` (as Code Example 1 does), it inherits the
endpoint's patterns. If split out, it follows the `src/lib/` helper shape below.

---

## Pattern Assignments

### `src/lib/describe-entry.ts` (utility, transform)

**Analog:** `src/lib/title-from-h1.ts` — the closest possible match: a pure,
module-scope-regex, body-derived string helper with a WHY-comment header naming its
decisions, unit-tested by direct import in `tests/lib.smoke.mjs`.

**Full analog file** (`src/lib/title-from-h1.ts:1-9`) — copy this shape exactly:
```typescript
// D-33 (technical/roadmap trees carry no frontmatter title) and D-01 (the
// frontmatter-less manifesto) both fall back to the body's first H1.

const H1_RE = /^#\s+(.+)$/m;

export function titleFromH1(body: string | undefined, fallback: string): string {
  const match = body?.match(H1_RE);
  return match ? match[1].trim() : fallback;
}
```

Structural rules to copy:
1. Leading WHY-comment naming the **decision IDs** it implements (here: D-51/D-52/D-58).
2. Regexes hoisted to `const` at module scope, `SCREAMING_SNAKE` named (`H1_RE`,
   `FILENAME_DATE_RE` in `devlog-meta.ts:10`, `FILENAME_RE`/`TECHNICAL_RE`/`ROADMAP_RE` in
   `content.config.ts:4,38,69`).
3. Named exports only, no default export, no class.
4. Pure — no `import.meta.env`, no `astro:content` value imports (type-only imports are fine,
   see `devlog-meta.ts:7`), so `tests/lib.smoke.mjs` can import it under bare Node.

**Loud-fail on `null` prose block (D-58)** — copy the error-throw shape from
`src/lib/content-guards.ts:4-11`:
```typescript
export function assertNonEmpty<T>(entries: T[], treeName: string): T[] {
  if (entries.length === 0) {
    throw new Error(
      `${treeName} collection resolved to zero entries — check the loader base path in src/content.config.ts`
    );
  }
  return entries;
}
```
Message shape across the whole repo is `` `${offender}: what went wrong — what to check` ``
(see `content.config.ts:20-22`, `:52-54`, `:77`). D-58's message must name the entry id.

**Sibling reference for optional-frontmatter fallback chains:** `src/lib/devlog-meta.ts:12-20`
```typescript
export function entryDate(entry: CollectionEntry<'devlog'>): Date {
  if (entry.data.date) return entry.data.date;
  const match = entry.id.match(FILENAME_DATE_RE);
  return match ? new Date(`${match[1]}T00:00:00Z`) : new Date(0);
}

export function entryTitle(entry: CollectionEntry<'devlog'>): string {
  return entry.data.title ?? titleFromH1(entry.body, entry.id);
}
```

---

### `src/lib/hero-image.ts` (utility, transform + loud-fail)

**Analog:** `src/lib/title-from-h1.ts` for shape; `src/lib/content-guards.ts:4-11` for the throw.

**Critical structural constraint (RESEARCH Wave-0 gap):** `import.meta.glob` is Vite-only and
cannot be imported by `tests/lib.smoke.mjs` under bare Node. Every other `src/lib/*.ts` file in
this repo is glob-free and directly importable — see `tests/lib.smoke.mjs:11-17`:
```javascript
import { parsePhaseNumber, sortByPhaseNumber } from '../src/lib/phase-sort.ts';
import { normalizeMilestone, milestoneSortKey } from '../src/lib/milestone-key.ts';
import { titleFromH1 } from '../src/lib/title-from-h1.ts';
import { assertNonEmpty, isVisible } from '../src/lib/content-guards.ts';
import { buildToc } from '../src/lib/toc.ts';
```
So `hero-image.ts` must split: a **pure** exported lookup taking the map as a parameter
(unit-testable), plus the `import.meta.glob` call that supplies it (not unit-tested). The repo
has one precedent for the "factory takes its dependency as a parameter" shape —
`createWikilinkResolver({ base, technicalRoot })` (`tests/lib.smoke.mjs:108-111`) and
`createWikilinkPlugin({ resolve })` (`:140`). Use that same injected-dependency idiom.

---

### `src/lib/site.ts` / invite constant + D-54 loud-fail (config)

**Analog:** `astro.config.mjs` — both the constant pattern and the proven config-load-time
failure hook.

**Constant + normalization pattern** (`astro.config.mjs:12-13`):
```javascript
const BASE = '/interstellar-website';
const NORMALIZED_BASE = BASE.endsWith('/') ? BASE : `${BASE}/`;
```

**The proven loud-fail hook** (`astro.config.mjs:85-110`) — the whole WHY-comment matters here,
it is the 02-08 lesson RESEARCH says not to re-learn:
```javascript
// 02-08 Task 2 finding: Astro's own glob loader (astro@7.0.9's
// content/loaders/glob.js) catches every render() error per-entry, logs it as
// `[ERROR] [glob-loader] ...`, and stores the entry with empty rendered
// content -- it never rethrows, so `astro build` exits 0 and silently ships
// an empty page ...
function validateContentLoudFail() {
  for (const { root, recursive, exclude } of CONTENT_TREES) {
    for (const filePath of collectMarkdownFiles(root, { recursive, exclude })) {
      const source = fs.readFileSync(filePath, 'utf8');
      // Errors here propagate straight out of config evaluation -- unlike the
      // glob loader's own try/catch, nothing downstream swallows this one.
      markdownToHtml(source, { mdastPlugins, fileURL: pathToFileURL(filePath) });
    }
  }
}

validateContentLoudFail();
```
Call the D-54 guard the same way: a bare top-level call in `astro.config.mjs`, *before*
`export default defineConfig(...)` (line 112). RESEARCH Pattern 4 recommends Option A with the
constant living in a `.mjs` module both `astro.config.mjs` and `src/lib/site.ts` import — note
`astro.config.mjs:8-10` already imports three `./src/lib/*.mjs` modules, so this crossing is
established:
```javascript
import { createWikilinkResolver } from './src/lib/wikilink-resolver.mjs';
import { createWikilinkPlugin } from './src/lib/mdast-wikilinks.mjs';
import { createDeepDiveLinkPlugin } from './src/lib/mdast-deepdive-links.mjs';
```

**Constraint:** `tests/build.smoke.sh:17` asserts no hardcoded host/base under `src/`:
```bash
! grep -rIn -e 'github\.io' -e '/interstellar-website' src/
```
`https://discord.gg/…` does not trip this, but the feed endpoint must derive its site URL from
`context.site` / `import.meta.env.BASE_URL`, never a literal.

---

### `src/pages/rss.xml.ts` (route / build-time endpoint, transform)

**No surviving analog** — there is no `APIRoute` in `src/pages/` today. The two Phase-2
diagnostic endpoints (`collection-counts.json.ts`, `markdown-render-check.astro`) were deleted,
and `tests/site.smoke.sh:127-130` actively asserts they stay gone:
```bash
echo "== Diagnostic routes from Plan 02-03 are gone (orchestrator note) =="
[ ! -f dist/collection-counts.json ]
[ ! -d dist/markdown-render-check ]
```
Use RESEARCH § Code Example 1 for the endpoint scaffold. Two in-repo patterns still bind it:

**Collection query pattern — copy verbatim** (`src/pages/index.astro:13-21`, the archive D-45
must not drift from):
```typescript
const allEntries = assertNonEmpty(await getCollection('devlog'), 'devlog');
const visible = allEntries.filter(isVisible);

// Same ordering as src/pages/devlog/[slug].astro's prev/next chain -- the
// archive and the post route must never disagree on order.
const sorted = [...visible].sort(
  (a, b) => entryDate(b).getTime() - entryDate(a).getTime()
);
```
Identical expression at `src/pages/devlog/[slug].astro:15-25`. Do **not** write an inline
`({data}) => data.status !== 'draft'` predicate — import `isVisible` from
`src/lib/content-guards.ts:15-17`.

**Base normalization pattern** (repeated verbatim at `BaseLayout.astro:15-16`,
`devlog/[slug].astro:60-61`, `index.astro:23-24`):
```typescript
const rawBase = import.meta.env.BASE_URL;
const base = rawBase.endsWith('/') ? rawBase : `${rawBase}/`;
```

**Render pattern** (`src/pages/devlog/[slug].astro:6,50`):
```typescript
import { getCollection, render } from 'astro:content';
const { Content, headings } = await render(entry);
```

**Import ordering convention** across all routes: `astro:content` first, then `../lib/*`
helpers, then layouts/components last (`devlog/[slug].astro:6-12`).

---

### `src/layouts/BaseLayout.astro` (layout, MODIFIED)

**Analog:** itself. Full current file is the contract — three insertion points, all already
reserved.

**Existing absolute-URL + base expressions to reuse** (`:11-16`) — `og:url` reuses
`canonicalUrl`, `og:image`/`rss.xml`/CTA hrefs use `base`:
```typescript
const canonicalUrl = new URL(Astro.url.pathname, Astro.site).toString();
// BASE_URL has no guaranteed trailing slash (astro.config.mjs's configured
// base ends with no slash), so appending route segments directly would glue
// them onto the last path component instead of separating with '/'.
const rawBase = import.meta.env.BASE_URL;
const base = rawBase.endsWith('/') ? rawBase : `${rawBase}/`;
```

**`<head>` block to extend** (`:20-27`) — the OG/Twitter/theme-color/`rel=alternate` tags join
here. Note the existing conditional-render idiom and the `{`${base}…`}` href shape:
```astro
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    {description && <meta name="description" content={description} />}
    <link rel="canonical" href={canonicalUrl} />
    <link rel="icon" href={`${base}favicon.svg`} type="image/svg+xml" />
  </head>
```
**Escaping:** use plain `{expr}` for every new `content=` / `href=` / `title=`. Do **not** use
`escapeHtml()` here (RESEARCH Pitfall 6; UI-SPEC corrected). `escapeHtml` stays confined to its
existing `set:html` call sites.

**Props interface to extend** (`:4-9`) — new optional props (`ogType`, `heroImage`,
`publishedTime`, …) follow the existing optional-with-`?` shape:
```typescript
export interface Props {
  title: string;
  description?: string;
}

const { title, description } = Astro.props;
```

**Header nav — D-17's reserved slot** (`:31-36`). Append the fifth `<a>`, same bare shape as
the four siblings, no class, no wrapper:
```astro
      <nav>
        <a href={base}>Devblog</a>
        <a href={`${base}technical/`}>Technical</a>
        <a href={`${base}how-its-made/`}>How It's Made</a>
        <a href={`${base}roadmap/`}>Roadmap</a>
      </nav>
```

**Footer — D-18's reserved slot** (`:41-43`):
```astro
    <footer>
      <p>© 2026 Spoods Studios</p>
    </footer>
```
Becomes `© 2026 Spoods Studios · RSS · Join the Discord` inside the same single `<p>`, ` · `
as literal text. No CSS: `nav`'s `flex-wrap` + `gap: 8px 16px` (`src/styles/global.css:66-70`)
already absorbs the fifth nav item, and the footer is plain text flow
(`global.css:82-86`).

---

### `src/assets/og-default.svg` + `public/og-default.png` (asset, file-I/O)

**Analog:** `public/favicon.svg` — carries the literal Phase-2 font stack, the exact `IE`
letterform, and the two palette colors the card must match:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <rect width="32" height="32" fill="#fefefe"/>
  <text x="16" y="22" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" font-size="16" font-weight="600" fill="#1a1a1a">IE</text>
</svg>
```
Copy the `font-family` string **verbatim**; UI-SPEC requires it. Drop the `<rect>` on the card
(UI-SPEC: invisible against `#fefefe`, a stray element). Wordmark weight `600` matches
`header .wordmark` (`global.css:59-64`).

`public/` is served verbatim and unhashed — same mechanism `BaseLayout.astro:26` relies on for
`favicon.svg`, and `tests/site.smoke.sh:66-72` proves that mechanism holds per-page.

---

### `tests/distribution.smoke.sh` (test, batch)

**Analog:** `tests/site.smoke.sh` — exact match; it is the whole-site harness this file extends.
Picked up automatically by `tests/run-all.sh:12-15`, no harness edit:
```bash
for script in tests/*.smoke.sh; do
  echo "== running $script =="
  bash "$script"
done
```

**Header + strict mode + cwd** (`tests/site.smoke.sh:1-18`) — every smoke script opens this way:
```bash
#!/usr/bin/env bash
# Whole-site smoke harness for Phase 2 Plan 08. Task 1: SITE-04 close-out
# sweep -- canonical coverage, sitemap completeness, dead-link sweep, zero
# client JS. ...
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Clean build =="
rm -rf dist
npm run build
```

**IDIOM 1 — `$PREFIX` derived from `astro.config.mjs`, never hardcoded**
(`tests/site.smoke.sh:20-27`) — reuse verbatim for the feed `<link>`/`<guid>` and the absolute
`og:url`/`og:image` assertions:
```bash
# --- Derive the expected canonical/sitemap URL prefix from astro.config.mjs
# itself (SITE-02: the site/base live in one config location, never a literal
# repeated here). ---
SITE=$(grep -oP "site:\s*'\K[^']+" astro.config.mjs)
BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
PREFIX="${SITE}${NORMALIZED_BASE}"
echo "expected canonical/sitemap prefix: $PREFIX"
```

**IDIOM 2 — per-file coverage loop with `grep -o | wc -l` occurrence counting**
(`tests/site.smoke.sh:29-48`) — the DIST-02 "every page emits exactly one of each OG tag" loop
is a direct clone of this, with the `case "$HREF" in "$PREFIX"*)` prefix check reused for
`og:url`/`og:image`:
```bash
echo "== Canonical coverage: every built page carries exactly one canonical link, base-prefixed =="
CANON_FAIL=0
while IFS= read -r f; do
  COUNT=$(grep -o '<link rel="canonical"' "$f" | wc -l)
  if [ "$COUNT" -ne 1 ]; then
    echo "FAIL: $f has $COUNT canonical link elements (expected exactly 1)"
    CANON_FAIL=1
    continue
  fi
  HREF=$(grep -o '<link rel="canonical" href="[^"]*"' "$f" | sed -E 's/.*href="([^"]*)".*/\1/')
  case "$HREF" in
    "$PREFIX"*) ;;
    *)
      echo "FAIL: $f canonical href '$HREF' does not carry the expected prefix '$PREFIX'"
      CANON_FAIL=1
      ;;
  esac
done < <(find dist -name "*.html")
[ "$CANON_FAIL" -eq 0 ]
echo "canonical coverage OK"
```
The WHY behind `grep -o | wc -l` is documented at `tests/build.smoke.sh:21-26`:
```bash
# grep -c counts matching LINES, not occurrences -- Astro's production build
# minifies dist/index.html to a single line, so -c always reports 1 regardless
# of post count. grep -o | wc -l counts actual occurrences instead.
test "$(grep -o 'href="[^"]*devlog/[^"]*/"' dist/index.html | wc -l)" -eq 9
```
That last line is also the exact expression the DIST-01 "feed item count == archive link count"
assertion compares against.

**IDIOM 3 — trap-and-restore loud-fail fixture** (`tests/site.smoke.sh:132-150`). The D-48
(bad hero path) and D-54 (blank invite constant) fixtures are clones of this, including the
final content-tree-clean check:
```bash
echo "== D-39 fixture: an unresolvable wikilink in a technical document fails the build loudly, naming the file and the link =="
D39_FILE="technical/m0.1/phase-06-ci-pipeline.md"
D39_BACKUP=$(mktemp)
cp "$D39_FILE" "$D39_BACKUP"
trap 'cp "$D39_BACKUP" "$D39_FILE" 2>/dev/null || true; rm -f "$D39_BACKUP"' EXIT
printf '\nDangling [[m9.9/phase-99-does-not-exist]] link.\n' >> "$D39_FILE"
if npm run build > /tmp/gsd-site-d39.log 2>&1; then
  cp "$D39_BACKUP" "$D39_FILE"
  echo "D-39 FIXTURE FAIL: build did not error on an unresolvable wikilink"
  exit 1
fi
grep -q "phase-06-ci-pipeline.md" /tmp/gsd-site-d39.log
grep -q "m9.9/phase-99-does-not-exist" /tmp/gsd-site-d39.log
cp "$D39_BACKUP" "$D39_FILE"
if git status --porcelain devlog/ technical/ roadmap/ pages/ | grep -q .; then
  echo "D-39 FIXTURE FAIL: a content tree was left dirty"
  exit 1
fi
echo "D-39 fixture OK: build failed loudly naming the file and the unresolved link; content trees clean"
```
Variant for a fixture whose build must *succeed* (the DIST-01 draft-post fixture): see the D-30
block, `tests/site.smoke.sh:152-184` — same backup/trap/restore, `npm run build` unguarded, a
`*_LEAK=0` accumulator, restore, then exit.

Tail convention (`tests/site.smoke.sh:204-213`): `trap - EXIT`, a final clean rebuild, a
content-tree-clean assertion, and `echo "ALL CHECKS PASSED"` as the last line — the runner
depends on the non-zero exit, but every script ends with that literal.

---

### `tests/lib.smoke.mjs` (test, MODIFIED)

**Analog:** itself. Append `describeEntry` and `heroFor` sections in the existing style.

**Section shape** (`tests/lib.smoke.mjs:57-64,66-76`) — banner `console.log`, top-level
assertions, closing OK log:
```javascript
console.log('== title-from-h1 ==');
assert.equal(
  titleFromH1('# A Moon That Actually Orbits\n\nbody', 'fallback'),
  'A Moon That Actually Orbits'
);
assert.equal(titleFromH1('no heading here', 'fallback'), 'fallback');
assert.equal(titleFromH1('text with a # not at line start', 'fallback'), 'fallback');
console.log('title-from-h1 OK');

console.log('== content-guards ==');
assert.throws(() => assertNonEmpty([], 'technical'), /technical/);
```

**Throw-naming assertion pattern** (`:171-186`) — the D-48/D-58 loud-fail cases assert on both
identifiers in the message, exactly as this does:
```javascript
    let threw = false;
    try {
      markdownToHtml(source, { ... });
    } catch (err) {
      threw = true;
      assert.match(err.message, /phase-01-window-surface\.md/);
      assert.match(err.message, /m9\.9\/phase-99-does-not-exist/);
    }
    assert.ok(threw, 'expected an unresolvable wikilink target to throw');
```
Note: `.ts` files are imported with their explicit `.ts` extension (`:11-15`). New assertion
sections go **before** the final `console.log('ALL CHECKS PASSED');` at `:197`.

---

### `package.json` (config, MODIFIED)

**Analog:** itself. Add to `dependencies` (not `devDependencies` — `@astrojs/sitemap` and
`satteri` are both build-time-only and live in `dependencies`):
```json
  "dependencies": {
    "@astrojs/sitemap": "^3.7.3",
    "astro": "^7.0.9",
    "satteri": "^0.9.5"
  },
```
Existing entries use caret ranges. RESEARCH § Security recommends pinning the two new packages
exactly (`@astrojs/rss@4.0.19`, `sanitize-html@2.17.6`) — that is a deliberate departure from
the surrounding caret convention; the planner should state it explicitly if adopted.

---

### Cross-repo vault edits (D-56)

**No code analog.** Two literal placeholder replacements, verified present this session:
- `../studio/vault/community/Discord Architecture.md:9` → `**Invite link:** (add when created)`
- `../studio/vault/community/Handles Secured.md:7` → the `Discord | Spoods Studios` table row's
  URL cell reads `(add invite link)`
- `../studio/vault/community/Phase 0 Launch Checklist.md:14` → `- [ ] Record the permanent
  invite link in \`Discord Architecture.md\` ("Invite link:")` — the checkbox D-56 ticks.
  (CONTEXT.md cites line 15; the actual line is 14 as of this reading.)

These are outside this repo's git tree — a separate, separately-committed step.

---

## Shared Patterns

### Loud-fail over silent skip
**Sources:** `src/lib/content-guards.ts:1-11`, `src/content.config.ts:18-23`,
`astro.config.mjs:85-110`
**Apply to:** `describe-entry.ts` (D-58), `hero-image.ts` (D-48), `rss.xml.ts` (D-46),
the invite constant (D-54)

Message contract, from `content.config.ts:19-23`:
```typescript
      if (!match) {
        // D-10: loud failure naming the offending file
        throw new Error(
          `devlog/${entry}: filename must match YYYY-MM-DD-slug.md (no valid frontmatter date/slug fallback found)`
        );
      }
```
Every message: offender identifier first, then what is wrong, then where to look. Every throw
carries a WHY-comment naming the decision ID.

### Base normalization
**Source:** `src/layouts/BaseLayout.astro:12-16` (canonical version with the WHY-comment)
**Apply to:** `rss.xml.ts`, every new href/URL in `BaseLayout.astro`
Repeated verbatim in three files already; do not invent a fourth spelling.

### URL prefix derived from config, never literal
**Sources:** `astro.config.mjs:12,113-114` (the single source);
`tests/build.smoke.sh:17` (the guard); `tests/site.smoke.sh:22-27` (the test-side derivation)
**Apply to:** feed endpoint, `og:image`/`og:url`, `distribution.smoke.sh`

### Escaping — two contexts, opposite rules
**Sources:** `src/lib/escape-html.ts:1-11`, `src/pages/index.astro:46-48`
```typescript
// WR-01 (02-REVIEW.md): escapes only the characters that would actually
// break HTML parsing (&, <, >). Apostrophes/quotes are deliberately left
// untouched -- set:html was originally chosen at these call sites so
// contraction-heavy devblog titles ("Doesn't", "I'm") render as plain
// literal text ...
export function escapeHtml(input: string): string {
  return input.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
```
`escapeHtml` is for `set:html` call sites **only** (`index.astro:48`,
`PostLayout.astro:38-39`). Every new `<head>` attribute uses plain `{expr}` — RESEARCH Pitfall 6.

### Comment density
**Source:** all of `src/lib/`, `astro.config.mjs`, every `tests/*.smoke.sh`
**Apply to:** everything new
Comments are dense **but exclusively WHY** — each names a decision ID or a discovered landmine
(`content.config.ts:8-13`, `build.smoke.sh:21-26`, `astro.config.mjs:85-98`). No comment in the
repo restates what the code does. Match this: a new helper without a decision-ID header comment
is off-pattern.

### Zero CSS / zero client JS
**Sources:** `tests/site.smoke.sh:74-76`, `tests/build.smoke.sh:45`
```bash
echo "== Zero client JS anywhere in dist/ =="
test "$(grep -rl '<script' dist/ | wc -l)" -eq 0
```
UI-SPEC: this phase adds **zero** rules to `src/styles/global.css`. Writing CSS is the signal
of having drifted from D-53.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `src/pages/rss.xml.ts` | route / endpoint | transform | No `APIRoute` / non-`.astro` page exists in `src/pages/`. The two Phase-2 diagnostic endpoints were deleted and `tests/site.smoke.sh:127-130` asserts they stay deleted. Use RESEARCH § Code Example 1 as the scaffold; borrow only the collection-query, base-normalization and `render()` patterns cited above. |
| `../studio/vault/community/*.md` | doc | file-I/O | Cross-repo vault prose, no code pattern applies. |

---

## Metadata

**Analog search scope:** `src/` (all), `tests/` (all), `public/`, `astro.config.mjs`,
`package.json`, `../studio/vault/community/`
**Files scanned:** 21 read in full or targeted; `src/` and `tests/` trees enumerated
**Pattern extraction date:** 2026-07-22

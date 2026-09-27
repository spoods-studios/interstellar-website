---
phase: 02-content-rendering-templating
fixed_at: 2026-07-22T14:45:00Z
review_path: .planning/phases/02-content-rendering-templating/02-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 2: Code Review Fix Report

**Fixed at:** 2026-07-22T14:45:00Z
**Source review:** .planning/phases/02-content-rendering-templating/02-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (2 Critical, 2 Warning)
- Fixed: 4
- Skipped: 0
- Info findings (4): deferred, not in scope for this fix pass (see below)

## Fixed Issues

### CR-01: Loud-fail preflight validates only `technical/` and `roadmap/` — `devlog/` and `pages/` can still silently ship empty content

**Files modified:** `astro.config.mjs`
**Commit:** `22b8bff`
**Applied fix:** Refactored `validateContentLoudFail()` around a single
`CONTENT_TREES` list (technical, roadmap, devlog, pages) and a shared
`collectMarkdownFiles()` walker, so the preflight now re-runs the wikilink
plugin pipeline over every file in all four content collections instead of
just two. Structured as a class fix, not an instance fix: a fifth content
tree can only escape validation if someone forgets to add a line to
`CONTENT_TREES`, not by the preflight silently scoping itself to a stale
tree list.

**Empirical verification performed** (not just Tier 1/2 syntax checks):
- Injected a dangling `[[m9.9/phase-99-does-not-exist]]` wikilink into a
  `devlog/` post — build now fails at config-load time (exit 1), naming
  both the file and the unresolved link. Previously: exit 0, silently
  shipped a gutted page.
- Repeated for a `pages/` file — same result.
- Repeated for `technical/` and `roadmap/` files — confirmed the
  already-covered paths still fail correctly (no regression).
- Confirmed a clean rebuild after every fixture still exits 0 and produces
  exactly 86 pages.
- Confirmed `git status --porcelain devlog/ technical/ roadmap/ pages/` was
  empty after every fixture (trap-and-restore left content trees
  byte-identical, per CLAUDE.md's read-only constraint on those trees).
- Full `npm test` suite green after the fix.

### CR-02: `technical/how-to-read.astro` bypasses the site's only draft-filter

**Files modified:** `src/pages/technical/how-to-read.astro`
**Commit:** `050fcba`
**Applied fix:** Replaced the bare `getEntry('technical', 'how-to-read')`
call with the shared `assertNonEmpty(await getCollection('technical'),
'technical').filter(isVisible).find(...)` pattern used by every other
single-entry route (`how-its-made.astro`, `roadmap/index.astro`), throwing
if no visible entry is found — consistent with how `how-its-made.astro`
handles the same situation for its own collection.

**Empirical verification performed:**
- Added `status: draft` to `technical/_how-to-read.md` and rebuilt: the
  build now fails loudly (`Error: technical collection has no visible
  'how-to-read' entry`) instead of silently building and linking a drafted
  page. Previously: exit 0, page built, still linked from the technical
  index.
- Restored the fixture; confirmed `git status --porcelain` on content
  trees was empty.
- Confirmed a clean rebuild produces 86 pages, exit 0.
- Full `npm test` suite green after the fix.

### WR-01: `set:html` used on plain-text titles/labels with no escaping

**Files modified:** `src/pages/index.astro`, `src/layouts/PostLayout.astro`,
`src/lib/escape-html.ts` (new)
**Commit:** `79a474b`
**Applied fix:** Adapted the review's suggested fix rather than applying it
verbatim. The review's literal suggestion (`<a href={post.href}>{post.title}</a>`)
was tried first and found to regress `tests/build.smoke.sh:13`, which
asserts a literal (unescaped) apostrophe in the built HTML — Astro's
default `{}` auto-escaping entity-encodes apostrophes (`&#39;`) in addition
to `&`/`<`/`>`, which both breaks that test and changes how every
contraction-heavy devblog title renders in the page source for no security
benefit (apostrophes can't break out of a text node). Kept `set:html` (as
the reviewer's own note flagged it was deliberately chosen to avoid
apostrophe escaping) but added a new minimal `escapeHtml()` helper that
escapes only `&`, `<`, `>` (order-safe, `&` first) and leaves apostrophes/
quotes untouched, then wrapped both call sites with it.

**Empirical verification performed:**
- Confirmed real titles containing apostrophes ("A Coordinate System That
  Doesn't Lie", "Why I'm Building a Hyperrealistic Space Sim") still render
  with literal apostrophes in the built HTML, matching pre-fix output
  exactly.
- Confirmed `&larr;`/`&rarr;` navigation entities still render correctly
  alongside escaped labels.
- Injected a fixture devlog title containing `std::vector<T> & friends`
  and confirmed it now renders safely escaped (`std::vector&lt;T&gt;
  &amp; friends`) instead of producing broken/injected markup.
- Restored the fixture; confirmed content trees clean.
- Full `npm test` suite green after the fix (the previously-regressed
  `build.smoke.sh:13` assertion now passes because apostrophes are no
  longer touched by the escape).

### WR-02: `technical/[milestone]/index.astro` fetches its roadmap entry without the shared `isVisible` filter

**Files modified:** `src/pages/technical/[milestone]/index.astro`
**Commit:** `0e293e3`
**Applied fix:** Replaced the bare `getEntry('roadmap', milestoneKey)` call
with `assertNonEmpty(await getCollection('roadmap'), 'roadmap').filter(isVisible).find(...)`,
matching the pattern already used one file over in
`technical/[milestone]/[slug].astro`. Not over-engineered further per the
review's own note that this bypass is currently inert (the roadmap
schema is `z.object({}).strict()` and rejects any `status` key).

**Verification performed:**
- `npx tsc --noEmit` clean (no new type errors).
- Rebuilt and confirmed per-milestone index headings (`M0.1 Vulkan
  Bootstrap`, `M0.8 Perturbation Refinements`, etc.) are unchanged from
  pre-fix output.
- Full `npm test` suite green after the fix.
- Did not attempt to temporarily loosen the locked roadmap schema to force
  the drafted-entry path live, since the review already confirmed the
  schema-level block and the fix's job here is consistency, not adding new
  runtime behavior.

## Deferred Issues (Info — out of scope)

Per this fix pass's scope (Critical + Warning only) and the T3 gate tier
(cosmetic/consistency nits do not block), the four Info findings are
recorded here as intentionally deferred rather than silently dropped:

### IN-01: Phase-filename shape regex duplicated across three files

**File:** `src/content.config.ts:39`, `src/lib/wikilink-resolver.mjs:9`,
`astro.config.mjs:24`
**Reason deferred:** Pure duplication-risk observation; all three copies
currently agree and nothing in this phase changed the filename convention.
Low priority — worth a follow-up phase/task to extract a shared regex, but
not a bug in current behavior.

### IN-02: Newest-first sort comparator duplicated between archive and post route

**File:** `src/pages/index.astro:18-20`, `src/pages/devlog/[slug].astro:23-25`
**Reason deferred:** Both copies are currently in agreement (verified by
the passing `npm test` suite, which exercises ordering on both routes).
Extraction to a shared `sortByDateDesc()` helper is a reasonable future
simplification, not a live defect.

### IN-03: `entryDate()`'s filename-fallback branch is structurally unreachable

**File:** `src/lib/devlog-meta.ts:12-16`
**Reason deferred:** The reviewer confirmed this branch cannot currently
be triggered (`content.config.ts`'s devlog `generateId` already throws for
any non-conforming filename before `entryDate` ever runs). Dead defensive
code with no live-bug risk; the review itself marked this "low priority."

### IN-04: `titleFromH1` has no structural guarantee it reads the first line

**File:** `src/lib/title-from-h1.ts:5`
**Reason deferred:** The reviewer confirmed the current corpus is uniform
(every real document's title is its literal first line) and marked this
fix "low priority given the current corpus is uniform." Hardening the
regex or adding a throw-on-missing-title path is a reasonable future
change but not required by any currently-committed content.

---

_Fixed: 2026-07-22T14:45:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

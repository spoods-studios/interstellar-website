---
phase: quick-260812-eot
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - src/styles/global.css
  - src/content.config.ts
  - src/lib/entry-order.ts
  - src/lib/devlog-meta.ts
  - tests/lib.smoke.mjs
autonomous: true
requirements: [QT-HERO-01, QT-ORDER-01]

must_haves:
  truths:
    - "A devlog post carrying a hero image renders that image inside the 65ch reading column — the image never extends past the right edge of the viewport at any width (the M1.2 hero is 1600x1000 and the M0.8 hero 1920x1080, both emitted as a bare <img> with explicit intrinsic width/height attributes into a column ~585px wide)"
    - "Constraining the hero width does not squash it: the rendered aspect ratio still matches the source PNG's intrinsic ratio"
    - "On the homepage archive, 'Three Small Fixes Before Closing the Books' (the M1.2 addendum) appears above 'The Line You Fly' — both carry date 2026-08-11, so this is decided by the same-date tie-break, not by the date comparison"
    - "The archive, the /devlog/<slug>/ prev-next chain, and rss.xml all present that same relative order — they share one comparator (sortEntriesNewestFirst) and must not be given a second ordering expression"
    - "A same-date pair where neither entry (or where both entries) carry the addendum tag still tie-breaks on id ascending, exactly as before this change"
    - "An addendum with an OLDER date never sorts above a newer non-addendum post — the addendum flag is a tie-break only and never overrides the date comparison"
    - "No file under devlog/ is modified by this plan — the sort fix lives entirely in the site layer"
  artifacts:
    - path: "src/styles/global.css"
      provides: "An unconditional img sizing rule that caps rendered image width at the containing reading column and lets height follow the intrinsic ratio"
      contains: "max-width: 100%"
    - path: "src/lib/entry-order.ts"
      provides: "compareNewestFirst extended with an addendum tie-break between the date comparison and the existing id comparison; still import-free so tests/lib.smoke.mjs can load it under bare Node"
      contains: "isAddendum"
    - path: "src/lib/devlog-meta.ts"
      provides: "An isAddendum(entry) predicate reading the devlog tag list, fed into the single shared sort so all three consumers inherit it"
      contains: "milestone-addendum"
    - path: "src/content.config.ts"
      provides: "tags added to the devlog Zod schema — without it Zod strips the key and entry.data.tags is undefined at every call site"
      contains: "tags:"
    - path: "tests/lib.smoke.mjs"
      provides: "Unit coverage pinning the addendum tie-break in both input orders, plus the unchanged id fallback and the date-wins-over-flag guard"
      contains: "milestone-addendum"
  key_links:
    - from: "src/content.config.ts (devlog schema)"
      to: "src/lib/devlog-meta.ts (isAddendum)"
      via: "entry.data.tags — undefined unless the schema declares the key, because Zod's default object behaviour strips unknown keys"
      pattern: "tags"
    - from: "src/lib/devlog-meta.ts (sortEntriesNewestFirst)"
      to: "src/pages/index.astro, src/pages/devlog/[slug].astro, src/pages/rss.xml.ts"
      via: "all three import sortEntriesNewestFirst — one comparator change reaches every consumer"
      pattern: "sortEntriesNewestFirst"
    - from: "src/styles/global.css"
      to: "dist/_astro/*.css"
      via: "BaseLayout.astro imports the stylesheet, Astro bundles and minifies it into the emitted asset"
      pattern: "max-width"
---

<objective>
Fix two reader-visible website bugs, both entirely in the site layer, with zero edits to any
`devlog/*.md` content file.

**Bug 1 — hero visuals overflow the reading column.** `src/styles/global.css` (126 lines) contains
no `img` rule at all. `main` is capped at `max-width: 65ch` (~585px at the site's 18px base), while
Astro's markdown image pipeline emits heroes as a bare `<img>` carrying explicit intrinsic
`width`/`height` attributes — verified against a built page: `width="1920" height="1080"` on the M0.8
hero. With no `max-width` constraint the image renders at its intrinsic width and pushes past the
right edge of the viewport. Source heroes are 1600x1000 (M1.2) and 1200x1125 (M1.1), so every
hero post is affected, not just the newest.

**Bug 2 — the M1.2 addendum sorts below the post it addends.** Both M1.2 posts carry
`date: 2026-08-11`, so `compareNewestFirst` falls through to its id-ascending tie-break, where
`2026-08-11-the-line-you-fly` sorts before `2026-08-11-three-small-fixes-before-closing-the-books`
(`the` < `thr`). The announcement therefore sits above its own addendum.

**Read this before choosing a different mechanism — do not re-diagnose, and do not "correct" the
requested direction.** The on-disk timestamps disagree with the requested order, and that
disagreement is exactly why they cannot be used as the tie-break key:

- Discord snowflakes (strictly chronological) decode to addendum 2026-08-11T16:31:48Z, announcement
  2026-08-11T17:27:04Z — the announcement was posted ~55 minutes *later*.
- Git commit order agrees: addendum `0ee2b6c` at 12:32 local, announcement `4e28464` at 13:26 local.

So a `discord_post_id` tie-break would keep the current (unwanted) order and is rejected on purpose.
The ordering the site must present is the *narrative* one, which the addendum's own opening line
states: it reads as the post that comes after the milestone write-ups ("The maneuver-node milestone
shipped last week, and the write-ups are already out"). Author intent about reading order is the
spec here; the same-day publish timestamps are a batching artifact.

The mechanism is therefore the `milestone-addendum` tag, which already exists on disk in the
addendum's frontmatter and appears in exactly one file repo-wide. Nothing in `devlog/` needs to
change — but `tags` is absent from the devlog Zod schema, and Zod strips unknown keys by default,
so `entry.data.tags` is `undefined` today. Declaring it in the schema is what makes the existing
content readable.

Purpose: heroes stop breaking the page layout, and the M1.2 pair reads in the order it was written
to be read — on the archive, in prev/next, and in the feed, from one shared comparator.
Output: one CSS rule, one schema field, one comparator tie-break, one predicate, and unit coverage
pinning all of it.

**Task shape note (tracer-first):** no separate `type="tracer"` task is emitted. This is a two-bug
quick fix under a 1-3 task cap, and each task is already an end-to-end user-visible slice — Task 1
runs CSS source → bundle → rendered page, Task 2 runs frontmatter → schema → comparator → all three
consumers. A synthetic tracer ahead of them would add a commit without proving any architecture
that the tasks themselves do not already prove.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

@src/styles/global.css
@src/lib/entry-order.ts
@src/lib/devlog-meta.ts
@src/content.config.ts
</context>

<constraints>
**Concurrency.** Another Claude session is active in this repo. Touch only the five files in
`files_modified`. Do not reformat, refactor, or tidy anything adjacent, and do not run
`git add -A` / `git commit -a` — stage the five paths explicitly by name.

**Content lock.** `devlog/`, `technical/`, `roadmap/`, and `pages/` `.md` files are drop targets for
the studio promote pipeline and are locked (repo `CLAUDE.md`). This plan requires no edit to any of
them; if a step seems to need one, stop and report rather than editing.

**Pre-existing red suite — do not fix, do not chase.** `npm test` is already failing on `main` for
reasons unrelated to these two bugs: the corpus grew to 12 devlog posts while three harnesses still
hardcode 10 (`tests/collections.smoke.sh:34`, `tests/post.smoke.sh:20`, `tests/build.smoke.sh:27`),
and `tests/post.smoke.sh:42` still names `2026-07-30-first-burn` as the newest post, which it no
longer is. That drift is out of scope for this plan. The `<verify>` blocks below therefore run
targeted gates instead of `npm test`, and no `tests/*.smoke.sh` file is edited. Report the stale
counts in the summary as a follow-up; do not repair them here.
</constraints>

<tasks>

<task type="auto">
  <name>Task 1: Constrain rendered images to the reading column</name>
  <files>src/styles/global.css</files>
  <action>
Add one unconditional rule to `src/styles/global.css` capping rendered image width at the width of
its container and letting height follow the intrinsic aspect ratio: an `img` selector setting
`max-width` to `100%` and `height` to `auto`.

Both declarations are load-bearing. The width cap alone is not sufficient: Astro emits the hero with
an explicit `height` attribute (confirmed `width="1920" height="1080"` in built output), and once
width is constrained below intrinsic that fixed height distorts the image — `height: auto` is what
restores the ratio.

Placement: with the other content-element rules, after the `code` block and before the `.toc` block
(roughly line 99). Do NOT put it inside the `@media (min-width: 640px)` block at the end — that
block carries a comment declaring itself the sole home of conditional rules, and this rule is
unconditional; a narrow viewport is precisely where the overflow is worst.

Match the file's existing style: two-space indentation, one declaration per line, a blank line
between rules. Per repo convention add no comment unless the WHY is non-obvious — the rule is
self-evident, so ship it bare.

Scope: this rule intentionally applies site-wide rather than being scoped to a devlog wrapper. The
same pipeline emits images into the technical and roadmap trees through the same `main` column, and
no selector in the file currently distinguishes them. Do not add a wrapper class or touch any
`.astro` file to create one.
  </action>
  <verify>
    <automated>npm run build &amp;&amp; grep -Eq 'max-width: *100%' src/styles/global.css &amp;&amp; grep -Eq 'max-width: *100%' dist/_astro/*.css &amp;&amp; grep -q 'width="1920" height="1080"' dist/devlog/2026-07-13-making-mercury-precess/index.html &amp;&amp; echo HERO_CSS_OK</automated>
    <human-check>Run `npm run preview`, open `/devlog/2026-08-11-the-line-you-fly/`, and confirm the hero sits inside the text column with no horizontal scrollbar. Narrow the window below 640px and confirm it still fits and is not vertically squashed.</human-check>
  </verify>
  <done>The built stylesheet ships the width constraint, the built hero page still carries its intrinsic width/height attributes (proving the fix is presentational and did not disturb the image pipeline), and the hero renders inside the reading column at both desktop and narrow widths.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Sort a same-date addendum above the post it addends</name>
  <files>src/content.config.ts, src/lib/entry-order.ts, src/lib/devlog-meta.ts, tests/lib.smoke.mjs</files>
  <behavior>
Write these cases into the `== entry-order ==` block of `tests/lib.smoke.mjs` (around line 279)
FIRST and watch them fail, before touching the comparator. Extend the existing block; keep every
assertion already there passing unchanged.

- Test 1 — same date, one flagged as an addendum and one not: the addendum sorts first (newest
  position). Assert with both input orders, because `Array.sort` is only stable with respect to
  input order and the three consumers do not build their input arrays the same way.
- Test 2 — same date, neither flagged: the existing id-ascending tie-break still decides. This is
  the regression guard for the nine untagged posts.
- Test 3 — same date, both flagged: id-ascending decides.
- Test 4 — different dates, the OLDER entry flagged as an addendum: the newer entry still sorts
  first. The flag must never override the date comparison.
- Test 5 — an entry compared against itself still returns 0.
- Test 6 — real-world pin: two entries built with the actual ids
  `2026-08-11-the-line-you-fly` and `2026-08-11-three-small-fixes-before-closing-the-books`, the
  same date, the second flagged, sort with the addendum first. This is the case that would silently
  regress if the tag string were ever mistyped.
  </behavior>
  <action>
Make the failing tests pass with three small edits.

**`src/content.config.ts` — devlog collection schema.** Add an optional `tags` field typed as an
array of strings, alongside the existing optional fields. This is required, not cosmetic: the devlog
schema is a non-strict `z.object`, so Zod strips undeclared keys and `entry.data.tags` is currently
`undefined` even though the frontmatter carries it. Optional is mandatory — five of the twelve posts
have no tags line at all. Verified safe across the corpus: every tags value on disk is already a
flat array of plain strings, so no existing post will fail validation. Change only the devlog
collection; leave technical, roadmap, and pages untouched.

**`src/lib/entry-order.ts` — the comparator.** Add an optional boolean `isAddendum` to the
`OrderableEntry` interface, and insert one tie-break in `compareNewestFirst` between the existing
date comparison and the existing id comparison. Direction: when the dates are equal, the entry
flagged as an addendum is the newer one and must sort first. Treat a missing flag as false so the
nine untagged posts are unaffected. Return the id comparison unchanged when the flags match.

Two hard constraints on this file. It must stay import-free — the header comment explains that
`tests/lib.smoke.mjs` loads this `.ts` directly under bare Node, and a single runtime import breaks
that. And the new comparison must sit strictly *after* the date comparison's early return, so the
flag can never outrank a date (Test 4). Add a short WHY comment for the new tie-break in the style
of the two already in the file: it should record that the addendum reads as the later post despite
the same-day publish timestamps, so a future reader does not "fix" it back to timestamp order.

**`src/lib/devlog-meta.ts` — the predicate.** Add a module-level constant holding the tag string
`milestone-addendum` and an exported `isAddendum(entry)` predicate returning whether the entry's tag
list contains it, coercing the absent-tags case to false. Pass its result for both operands inside
the existing `sortEntriesNewestFirst` mapping, next to the `id` and `date` fields already built
there.

Do not add a second sort anywhere. `src/pages/index.astro`, `src/pages/devlog/[slug].astro`, and
`src/pages/rss.xml.ts` all already call `sortEntriesNewestFirst`, so all three inherit this change
with no edit — that shared-comparator property is deliberate and documented in the file headers, and
those three files must not appear in the diff.
  </action>
  <verify>
    <automated>node tests/lib.smoke.mjs &amp;&amp; npm run build &amp;&amp; ADD=$(grep -boF "Three Small Fixes" dist/index.html | head -1 | cut -d: -f1) &amp;&amp; ANN=$(grep -boF "The Line You Fly" dist/index.html | head -1 | cut -d: -f1) &amp;&amp; test "$ADD" -lt "$ANN" &amp;&amp; grep -q 'Three Small Fixes' dist/rss.xml &amp;&amp; RADD=$(grep -boF "Three Small Fixes" dist/rss.xml | head -1 | cut -d: -f1) &amp;&amp; RANN=$(grep -boF "The Line You Fly" dist/rss.xml | head -1 | cut -d: -f1) &amp;&amp; test "$RADD" -lt "$RANN" &amp;&amp; test -z "$(git diff --name-only -- devlog/)" &amp;&amp; echo ORDER_OK</automated>
  </verify>
  <done>`node tests/lib.smoke.mjs` prints ALL CHECKS PASSED with the six new cases; the addendum's title precedes the announcement's title by byte offset both on the built homepage and in the built feed; and `git diff` reports no change under `devlog/`.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| `devlog/*.md` frontmatter → build pipeline | Author-controlled content parsed by Zod at build time; this plan widens the parsed surface by one field (`tags`) |
| built static assets → reader browser | Static output only; no user input crosses this boundary and this plan adds no client JavaScript |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-QT-EOT-01 | Tampering | `src/content.config.ts` devlog `tags` field | low | mitigate | Type the field as an array of strings so a malformed value fails the build loudly at content-sync time rather than silently coercing and reverting sort order. Optional, so absent-tags posts stay valid. |
| T-QT-EOT-02 | Information disclosure | tag values in built output | low | accept | The comparator only reads tags; no task renders a tag value into any page, feed item, or meta tag, so the change creates no new output surface. Verified: no consumer prints `entry.data.tags`. |
| T-QT-EOT-03 | Denial of service | oversized hero PNGs | low | accept | `max-width: 100%` is a render-time constraint only. Transferred bytes are unchanged and already bounded by Astro's build-time image optimization (heroes ship as optimized WebP). |
| T-QT-EOT-SC | Tampering | npm/pip/cargo installs | high | accept | Not applicable — this plan installs no packages and does not touch `package.json` or `package-lock.json`. Any diff to either file is out of scope and must be reverted. |
</threat_model>

<verification>
Both fixes land in one build, so verify them together at the end:

1. `npm run build` completes with zero errors (a bad Zod schema surfaces here first, as a content-sync failure naming the offending file).
2. `node tests/lib.smoke.mjs` prints ALL CHECKS PASSED.
3. `git diff --name-only` lists exactly the five files in `files_modified` — no `devlog/*.md`, no `package.json`, no `tests/*.smoke.sh`, and none of the three page/route consumers.
4. Homepage archive order reads: Three Small Fixes Before Closing the Books, then The Line You Fly, then First Burn.
5. Manual pass: `/devlog/2026-08-11-the-line-you-fly/` renders its hero inside the text column with no horizontal scrollbar, at both desktop and sub-640px widths; the addendum's prev/next chain names The Line You Fly as its older neighbour.
</verification>

<success_criteria>
- Hero images render within the 65ch reading column at every viewport width, with their aspect ratio intact.
- The M1.2 addendum sorts above The Line You Fly on the archive, in the prev/next chain, and in the feed — from one shared comparator, not three.
- Same-date pairs with no addendum among them keep their previous id-ascending order; an older addendum never outranks a newer post.
- No content file is modified, and the diff is confined to the five listed site-layer files.
</success_criteria>

<output>
Create `.planning/quick/260812-eot-fix-hero-visual-overflow-and-devlog-adde/260812-eot-SUMMARY.md` when done.

Record in the summary: (a) the stale hardcoded post counts in `tests/collections.smoke.sh:34`,
`tests/post.smoke.sh:20`, `tests/build.smoke.sh:27` and the stale newest-post reference at
`tests/post.smoke.sh:42`, all left unfixed as out of scope; (b) the tie-break mechanism chosen
(`milestone-addendum` tag) and why `discord_post_id` was rejected despite being the chronologically
authoritative field.
</output>
</content>
</invoke>

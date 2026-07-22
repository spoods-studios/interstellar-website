# Phase 2: Content Rendering & Templating - Context

**Gathered:** 2026-07-14
**Re-gathered:** 2026-07-22 — studio decisions [D-M] and [D-N] (both 2026-07-21)
landed a phase-granular technical devlog series (60 deep-dives) and a
restructured roadmap layer (9 milestone detail docs + a new pinned-overview
source) *after* the original context was written. Website v1 carries the
technical series (user call, 2026-07-22). Decisions D-11–D-30 below are
carried forward, amended, or superseded as marked; D-31–D-44 are new.
**Status:** Ready for planning

<domain>
## Phase Boundary

Every piece of locked studio content renders as a readable, mobile-friendly
page with baseline polish — VOICE.md prose untouched by the site layer. As of
the 2026-07-22 re-discuss this spans **four content trees**, not one:

1. `devlog/` — milestone announcements (manifesto + M0.1–M0.8), VOICE-locked
2. `technical/` — per-phase technical deep-dives (D-M series), 55 docs for
   M0.1–M0.8
3. `roadmap/` — per-milestone granular roadmap detail (D-M), 8 docs for
   M0.1–M0.8
4. `pages/` — standalone pages: `how-its-made.md`, `roadmap.md`

Covers CONT-02 (full announcement archive), CONT-03 (How It's Made), CONT-04
(roadmap — now overview page + per-milestone detail), SITE-04 (mobile,
custom 404, favicon, canonical URLs, sitemap.xml), and — pulled forward from
v2 this phase — the syntax-highlighting half of CONT-07.

RSS/OpenGraph/Discord CTA are Phase 3; analytics, the M1.1 launch post (plus
M1.1's 5 deep-dives and `M1.1.md`), and deploy hardening are Phase 4.

Phase 1's throwaway `src/pages/index.astro` is replaced wholesale; the devlog
content schema and glob loader in `src/content.config.ts` carry forward as the
pattern the three new collections mirror.

**Scope note for the planner:** this phase's requirement text in
`.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` predates the technical
series. CONT-02/CONT-04 wording and the CONT-07/CONT-08 v2 deferrals need
amending to match the decisions below — flagged, not silently assumed.

</domain>

<decisions>
## Implementation Decisions

### Carried forward unchanged from the 2026-07-14 pass
- **D-11:** Announcement archive entry format: title + date + milestone tag
  (from frontmatter, e.g. "M0.3"). Manifesto has no milestone — renders plain.
- **D-13:** The homepage IS the announcement archive — `/` lists the 9
  announcement posts directly, no separate landing page. Post URLs:
  `/devlog/YYYY-MM-DD-slug/`. **Reaffirmed 2026-07-22** against the
  alternative of a unified stream: 60 deep-dives would swamp the 9 posts a
  newcomer should read first.
- **D-14:** Post pages render the Markdown body untouched (body `# H1` is the
  title). Site adds only a small meta line. No site-generated title header,
  no H1 dedup logic — protects "rendered text matches source exactly".
- **D-15:** Announcement bottom nav: prev/next by date + back-to-archive.
- **D-16:** Homepage top matter: ONE quiet sentence describing the project
  (VOICE register, no hype). Exact wording gets user approval at plan review.
- **D-18:** Footer minimal — copyright (Spoods Studios) + the spot where the
  RSS link lands in Phase 3.
- **D-19:** Custom 404: short "page not found" note + link home, same chrome
  as every other page.
- **D-20:** `pages/` standalone pages use the post layout; meta line shows
  "Last updated: YYYY-MM-DD" (from `updated:` frontmatter).
- **D-21:** System font stack — zero webfonts, zero external requests.
- **D-22:** Light-only color scheme: near-white background, near-black text,
  one restrained link accent. Dark mode stays v2 (SITE-05).
- **D-23:** Hand-written minimal CSS — reading measure (~65ch), spacing, link
  accent, responsive rules. No CSS framework or classless base.
- **D-24:** Favicon: hand-authored text/letterform SVG ("IE"-style glyph) —
  D-G-clean, swappable later for an engine capture.
- **D-25:** Content is promoted into the repo IN-PHASE via the studio-side
  promote flow (not manual copies) — the site builds against real content and
  the success criteria hold at phase end. **Extended by D-43** (scope).
- **D-26:** `pages/` is a read-only promote drop target with the same contract
  as `devlog/`. `how-its-made.md` and `roadmap.md` are promoted into it.
- **D-28:** If a promoted post references images, the promote flow lands them
  alongside the post so relative paths resolve unchanged. **Note:** verified
  2026-07-22 that the 60 technical deep-dives contain **zero** image
  references; this remains relevant only for the announcement posts.
- **D-29:** `hero_visual` frontmatter is IGNORED in v1.
- **D-30:** Collections honor `status: draft` exactly like `devlog/`
  (draft = not rendered).

### Amended by the technical series
- **D-12 (amended):** Flat reverse-chronological list applies to the
  **announcement archive only** (9 posts). The technical and roadmap trees are
  grouped structurally instead — see D-40.
- **D-17 (amended):** Header on every page: "Interstellar Engine" wordmark
  (links home) + nav links **Devblog / Technical / How It's Made / Roadmap**
  ("Technical" is new). The Discord CTA still slots into this header in
  Phase 3 — no placeholder now.
- **D-27 (SUPERSEDED):** The roadmap page no longer sources from
  `../studio/vault/community/roadmap-backfill.discord.txt` — [D-N] moved the
  living source to `../studio/vault/devlog/discord/roadmap-overview.pinned.md`
  and [D-M] added the per-milestone detail layer. Replaced by D-36/D-37/D-38.

### Content trees & information architecture
- **D-31:** Technical deep-dives land in a **new `technical/` directory at
  repo root**, sibling to `devlog/` and `pages/`, with the vault's milestone
  subdirs preserved (`technical/m0.1/phase-01-window-surface.md`). Its own
  Astro collection with its own schema; same read-only promote-drop contract
  as `devlog/` — never hand-edited in this repo. Separate collection means an
  archive or RSS query structurally cannot mix the two layers.
- **D-32:** Technical URL shape mirrors the vault path:
  `/technical/m0.1/phase-01-window-surface/`, with `/technical/` as the full
  index and `/technical/m0.1/` as a per-milestone index. Slug is derivable
  from the file path with no mapping table, and the milestone is readable in
  the URL. `_how-to-read.md` renders at `/technical/how-to-read/`.
- **D-33:** Technical docs carry **no YAML frontmatter and no date** (verified
  across all 60). Metadata is derived from the path — milestone from the
  `m0.X/` directory, phase number and slug from `phase-NN-slug.md`, title from
  the body H1 — in the same filename-fallback spirit as CONT-01/D-10. A
  non-conforming filename is a **loud build failure** naming the file (D-10),
  never a silent skip.
- **D-34:** Technical indexes order by **phase number, not date**. The
  retroactive backfill was all written in Jul 2026 about work spanning
  Apr–Jul, so file/commit dates are meaningless as reading order.
  **Planner note:** phase numbers include decimals (`phase-10.5`,
  `phase-27.5`, `phase-46.1`) — the sort key must be numeric-aware, not
  lexical.
- **D-35:** Cross-linking between the layers is **generated in both
  directions from the collection query**, never hand-maintained: an
  announcement page lists its milestone's deep-dives (matching on milestone),
  and each deep-dive carries a breadcrumb back to its milestone announcement
  and milestone roadmap page. Derived data can't rot as content lands. The
  generated list is site chrome outside the Markdown body — D-14's
  "body renders untouched" is unaffected.

### Roadmap
- **D-36:** `/roadmap` is an **overview page plus per-milestone detail pages**
  (`/roadmap/m0.3/`), mirroring [D-N]'s Discord structure (one pinned overview
  + one thread per milestone) and giving the deep-dives a natural parent.
- **D-37:** The overview renders from a **site-voice transcription** at
  `pages/roadmap.md`, promoted like any other standalone page, using
  `../studio/vault/devlog/discord/roadmap-overview.pinned.md` as the reference
  text. It is NOT rendered verbatim: the pinned copy opens with "How this
  channel works" and points readers at `#technical-devlog` / `#announcements`
  for content the site itself hosts — that framing gets rewritten to site
  framing. Updated by hand when the pin changes (an era/milestone arc moves a
  few times a year).
- **D-38:** The 8 milestone detail docs land in a **new `roadmap/` directory
  at repo root** as a third promote drop target (`roadmap/M0.1.md` …
  `roadmap/M0.8.md`), own collection, milestone derived from filename, ordered
  by milestone number.

### Rendering fidelity
- **D-39:** Obsidian wikilinks (`[[../_how-to-read|How to Read]]`) are
  resolved to real anchors by a **site-side remark plugin at build time**.
  Source Markdown stays byte-identical (D-14 holds; the promote pipeline stays
  dumb, and an automated promote script is explicitly out of this repo's scope
  per REQUIREMENTS.md). An unresolvable wikilink target is a **loud build
  failure** naming the file and the link — never a silent passthrough of
  literal `[[…]]` text.
- **D-40:** `/technical/` groups deep-dives under era → milestone headings in
  phase order; `/roadmap/m0.X/` independently lists a milestone's phases with
  goals. Two structural routes to any document, so **CONT-08 (search/tags)
  stays v2** — its stated rationale ("no payoff at ~9 posts") is dead, but its
  conclusion still holds against a corpus this well-structured. No client-side
  search index in v1.
- **D-41:** **CONT-07 is split.** Build-time syntax highlighting lands in
  Phase 2 via Astro's built-in Shiki (no new dependency, zero client JS, light
  theme consistent with D-22) — the deep-dives are function-by-function C++
  and read badly unhighlighted. KaTeX math stays v2: verified 2026-07-22 that
  the deep-dives contain **zero LaTeX and zero mermaid**, so deferring it
  costs nothing today.
- **D-42:** Long documents get an **auto-generated table of contents** from
  Astro's rendered `headings` array — static, build-time, no JS. Matches the
  section index the Discord exports already carry. Applies to the technical
  and roadmap trees; the planner may skip it on short announcement posts.

### Promote scope for this phase
- **D-43:** Phase 2 promotes **everything for closed milestones M0.1–M0.8**:
  9 announcements (`devlog/`), 55 deep-dives (`technical/m0.1`…`m0.8`) plus
  `_how-to-read.md`, 8 roadmap detail docs (`roadmap/`), and 2 standalone
  pages (`pages/how-its-made.md`, `pages/roadmap.md`). The site is
  complete-as-of-Era-0 at phase end.
- **D-44:** **M1.1 content is Phase 4**, riding along with the launch post
  (CONT-05): its 5 deep-dives, `roadmap/M1.1.md`, and the M1.1 announcement
  land together when the milestone actually closes. Until then M1.1 appears on
  the roadmap overview as in-progress with no detail page.

### Claude's Discretion
- Sitemap/canonical mechanics (`@astrojs/sitemap` vs hand-rolled), exact
  responsive breakpoints, link accent color, meta-line placement relative to
  the body H1.
- Collection loader configs for `technical/` and `roadmap/` (mirror the devlog
  glob loader; different filename conventions per D-33/D-38).
- Whether the TOC is a sticky desktop sidebar or an inline block, and the
  heading depth it includes.
- Layout factoring — one shared post layout with variants vs. separate layouts
  per collection.
- How the promote step is sequenced inside the phase (which plan/wave) — note
  it is cross-repo work reading from `../studio/vault/`.
- Whether the era → milestone grouping on `/technical/` is derived from data
  or a small hand-written map (the deep-dives carry no era metadata; the
  roadmap overview does).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Studio decisions that reshaped this phase
- `../studio/vault/decisions/Decision Log.md` — **[D-M] 2026-07-21**
  (retroactive phase-granular roadmap + technical devlog series; Era →
  Milestone → Phase → Plan terminology; as-built-then framing with a mandatory
  drift section; hero-visual rule D-K applies to announcements only) and
  **[D-N] 2026-07-21** (Discord restructure: pinned overview + thread per
  milestone in #roadmap, #technical-devlog forum, #devlog → #announcements).
  Also [D-H] (website launches at M1.1 as the devblog home), [D-G] (AI
  transparency, no generative imagery), [D-K] (hero visuals from real engine
  output).

### Content contract — announcements
- `devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md` — the
  frontmatter-less manifesto (title in body H1 only); must render via
  filename fallback, untouched
- `../studio/vault/devlog/_TEMPLATE.md` — frontmatter field set promoted
  announcements carry (real drafts also carry `published_date`, absent from
  the template — Zod strips unknown keys; planner should confirm)
- `../studio/vault/devlog/drafts/` — the M0.1–M0.8 announcement drafts +
  `how-its-made.md` to be promoted in-phase (`.discord.txt` siblings are NOT
  posts — the promote flow must exclude them)
- `../studio/vault/devlog/VOICE.md` — locked voice; the site renders, never
  restyles

### Content contract — technical series (new)
- `../studio/vault/devlog/technical/_how-to-read.md` — load-bearing tag legend
  (Era/Milestone/Phase/Plan, requirement IDs, `D-NN` vs `[D-X]` decision tags,
  `[Rule N]` deviation tags). Every deep-dive wikilinks to it; it must render
  and every link to it must resolve.
- `../studio/vault/devlog/technical/m0.1/` … `m0.8/` — the 55 deep-dives
  promoted in this phase (`m1.1/`'s 5 are Phase 4 per D-44). Read at least
  `m0.1/phase-01-window-surface.md` and `m0.3/phase-12-force-model.md` before
  planning — they show the real shape: no frontmatter, body H1 title, heavy
  C++ fences, wikilinks, `> ` blockquote preamble, drift section at the end.
- `../studio/vault/project/roadmap-detail/M0.1.md` … `M0.8.md` — the 8
  milestone detail docs (`M1.1.md` is Phase 4). Same no-frontmatter shape;
  each phase entry ends with a `Deep-dive:` path pointing into
  `vault/devlog/technical/…` — those paths need resolving to site URLs.
- `../studio/vault/devlog/discord/roadmap-overview.pinned.md` — reference text
  for the transcribed `pages/roadmap.md` (D-37). Discord-framed; do not render
  verbatim.

### Project ground truth
- `.planning/PROJECT.md` — constraints (quiet content-first, D-G no generative
  imagery, privacy, timeline)
- `.planning/REQUIREMENTS.md` — CONT-02, CONT-03, CONT-04, SITE-04
  definitions, plus the CONT-07/CONT-08 v2 deferrals that D-40/D-41 amend
- `.planning/ROADMAP.md` — Phase 2 success criteria (the four TRUE statements)
- `.planning/phases/01-stack-scaffolding/01-CONTEXT.md` — carried-forward
  decisions D-01–D-10 (filename fallback, never edit `devlog/`, loud-fail)
- `CLAUDE.md` (repo root) — `devlog/` untouchability rule; extend the same
  rule to `technical/`, `roadmap/`, and `pages/`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/content.config.ts` — devlog collection with a permissive all-optional
  schema, filename-fallback `generateId`, loud-fail on unparseable filenames
  (D-10), `_TEMPLATE.md` exclusion. The `technical/`, `roadmap/`, and `pages/`
  collections mirror this pattern with their own filename rules.
- `astro.config.mjs` — `site` + `base` are the single config-driven URL source
  (SITE-02). The remark plugin (D-39) and Shiki config (D-41) both land here.
- Title/date fallback logic in `src/pages/index.astro` (H1 regex, filename
  date) — extract into a shared helper; the H1-title half is now needed by
  three collections, not one. The throwaway page itself is replaced.
- Draft filtering (`status !== 'draft'`) already established in index.astro.

### Established Patterns
- Read-only promote drop targets: `devlog/` today; `technical/`, `roadmap/`,
  and `pages/` join it. Never hand-edited in this repo.
- Zero-entry collection assert (loud-fail on a misconfigured loader base) —
  keep it, and repeat it per new collection.
- Loud-fail over silent skip on malformed content (D-10) — extended by D-33
  (bad technical filename) and D-39 (unresolvable wikilink).
- `set:html` for titles (git-trusted content, avoids apostrophe escaping) —
  same reasoning applies to the new templates.
- `glob()`'s `base` resolves relative to the **project root**, not to
  `src/content.config.ts` — the Phase 1 landmine, documented in the config.

### Integration Points
- Deploy pipeline (Phase 1) rebuilds on every push to main — promoted content
  goes live automatically once merged.
- Phase 3 hangs off this phase: RSS from the announcement collection query
  (planner should note D-31 makes "technical posts in the feed?" a clean Phase
  3 decision rather than a filter problem); Discord CTA into the header slot
  (D-17); OG metadata into the shared layout head. Build the base layout with
  those insertion points in mind.
- Phase 4 adds M1.1 content into the same three trees (D-44) — nothing about
  the templates should assume the corpus is closed.

</code_context>

<specifics>
## Specific Ideas

- "Boring is correct" carries through: system fonts, light-only, hand-written
  CSS, no framework, no client JS. Syntax highlighting (D-41) and the TOC
  (D-42) are both build-time only — they don't break that.
- The site is a quiet reading surface for locked content — every decision
  biased toward "add nothing between reader and text". The generated
  cross-links and TOC are navigation chrome around the body, never inside it.
- Two audiences, two front doors: `/` is for someone meeting the project
  (9 announcements); `/technical/` is for someone who wants the engineering
  (55 deep-dives). The nav is the only thing that has to make that obvious.
- Homepage one-liner needs user sign-off on exact wording (D-16).

</specifics>

<deferred>
## Deferred Ideas

- Dark mode / `prefers-color-scheme` — v2 (SITE-05), explicitly out of this
  phase's CSS. Note it now pairs with a Shiki theme (D-41), which is why
  SITE-05 and CONT-07 were bundled in the first place.
- KaTeX math rendering — v2 (the other half of CONT-07). Zero LaTeX in the
  current corpus; revisit if future deep-dives carry it.
- Search / tag taxonomy — v2 (CONT-08), per D-40. If the corpus grows past
  Era 1 or grouping stops being enough, a build-time static index
  (Pagefind-class) is the shape to reach for.
- `hero_visual` rendering / OG image source — Phase 3 (OG) or v2.
- Old-Discord-link 404 behavior into the technical corpus — Phase 4's
  slug-immutability norm and redirect-stub mechanism (CONT-06) now has to
  cover three URL trees, not one. Flagged for Phase 4 planning.
- Automated studio→website promote script — still out of scope for this repo
  (REQUIREMENTS.md); three more drop targets makes the manual step bigger,
  which strengthens the case for studio-side automation later.

</deferred>

---

*Phase: 2-Content Rendering & Templating*
*Context gathered: 2026-07-14 · re-gathered 2026-07-22*

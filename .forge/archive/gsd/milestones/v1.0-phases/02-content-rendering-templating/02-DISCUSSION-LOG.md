# Phase 2: Content Rendering & Templating - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Sessions:** 2026-07-22 (re-discuss, current) · 2026-07-14 (original, retained below)

---

# Session 2 — 2026-07-22 (re-discuss)

**Phase:** 2-content-rendering-templating
**Areas discussed:** Two-layer IA & URLs, Technical-post fidelity, Roadmap page shape, Browsability at ~70 posts

**Why re-discussed:** The 2026-07-14 context was written before studio decisions
[D-M] and [D-N] (both 2026-07-21), which created a 60-document phase-granular
technical devlog series and restructured the roadmap layer. User's call
(2026-07-22): the website carries the technical devlogs.

---

## Two-layer IA & URLs

### Where technical deep-dives land in the repo

| Option | Description | Selected |
|--------|-------------|----------|
| New `technical/` root dir | Sibling to `devlog/`/`pages/`, milestone subdirs preserved, own collection and URL space, same read-only promote contract | ✓ |
| Subdir of `devlog/` | `devlog/technical/m0.X/…` in the existing collection, filtered by path or `type:` frontmatter | |
| One flat collection, `type:` field | All content in `devlog/`, distinguished only by frontmatter | |

**User's choice:** New `technical/` root dir.
**Notes:** Separate collection means archive/RSS queries structurally cannot mix layers. The rejected options both broke the existing `YYYY-MM-DD-slug.md` filename contract, since deep-dives are named `phase-NN-slug.md` with no date.

### URL shape

| Option | Description | Selected |
|--------|-------------|----------|
| `/technical/m0.1/phase-01-window-surface/` | Mirrors vault path; milestone readable in URL; slug derivable with no mapping table | ✓ |
| `/technical/phase-01-window-surface/` | Flat — global phase numbers 1–52 are already unique | |
| `/devlog/technical/…` | Nest under devlog in URL space to signal "part of the devblog" | |

**User's choice:** Path-mirroring URLs.
**Notes:** Gives `/technical/` and `/technical/m0.1/` as natural index routes.

### What `/` becomes

| Option | Description | Selected |
|--------|-------------|----------|
| Keep `/` = announcement archive | D-13 unchanged; `/technical/` is its own index in the nav | ✓ |
| `/` = unified stream | Both layers interleaved reverse-chron with a type distinction | |
| `/` = small landing, both indexes below | Homepage becomes a landing page, reversing D-13 | |

**User's choice:** Keep `/` as the announcement archive.
**Notes:** 60 deep-dives would swamp the 9 posts a newcomer should read first, and the retroactive backfill dates would scramble a merged chronology.

### Cross-linking between layers

| Option | Description | Selected |
|--------|-------------|----------|
| Auto both directions by milestone | Announcement lists its milestone's deep-dives; deep-dive breadcrumbs back; derived from the collection query | ✓ |
| Deep-dive → announcement only | One-way breadcrumb; announcements get nothing appended | |
| No auto-linking | Nav + indexes only; cross-references come from body prose | |

**User's choice:** Auto both directions.
**Notes:** Derived from data so it can't rot as content lands; no hand-maintained link lists in the `.md` bodies. Generated lists are chrome outside the body, so D-14's "body renders untouched" still holds.

---

## Technical-post fidelity

### Obsidian wikilinks

| Option | Description | Selected |
|--------|-------------|----------|
| remark plugin, site-side | Resolves `[[target\|label]]` to real anchors at build time; source stays byte-identical; unresolvable target = loud build failure | ✓ |
| Rewrite at promote time | Studio-side conversion before the file lands; no plugin needed, but repo copy diverges from vault and depends on a script this repo doesn't own | |
| Strip to plain text | Render the label, drop the link | |

**User's choice:** Site-side remark plugin.
**Notes:** Stripping was rejected because `_how-to-read.md` is load-bearing — every deep-dive points at it for the tag legend, and a reader landing mid-corpus would have no route to it.

### CONT-07 (syntax highlighting / KaTeX)

| Option | Description | Selected |
|--------|-------------|----------|
| Highlighting now, KaTeX v2 | Astro's built-in Shiki, build-time, light theme per D-22; KaTeX stays deferred | ✓ |
| Both now | Pull all of CONT-07 forward including math rendering | |
| Keep all of CONT-07 in v2 | Ship plain `<pre><code>` | |

**User's choice:** Split CONT-07 — highlighting in Phase 2, KaTeX in v2.
**Notes:** Verified during the session that the 60 deep-dives contain zero LaTeX and zero mermaid, so the KaTeX deferral costs nothing today. Shiki adds no dependency and no client JS.

### Metadata source (no frontmatter, no date)

| Option | Description | Selected |
|--------|-------------|----------|
| Derive from path, order by phase number | Milestone from dir, phase+slug from filename, title from body H1; loud-fail on non-conforming name | ✓ |
| Ask studio to add frontmatter | Backfill YAML onto all 60 vault docs | |
| Path-derived + optional frontmatter override | Path by default, frontmatter wins if it ever appears | |

**User's choice:** Derive from path.
**Notes:** Discovered mid-session that the deep-dives have no YAML frontmatter at all and no date of any kind. Ordering by phase number rather than date follows, since the retroactive backfill was all written Jul 2026 about Apr–Jul work. Flagged for the planner: phase numbers include decimals (`phase-10.5`, `phase-27.5`, `phase-46.1`), so the sort key must be numeric-aware.

---

## Roadmap page shape

### What `/roadmap` renders

| Option | Description | Selected |
|--------|-------------|----------|
| Overview page + per-milestone detail | Living era→milestone overview at `/roadmap`, each milestone linking to `/roadmap/m0.X/` | ✓ |
| Overview only | Single page; the 9 detail docs stay vault/Discord-only | |
| Detail only, no overview | Index of the 9 milestone docs without the era-level arc | |

**User's choice:** Overview + per-milestone detail.
**Notes:** Mirrors [D-N]'s Discord structure (pinned overview + thread per milestone) and gives the deep-dives a natural parent page.

### Overview sourcing

| Option | Description | Selected |
|--------|-------------|----------|
| Transcribed `pages/roadmap.md`, hand-synced | Site-voice transcription with the pinned file as reference text | ✓ |
| Render the pinned file verbatim | Zero drift by construction | |
| Generate from the site's own data | Build the era→milestone list from the roadmap-detail collection | |

**User's choice:** Transcribed `pages/roadmap.md`.
**Notes:** The pinned copy is Discord-framed — it opens with "How this channel works" and points readers at `#technical-devlog`/`#announcements` for content the site itself hosts. Verbatim rendering would tell site readers to go read Discord. Generating from data was rejected because the detail docs carry no machine-readable status field.

### Where the 9 detail docs land

| Option | Description | Selected |
|--------|-------------|----------|
| `roadmap/` root dir, third collection | Fourth drop target alongside devlog/technical/pages, same read-only contract | ✓ |
| Inside `pages/` | Treat them as more standalone pages | |
| Inside `technical/` | Keep a milestone's material in one directory | |

**User's choice:** `roadmap/` root dir.
**Notes:** They're a structured series, not one-offs; `pages/`'s no-date one-off shape fits them badly.

---

## Browsability at ~70 posts

### Finding things

| Option | Description | Selected |
|--------|-------------|----------|
| Milestone-grouped indexes, no search | Era→milestone grouping on `/technical/`; `/roadmap/m0.X/` as a second route; CONT-08 stays v2 | ✓ |
| Add client-side search now | Static search index (Pagefind-class) in Phase 2 | |
| Grouped indexes + milestone tag filter | Grouping plus a no-JS filter | |

**User's choice:** Grouped indexes, no search.
**Notes:** CONT-08's stated rationale ("no payoff at ~9 posts") is dead at ~70, but its conclusion survives because the corpus is well-structured — two structural routes to any document. Revisit if the corpus grows past Era 1.

### In-page navigation for long docs

| Option | Description | Selected |
|--------|-------------|----------|
| Auto TOC from headings, no JS | Static list from Astro's rendered `headings` array | ✓ |
| No TOC | Body only, maximum fidelity to "add nothing between reader and text" | |
| TOC on technical only | Two post layouts instead of one | |

**User's choice:** Auto TOC, build-time, no JS.
**Notes:** Deep-dives run 250–350 lines with many H2/H3 sections; the Discord exports already ship a section index for the same reason. Readers land in these mid-corpus rather than reading linearly.

### Promote scope for the phase

| Option | Description | Selected |
|--------|-------------|----------|
| All closed milestones now; M1.1 with the launch post | 9 announcements + 55 deep-dives + 8 roadmap docs + 2 pages in Phase 2; M1.1's material rides with CONT-05 in Phase 4 | ✓ |
| Everything now, including M1.1 | All 60 deep-dives and all 9 roadmap docs in Phase 2 | |
| Structure now, content drips | Templates against representative docs; rest promoted incrementally | |

**User's choice:** Era-0-complete in Phase 2; M1.1 in Phase 4.
**Notes:** "Structure now, content drips" was rejected because CONT-02's "full archive live at launch" wouldn't hold at phase end. Timeline risk turned out lower than first flagged — the vault backfill is essentially complete (60 docs on disk), so this is a copy-and-render job, not a writing job.

---

## Claude's Discretion (session 2)

- Sitemap/canonical mechanics; responsive breakpoints; link accent color; meta-line placement
- Loader configs for the `technical/` and `roadmap/` collections
- TOC presentation (sticky sidebar vs inline) and heading depth
- Layout factoring — one shared layout with variants vs per-collection layouts
- Promote-step sequencing within the phase (which plan/wave)
- Whether the era→milestone grouping is data-derived or a small hand-written map

## Deferred Ideas (session 2)

- Dark mode (SITE-05) — v2; now pairs with a Shiki theme, which is why SITE-05 and CONT-07 were bundled originally
- KaTeX math (other half of CONT-07) — v2; zero LaTeX in the current corpus
- Search / tag taxonomy (CONT-08) — v2 per the grouping decision; Pagefind-class static index is the shape to reach for if grouping stops being enough
- `hero_visual` rendering / OG image source — Phase 3 or v2
- Old-Discord-link 404 behavior — Phase 4's CONT-06 slug-immutability and redirect-stub work now spans three URL trees, not one
- Automated studio→website promote script — still out of scope for this repo; three more drop targets strengthens the case for studio-side automation later

## Follow-ups outside this phase

- `.planning/REQUIREMENTS.md` — CONT-02 and CONT-04 wording predates the technical series; CONT-07/CONT-08 v2 deferrals need amending per D-40/D-41
- `.planning/ROADMAP.md` — Phase 2 success criteria don't mention the technical or roadmap trees
- `studio/vault/decisions/Decision Log.md` — "website v1 carries the technical devlog series" amends [D-H]'s website scope and is a cross-repo decision; needs an entry

---

# Session 1 — 2026-07-14 (original, superseded where session 2 overlaps)

**Date:** 2026-07-14
**Phase:** 2-Content Rendering & Templating
**Areas discussed:** Archive index presentation, Site chrome & navigation, Visual baseline, Content sourcing, Round 2 (hero_visual / homepage / post nav / draft pages)

---

## Archive index presentation

| Option | Description | Selected |
|--------|-------------|----------|
| Title + date + milestone | Milestone tag from frontmatter gives structure without excerpts | ✓ |
| Title + date only | Most minimal, restyle of throwaway page | |
| Title + date + excerpt | Teaser derived from body — more to maintain | |

**User's choice:** Title + date + milestone (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Flat, newest first | Single reverse-chron list; grouping adds nothing at ~9 posts | ✓ |
| Flat, oldest first | Story order but stale start on every visit | |
| Grouped by milestone | Overkill at 9 posts; manifesto rule needed | |

**User's choice:** Flat, newest first (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Homepage IS the archive | `/` lists posts; posts at /devlog/YYYY-MM-DD-slug/ | ✓ |
| Separate landing + /devlog/ | Conventional marketing shape, extra page to keep un-hypey | |
| Landing with inline archive | One-paragraph intro above list | |

**User's choice:** Homepage IS the archive (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Meta line only | Body untouched (H1 = title) + small date/milestone line | ✓ |
| Body only, zero additions | No date visible on post pages | |
| Site title header | Frontmatter title header — duplicates body H1 | |

**User's choice:** Meta line only (recommended)

---

## Site chrome & navigation

| Option | Description | Selected |
|--------|-------------|----------|
| Name + 3 nav links | Wordmark + Devblog / How It's Made / Roadmap; Discord CTA slots in Phase 3 | ✓ |
| Name only, links in footer | Quietest, weak discoverability from shared links | |
| Name + nav + Discord placeholder | Reserve CTA space now | |

**User's choice:** Name + 3 nav links (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal: copyright + RSS slot | One line; RSS link lands there in Phase 3 | ✓ |
| Footer nav repeat + links | More conventional, more chrome | |
| No footer | RSS/Discord would need another home in Phase 3 | |

**User's choice:** Minimal: copyright + RSS slot (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Short note + archive link | Same chrome; matters for Phase 4 redirect-stub story | ✓ |
| 404 with full post list | Slightly more useful, more noise | |
| Bare minimum | Meets SITE-04 letter only | |

**User's choice:** Short note + archive link (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Same layout, 'updated' meta | "Last updated" from frontmatter instead of date+milestone | ✓ |
| Same layout, no meta line | No dates on standalone pages | |
| You decide | Planner picks | |

**User's choice:** Same layout, 'updated' meta (recommended)

---

## Visual baseline

| Option | Description | Selected |
|--------|-------------|----------|
| System font stack | Zero webfont, zero external requests | ✓ |
| One self-hosted webfont | More identity, +1 asset | |
| Serif body, sans UI | Essay feel via system serif | |

**User's choice:** System font stack (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Light only | Near-white/near-black + one accent; dark mode stays v2 | ✓ |
| Dark only | Space audience skews dark but polarizing for long reads | |
| prefers-color-scheme now | Pulls part of SITE-05 forward | |

**User's choice:** Light only (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Text/letterform SVG | Hand-authored, trivially D-G-clean | ✓ |
| Engine capture crop | On-brand, needs source image picked this phase | |
| Geometric orbit mark | Hand-drawn SVG, slightly more designed | |

**User's choice:** Text/letterform SVG (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Hand-written minimal CSS | ~65ch measure, spacing, accent, responsive; no dependency | ✓ |
| Classless base + overrides | Fast start, look you then fight | |
| Tailwind | Overkill for a few templates | |

**User's choice:** Hand-written minimal CSS (recommended)

---

## Content sourcing

| Option | Description | Selected |
|--------|-------------|----------|
| Promote via studio pipeline in-phase | Real .md files land in devlog/ with template frontmatter | ✓ |
| Manual copy into devlog/ | Bypasses studio flow owning status/discord_post_id | |
| Build templates, promote at end | Fixture-driven build, promote as final verification | |

**User's choice:** Promote via studio pipeline in-phase

| Option | Description | Selected |
|--------|-------------|----------|
| New pages/ .md from Discord text | roadmap.md transcribed from #roadmap pinned overview | ✓ |
| Derive from studio Roadmap.md | Internal planning doc, not the public overview | |
| You decide | Compare sources at planning time | |

**User's choice:** New pages/ .md, from Discord text (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Promote both like posts | pages/ is a read-only drop target like devlog/ | ✓ |
| Author directly in repo | Forks source of truth away from studio vault | |
| You decide | Match promote pipeline mechanics | |

**User's choice:** Promote both like posts (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Promote assets/ alongside posts | Images land in devlog/assets/; relative paths resolve unchanged | ✓ |
| Rewrite paths at build | Transform layer between source and render | |
| You decide | Constraint: no body edits, images must render | |

**User's choice:** Promote assets/ alongside posts (recommended)

---

## Round 2: hero_visual / homepage / post nav / draft pages

| Option | Description | Selected |
|--------|-------------|----------|
| Ignore hero_visual in v1 | Drafting note, mixed path/prose/TBD; schema keeps field for later | ✓ |
| Render when valid path | Duplicates images bodies already embed | |
| You decide | Per-post consistency check at planning | |

**User's choice:** Ignore it in v1 (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| One-line description + list | Single quiet sentence, VOICE register; wording approved at plan review | ✓ |
| Bare heading only | Manifesto carries the context | |
| Short paragraph | More orientation, more copy | |

**User's choice:** One-line description + list (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Prev/next + archive link | Serialized M0.x reading order | ✓ |
| Archive link only | Back to index each time | |
| Nothing | Header nav only | |

**User's choice:** Prev/next + archive link (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Honor status; promote flips it | pages/ same draft rule as devlog; promote publishes how-its-made in-phase | ✓ |
| pages/ ignores status | Accidental draft publish risk | |
| You decide | Align with promote flow mechanics | |

**User's choice:** Honor status; promote flips it (recommended)

---

## Claude's Discretion

- Sitemap/canonical mechanics, breakpoints, accent color, meta-line placement
- pages/ collection loader config (no date-filename requirement)
- Promote-step sequencing within the phase (cross-repo work)

## Deferred Ideas

- Dark mode / prefers-color-scheme — v2 (SITE-05)
- hero_visual rendering / OG image source — Phase 3 or v2
- Syntax highlighting + KaTeX — v2 (CONT-07)
- Search / tags — v2 (CONT-08)

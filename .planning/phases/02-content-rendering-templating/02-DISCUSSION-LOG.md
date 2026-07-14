# Phase 2: Content Rendering & Templating - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

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

# Phase 3: RSS, OpenGraph & Discord Distribution - Research

**Researched:** 2026-07-22
**Domain:** Static-site distribution metadata — RSS generation, OpenGraph/Twitter Card emission, build-time asset URL resolution
**Confidence:** HIGH (every load-bearing mechanism was verified by running it against this repo's real astro@7.0.9 + Sätteri build, not read from docs)

## Summary

The stack is fixed and every genuinely uncertain mechanism in this phase was resolved
empirically this session by adding throwaway probe routes to `src/pages/`, running
`npm run build`, reading the emitted output, and deleting the probes. The repo is back
to its pre-probe state (`git status` clean apart from two pre-existing entries) and
`npm test` is green at baseline.

Three findings dominate the phase:

1. **The official Astro RSS recipe is wrong for this repo.** `docs.astro.build/en/recipes/rss/`
   still tells you to re-parse `post.body` with `markdown-it` and sanitize the result.
   In this project that would run a *second, different* Markdown parser that has never
   heard of `mdast-wikilinks.mjs`, `mdast-deepdive-links.mjs`, or Astro's image pipeline —
   producing feed content that silently differs from the site. The **Container API**
   (`experimental_AstroContainer` from `astro/container`) works inside a build-time endpoint
   on astro@7.0.9 and returns the *exact same* HTML the page routes render, wikilinks and
   processed images included. Verified by running it.
2. **`entry.rendered.html` is a trap.** It is available on collection entries and looks
   like the answer, but images in it are still unresolved placeholders
   (`<img __ASTRO_IMAGE_="{...}">`). Using it produces a feed with zero working images and
   no build error.
3. **The default OG card needs no new dependency and no research risk.** `rsvg-convert`
   (librsvg), ImageMagick 7 and Google Chrome headless are all already installed on this
   machine; `rsvg-convert` produced a correct 1200×630, 33 KB, alpha-free PNG from the
   UI-SPEC composition on the first try, with system-font fallback resolving to Nimbus Sans.

**Primary recommendation:** Build `src/pages/rss.xml.ts` as an `APIRoute` that calls
`getCollection('devlog')` → `isVisible` → `render(entry)` → `container.renderToString(Content)`,
then rewrites root-relative `src`/`href` to absolute with `new URL(v, context.site)` inside a
`sanitize-html` `transformTags` hook (which is also where the D-46 loud-fail lives), and hands
the result to `getRssString()`. Resolve OG hero images from `entry.assetImports?.[0]` joined
against an `import.meta.glob('../../assets/*.png', { eager: true })` map, which yields
`ImageMetadata` carrying `.src`, `.width` and `.height` — all three tags in one lookup.
Use plain `{expr}` attribute interpolation for every meta tag, **not** `escapeHtml()`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| RSS XML generation | Build-time endpoint (`src/pages/rss.xml.ts`) | — | Static prerender; no runtime tier exists (GitHub Pages) |
| Post HTML for feed content | Build-time endpoint via Container API | Content pipeline (Sätteri + mdast plugins) | The content pipeline owns rendering; the endpoint must *reuse* it, never re-implement it |
| Absolute-URL rewriting | Build-time endpoint (sanitize-html transformer) | — | Only the endpoint knows `context.site`; the mdast plugins run before base/asset resolution |
| Description extraction | `src/lib/` pure helper | Every route + the feed endpoint | One extracted value, three consumers (D-51) — must be a shared module, not per-route logic |
| OG/Twitter/`theme-color`/feed-discovery tags | `src/layouts/BaseLayout.astro` | — | D-50 covers all ~75 pages; a layout change is the only change that reaches all of them |
| Hero image URL resolution | `src/lib/` helper + `import.meta.glob` | Astro/Vite asset pipeline | Vite owns hashing/emission; the helper only maps a source path to the emitted URL |
| Default OG card rasterization | One-time authoring step (shell) | — | D-49 explicitly forbids a build-time rendering dependency |
| Discord invite constant + loud-fail | `astro.config.mjs` or `src/lib/site.ts` | Build process | D-54 requires the build to stop, which means config-load or module-eval time |
| Feed validity proof | `tests/*.smoke.sh` (local) + human W3C check | — | CI does not run `npm test` (see Environment Availability) |

## Project Constraints (from CLAUDE.md)

From `./CLAUDE.md`, `./.claude/CLAUDE.md`, and `~/Projects/spoods-studios/CLAUDE.md`:

- `devlog/`, `technical/`, `roadmap/`, `pages/` are **read-only promote drop targets** — never
  move, rename, or restyle their `.md` files. **This forbids adding `description:` frontmatter**
  (already reflected in D-51) and forbids back-filling `hero_visual` to make D-48 easier.
- Gate tier **T3** — bugs/broken pages block; cosmetic nits don't.
- **No cookies, no invasive tracking.** Nothing in this phase adds a network call from the page;
  keep it that way (`og:image` is fetched by the *embedding client*, not by the reader's browser).
- **No comments unless WHY-comments.** The existing `src/lib/*.ts` files model this well —
  every comment there explains a non-obvious constraint, none restate the code.
- **Match surrounding code** — `src/lib/` helpers are small, single-purpose, pure, and tested by
  direct import in `tests/lib.smoke.mjs`. New helpers must follow that shape.
- **Vendor-conservative**: well-established tools only; no bleeding edge.
- `.planning/STATE.md` is the authoritative phase position; GSD-driven workflow.
- **Cross-repo writes** (D-56 into `../studio/vault/community/`) have precedent (D-25) but are
  outside this repo's git tree — the planner must treat that as a separate, uncommitted-here step.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

Numbering continues from Phase 2 (which ended at D-44).

#### RSS
- **D-45:** **One feed at `/rss.xml`, announcements only** — the 9 posts in
  the `devlog` collection, generated from the *same* collection query +
  `isVisible` filter as the homepage archive so the two structurally cannot
  drift (DIST-01 read literally). `technical/`, `roadmap/`, and `pages/` are
  excluded by virtue of being separate collections (D-31), not by a filter
  that could be forgotten. Rejected: a second `/technical/rss.xml` (the
  55-doc backfill would dump into a subscriber's reader all at once, all
  dated Jul 2026) and a combined feed (contradicts D-13's reasoning — the
  deep-dives swamp the 9 posts a newcomer should read first).
- **D-46:** Feed items carry the **full rendered post HTML** in
  `<content:encoded>`, sanitized per Astro's own RSS guidance. These are
  long-form essays; a subscriber should get the whole post in their reader,
  which is what "permanent, linkable home" means for someone who reads by
  feed. **Landmine:** two announcement bodies reference images by relative
  path (`![…](../assets/m0.7-hero-contrast.png)`, and the M0.8 equivalent) —
  relative paths are broken in every feed reader, so image `src` values in
  feed content MUST be rewritten to absolute site URLs.
- **D-47:** Discovery is **`<link rel="alternate" type="application/rss+xml">`
  in `BaseLayout`'s `<head>` (so reader apps autodetect on every page) plus a
  visible RSS link in the footer** — the slot D-18 reserved for exactly this.
  No homepage subscribe callout; that's louder than the quiet, content-first
  philosophy (PRD §21.1) warrants.

#### OpenGraph / Twitter Card
- **D-48:** **Per-post real hero image where one exists, site-wide default
  card everywhere else.** Only 2 of 9 announcements have a real image file
  (`assets/m0.7-hero-contrast.png`, `assets/m0.8-hero-precession.png`, both
  genuine engine output — D-K-clean); the other 7 announcements, all 55
  deep-dives, the roadmap tree, and the standalone pages get the default.
  Rejected: build-time generated per-post banners (needs a rendering
  dependency — satori/resvg/sharp — against a project whose aesthetic is
  no dependencies and no client JS) and one static image everywhere (every
  Discord paste would look identical).
  **`hero_visual` is NOT a reliable source** and D-29 (ignored in v1) is
  amended only as far as OG needs an image: M0.5/M0.6 carry *prose
  descriptions* in that field with no file behind them, while M0.7/M0.8 carry
  `path — description`. Whatever mechanism the planner picks, it MUST
  **loud-fail naming the post and the path** when a detected image doesn't
  resolve — never silently fall through to the default (D-10/D-33/D-39
  culture).
- **D-49:** The site-wide default OG card is a **hand-authored wordmark
  image** — "Interstellar Engine" set in the site's own type on its near-white
  background with the favicon glyph — authored as SVG in-repo and exported
  once to PNG at OG dimensions. D-G-clean (no generative imagery), matches the
  site exactly, adds no dependency, and is produced in-phase. Rejected:
  reusing `m0.8-hero-precession.png` as the site default (a specific
  milestone's plot standing in for How It's Made and the roadmap reads
  oddly) and blocking on a fresh engine screenshot (puts site work on the
  engine milestone's clock).
- **D-50:** **Every generated page emits full OG + Twitter Card metadata** —
  homepage, 9 announcements, `/technical/` index, 8 milestone indexes, 55
  deep-dives, how-to-read, `/roadmap/` overview, 8 milestone detail pages,
  How It's Made, 404. DIST-02 says "every post and page", and deep-dive URLs
  are exactly what gets pasted into #technical-devlog. `og:image` and
  `og:url` must be **absolute** URLs (built from `site` + `base`, SITE-02's
  single config source).

#### Embed descriptions
- **D-51:** Descriptions are **auto-extracted from the body's first real prose
  paragraph** — skipping the H1, any leading image, and (for the technical
  tree) the boilerplate `> Retroactive technical devlog. Code shown as built
  on … drift section at the end.` blockquote that opens all 55 deep-dives
  identically. Derived from content, so it cannot rot, and every future
  promoted post gets one automatically. No `description:` frontmatter is
  added and no site-side slug→description map is introduced: all four content
  trees are read-only promote drop targets (CLAUDE.md), and a hand-written map
  would be a second source of truth that silently goes stale.
  **One extracted value feeds three consumers:** `<meta name="description">`,
  the OG/Twitter description, and the RSS item description.
- **D-52:** Truncate at the **last complete sentence under ~160 characters**,
  with an ellipsis when the cut lands mid-paragraph. Fits what Discord and
  search engines actually display without visible clipping, and reads as a
  finished thought rather than a severed one.

#### Discord CTA
- **D-53:** The CTA appears **twice on every page**: an accent-colored text
  link in the header nav slot D-17 reserved for this phase, plus a footer line
  beside the RSS link. **Plain text in the site's existing link accent** — no
  button or pill styling, no icon asset. The site has zero
  interactive-looking elements today (D-21/D-22/D-23) and introducing its
  first button for a CTA cuts against "quiet, content-first" (PRD §21.1).
  Two placements satisfy DIST-03's "prominent" with one shared layout change
  and no per-template work.
- **D-54:** The invite URL is a **single config constant, and the build
  hard-fails naming that constant while it is unset or still the
  placeholder** — same loud-fail culture as D-10 (bad devlog filename), D-33
  (bad technical filename), and D-39 (unresolvable wikilink). A CTA that
  silently doesn't render, or renders pointing at a dead link, is exactly the
  failure mode this project has repeatedly designed against.
  **Consequence:** with the constant unset, `astro build` fails, so Phase 3
  cannot execute to green until a real URL exists. That URL now exists — see
  D-55 — so the loud-fail is a permanent guard against regression rather than
  a live blocker.
- **D-55:** **RESOLVED 2026-07-22.** The permanent invite is
  **`https://discord.gg/yeyyh6ycfw`** — this is the locked value for D-54's
  config constant. Created in-session by driving the headed Playwright browser
  against the developer's own Discord server (guild `Spoods Studios`,
  `1490855396678701107`) with **Expire After: Never**, **Max Number of Uses:
  No limit**, no role grant, no temporary membership; Discord confirmed "Your
  invite link will never expire." Recipients land in `#rules`, the server's
  first channel.
  No planner checkpoint is needed for this — the value is known and the build
  can go green. — **Reversibility:** one-way — this URL will be published in
  page markup, in the studio vault, and in every Discord embed; changing it
  later leaves shared links and vault references pointing at a dead invite.
  Do not regenerate it.
- **D-56:** The same pass **writes the invite link back into the studio
  vault**: `../studio/vault/community/Discord Architecture.md:9`
  (`**Invite link:** (add when created)`) and
  `../studio/vault/community/Handles Secured.md:7` (`(add invite link)`),
  closing an open item on
  `../studio/vault/community/Phase 0 Launch Checklist.md:15`. Cross-repo work
  in-phase has precedent (D-25's promote flow). Only fires once a real link
  exists.

### Claude's Discretion
- `@astrojs/rss` (official, not yet installed) vs. a hand-rolled XML endpoint
  — prefer the official package unless research says otherwise; and the
  `sanitize-html` configuration for D-46.
- The mechanism for detecting a post's hero image (body's first image
  reference vs. parsing `hero_visual`'s leading path), provided D-48's
  loud-fail holds.
- Exact OG card composition and pixel dimensions beyond the ≥1200×630
  convention; `twitter:card` type; whether to emit `og:type`,
  `article:published_time`, `og:site_name`.
- Where the invite constant lives (`astro.config.mjs` alongside `BASE`, vs.
  a new `src/lib/site.ts`) and how the loud-fail is wired — config-load-time
  like the existing `validateContentLoudFail()`, or a layout-level throw.
- Whether the 404 page carries feed/CTA/OG treatment (it inherits
  `BaseLayout`, so it likely gets all three for free).
- Whether the feed caps item count or carries all 9 (and all future)
  announcements.
- Feed `<title>`/`<description>`/`<language>` channel metadata wording.

*(Most of these were subsequently resolved in `03-UI-SPEC.md` and confirmed by the developer
2026-07-22 — see that file's "Discretion Items — Developer-Confirmed" section. Where UI-SPEC
resolved a discretion item, UI-SPEC wins. The two exceptions where this research contradicts
UI-SPEC are flagged explicitly in **Common Pitfalls 6 and 8**.)*

### Deferred Ideas (OUT OF SCOPE)
- **Second feed for the technical series** (`/technical/rss.xml`) — rejected
  for v1 because the 55-doc retroactive backfill would arrive in subscribers'
  readers as one Jul-2026 dump. Revisit once deep-dives are landing
  incrementally with real dates (M1.1+), when a per-tree feed becomes a
  genuine subscription rather than an archive flush.
- **End-of-post "discuss this on Discord" block** — considered for D-53 and
  set aside; it adds chrome below every post next to D-15's prev/next nav.
  Natural to revisit if analytics (Phase 4) show the header/footer CTA
  underperforming.
- **Styled CTA button/pill** — deferred with the same reasoning; would be the
  site's first button, and belongs with any future visual-polish milestone
  rather than smuggled in here.
- **Hand-written per-page descriptions** — a slug→description map was
  rejected (second source of truth, silently stale for new posts). If a
  specific post's auto-extracted description ever reads badly, the fix
  belongs studio-side in the promoted source, not in a site-side override
  table.
- **`hero_visual` prose descriptions on M0.5/M0.6** — those two posts describe
  an image that was never produced as a file. If the images get made later
  they drop into `assets/` and D-48 picks them up with no code change.
- **CONT-06 slug-immutability / redirect stubs across three URL trees** —
  carried forward from Phase 2's deferred list; belongs to Phase 4, and the
  OG/RSS URLs this phase publishes make it more load-bearing, since a moved
  slug now breaks feed items and Discord embeds too.
- **Analytics on outbound Discord CTA clicks** — Phase 4 territory at most,
  and likely never: cookieless analytics (ANLT-01) plus "no invasive
  tracking" makes click-attribution a poor fit.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIST-01 | RSS feed generated from the same content-collection query as the archive page (cannot drift), validates clean | Container-API feed pattern (Pattern 1); shared `getCollection('devlog').filter(isVisible)` query; `getRssString` verified to emit well-formed RSS 2.0 with `content:encoded` (Code Example 1); validation strategy in **Validation Architecture** and **Open Question 1** |
| DIST-02 | Every post and page emits OpenGraph + Twitter Card metadata; a live post URL renders a rich embed when pasted in Discord | Verified Discord tag set (Architecture Pattern 3); absolute-URL construction from `Astro.site` + normalized `BASE_URL` (already in `BaseLayout.astro:11,15-16`); hero-image resolution mechanism (Pattern 2, the phase's highest-uncertainty item, resolved) |
| DIST-03 | Prominent Discord invite CTA on every page | Placement is a pure `BaseLayout.astro` edit per `03-UI-SPEC.md` § Placement Contract; loud-fail wiring options in Architecture Pattern 4; no research risk |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `@astrojs/rss` | `4.0.19` `[VERIFIED: npm registry — npm view @astrojs/rss version, run this session]` | RSS 2.0 feed generation | First-party Astro package, named in Astro's own RSS guide. Emits `xmlns:content` automatically when any item carries `content`, generates `<guid isPermaLink="true">`, and RFC-822 `<pubDate>` — all verified by running `getRssString()` against this repo's real rendered HTML this session. |
| `sanitize-html` | `2.17.6` `[VERIFIED: npm registry — npm view sanitize-html version, run this session]` | Sanitize + rewrite feed content HTML | Named in the official Astro RSS recipe. Its `transformTags` hook is the correct place to do the D-46 absolute-URL rewrite *and* the D-46 loud-fail, so it does double duty rather than being a second pass. |
| `astro/container` (built into astro@7.0.9) | bundled | Render a collection entry to an HTML string inside an endpoint | **Not a new dependency.** `import { experimental_AstroContainer as AstroContainer } from 'astro/container'` — the `./container` export exists in the installed `astro@7.0.9` package `[VERIFIED: node_modules/astro/package.json exports, read this session]` and `AstroContainer.create()` + `renderToString(Content)` was executed successfully inside a build-time endpoint against this repo `[VERIFIED: probe route built and output read this session]`. |

**Do NOT install:** `markdown-it` (see Pitfall 1), `satori`, `@resvg/resvg-js`, `sharp`, any icon
set, any test framework.

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `rsvg-convert` (librsvg) | system, `/usr/bin/rsvg-convert` `[VERIFIED: command -v, run this session]` | One-time SVG → PNG export of `og-default.png` | **Recommended rasterizer.** Produced a correct 1200×630 / 32,965-byte / 3-channel (no alpha) sRGB PNG from the UI-SPEC composition on the first attempt this session. Not a project dependency — an authoring-step shell command. |
| `xmllint` (libxml2 2.12.10) | system, `/usr/bin/xmllint` `[VERIFIED: xmllint --version, run this session]` | XML well-formedness gate on `dist/rss.xml` | Zero-dependency, offline. `xmllint --noout dist/rss.xml` returned clean against the generated feed this session. Covers "is it parseable XML"; does *not* cover RSS 2.0 semantics — see Open Question 1. |

**Installation:**
```bash
npm install @astrojs/rss@4.0.19 sanitize-html@2.17.6
```

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Container API for feed content | `markdown-it` re-parse (the official Astro recipe) | **Rejected — actively wrong here.** See Pitfall 1. Would silently emit `[[wikilinks]]` and broken image paths. |
| Container API | `entry.rendered.html` | **Rejected — silently broken.** See Pitfall 2. Images are unresolved `__ASTRO_IMAGE_` placeholders. |
| `@astrojs/rss` | Hand-rolled XML template string | Rejected: you would re-implement CDATA escaping, RFC-822 dates, and `guid` semantics. The official package is 3 transitive deps (`fast-xml-parser`, `piccolore`, `zod`) `[VERIFIED: npm view @astrojs/rss dependencies]`. |
| `rsvg-convert` | `magick` (ImageMagick 7, installed) | Works (produced 1200×630) but emitted a **4-channel** PNG — UI-SPEC requires no alpha. Would need `-alpha remove -background '#fefefe'`. Use only if librsvg is unavailable. |
| `rsvg-convert` | `google-chrome --headless --screenshot` (installed) or Playwright's bundled chromium-1228 (`~/.cache/ms-playwright/`) | Works (1200×630, 3-channel) but is a heavier, less deterministic path for a flat vector. Keep as fallback if font rendering looks wrong. |
| PNG hero (`.png` via `import.meta.glob`) | WebP hero (`.webp` from the Markdown pipeline) | Both are emitted to `dist/_astro/`. Prefer PNG: Discord renders WebP embeds, but X/Twitter Card support for WebP is unreliable and DIST-02 names Twitter Card explicitly. See Pattern 2. |

**Version verification:** `npm view` was run this session for `@astrojs/rss` (4.0.19,
last published 2026-06-30) and `sanitize-html` (2.17.6, last published 2026-07-10).
Installed-in-repo versions confirmed by reading `node_modules/<pkg>/package.json`:
`astro@7.0.9`, `satteri@0.9.5`, `@astrojs/markdown-satteri@0.3.4`, `@astrojs/sitemap@3.7.3`.

## Package Legitimacy Audit

`gsd-tools query package-legitimacy check --ecosystem npm @astrojs/rss sanitize-html` was run
this session. Raw output preserved:

| Package | Registry | Last publish | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|--------------|-----------|-------------|---------|-------------|
| `@astrojs/rss` | npm | 2026-06-30 | 566,717/wk | `github.com/withastro/astro` (monorepo, `packages/astro-rss`) | **SUS** (`too-new`) | **Approved with note** |
| `sanitize-html` | npm | 2026-07-10 | 9,750,645/wk | `github.com/apostrophecms/apostrophe` | **SUS** (`too-new`) | **Approved with note** |

**Packages removed due to `SLOP` verdict:** none.

**Packages flagged as suspicious `SUS`:** both — but the `too-new` reason is a **false
positive on the seam's part**: it keys off the *most recent release date*, not package age.
Both packages are long-established, first-party or near-first-party, and carry
half-a-million / ten-million weekly downloads with `postinstall: null` and no deprecation.
`@astrojs/rss` is additionally the package named in Astro's own official RSS documentation
(a `[CITED]` authoritative source, not a search result), and CONTEXT.md's discretion list
already names it by hand.

**Planner guidance:** per protocol a `SUS` verdict warrants a checkpoint, but the honest
risk here is nil. Recommend **one** `checkpoint:human-verify` covering both installs at the
top of the dependency task — "confirm `@astrojs/rss@4.0.19` and `sanitize-html@2.17.6`;
both flagged `SUS` only for recent-release-date, both verified as established first-party /
9.7M-weekly-download packages" — rather than two separate gates.

## Architecture Patterns

### System Architecture Diagram

```
                     ┌──────────────────────────────────────────────┐
  devlog/*.md        │  astro.config.mjs                            │
  technical/**/*.md ─┤   site + base (SITE-02 single source)        │
  roadmap/*.md       │   satteri({ mdastPlugins })                  │
  pages/*.md         │   validateContentLoudFail()  ← D-54 hook?    │
                     └──────────────────┬───────────────────────────┘
                                        │
                     ┌──────────────────▼───────────────────────────┐
  assets/*.png ─────►│  Astro / Vite build                          │
                     │   Markdown img  →  /_astro/<name>.<h>_<h>.webp│
                     │   ESM  import   →  /_astro/<name>.<h>.png     │
                     └───────┬───────────────────────┬──────────────┘
                             │                       │
        ┌────────────────────▼───────┐     ┌─────────▼─────────────────────┐
        │  ~75 page routes           │     │  src/pages/rss.xml.ts         │
        │  (existing, unchanged)     │     │  (NEW — build-time endpoint)  │
        └────────────────┬───────────┘     │                               │
                         │                 │  getCollection('devlog')      │
        ┌────────────────▼───────────┐     │    .filter(isVisible)         │  ← SAME query
        │  BaseLayout.astro (EDIT)   │     │    .sort(entryDate desc)      │     as archive
        │                            │     │        │                      │     (D-45)
        │  <head>:                   │     │        ▼                      │
        │   description  ◄───────────┼─────┤  render(entry) → Content      │
        │   og:* / twitter:*         │     │        │                      │
        │   theme-color              │     │        ▼                      │
        │   link rel=alternate ──────┼────►│  container.renderToString()   │
        │   og:image (abs) ◄─────────┼──┐  │        │  full site-identical │
        │                            │  │  │        │  HTML, imgs resolved │
        │  header nav: + Discord     │  │  │        ▼                      │
        │  footer: RSS · Discord ────┼──┼──┤  sanitizeHtml(transformTags)  │
        └────────────────────────────┘  │  │   root-rel → absolute         │
                         ▲              │  │   LOUD-FAIL if unrewritable   │
                         │              │  │        │                      │
        ┌────────────────┴───────────┐  │  │        ▼                      │
        │  src/lib/ (NEW helpers)    │  │  │  getRssString({items})        │
        │   describe-entry.ts  ──────┘  │  └────────┬──────────────────────┘
        │   hero-image.ts  ─────────────┘           │
        │   site.ts (invite const, D-54)            ▼
        └───────────────────────────────┐     dist/rss.xml
                                        │
        public/og-default.png ──────────┴──►  dist/og-default.png
        (committed raster, exported once      (verbatim copy, NOT hashed)
         from src/assets/og-default.svg)
```

### Recommended Project Structure

```
src/
├── pages/
│   └── rss.xml.ts               # NEW — build-time APIRoute (D-45/D-46)
├── layouts/
│   └── BaseLayout.astro         # EDIT — <head> block, nav item, footer line
├── lib/
│   ├── describe-entry.ts        # NEW — D-51/D-52 extractor (3 consumers)
│   ├── hero-image.ts            # NEW — D-48 resolver + loud-fail
│   ├── feed-content.ts          # NEW — sanitize + absolutize + loud-fail
│   └── site.ts                  # NEW (optional) — Discord invite constant + D-54 guard
├── assets/
│   └── og-default.svg           # NEW — editable master (D-49)
public/
└── og-default.png               # NEW — committed 1200×630 raster (D-49)
tests/
└── distribution.smoke.sh        # NEW — picked up automatically by tests/run-all.sh
```

`tests/run-all.sh:13` loops `for script in tests/*.smoke.sh` — a new smoke file needs **no**
harness edit `[VERIFIED: tests/run-all.sh:13, read this session]`.

### Pattern 1: Feed content via the Container API (THE load-bearing pattern)

**What:** Render each devlog entry to an HTML string inside the RSS endpoint using
Astro's Container API, so the feed carries byte-identical HTML to the page routes.

**When to use:** Always, for D-46. This replaces the official docs' `markdown-it` recipe.

**Verified behaviour** (probe route built and output read this session):
- `container.renderToString(Content)` for all 9 devlog entries took **7 ms total**.
- Output for `2026-07-10-warping-without-losing-the-moon` was 9,503 chars and contained
  `<img alt="…" loading="lazy" decoding="async" width="1900" height="1060"
  src="/interstellar-website/_astro/m0.7-hero-contrast.pk4qHc1U_1sWym9.webp" srcset="">`
  — i.e. the **fully-resolved, base-prefixed, content-hashed** asset URL.
- Zero `[[` wikilink artifacts survived (`hasWikilinkArtifact: false`).

```ts
// src/pages/rss.xml.ts
import type { APIRoute } from 'astro';
import { getCollection, render } from 'astro:content';
import { experimental_AstroContainer as AstroContainer } from 'astro/container';

export const GET: APIRoute = async (context) => {
  const container = await AstroContainer.create();
  const entries = (await getCollection('devlog')).filter(isVisible);
  for (const entry of entries) {
    const { Content } = await render(entry);
    const html = await container.renderToString(Content); // site-identical HTML
  }
};
```

**Full HTML surface of the 9 devlog posts** (measured this session across all entries):
tags `h1`(9) `p`(127) `em`(58) `h2`(36) `hr`(8) `strong`(17) `ul`(2) `li`(6) `code`(7) `img`(2);
attributes `id, alt, loading, decoding, width, height, src, srcset`.
**Zero `<a>` elements and zero `<pre>` blocks exist in the devlog tree** — the feed's sanitizer
surface is far smaller than feared. Shiki-highlighted code lives only in `technical/`, which
D-45 excludes from the feed. (Configure the `a`/`pre` handling anyway so a future post that
adds a link or code block doesn't produce a surprise.)

### Pattern 2: Hero image → absolute built URL (D-48, the highest-uncertainty item — resolved)

**What:** Map a post's first body image to the URL of the emitted, content-hashed asset.

**Verified facts** (probe routes built and output read this session):

| Fact | Value |
|------|-------|
| `entry.assetImports` on entries **with** a body image | `["../assets/m0.7-hero-contrast.png"]` — array of raw source paths, in document order |
| `entry.assetImports` on entries **without** one | `undefined` (not `[]`) |
| Which entries carry it | **exactly** `2026-07-10-warping-without-losing-the-moon` and `2026-07-13-making-mercury-precess`; `technical`, `roadmap` and `pages` are all empty |
| Typed in the installed package? | Yes — `assetImports?: Array<string>` in `node_modules/astro/dist/content/runtime.d.ts:29` |
| `import.meta.glob('../../assets/*.png', { eager: true })` from `src/**` | keys `"../../assets/m0.7-hero-contrast.png"`, `"../../assets/m0.8-hero-precession.png"`; each value's `.default` is `ImageMetadata` with keys `src, width, height, format` |
| `.src` value | `/interstellar-website/_astro/m0.7-hero-contrast.pk4qHc1U.png` (base-prefixed, hashed, **PNG**) |
| Is the PNG actually emitted? | **Yes** — `dist/_astro/m0.7-hero-contrast.pk4qHc1U.png` (119,184 B) and `m0.8-hero-precession.SUqOEvDl.png` (134,885 B) both appeared in `dist/` |
| Markdown-pipeline variant | `/_astro/m0.7-hero-contrast.pk4qHc1U_1sWym9.webp` (50,932 B) — **different hash, different format**; both variants coexist in `dist/` |

**Recommendation:** use `entry.assetImports?.[0]` as the detector and an `import.meta.glob`
map as the resolver, keyed on basename. This satisfies D-48's "body's first image reference"
option, gives `width`/`height` for `og:image:width`/`og:image:height` from the same lookup,
and returns a **PNG** (safer than WebP for Twitter Card).

```ts
// src/lib/hero-image.ts
import type { ImageMetadata } from 'astro';

const heroes = import.meta.glob<{ default: ImageMetadata }>(
  '../../assets/*.png',
  { eager: true }
);
const byName = new Map(
  Object.entries(heroes).map(([p, m]) => [p.split('/').pop()!, m.default])
);

export function heroFor(entry: { id: string; assetImports?: string[] }): ImageMetadata | null {
  const ref = entry.assetImports?.[0];
  if (!ref) return null;                       // no image in body -> default card (D-48)
  const meta = byName.get(ref.split('/').pop()!);
  if (!meta) {
    // D-48: loud-fail naming the post AND the path -- never silently fall through
    throw new Error(
      `${entry.id}: hero image "${ref}" is referenced in the body but did not resolve to a ` +
      `built asset (hero-image.ts globs assets/*.png only)`
    );
  }
  return meta;
}
```

**Note:** the eager glob imports both PNGs into every page's module graph, so both are emitted
regardless of use (~254 KB total). That is acceptable and is exactly what makes the URL
resolvable from `BaseLayout` without a per-route import.

**Rejected alternative:** parsing `hero_visual` frontmatter. D-48 already says it is unreliable;
verified this session — `2026-06-19` and `2026-06-25` carry prose sentences with no file
(`hero_visual: The eligibility gate in action — …`), while `2026-07-10`/`2026-07-13` carry
`assets/… — description`. `assetImports` has none of that ambiguity.

**Rejected alternative:** regexing `<img src>` out of the container-rendered HTML. Works, but
(a) yields WebP, (b) forces a container render on every page route just to get a meta tag,
(c) `assetImports` is cheaper and available from `getCollection` alone.

### Pattern 3: The `<head>` metadata block (D-50)

Verified Discord behaviour `[CITED: opengraphplus.com/consumers/discord/tags]` +
`[LOW: WebSearch, cross-checked across 3 results]`:

| Tag | Discord reads it? | Emit? | Note |
|-----|-------------------|-------|------|
| `og:title` | Yes | Yes | ~256 char limit. Do not append site name (UI-SPEC). |
| `og:description` | Yes | Yes | ~350 char limit; D-52's ~160 is well inside. |
| `og:image` | Yes | Yes | **Must be absolute** or the embed degrades to a bare link. |
| `og:url` | Yes | Yes | Absolute; reuse `BaseLayout.astro:11`'s `canonicalUrl`. |
| `og:site_name` | Yes | Yes | Renders as small text above the title. |
| `og:type` | Yes (hint) | Yes | `article` / `website` split per UI-SPEC. |
| `theme-color` | **Yes** — sets the embed's left border | Yes | Discord is the only major consumer that uses it. |
| `twitter:card` | Disputed — sources conflict | Yes | `summary_large_image`. Required for X/Twitter regardless (DIST-02). |
| `og:image:width` / `og:image:height` | Used as a large-vs-thumbnail hint | **Yes** | Free from `ImageMetadata` (Pattern 2) and from the known 1200×630 default. |
| `og:image:alt` | Not rendered by Discord | Yes | Accessibility/other consumers; UI-SPEC specifies the copy. |
| `article:published_time` | Not rendered | Conditional | Announcements only; never fabricate on deep-dives (D-33). |
| `twitter:title` / `twitter:description` / `twitter:image` | Fallback only, when OG is absent | **No** | Redundant — OG is always present. Emitting them adds tags with no consumer. |
| oEmbed | Whitelisted providers only | No | Not available to general sites. |

### Pattern 4: The D-54 loud-fail

Two wiring options, both consistent with existing precedent:

| Option | Where | Fails at | Pros | Cons |
|--------|-------|----------|------|------|
| **A** — config-load | `astro.config.mjs`, beside `validateContentLoudFail()` (`astro.config.mjs:106`) | Config evaluation, before the build starts | Matches the proven pattern; nothing downstream can swallow it (that was the whole 02-08 lesson) | Needs a mechanism to get the constant into `src/` too (export from a shared `.mjs`, or duplicate) |
| **B** — module eval | `src/lib/site.ts`, thrown at import time | First page render | Single source, importable from `BaseLayout` directly | Astro's per-route error handling is the layer 02-08 found *does* swallow things — verify the throw actually exits non-zero |

**Recommendation: A, with the constant exported from a `.mjs` module that both `astro.config.mjs`
and `src/lib/site.ts` import.** The 02-08 finding (`astro.config.mjs:87-100`) is explicit that
per-entry `try/catch` in Astro's own loader silently converts throws into empty output; the
config-load trick is documented in-repo as "the proven way to make a failure actually stop the
build." Do not re-learn that lesson.

**Note on `tests/build.smoke.sh:16`:** `! grep -rIn -e 'github\.io' -e '/interstellar-website' src/`
asserts no hardcoded host/base under `src/`. The Discord invite (`https://discord.gg/yeyyh6ycfw`)
does not trip it, but the RSS endpoint **must** derive its site URL from `context.site` /
`import.meta.env.BASE_URL`, never a literal.

### Anti-Patterns to Avoid

- **Re-parsing Markdown for the feed** (`markdown-it`, `marked`, a second `markdownToHtml()` call
  without `mdastPlugins`). See Pitfall 1.
- **Trusting `entry.rendered.html`.** See Pitfall 2.
- **Running interpolated meta values through `escapeHtml()`.** See Pitfall 6.
- **Filtering the feed by collection name instead of reusing the archive's query.** D-45's whole
  point is that the feed and the archive share one expression. Do not write
  `getCollection('devlog', ({data}) => data.status !== 'draft')` in the endpoint — import and
  call `isVisible` from `src/lib/content-guards.ts` exactly as `src/pages/devlog/[slug].astro:16`
  and every other query site does.
- **Adding CSS.** `03-UI-SPEC.md` § Spacing: "This phase must add zero rules to `global.css`."
- **Adding a `<script>` anywhere.** `tests/site.smoke.sh` asserts
  `grep -rl '<script' dist/ | wc -l -eq 0`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| RSS 2.0 serialization | Template-literal XML | `@astrojs/rss` `getRssString()` | CDATA escaping, RFC-822 dates, `guid isPermaLink`, `xmlns:content` auto-declaration — all verified emitted correctly this session |
| Markdown → HTML for the feed | A second parser | `render()` + Container API | The site's HTML is the product of `satteri({ mdastPlugins })` **plus** Astro's image pipeline. Nothing else reproduces it. |
| HTML sanitization / URL rewriting | Regex over the HTML string | `sanitize-html` with `transformTags` | Regex over HTML is the classic footgun; `transformTags` gives you a per-attribute hook that is also the natural place for the D-46 loud-fail |
| Absolute-URL construction | String concatenation | `new URL(value, context.site)` | Verified: `context.site` is `https://spoods-studios.github.io/` and rendered `src` values already carry the base (`/interstellar-website/_astro/…`), so `new URL()` composes correctly with no manual slash arithmetic |
| Asset content-hash lookup | Reading `dist/_astro/` at build time | `import.meta.glob(..., { eager: true })` → `ImageMetadata.src` | Vite owns hashing; the glob is the supported way to ask it |
| Attribute escaping in `<head>` | `escapeHtml()` | Astro's default `{expr}` interpolation | Verified: Astro escapes `"` → `&quot;` and `&` → `&amp;` in attribute values; `escapeHtml()` deliberately does **not** escape quotes (`src/lib/escape-html.ts:1-11`) |
| SVG rasterization | A build-time npm renderer | `rsvg-convert`, once, by hand | D-49 rejected satori/resvg/sharp explicitly; the tool is already installed |

**Key insight:** every "just re-derive it" shortcut in this phase produces output that *looks*
right in a grep and is wrong in a reader. The feed content, the hero URL, and the OG image URL
must all be pulled out of the **same build** that produced the pages, never recomputed.

## Common Pitfalls

### Pitfall 1: Following the official Astro RSS recipe verbatim

**What goes wrong:** `docs.astro.build/en/recipes/rss/` currently recommends
`sanitizeHtml(parser.render(post.body))` with `markdown-it`
`[CITED: docs.astro.build/en/recipes/rss/, fetched this session]`. In this repo that runs a
parser that has never been given `createWikilinkPlugin` or `createDeepDiveLinkPlugin`
(`astro.config.mjs:55-58`) and has no connection to Astro's image pipeline.

**Why it happens:** the recipe predates the Container API and assumes a default remark
pipeline with no custom plugins.

**Result:** raw `[[m0.4/phase-19-…]]` literals and unrewritable `../assets/…png` paths in
the feed. **The build still succeeds.** The docs even warn: *"Images and internal links using
relative paths are unsupported."*

**How to avoid:** Pattern 1. Never call a Markdown parser inside the endpoint.

**Warning signs:** the string `markdown-it` appearing anywhere in `package.json`; `[[` appearing
in `dist/rss.xml`.

### Pitfall 2: Using `entry.rendered.html`

**What goes wrong:** collection entries expose `rendered: { html, metadata }`, which looks like
free pre-rendered HTML. Verified this session, the M0.7 entry's `rendered.html` contains:

```
<img __ASTRO_IMAGE_="{&quot;alt&quot;:&quot;…&quot;,&quot;src&quot;:&quot;../assets/m0.7-hero-contrast.png&quot;,&quot;index&quot;:0}">
```

**Why it happens:** image resolution is a *later* stage than Markdown rendering; the placeholder
is substituted when the entry is rendered through a component.

**How to avoid:** always go through `render(entry)` → `Content` → container.

**Warning signs:** `__ASTRO_IMAGE_` in `dist/rss.xml`; `<img>` tags with no `src` attribute at all
(sanitize-html will strip the unknown `__ASTRO_IMAGE_` attribute, leaving a bare `<img>` —
so the failure is *invisible* in the feed source too).

### Pitfall 3: `sanitize-html` strips `<img>` by default

**What goes wrong:** `sanitizeHtml.defaults.allowedTags` does **not** include `img`
`[VERIFIED: read from installed sanitize-html@2.17.6 defaults this session]`. Default config
silently deletes both hero images from the feed.

**How to avoid:** `allowedTags: sanitizeHtml.defaults.allowedTags.concat(['img'])`, exactly as
the official recipe shows. Default `allowedAttributes` already permits
`img: ['src','srcset','alt','title','width','height','loading']` and
`a: ['href','name','target']`.

**Also note:** `style` is not in the default attribute allow-list, so Shiki's
`<pre class="astro-code" style="background-color:#fff;…">` and its `<span style="color:#…">`
children would be stripped of color if a code block ever entered the feed. Irrelevant today
(zero `<pre>` in the devlog tree, verified) and the degradation is graceful — monochrome code,
not broken markup. **Do not** add `style` to the allow-list to "fix" it; that re-opens a CSS
injection surface for a cosmetic gain in a surface no current post uses.

### Pitfall 4: Feed URLs are root-relative, not relative

**What goes wrong:** D-46 says the bodies "reference images by relative path". They do *in the
Markdown source*. After the build, the rendered `src` is **root-relative with the base already
applied**: `/interstellar-website/_astro/m0.7-hero-contrast.pk4qHc1U_1sWym9.webp`
`[VERIFIED: read from dist/devlog/2026-07-10-…/index.html this session]`.

**Why it matters:** a rewrite rule written for `../assets/…` will match nothing and the
loud-fail will never fire; a rule that only prepends the host will produce the right answer
by accident. Write the rule for what is actually there: `src.startsWith('/')` →
`new URL(src, context.site).href`, and **throw** on anything that is neither absolute-http nor
root-relative.

**Scope:** across all 9 devlog posts there are exactly **2** root-relative URLs and **0**
anchors, so the rewrite has a very small blast radius today — which is precisely why the
loud-fail matters more than the rewrite.

### Pitfall 5: CONTEXT.md's sitemap expectation is wrong

`03-CONTEXT.md` § Integration Points says "the new `/rss.xml` route should appear in the
sitemap for free; worth an assertion." **It will not.** Verified this session: a probe
endpoint at `src/pages/probe.json.ts` was built to `dist/probe.json` and was **absent** from
`dist/sitemap-0.xml`; the sitemap listed exactly 85 URLs against 85 non-404 HTML pages.
`@astrojs/sitemap` includes page routes, not endpoint routes.

**Consequence:** this is *good news* — `tests/site.smoke.sh:63-70` asserts
`sitemap URL count == non-404 HTML page count`, and that assertion stays green with no edit.
Do not write an assertion that `/rss.xml` is in the sitemap; it would fail.

### Pitfall 6: UI-SPEC's `escape-html.ts` instruction is wrong for attributes

`03-UI-SPEC.md` § Placement → `<head>` says *"All interpolated attribute values pass through
the existing `src/lib/escape-html.ts`."* **Do not do this.**

Verified this session by building a probe page interpolating
`He said "quoted" & <b>bold</b> — test` into `content={...}`:
```html
<meta name="description" content="He said &quot;quoted&quot; &amp; <b>bold</b> — test">
```
Astro's own attribute interpolation escapes `"` and `&`. `escapeHtml()` escapes `&`, `<`, `>`
and **deliberately not quotes** (`src/lib/escape-html.ts:1-11` — quotes were left alone on
purpose so contraction-heavy titles survive `set:html`). Applying it here would:
1. leave `"` unescaped *if* it were used with `set:html` (an attribute-injection hazard), and
2. double-escape `&` → `&amp;amp;` when combined with `{expr}`.

**Correct:** use plain `{value}` interpolation for every `content=` / `href=` / `title=` in the
new `<head>` block. `escapeHtml()` remains correct for its existing `set:html` call sites only
(`PostLayout.astro:38-39`). The planner should record this as an explicit amendment to UI-SPEC.

### Pitfall 7: Discord will not re-scrape a URL you already pasted

Discord caches embed scrapes. If a URL is pasted before the OG tags deploy, the naked-link
version is cached and re-pasting the same URL in the same channel shows the stale result.
`[ASSUMED — widely-reported behaviour, not verified this session]`

**How to avoid:** during verification, paste a URL that has never been shared, or append a
throwaway `?v=2` query string to bust the cache. Plan the human-verification step accordingly.

### Pitfall 8: `og:title` doubling and the 404 page

`03-UI-SPEC.md` requires `og:title` to equal the page's own `<title>` with no site-name suffix.
`BaseLayout.astro:22` renders `<title>{title}</title>` — a bare prop, no suffix — so
`og:title={title}` is correct as-is. **Verify** that no route passes an already-suffixed title.

## Code Examples

### Example 1: The complete RSS endpoint (verified pattern)

The XML-generation half of this was executed end-to-end this session against the real
container-rendered HTML of all 9 posts; the output passed `xmllint --noout`.

```ts
// src/pages/rss.xml.ts
import type { APIRoute } from 'astro';
import { getCollection, render } from 'astro:content';
import { experimental_AstroContainer as AstroContainer } from 'astro/container';
import { getRssString } from '@astrojs/rss';
import sanitizeHtml from 'sanitize-html';
import { assertNonEmpty, isVisible } from '../lib/content-guards';
import { entryDate, entryTitle } from '../lib/devlog-meta';
import { describeEntry } from '../lib/describe-entry';

function absolutize(html: string, site: URL, entryId: string): string {
  const toAbsolute = (attr: 'src' | 'href') => (tagName: string, attribs: Record<string, string>) => {
    const v = attribs[attr];
    if (v && v.startsWith('/')) {
      attribs[attr] = new URL(v, site).href;
    } else if (v && !/^https?:/i.test(v) && !v.startsWith('#')) {
      // D-46: a feed-content URL that cannot be made absolute fails the build, named.
      throw new Error(`${entryId}: feed content ${attr}="${v}" could not be rewritten to an absolute URL`);
    }
    return { tagName, attribs };
  };
  return sanitizeHtml(html, {
    allowedTags: sanitizeHtml.defaults.allowedTags.concat(['img']),
    transformTags: { img: toAbsolute('src'), a: toAbsolute('href') },
  });
}

export const GET: APIRoute = async (context) => {
  const site = context.site!; // set in astro.config.mjs (SITE-02)
  const base = import.meta.env.BASE_URL.endsWith('/')
    ? import.meta.env.BASE_URL
    : `${import.meta.env.BASE_URL}/`;

  // D-45: the SAME query + filter the homepage archive uses.
  const entries = assertNonEmpty(await getCollection('devlog'), 'devlog').filter(isVisible);
  const sorted = [...entries].sort((a, b) => entryDate(b).getTime() - entryDate(a).getTime());

  const container = await AstroContainer.create();
  const items = [];
  for (const entry of sorted) {
    const { Content } = await render(entry);
    items.push({
      title: entryTitle(entry),
      pubDate: entryDate(entry),
      link: `devlog/${entry.id}/`,          // resolved against `site` below
      description: describeEntry(entry),
      content: absolutize(await container.renderToString(Content), site, entry.id),
    });
  }

  const feedUrl = new URL(`${base}rss.xml`, site).href;
  const xml = await getRssString({
    title: 'Interstellar Engine — Devblog',
    description:
      'Milestone announcements from Interstellar Engine — a space engine built from scratch on real n-body physics.',
    site: new URL(base, site).href,          // channel <link> carries the base
    items,
    xmlns: { atom: 'http://www.w3.org/2005/Atom' },
    customData: `<language>en</language><atom:link href="${feedUrl}" rel="self" type="application/rss+xml"/>`,
    trailingSlash: true,
  });

  return new Response(xml, { headers: { 'Content-Type': 'application/xml' } });
};
```

**Verified output shape** (from running exactly this generation step this session, 58,535 bytes
for 9 items):
```xml
<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"
  xmlns:content="http://purl.org/rss/1.0/modules/content/"
  xmlns:atom="http://www.w3.org/2005/Atom"><channel>
<title>Interstellar Engine — Devblog</title>
<description>Milestone announcements from Interstellar Engine.</description>
<link>https://spoods-studios.github.io/interstellar-website/</link>
<language>en</language>
<atom:link href="https://spoods-studios.github.io/interstellar-website/rss.xml" rel="self" type="application/rss+xml"/>
<item><title>…</title>
<link>https://spoods-studios.github.io/interstellar-website/devlog/2026-04-07-…/</link>
<guid isPermaLink="true">https://spoods-studios.github.io/interstellar-website/devlog/2026-04-07-…/</guid>
<description>…</description><pubDate>Tue, 07 Apr 2026 00:00:00 GMT</pubDate>
<content:encoded><![CDATA[…]]></content:encoded></item>…
```

Notes proven by that run:
- `xmlns:content` is added **automatically** when any item sets `content` — do not declare it in `xmlns`.
- `<guid isPermaLink="true">` is generated from `link` automatically.
- `<pubDate>` is correct RFC-822 (`Tue, 07 Apr 2026 00:00:00 GMT`).
- Passing `site` **with** the base makes the channel `<link>` base-inclusive and lets item
  `link` values be short relatives — this is the cleanest way to satisfy SITE-02.
- `<atom:link rel="self">` is not emitted by the package; add it via `xmlns` + `customData`
  (see Open Question 1 for why it matters).

### Example 2: The description extractor (D-51/D-52) — prototyped and run over all content

This prototype was executed this session against all 9 devlog posts, both `pages/`, all 8
`roadmap/` entries and 3 sampled `technical/` deep-dives; every one produced a sensible
description and none returned `null`.

```ts
// src/lib/describe-entry.ts
const BLOCK_SKIP = [
  /^#/,            // headings (H1 title)
  /^!\[/,          // leading image
  /^>/,            // blockquote -- the 55 deep-dives' identical boilerplate (D-51)
  /^[-*+]\s|^\d+\.\s/, // lists
  /^\|/,           // tables
  /^(-{3,}|\*{3,})$/,  // thematic breaks
];

export function firstProseBlock(body: string): string | null {
  for (const block of body.split(/\n\s*\n/).map((b) => b.trim()).filter(Boolean)) {
    if (BLOCK_SKIP.some((re) => re.test(block))) continue;
    return block;
  }
  return null;
}

export function stripInline(s: string): string {
  return s
    .replace(/\s*\n\s*/g, ' ')
    .replace(/\[\[([^\]|]+)(\|[^\]]+)?\]\]/g, (_m, a, b) => (b ? b.slice(1) : a))
    .replace(/!\[[^\]]*\]\([^)]*\)/g, '')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/(?<!\*)\*([^*]+)\*(?!\*)/g, '$1')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/_([^_]+)_/g, '$1')
    .replace(/\s+/g, ' ')
    .trim();
}

export function truncate(s: string, max = 160): string {
  if (s.length <= max) return s;
  const cut = s.slice(0, max + 1);
  const end = Math.max(cut.lastIndexOf('. '), cut.lastIndexOf('? '), cut.lastIndexOf('! '));
  if (end > 0) return cut.slice(0, end + 1);      // D-52: last COMPLETE sentence
  return `${cut.slice(0, cut.lastIndexOf(' '))}…`; // no sentence break -> ellipsis
}
```

**Actual measured output** (representative sample, this session):

| Entry | Extracted description |
|-------|-----------------------|
| `devlog/2026-04-07-…manifesto` | `I've spent more hours than I'd like to admit in Kerbal Space Program.` |
| `devlog/2026-07-13-making-mercury-precess` | `In 1859, the astronomer Urbain Le Verrier noticed something wrong with Mercury.` |
| `devlog/2026-06-25-shipping-the-warp-lever…` | `Last milestone I built a symplectic integrator — the Wisdom-Holman method, the math real astronomers use to push the solar system across millions of years — and…` |
| `pages/how-its-made` | `Setare Aerospace is built solo, and I use AI heavily. This page says exactly how — what AI does here, what it never does, and why you can trust the result…` |
| `roadmap/M0.8` | `Milestone: M0.8 Perturbation Refinements — closes the two perturbation-fidelity corrections the engine's design document promised but no milestone had…` |
| `technical/m0.8/phase-45-…` | `Phase 44 landed J2 oblateness the same milestone — a per-body catalog term threaded through the WH flat kick, the HJS nested kick, and the worker's direct-force…` |

**One tuning decision for the planner:** D-52 says "last complete sentence under ~160
characters." A strict reading turns the `pages/how-its-made` case into just
`Setare Aerospace is built solo, and I use AI heavily.` (52 chars) rather than the
160-char word-cut shown above. The prototype above implements the strict reading
(`end > 0`, no minimum-length floor). A `end > 60` floor produces the longer, arguably
better result. **Recommend the strict D-52 reading** — it is what the decision says, and
the short version reads as a finished thought. Flag as a one-line tunable, not a redesign.

**Loud-fail note:** `firstProseBlock` returning `null` means a content file has no prose at
all. Every one of the ~75 current entries produces a value, so make `null` a build error
naming the entry, consistent with D-10/D-33/D-39 culture.

### Example 3: One-time OG card export (D-49)

Verified this session — `rsvg-convert` produced a 1200×630, 32,965-byte, 3-channel sRGB PNG
(no alpha, well under UI-SPEC's 200 KB budget) and the rendered text resolved through the
system-font fallback chain to Nimbus Sans (`fc-match Helvetica` → `NimbusSans-Regular.otf`).

```bash
# One-time authoring step -- NOT a build step, NOT an npm script (D-49).
rsvg-convert -w 1200 -h 630 -b '#fefefe' -f png \
  -o public/og-default.png src/assets/og-default.svg

# Verify before committing:
identify -format '%wx%h %[channels] %b\n' public/og-default.png
#   expect: 1200x630 srgb  ~33KB   (srgb = 3 channels, no alpha -- UI-SPEC requirement)
```

The SVG must use the literal Phase 2 font stack. The existing favicon
(`public/favicon.svg:3`) already carries it verbatim and is the reference for the `IE` glyph:
```
font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
```
Note that `rsvg-convert` resolved `font-weight="600"` to a bold face — the exported card's
wordmark weight matched `header .wordmark`'s `font-weight: 600` (`src/styles/global.css:60`).

**Fallbacks if librsvg misbehaves:**
```bash
magick -background '#fefefe' src/assets/og-default.svg -alpha remove -alpha off \
  -resize 1200x630 public/og-default.png            # ImageMagick 7, installed
google-chrome --headless --disable-gpu --screenshot=public/og-default.png \
  --window-size=1200,630 "file://$PWD/src/assets/og-default.svg"   # installed
```

## Runtime State Inventory

*Not a rename/refactor/migration phase — greenfield additions only. Section retained because
D-56 writes to state outside this repo:*

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore in this project (static site on GitHub Pages) | none |
| Live service config | **Discord server** `Spoods Studios` (`1490855396678701107`) — the permanent invite `https://discord.gg/yeyyh6ycfw` already exists (D-55) and must **not** be regenerated. Verified as a locked, one-way decision in CONTEXT.md. | none — consume the existing value |
| Cross-repo files (D-56) | `../studio/vault/community/Discord Architecture.md:9`, `../studio/vault/community/Handles Secured.md:7`, `../studio/vault/community/Phase 0 Launch Checklist.md:15` — outside this git tree | separate edit step; not part of this repo's commits |
| OS-registered state | None | none |
| Secrets/env vars | None — the invite URL is public by design and belongs in git | none |
| Build artifacts | `dist/` is regenerated per build; `node_modules/.astro` image cache holds the two hero WebP variants ("reused cache entry" observed) — harmless | none |

## Common Pitfalls (summary for verification steps)

1. `markdown-it` present in `package.json` → wrong pattern (Pitfall 1)
2. `__ASTRO_IMAGE_` or `<img>` with no `src` in `dist/rss.xml` → `rendered.html` used (Pitfall 2)
3. Zero `<img` in `dist/rss.xml` → `img` missing from `allowedTags` (Pitfall 3)
4. `src="/interstellar-website/` (root-relative, no host) in `dist/rss.xml` → rewrite missed (Pitfall 4)
5. Sitemap assertion on `/rss.xml` → will fail; endpoints are excluded (Pitfall 5)
6. `escapeHtml()` in the new `<head>` block → wrong; use `{expr}` (Pitfall 6)
7. Discord shows a naked link on re-paste → cached scrape, use a fresh URL (Pitfall 7)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `markdown-it` re-parse for full-content feeds (still the published Astro recipe) | Container API (`astro/container`) render of the real `Content` component | Container API shipped with Astro 4.9+; recipe not yet updated | The docs are behind; this repo's custom Markdown processor makes the gap load-bearing rather than cosmetic |
| `pagesGlobToRssItems` / `import.meta.glob` feeds | `getCollection()` + `render()` | Content Layer (Astro 5) | Already the pattern here; `pagesGlobToRssItems` is legacy and irrelevant |
| `entry.render()` method on entries | standalone `render(entry)` from `astro:content` | Astro 5 Content Layer | Already used at `src/pages/devlog/[slug].astro:49` |

**Deprecated/outdated:**
- `pagesGlobToRssItems` — for the pre-Content-Layer `import.meta.glob` style. Do not use.
- The `content` + `markdown-it` recipe in the official docs — technically still supported, but
  produces incorrect output for any project with custom mdast/remark plugins or Markdown images.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Discord caches embed scrapes per-URL, so re-pasting a previously-shared URL shows the stale result | Pitfall 7 | Verification step reports a false negative and someone "fixes" working tags |
| A2 | Discord renders WebP `og:image` fine, but X/Twitter Card WebP support is unreliable | Alternatives / Pattern 2 | Recommendation to prefer PNG is merely suboptimal, not broken — both formats are emitted |
| A3 | `twitter:card: summary_large_image` is honored by Discord | Pattern 3 | Sources actively conflict on this. If ignored, Discord's own `og:image` dimension heuristic still yields the large layout at 1200×630 (UI-SPEC already accepts this). Tag is required for X regardless. |
| A4 | GitHub Actions `ubuntu-latest` ships `xmllint` | Environment Availability | Moot — CI does **not** run `npm test` (verified: `.github/workflows/deploy.yml` only runs `withastro/action@v6`). Feed validation is local-only either way. |
| A5 | `og:title` ~256 char / `og:description` ~350 char Discord truncation limits | Pattern 3 | Cosmetic only; D-52's ~160 chars is far inside any plausible limit |
| A6 | The Container API remains stable across Astro 7 patch releases despite the `experimental_` prefix | Pattern 1 | A future `astro` upgrade could rename the export. The name is `experimental_AstroContainer` — pin the astro version and let a rename fail loudly at build. |

## Open Questions (RESOLVED)

> **All three resolved during discuss and planning, 2026-07-22.** Each item's resolution is
> annotated inline below. Nothing here is still open; no downstream agent needs to re-litigate one.

1. **What does "the RSS feed validates clean" concretely mean (success criterion 4)?**
   - ✅ **RESOLVED by D-57** (developer-confirmed 2026-07-22): a split criterion. The automated leg
     is `xmllint --noout dist/rss.xml` plus the structural greps, owned by Plan 03-05 Task 2; the
     human leg is one W3C Feed Validation Service run against the deployed feed, owned by Plan 03-06
     Task 3 check 5 and recorded as a backstop truth, never a build step. `<atom:link rel="self">`
     is emitted from the start (Plan 03-02 Task 1) to pre-empt the one predictable recommendation.
     The recommendation below was adopted verbatim.
   - **What we know:** `xmllint --noout` on the generated feed passes (verified this session).
     The feed is structurally RSS 2.0 with a `content` module namespace. The
     W3C Feed Validation Service (`validator.w3.org/feed`) is a **network** service and takes
     a URL or a paste. The `feed-validator` npm package is a *client* for that same W3C service,
     not an offline validator `[LOW: WebSearch]`. No maintained offline Node RSS 2.0 validator
     was found; the only offline option surfaced was a Go tool (`rss-validator`), which would
     add a Go toolchain for one check.
   - **What's unclear:** whether the W3C validator will emit its standard
     *"feed does not contain an `atom:link` with `rel=self`"* recommendation, which many people
     read as "not clean."
   - **Recommendation — a two-part acceptance criterion:**
     - **Automated (in `tests/distribution.smoke.sh`, offline, zero new deps):**
       `xmllint --noout dist/rss.xml` for well-formedness, plus greps asserting: exactly one
       `<channel>`; `<title>`, `<link>`, `<description>` present on the channel; item count
       equals the visible devlog count computed from the same source the archive assertion uses;
       every `<link>`/`<guid>` starts with the `$PREFIX` derived from `astro.config.mjs` (reuse
       `tests/site.smoke.sh:22-27`'s existing extraction); every `<pubDate>` matches
       `^[A-Z][a-z]{2}, [0-9]{2} [A-Z][a-z]{2} [0-9]{4} `; zero occurrences of
       `src="/interstellar-website` (i.e. no un-absolutized URLs); zero occurrences of
       `__ASTRO_IMAGE_` and `[[`.
     - **Human, once, against the deployed URL:** paste
       `https://spoods-studios.github.io/interstellar-website/rss.xml` into
       `validator.w3.org/feed` and require **zero errors**. Pre-empt the one predictable
       recommendation by emitting `<atom:link rel="self">` (shown in Code Example 1 and
       verified to serialize correctly this session).

2. **Should the deep-dive `og:description` strip the boilerplate blockquote, or is skipping it enough?**
   - ✅ **RESOLVED at planning:** skipping is enough. The `^>` skip rule ships in
     `src/lib/describe-entry.ts` (Plan 03-01 Task 4, with a dedicated unit assertion for the
     blockquote case), and the recommended distinctness assertion is implemented as
     `distinct og:description values > 60` in Plan 03-04 Task 1 and again as a permanent gate in
     Plan 03-05 Task 1. If the skip rule ever stops working, all 55 deep-dives collapse onto one
     sentence and that assertion fails — which is exactly the residual risk this question raised.
     devlog…` blockquote. The prototype's `^>` skip rule handles it and produces good
     descriptions (verified on 3 sampled files).
   - **What's unclear:** whether any deep-dive's *first non-blockquote* paragraph is also
     near-boilerplate. The two sampled ones were not.
   - **Recommendation:** ship the skip rule; add a smoke assertion that the ~75 emitted
     `<meta name="description">` values contain at least N distinct strings (they must not
     all collapse to one boilerplate sentence).

3. **Does `og:image` need to be the PNG or the WebP for the two hero posts?**
   - ✅ **RESOLVED by D-59:** the PNG. Plan 03-03 globs `assets/*.png` only and asserts neither hero
     page's `og:image` value ends in `.webp`. The certainty check the recommendation asked for is
     covered by Plan 03-06 Task 3 check 1, which pastes a hero post and confirms a large image
     renders.

4. **Is the exported default card typographically faithful to the live site?** *(implicit in the
   `rsvg-convert` font-fallback finding, § Code Example 3)*
   - ✅ **RESOLVED as an owned verification, not a research gap:** the executor inspects the exported
     PNG before committing it (Plan 03-01 Task 2, with `identify` asserting 1200x630 / no alpha /
     under 200 KB), and the human compares it against the live header in Plan 03-06 Task 3 check 6.
     Two documented rasterizer fallbacks exist if the font resolves wrongly.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | Astro build | ✓ | v24.15.0 | — |
| `astro` | everything | ✓ | 7.0.9 (installed) | — |
| `astro/container` export | Feed content (Pattern 1) | ✓ | bundled in astro@7.0.9 | none needed |
| `@astrojs/rss` | Feed XML | ✗ (to install) | 4.0.19 on registry | hand-rolled XML (not recommended) |
| `sanitize-html` | Feed content sanitize + rewrite | ✗ (to install) | 2.17.6 on registry | none acceptable |
| `rsvg-convert` | One-time OG card export | ✓ | `/usr/bin/rsvg-convert` (librsvg) | `magick`, `google-chrome --headless` |
| `magick` / `convert` | Fallback rasterizer + `identify` verification | ✓ | ImageMagick 7 | — |
| `google-chrome` | Fallback rasterizer | ✓ | `/usr/bin/google-chrome` | Playwright chromium-1228 in `~/.cache/ms-playwright/` |
| `xmllint` | Feed well-formedness gate | ✓ | libxml 2.12.10 | node `fast-xml-parser` (arrives transitively with `@astrojs/rss`) |
| `inkscape` | (alternative rasterizer) | ✗ | — | not needed — three others available |
| Python `feedvalidator` | offline RSS semantics check | ✗ | — | **no viable offline option** — see Open Question 1 |
| GitHub Actions runner | Deploy | ✓ | `ubuntu-latest`, `withastro/action@v6` + `actions/deploy-pages@v5` | — |
| Discord invite | DIST-03 | ✓ | `https://discord.gg/yeyyh6ycfw` (D-55, permanent) | none — do not regenerate |

**Missing dependencies with no fallback:** none blocking. The offline RSS-semantics validator
gap is handled by the split acceptance criterion in Open Question 1.

**Missing dependencies with fallback:** `@astrojs/rss` and `sanitize-html` are simple installs.

**Note on CI:** `.github/workflows/` contains only the deploy workflow, which runs
`withastro/action@v6` (build) and `actions/deploy-pages@v5`. **`npm test` is never run in CI.**
Therefore: (a) all smoke assertions are local-only gates, and (b) D-54's loud-fail is
nevertheless deploy-blocking, because it fails `astro build` itself.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | **none by decision** — `bash` smoke scripts + `node:assert/strict` (D-03/D-09; Phase 1 RESEARCH) |
| Config file | `tests/run-all.sh` (runner), `package.json:test → bash tests/run-all.sh` |
| Quick run command | `npm run build` (the D-54/D-48/D-46 loud-fails ARE the fast gate) |
| Full suite command | `npm test` |
| Baseline status | **GREEN** — `npm test` run this session, output ended `ALL CHECKS PASSED` |

`tests/run-all.sh` runs `node tests/lib.smoke.mjs` first, then every `tests/*.smoke.sh` in
sorted order. A new `tests/distribution.smoke.sh` is picked up automatically — **no harness
edit and no parallel-plan collision risk**.

**Existing idioms the planner must reuse (not reinvent):**
- `grep -o … | wc -l` for occurrence counts — `grep -c` counts *lines*, and Astro minifies
  `dist/*.html` to one line (`tests/build.smoke.sh:24-28`).
- Derive `$PREFIX` from `astro.config.mjs` with `grep -oP`, never hardcode
  (`tests/site.smoke.sh:22-27`).
- Trap-and-restore fixtures for loud-fail proofs — back up the file, mutate, assert the build
  fails and names the offender, restore, assert the content trees are clean
  (`tests/site.smoke.sh`, D-39/D-30/deep-dive fixtures).

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DIST-01 | `/rss.xml` builds and is well-formed XML | smoke | `xmllint --noout dist/rss.xml` | ❌ Wave 0 |
| DIST-01 | Feed item count == homepage archive link count (cannot drift) | smoke | `test "$(grep -o '<item>' dist/rss.xml \| wc -l)" -eq "$(grep -o 'href="[^"]*devlog/[^"]*/"' dist/index.html \| wc -l)"` | ❌ Wave 0 |
| DIST-01 | A drafted devlog post disappears from the feed **and** the archive together | smoke fixture | trap-and-restore: prepend `status: draft` to one devlog file, rebuild, assert both counts drop by 1 | ❌ Wave 0 |
| DIST-01 | Every feed link/guid carries the config-derived prefix | smoke | grep `<link>`/`<guid>` vs `$PREFIX` extracted from `astro.config.mjs` | ❌ Wave 0 |
| DIST-01 | `<pubDate>` is RFC-822 | smoke | `grep -oP '<pubDate>\K[^<]+' dist/rss.xml \| grep -cvP '^[A-Z][a-z]{2}, \d{2} [A-Z][a-z]{2} \d{4} ' -eq 0` | ❌ Wave 0 |
| DIST-01 | Feed content carries the two hero images, absolutized | smoke | `test "$(grep -o 'https://[^"]*_astro/[^"]*\.webp' dist/rss.xml \| wc -l)" -eq 2` **and** `! grep -q 'src="/interstellar-website' dist/rss.xml` | ❌ Wave 0 |
| DIST-01 | No second-parse artifacts | smoke | `! grep -qF '__ASTRO_IMAGE_' dist/rss.xml && ! grep -qF '[[' dist/rss.xml` | ❌ Wave 0 |
| DIST-01 | Feed validates clean per W3C | 🧪 **human, once** | paste deployed `/rss.xml` into `validator.w3.org/feed`, require zero errors | n/a |
| DIST-02 | All 86 built pages emit `og:title`, `og:description`, `og:image`, `og:url`, `og:site_name`, `og:type`, `twitter:card`, `theme-color` | smoke | per-file loop over `find dist -name '*.html'`, assert exactly 1 of each (mirrors the existing canonical-coverage loop, `tests/site.smoke.sh:34-52`) | ❌ Wave 0 |
| DIST-02 | `og:image` and `og:url` are absolute and prefix-correct on every page | smoke | extract `content="…"`, assert `case "$V" in "$PREFIX"*)` | ❌ Wave 0 |
| DIST-02 | `og:image` targets a file that actually exists in `dist/` | smoke | strip `$SITE$BASE` from the URL, `test -f "dist/$rel"` — catches a renamed `og-default.png` (UI-SPEC E3 "error" requirement) | ❌ Wave 0 |
| DIST-02 | The 2 hero posts get their own image, the other ~84 pages get `og-default.png` | smoke | count distinct `og:image` values across `dist/**/*.html` == 3 | ❌ Wave 0 |
| DIST-02 | D-48 loud-fail fires | smoke fixture | trap-and-restore: change M0.7's body image path to `../assets/does-not-exist.png`, assert build fails naming both the post id and the path | ❌ Wave 0 |
| DIST-02 | Descriptions are not all identical boilerplate | smoke | `test "$(grep -ohP '<meta name="description" content="\K[^"]+' dist/**/*.html \| sort -u \| wc -l)" -gt 60` | ❌ Wave 0 |
| DIST-02 | `og:title` is not doubled with the site name | smoke | `! grep -q 'og:title" content="[^"]*— Interstellar Engine"' dist/**/*.html` | ❌ Wave 0 |
| DIST-02 | A pasted live URL renders a rich Discord embed | 🧪 **human, backstop** | paste 3 fresh deployed URLs (an M0.7/M0.8 hero post, a deep-dive, a roadmap page) into Discord; confirm large image + title + description + accent border on each | n/a |
| DIST-03 | Every page carries the header Discord link and the footer `RSS · Join the Discord` line | smoke | per-file loop asserting exactly 2 occurrences of the invite URL and 1 of `rss.xml` in the footer `<p>` | ❌ Wave 0 |
| DIST-03 | `<link rel="alternate" type="application/rss+xml">` on every page (D-47) | smoke | per-file loop, exactly 1 | ❌ Wave 0 |
| DIST-03 | D-54 loud-fail fires | smoke fixture | trap-and-restore: blank the invite constant, assert build fails **naming the constant** | ❌ Wave 0 |
| — (regression) | Zero client JS still holds | smoke | already asserted, `tests/site.smoke.sh:78-79` | ✅ exists |
| — (regression) | Page count still 86, sitemap count still 85 | smoke | already asserted, `tests/site.smoke.sh:63-70,120-127` — **stays green**, `/rss.xml` is an endpoint and is excluded from both (verified) | ✅ exists |
| — (regression) | Dead-link sweep covers the new footer RSS link | smoke | already asserted, `tests/site.smoke.sh:83-115` — `href="{base}rss.xml"` resolves to `dist/rss.xml`; the Discord `https://` link is skipped by the existing `http*)` case | ✅ exists |
| — (regression) | No hardcoded host/base under `src/` | smoke | already asserted, `tests/build.smoke.sh:16` | ✅ exists |
| — (unit) | `describeEntry` extraction + D-52 truncation | node assert | add cases to `tests/lib.smoke.mjs` (direct import, matching existing style) | ✅ file exists, cases needed |
| — (unit) | `heroFor` returns null on no-image entries and throws naming the post on unresolvable paths | node assert | add cases to `tests/lib.smoke.mjs` — note the `import.meta.glob` in `hero-image.ts` will not resolve under bare Node, so **factor the pure map-lookup into a separately-importable function** | ✅ file exists, cases needed |

### Sampling Rate

- **Per task commit:** `npm run build` (the three loud-fails are the fast gate)
- **Per wave merge:** `npm test`
- **Phase gate:** `npm test` green + the two human items above, before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `tests/distribution.smoke.sh` — covers DIST-01, DIST-02, DIST-03 build-time assertions
- [ ] New assertion cases appended to `tests/lib.smoke.mjs` — `describeEntry`, `heroFor`
- [ ] `src/lib/hero-image.ts` must expose a pure, glob-free lookup function so
      `tests/lib.smoke.mjs` can import it under bare Node (the `import.meta.glob` call itself
      is Vite-only and cannot be unit-tested outside a build)
- [ ] Framework install: **none** — no test framework by decision

### NOT build-time provable (must be human-verified)

Per the research focus and `03-UI-SPEC.md` § E4, these cannot be faked with a grep:

1. **Success criterion 2 — "pasting a live post or page URL into Discord renders a rich embed
   with title, description, and image."** Requires the *deployed* site and Discord's own
   scraper. `dist/` greps prove the tags exist; they do not prove the embed renders. Use fresh
   URLs (Pitfall 7). Cover both image paths (hero post + default-card page) and the longest
   deep-dive title.
2. **Success criterion 4's W3C leg** — the validator is a network service (Open Question 1).
3. **OG card visual fidelity** — UI-SPEC requires the exported PNG be "eyeballed once against
   the live header." No automated check substitutes for that.

## Security Domain

### Applicable ASVS Categories (Level 1)

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Static site, no accounts |
| V3 Session Management | no | No sessions, no cookies (project constraint) |
| V4 Access Control | no | All content is public by design |
| V5 Input Validation / Output Encoding | **yes** | Two surfaces: (a) meta-tag attribute values — use Astro's built-in `{expr}` attribute escaping, verified to escape `"`→`&quot;` and `&`→`&amp;` (Pitfall 6); (b) feed content HTML — `sanitize-html@2.17.6` with an explicit allow-list |
| V6 Cryptography | no | No secrets, no crypto in scope |
| V14 Configuration | **yes** | `target="_blank"` on the two Discord links **must** carry `rel="noopener noreferrer"` (UI-SPEC already specifies this) — reverse-tabnabbing mitigation |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Attribute-breakout injection via an interpolated `content="…"` value | Tampering | Astro's default attribute escaping (**not** `escapeHtml()`, which leaves `"` alone) — Pitfall 6 |
| Stored XSS via feed content reaching a reader that renders HTML | Tampering / Elevation | `sanitize-html` allow-list; do **not** add `style`, `script`, `iframe`, `on*` handlers to the allow-list |
| Reverse tabnabbing via `target="_blank"` | Tampering | `rel="noopener noreferrer"` (UI-SPEC § Link target behaviour) |
| Open-redirect-ish URL rewriting in the feed | Spoofing | The `transformTags` rewriter only rebases `/`-prefixed values against `context.site`; anything else throws (Code Example 1) |
| Supply chain: two new npm packages | Tampering | Legitimacy audit run (see § Package Legitimacy Audit); both `postinstall: null`; pin exact versions |

**Threat model note:** all content is git-tracked, developer-authored, promoted through a
studio-side pipeline — there is no untrusted user input anywhere in this phase. The controls
above are defense-in-depth against a compromised/mistaken promote, not against an attacker
with a form.

## Sources

### Primary (HIGH confidence — executed against this repo this session)
- `npm run build` + throwaway probe routes in `src/pages/` (created, read, deleted) — proved:
  Container API works in an endpoint; `entry.rendered.html` carries `__ASTRO_IMAGE_`
  placeholders; `entry.assetImports` presence/absence across all 4 collections;
  `import.meta.glob` ImageMetadata `.src`/`.width`/`.height`; both PNG and WebP emitted to
  `dist/_astro/`; Astro attribute escaping behaviour; endpoints excluded from the sitemap
- `getRssString()` executed in an isolated scratch project against the real container-rendered
  HTML of all 9 devlog posts — proved feed shape, `xmlns:content` auto-declaration,
  `guid isPermaLink`, RFC-822 `pubDate`, `atom:link` via `xmlns`+`customData`
- `xmllint --noout` on the generated feed — clean
- `rsvg-convert` / `magick` / `google-chrome --headless` executed on the UI-SPEC composition;
  output PNGs inspected visually and with `identify`
- `npm test` — baseline GREEN (`ALL CHECKS PASSED`)
- Installed package sources read: `node_modules/astro/dist/content/runtime.d.ts`,
  `node_modules/astro/dist/container/index.d.ts`, `node_modules/astro/package.json`,
  `@astrojs/rss@4.0.19` `dist/index.d.ts` (via `npm pack`), `sanitize-html@2.17.6` defaults
- Repo files read: `astro.config.mjs`, `src/content.config.ts`, `src/layouts/BaseLayout.astro`,
  `src/layouts/PostLayout.astro`, `src/lib/*.ts`, `src/styles/global.css`, `public/favicon.svg`,
  `tests/run-all.sh`, `tests/build.smoke.sh`, `tests/site.smoke.sh`, `tests/lib.smoke.mjs`,
  `.github/workflows/`, `devlog/*.md`, `pages/*.md`, `roadmap/*.md`, sampled `technical/**`
- `npm view` for `@astrojs/rss`, `sanitize-html`, `markdown-it` versions and metadata
- `gsd-tools query package-legitimacy check` and `query classify-confidence`

### Secondary (MEDIUM confidence — official documentation)
- `docs.astro.build/en/recipes/rss/` — fetched this session; source of the `markdown-it`
  recipe that Pitfall 1 rejects, and of the `sanitize-html` `allowedTags.concat(['img'])` config

### Tertiary (LOW confidence — WebSearch/WebFetch, per `classify-confidence --provider websearch`)
- `opengraphplus.com/consumers/discord/tags` — Discord tag support, image layout hints,
  `theme-color` behaviour, character limits
- WebSearch: "Discord link embed OpenGraph tags supported…" (8 results, cross-checked ≥3),
  "RSS feed validator command line offline…" (10 results)

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — versions from the registry this session; the one non-obvious choice
  (Container API over `markdown-it`) was proven by execution, not argument
- Architecture: **HIGH** — every pattern was run against this repo's real build
- Hero-image resolution (the flagged high-uncertainty item): **HIGH** — `assetImports` presence
  verified across all 75 entries in all 4 collections; emitted asset URLs read from `dist/`
- Discord tag semantics: **LOW–MEDIUM** — no first-party Discord documentation for link embeds
  exists; consolidated from third-party references and cross-checked. This is why UI-SPEC
  correctly marks the embed itself as a human-verified backstop.
- Feed validation strategy: **MEDIUM** — the offline half is verified; the "validates clean"
  definition needs the developer's sign-off (Open Question 1)
- Pitfalls: **HIGH** — 6 of 8 were reproduced or measured directly this session

**Research date:** 2026-07-22
**Valid until:** 2026-08-21 (30 days — Astro minor releases could move the Container API's
`experimental_` prefix; everything else is stable)

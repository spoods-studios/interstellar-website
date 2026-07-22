# Phase 3: RSS, OpenGraph & Discord Distribution - Context

**Gathered:** 2026-07-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Shared links produce rich Discord embeds, readers can subscribe by RSS, and
every page routes to Discord — the three pieces that make the Discord-first
distribution strategy (D-F) actually work. Covers DIST-01 (RSS), DIST-02
(OpenGraph/Twitter Card), DIST-03 (Discord CTA).

This phase adds **distribution metadata and one new route**; it does not
change how any content renders. The four content trees (`devlog/`,
`technical/`, `roadmap/`, `pages/`) stay read-only promote drop targets, and
D-14's "body renders untouched" is unaffected — everything here is `<head>`
metadata, site chrome, and a build-time feed endpoint.

Phase 2 left three explicit insertion points for this phase, all of them in
`src/layouts/BaseLayout.astro`: the header nav slot (D-17), the footer slot
beside copyright (D-18), and the `<head>` (D-50 fills it).

Analytics, the M1.1 launch post, slug-immutability/redirect stubs, and
post-deploy smoke checks are Phase 4.

</domain>

<decisions>
## Implementation Decisions

Numbering continues from Phase 2 (which ended at D-44).

### RSS
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

### OpenGraph / Twitter Card
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

### Embed descriptions
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

### Discord CTA
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
  **Consequence the planner must handle:** with the constant unset,
  `astro build` fails, so Phase 3 cannot execute to green until a real URL
  exists. See D-55.
- **D-55:** The permanent invite is **created in-session by driving the headed
  Playwright browser against the user's own Discord server** (never expires,
  unlimited uses), and the resulting URL is baked in as the locked value.
  **Status at context-write time: BLOCKED — Discord is not logged in on the
  Playwright browser** (`https://discord.com/login`), which is a user-only
  interactive step. The URL is the one open slot in this context.
  **Planner fallback:** if the URL is still absent when planning runs,
  front-load a `checkpoint:decision` task that obtains it before any task
  that depends on it, rather than letting a mid-phase build failure surface
  it. — **Reversibility:** one-way — a published invite URL that later
  changes leaves every shared link and vault reference pointing at a dead
  invite; the permanent/unlimited settings must be right the first time.
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase ground truth
- `.planning/ROADMAP.md` — Phase 3's four success criteria (the TRUE statements)
- `.planning/REQUIREMENTS.md` — DIST-01, DIST-02, DIST-03 definitions
- `.planning/PROJECT.md` — constraints: quiet content-first, D-G no generative
  imagery, privacy, "must not become the long pole"
- `.planning/phases/02-content-rendering-templating/02-CONTEXT.md` — D-11–D-44,
  especially **D-13** (homepage is the archive), **D-14** (body untouched),
  **D-17** (header nav + reserved Discord slot), **D-18** (footer + reserved
  RSS slot), **D-21/D-22/D-23** (system fonts, light-only, hand-written CSS),
  **D-29** (`hero_visual` ignored — amended by D-48), **D-31** (separate
  collections make feed scope a clean choice)
- `.planning/phases/01-stack-scaffolding/01-CONTEXT.md` — D-01–D-10, the
  loud-fail-over-silent-skip norm D-54 extends

### Studio decisions
- `../studio/vault/decisions/Decision Log.md` — **[D-F]** (Discord-first
  audience building; the server already exists and the "add when created"
  invite line is stale, not the server), **[D-G]** (AI transparency, no
  generative imagery — binds D-49), **[D-H]** (website is the devblog home at
  M1.1), **[D-K]** (hero visuals are real engine output — binds D-48),
  **[D-N]** (Discord restructure: #announcements, #technical-devlog,
  #roadmap)

### Discord specifics
- `../studio/vault/community/Discord Architecture.md` — server/channel
  structure; line 9 is the `**Invite link:**` slot D-56 fills
- `../studio/vault/community/Handles Secured.md` — line 7 is the second
  `(add invite link)` slot D-56 fills
- `../studio/vault/community/Phase 0 Launch Checklist.md` — line 15 is the
  open "record the permanent invite link" item D-56 closes
- `../studio/vault/community/Discord Launch Copy.md` — existing Discord-facing
  copy; useful register reference if the CTA needs wording beyond "Discord"

### Astro / implementation
- `docs.astro.build/en/guides/rss/` — official RSS guide (`@astrojs/rss`,
  `content:encoded` + `sanitize-html` pattern, `getCollection()` sourcing)
- `astro.config.mjs` — `site` + `base` are the single URL source (SITE-02);
  `validateContentLoudFail()` at the bottom is the existing precedent for a
  config-load-time hard failure

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/layouts/BaseLayout.astro:9` — already takes an optional `description`
  prop and renders `<meta name="description">` at `:24`. D-51's extracted
  value flows into the existing prop; OG/Twitter tags join it at `:20-27`.
- `src/layouts/BaseLayout.astro:15-16` — the `BASE_URL` trailing-slash
  normalization every route already relies on; the RSS link, CTA hrefs, and
  absolute `og:url`/`og:image` all need it.
- `src/layouts/BaseLayout.astro:11` — `canonicalUrl` already builds an
  absolute URL from `Astro.url.pathname` + `Astro.site`; the same expression
  is what `og:url` needs.
- `src/layouts/BaseLayout.astro:29-37` header (D-17's Discord slot) and
  `:41-43` footer (D-18's RSS slot) — both CTA placements land here.
- `src/lib/content-guards.ts` — the `isVisible` filter already applied at
  every collection query site; D-45's feed query must use it too or the feed
  and the archive drift on the first `status: draft` post.
- `src/lib/devlog-meta.ts`, `src/lib/title-from-h1.ts` — existing
  title/date-fallback helpers; the description extractor (D-51) is the same
  family of body-derived helper and belongs beside them.
- `src/lib/escape-html.ts` — existing escaping helper; OG/meta attribute
  values need the same treatment.

### Established Patterns
- **Loud-fail over silent skip** — `content.config.ts:19-24,50-55,76-78`
  (filename violations) and `astro.config.mjs`'s `validateContentLoudFail()`
  (unresolvable wikilinks/deep-dive placeholders, run at config-load time so
  the glob loader's per-entry `try/catch` can't swallow it). D-48 and D-54
  extend this pattern; the config-load-time trick is the proven way to make a
  failure actually stop the build.
- **`set:html` for git-trusted content** with explicit escaping for anything
  interpolated into markup (02 code review findings WR-01/WR-02).
- **Read-only promote drop targets** — `devlog/`, `technical/`, `roadmap/`,
  `pages/` are never hand-edited in this repo. This is why D-51 extracts
  rather than adding frontmatter.
- **Build smoke tests** — `tests/build.smoke.sh`, `tests/shell.smoke.sh`,
  `tests/lib.smoke.mjs`, run via `npm test` → `tests/run-all.sh`. Grep-based
  assertions against `dist/` output; note `grep -c` counts *lines*, so
  `grep -o | wc -l` is the correct idiom for counting occurrences in Astro's
  minified single-line HTML (02-01 finding).

### Integration Points
- `@astrojs/rss` is **not installed** — `package.json` carries astro@^7.0.9,
  @astrojs/sitemap@^3.7.3, satteri@^0.9.5 only. D-46's sanitizer is a second
  new dependency.
- `@astrojs/sitemap` is already wired in `astro.config.mjs` `integrations` —
  the new `/rss.xml` route should appear in the sitemap for free; worth an
  assertion.
- The deploy pipeline (Phase 1) rebuilds on every push to main, so D-54's
  hard failure is also a **deploy-blocking** failure — correct, but it means
  the invite constant must be set before the phase's work merges.
- Phase 4 builds on this: analytics script into the same `<head>`, the M1.1
  launch post entering the same feed query, and CONT-06's redirect stubs now
  covering three URL trees.

</code_context>

<specifics>
## Specific Ideas

- "Boring is correct" continues to hold: no button styling, no icon assets,
  no client JS, no generated imagery. The only new visual artifact in the
  whole phase is one hand-authored wordmark card (D-49).
- Everything user-visible added here is **site chrome around the body, never
  inside it** — two link texts and a `<head>` block. D-14 is untouched.
- The feed is the *archive's* feed, not the *site's* feed. Someone who
  subscribes is subscribing to the 9 announcements, the same thing the
  homepage shows them.
- Discord embeds are the highest-leverage surface in the phase: per [D-N] the
  #technical-devlog forum is where deep-dive links get pasted, which is why
  D-50 covers all ~75 pages rather than just the announcements.
- The invite link is genuinely blocking, not paperwork — DIST-03's success
  criterion cannot be verified without a working link, and D-54 makes the
  build enforce that rather than letting it slip to launch day.

</specifics>

<deferred>
## Deferred Ideas

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

</deferred>

---

*Phase: 3-RSS, OpenGraph & Discord Distribution*
*Context gathered: 2026-07-22*

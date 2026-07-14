# Phase 2: Content Rendering & Templating - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

The full devblog archive (index + individual post pages) and both standalone
pages ("How It's Made", Roadmap) render as readable, mobile-friendly pages with
baseline polish — VOICE.md prose untouched by the site layer. Covers CONT-02
(full archive: manifesto + M0.1–M0.8), CONT-03 (How It's Made standalone,
never in archive), CONT-04 (Roadmap standalone), SITE-04 (mobile-responsive,
custom 404, favicon, canonical URLs, sitemap.xml). RSS/OpenGraph/Discord CTA
are Phase 3; analytics, launch post, and deploy hardening are Phase 4.

Phase 1's throwaway `src/pages/index.astro` is replaced wholesale; the content
schema and glob loader in `src/content.config.ts` carry forward.

</domain>

<decisions>
## Implementation Decisions

### Archive index & post pages
- **D-11:** Archive entry format: title + date + milestone tag (from
  frontmatter, e.g. "M0.3"). Manifesto has no milestone — renders plain
  without one.
- **D-12:** Flat reverse-chronological list (newest first). No grouping —
  ~9 posts at launch. Manifesto sits naturally at the bottom as oldest.
- **D-13:** The homepage IS the archive — `/` lists posts directly; no
  separate landing page. Post URLs: `/devlog/YYYY-MM-DD-slug/`.
- **D-14:** Post pages render the Markdown body untouched (body `# H1` is the
  title — promoted posts carry it in both frontmatter and body; manifesto in
  body only). Site adds only a small date + milestone meta line. No
  site-generated title header, no H1 dedup logic — protects the
  "rendered text matches source exactly" criterion.
- **D-15:** Post bottom nav: prev/next links by date plus a back-to-archive
  link — supports reading the M0.x series in order.
- **D-16:** Homepage top matter: ONE quiet sentence describing the project
  (VOICE register, no hype) above the post list. Exact wording gets user
  approval at plan review.

### Site chrome & navigation
- **D-17:** Header on every page: "Interstellar Engine" wordmark (links home)
  + nav links Devblog / How It's Made / Roadmap. The Discord CTA slots into
  this header in Phase 3 — no placeholder now.
- **D-18:** Footer: minimal — copyright (Spoods Studios) + a spot where the
  RSS link lands in Phase 3.
- **D-19:** Custom 404: short "page not found" note + link home, wearing the
  same chrome as every other page. (Phase 4's redirect-stub story lands dead
  Discord links here.)
- **D-20:** Standalone pages use the same layout as posts; their meta line
  shows "Last updated: YYYY-MM-DD" (from `updated:` frontmatter) instead of
  date + milestone.

### Visual baseline
- **D-21:** System font stack — zero webfonts, zero external requests.
- **D-22:** Light-only color scheme: near-white background, near-black text,
  one restrained link accent. Dark mode stays v2 (SITE-05, paired with syntax
  themes).
- **D-23:** Hand-written minimal CSS — reading measure (~65ch), spacing, link
  accent, responsive rules. No CSS framework or classless base.
- **D-24:** Favicon: hand-authored text/letterform SVG ("IE"-style glyph) —
  trivially D-G-clean (no generative imagery), swappable later for an engine
  capture.

### Content sourcing
- **D-25:** M0.1–M0.8 posts are promoted into `devlog/` IN-PHASE via the
  studio-side draft→promote pipeline (not manual copies) — the archive builds
  against real content and success criterion 1 holds at phase end.
- **D-26:** Standalone page content lives in a NEW `pages/` directory at repo
  root — a second read-only promote drop target with the exact same contract
  as `devlog/`. `how-its-made.md` and `roadmap.md` are promoted into it via
  the same studio flow, not authored in-repo.
- **D-27:** Roadmap page source of truth: a `pages/roadmap.md` transcribed
  from the Discord #roadmap pinned overview
  (`../studio/vault/community/roadmap-backfill.discord.txt` as reference) —
  NOT the internal `../studio/vault/project/Roadmap.md`. Updated manually when
  the Discord pin changes.
- **D-28:** Post images: the promote flow lands referenced images in
  `devlog/assets/` alongside the posts; the site serves them as static files
  so relative `assets/*.png` paths in the `.md` bodies resolve unchanged —
  body text stays byte-identical. (M0.7 and M0.8 embed images.)
- **D-29:** `hero_visual` frontmatter is IGNORED in v1 — it's a
  drafting-pipeline note with mixed path/prose/TBD values, not
  machine-reliable. Field stays in the schema for later use (e.g. Phase 3 OG
  images). Bodies already embed their images where the prose wants them.
- **D-30:** The `pages/` collection honors `status: draft` exactly like
  `devlog/` (draft = not rendered). The in-phase promote step flips
  `how-its-made.md` to `published`, so criterion 3 holds by phase end.

### Claude's Discretion
- Sitemap/canonical mechanics (`@astrojs/sitemap` vs hand-rolled), exact
  responsive breakpoints, link accent color choice, meta-line placement
  relative to the body H1 — planner/executor's call within the decisions
  above.
- Exact `pages/` collection loader config (mirror the devlog glob loader;
  filename convention for standalone pages need not carry dates).
- How the promote step is sequenced inside the phase (which plan/wave) —
  note it is cross-repo work touching `../studio/vault/devlog/drafts/`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Content contract
- `devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md` — the
  frontmatter-less manifesto (title in body H1 only); must render via
  filename fallback, untouched
- `../studio/vault/devlog/_TEMPLATE.md` — full frontmatter field set promoted
  posts carry (note: real drafts also carry `published_date`, absent from the
  template — Zod strips unknown keys, but planner should confirm)
- `../studio/vault/devlog/drafts/` — the M0.1–M0.8 drafts + `how-its-made.md`
  to be promoted in-phase (`.discord.txt` siblings are NOT posts — promote
  flow must exclude them)
- `../studio/vault/devlog/VOICE.md` — locked voice; the site renders, never
  restyles
- `../studio/vault/community/roadmap-backfill.discord.txt` — reference text
  for the Roadmap page (D-27)

### Project ground truth
- `.planning/PROJECT.md` — constraints (quiet content-first, D-G no
  generative imagery, privacy, timeline)
- `.planning/REQUIREMENTS.md` — CONT-02, CONT-03, CONT-04, SITE-04 definitions
- `.planning/ROADMAP.md` — Phase 2 success criteria (the four TRUE statements)
- `.planning/phases/01-stack-scaffolding/01-CONTEXT.md` — carried-forward
  decisions D-01–D-10 (filename fallback, never edit `devlog/`, loud-fail)
- `CLAUDE.md` (repo root) — `devlog/` untouchability rule

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/content.config.ts` — devlog collection with permissive all-optional
  schema, filename-fallback `generateId`, loud-fail on unparseable filenames
  (D-10), `_TEMPLATE.md` exclusion. The `pages/` collection mirrors this
  pattern (minus the date-filename requirement).
- Title/date fallback logic in `src/pages/index.astro` (H1 regex, filename
  date) — extract into a shared helper; the throwaway page itself is replaced.
- Draft filtering (`status !== 'draft'`) already established in index.astro.

### Established Patterns
- `devlog/` is a read-only promote drop target — Phase 2 extends the same
  contract to `pages/` and `devlog/assets/`.
- Zero-entry collection assert (loud-fail on misconfigured loader base) —
  keep when restructuring pages.
- `set:html` used for titles (git-trusted content, avoids apostrophe
  escaping) — same reasoning applies to new templates.

### Integration Points
- Deploy pipeline (Phase 1) rebuilds on every push to main — promoted content
  goes live automatically once merged.
- Phase 3 hangs off this phase: RSS from the same devlog collection query;
  Discord CTA into the header slot (D-17); OG metadata into the shared layout
  head. Build the base layout with those insertion points in mind.

</code_context>

<specifics>
## Specific Ideas

- "Boring is correct" carries through: system fonts, light-only, hand-written
  CSS, no framework.
- The site is a quiet reading surface for locked VOICE prose — every
  decision biased toward "add nothing between reader and text".
- Homepage one-liner needs user sign-off on exact wording (D-16).

</specifics>

<deferred>
## Deferred Ideas

- Dark mode / prefers-color-scheme — v2 (SITE-05), explicitly kept out of
  this phase's CSS.
- hero_visual rendering (post header images / OG image source) — revisit in
  Phase 3 (OG) or v2; field already in schema.
- Syntax highlighting + KaTeX — v2 (CONT-07).
- Search / tags — v2 (CONT-08), no payoff at ~9 posts.

</deferred>

---

*Phase: 2-Content Rendering & Templating*
*Context gathered: 2026-07-14*

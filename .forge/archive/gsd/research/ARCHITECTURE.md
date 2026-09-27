# Architecture Research

**Domain:** Markdown-sourced static devblog site with an externally-fed content pipeline
**Researched:** 2026-07-13
**Confidence:** MEDIUM (repo-state claims HIGH — read directly this session; generic SSG architecture claims MEDIUM — cross-checked via web search against Astro's own docs and community SSG-building writeups)

## Grounded Repo Facts (read this session — HIGH confidence)

These are not "typical" claims — they are the actual current state of this repo and its
upstream source, and they directly constrain the architecture:

- `interstellar-website/devlog/` currently holds exactly one file:
  `2026-04-07-why-im-building-a-hyperrealistic-space-sim.md` — **no YAML frontmatter**, just
  an H1 title followed by prose.
  (`/home/spoods/Projects/spoods-studios/interstellar-website/devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md:1`)
- The studio-side source of truth is `studio/vault/devlog/drafts/*.md`. Of the 10 drafts
  there, **9 have full YAML frontmatter** (`milestone`, `title`, `date`, `status`,
  `discord_post_id`, `audience`, `hero_visual`) per the locked template — **`manifesto.md` is
  the one exception**, plain H1 with no frontmatter.
  (`studio/vault/devlog/_TEMPLATE.md:1-9`; `studio/vault/devlog/drafts/manifesto.md:1`)
- The promoted file in `interstellar-website/devlog/` matches the frontmatter-less shape of
  `manifesto.md` exactly — **this confirms the one promotion that has happened so far carried
  the source file's shape through unchanged.** No frontmatter was stripped or added; it's a
  straight copy. Git log confirms a single manual commit (`ee0d40f`, author `jushyi`, direct —
  not agent-authored) added it.
- **There is no automated promote script.** `draft-devblog` (`~/.claude/skills/draft-devblog/SKILL.md:11-12,45-51`)
  explicitly stops at writing the draft into `studio/vault/devlog/drafts/` — "publishing is a
  human step, surfaced at curate-accept and never run by this skill." The
  studio→website hop for the remaining 8 milestone drafts + `how-its-made.md` is **manual
  copy**, not yet executed.
- **Consequence for the SSG's content schema:** the collection MUST tolerate two shapes —
  frontmatter-full posts (the 8 pending M0.1–M0.8 drafts, once promoted) and one
  frontmatter-less post (the manifesto, already live). Filenames uniformly follow
  `YYYY-MM-DD-slug.md`, so date + slug can always be derived from the filename as a fallback
  when frontmatter is absent or partial — this is the load-bearing design choice, not a nice-to-have.
- `how-its-made.md` (`studio/vault/devlog/drafts/how-its-made.md:1-2`) is explicitly scoped
  as **"publishes to interstellar-website as a permanent page at M1.1 close"** — i.e. it is
  NOT a devlog post. It needs its own standalone-page route, separate from the post
  collection, even though it originates from the same studio vault and travels the same
  manual promote hop.
- Roadmap page content lives outside any `.md` file today — PROJECT.md says it "mirrors the
  Discord #roadmap pinned overview," meaning at launch it is authored directly in this repo
  (not sourced from the studio vault promote flow) unless a future decision routes it through
  the same pipeline.

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│  UPSTREAM (studio repo — outside this repo, human-in-the-loop)        │
│  studio/vault/devlog/drafts/*.md  (frontmatter + VOICE.md canon)      │
│  studio/vault/devlog/drafts/how-its-made.md (standalone page source)  │
└───────────────────────────┬────────────────────────────────────────--┘
                             │ MANUAL copy (git mv/cp + commit, no script today)
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│  CONTENT SOURCE (this repo, source of truth for the LIVE site)        │
│  ┌────────────────┐   ┌───────────────────┐                          │
│  │ devlog/*.md     │   │ pages/*.md or      │  ← standalone pages     │
│  │ (post collection)│   │ src/content/*.md  │    (how-its-made,       │
│  └────────┬────────┘   └─────────┬─────────┘     roadmap)            │
└───────────┼──────────────────────┼──────────────────────────────────┘
            │                      │
            ▼                      ▼
┌──────────────────────────────────────────────────────────────────────┐
│  BUILD (SSG — Astro/Eleventy/Hugo class tool, decided in STACK.md)     │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐               │
│  │ Content       │  │ Layouts /     │  │ RSS generator │               │
│  │ collection /  │→│ templates     │→│ (feed.xml)    │               │
│  │ frontmatter   │  │ (post, page,  │  └───────────────┘               │
│  │ parser        │  │ archive,      │                                │
│  │ (schema =     │  │ roadmap)      │                                │
│  │ filename-      │  └──────────────┘                                │
│  │ fallback)     │                                                    │
│  └──────────────┘                                                    │
└───────────────────────────┬────────────────────────────────────────--┘
                             │ static build output (HTML/CSS/JS/XML)
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│  CI/CD (GitHub Actions)                                               │
│  push to main → build job → upload-pages-artifact → deploy-pages      │
└───────────────────────────┬────────────────────────────────────────--┘
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│  GitHub Pages (hosting) + client-side privacy analytics embed          │
│  (Plausible/GoatCounter script tag — no server component in this repo) │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Content source (`devlog/*.md`) | Canonical post files, one per milestone, landed by the studio promote hop | Plain Markdown + YAML frontmatter, `YYYY-MM-DD-slug.md` naming |
| Standalone page source | Non-post pages that also originate as vault drafts (`how-its-made`) or are authored in-repo (`roadmap`) | Markdown or framework-native page files, kept OUT of the post collection so they don't appear in the archive/RSS |
| Content collection / schema layer | Parses frontmatter, validates required fields, supplies filename-derived fallbacks (date, slug) when frontmatter is partial/absent | Astro Content Collections `zod` schema with `.optional()` fields + a loader that derives `date`/`slug` from filename; or Eleventy front matter + computed data; or Hugo archetypes with lenient front matter |
| Layouts/templates | Render post, standalone page, archive/index, and roadmap views from the same design system | Component-based templates (`.astro`/`.njk`/`.html` per SSG) sharing a base layout + VOICE-locked typography |
| RSS generator | Emits a spec-valid `feed.xml` from the post collection only (excludes standalone pages) | SSG-native RSS integration (`@astrojs/rss`, `eleventy-plugin-rss`, Hugo's built-in `index.xml`) driven off the same collection query used for the archive page |
| Build pipeline (GitHub Actions) | Installs deps, runs the SSG build, uploads the `dist/` artifact, deploys to Pages | `actions/checkout` → `actions/setup-node` (or SSG-specific action, e.g. `withastro/action`) → build → `actions/upload-pages-artifact` → `actions/deploy-pages` |
| Hosting (GitHub Pages) | Serves the static build output; no server-side logic ever runs here | GitHub Pages "Deploy from GitHub Actions" source mode (not the legacy branch-based `gh-pages` mode) |
| Analytics embed | Client-side pageview counting, no cookies | A single `<script>` tag (Plausible or GoatCounter) added to the base layout — decided in STACK.md, zero build-time coupling |

## Recommended Project Structure

```
interstellar-website/
├── devlog/                      # SOURCE OF TRUTH — untouched by build tooling's
│   │                             #   naming/location; promote pipeline keeps writing here
│   ├── 2026-04-07-why-im-building-a-hyperrealistic-space-sim.md   # manifesto (no frontmatter)
│   ├── 2026-0X-XX-m0.1-*.md     # future promotions land here, same flat dir, same naming
│   └── ...
├── pages/                       # NEW — standalone, non-post content (how-its-made, roadmap)
│   ├── how-its-made.md          # promoted from studio drafts, same manual hop as devlog/
│   └── roadmap.md               # authored in-repo (mirrors Discord #roadmap pin)
├── src/                         # SSG app code — everything the build compiles
│   ├── content/                 # SSG content-collection config only (schema), NOT the posts
│   │   └── config.ts            # points the collection loader at ../../devlog and ../../pages
│   ├── layouts/                 # BaseLayout, PostLayout, PageLayout
│   ├── components/               # Header, Footer, DiscordCTA, HeroVisual, etc.
│   └── pages/                   # route files: index, devlog archive, [slug], roadmap, how-its-made
├── public/                      # static assets (favicon, og-image, hero visuals if not co-located)
├── .github/workflows/deploy.yml # build+deploy on push to main
├── astro.config.mjs             # (or eleventy.config.js / hugo.toml — SSG-specific)
└── .planning/                   # GSD — not part of the built site
```

### Structure Rationale

- **`devlog/` stays exactly where it is, flat, untouched.** This is the hard constraint from
  PROJECT.md ("devlog `.md` files remain the source of truth... promote pipeline keeps
  landing them in `devlog/`") and it is corroborated by the grounded repo facts above — moving
  or renaming this directory breaks the one working half of the pipeline (studio → website)
  for zero benefit. The SSG's content-collection config reaches INTO `devlog/` from `src/`
  rather than requiring content to live under `src/content/`. Every SSG in this class (Astro,
  Eleventy, Hugo) supports pointing a collection/glob loader at an arbitrary path outside the
  conventional content folder — this is a config-level decision, not a file-move.
- **`pages/` is a new sibling directory, not a subfolder of `devlog/`.** `how-its-made.md` is
  explicitly NOT a devlog post (no milestone number, permanent page, excluded from the
  archive/RSS) — collapsing it into `devlog/` would either pollute the archive listing or
  require a frontmatter flag (`type: page`) to filter it back out at every render call site.
  A separate directory makes the "is this a post or a page" boundary structural instead of
  convention-based, and it gives the studio promote flow (or a future automated version of it)
  an unambiguous drop target for non-post content.
- **`src/content/config.ts` (or equivalent) is a thin pointer + schema, not a content copy.**
  It defines the Zod/frontmatter schema with every post field OPTIONAL except what the
  filename can't supply (title needs frontmatter or an H1-derived fallback; date/slug can
  always come from the `YYYY-MM-DD-slug.md` filename). This directly resolves the
  frontmatter-inconsistency finding above without requiring a backfill of the manifesto file
  or a rewrite of the promote flow before launch.
- **`src/pages/` (route files) is separate from top-level `pages/` (content).** This is
  SSG-specific naming overlap to watch for — in Astro, `src/pages/` is the router; content
  markdown does not belong there directly. Naming the content directory `pages/` at repo root
  (sibling to `devlog/`) avoids colliding with framework routing conventions while keeping the
  "these are permanent standalone pages" naming intuitive for the human doing the promote hop.

## Architectural Patterns

### Pattern 1: Filename-derived fallback schema

**What:** The content-collection schema treats `date` and `slug` as always-derivable from the
`YYYY-MM-DD-slug.md` filename (already the convention in both `devlog/` and studio's
`drafts/`), and treats every other frontmatter field (`title`, `milestone`, `status`,
`hero_visual`, `discord_post_id`) as optional with a sane fallback (e.g. `title` falls back to
the first `# H1` line in the body if frontmatter is absent).
**When to use:** Any time content arrives from an external, only-partially-controlled pipeline
where you cannot guarantee every file has full frontmatter — exactly this repo's situation
(manifesto has none, 8 pending posts have full frontmatter, `how-its-made.md` has a slightly
different field set again).
**Trade-offs:** Slightly more schema code up front (write the fallback logic once); in
exchange, the promote hop never has to be "fixed" before content can render, and a future
backfill of the manifesto's frontmatter is a nice-to-have, not a blocker.

**Example (Astro Content Collections, illustrative):**
```typescript
// src/content/config.ts
import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

const devlog = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "../../devlog" }),
  schema: ({ image }) => z.object({
    title: z.string().optional(),      // fallback: first H1 in body
    milestone: z.string().optional(),
    status: z.enum(["draft", "published"]).optional().default("published"),
    date: z.coerce.date().optional(),  // fallback: parsed from filename prefix
    hero_visual: z.string().optional(),
    audience: z.string().optional(),
  }),
});
```

### Pattern 2: One-way content mirror, never a build-time fetch

**What:** The studio vault (`../studio/vault/devlog/drafts/`) is never read at build time —
content crosses the repo boundary exactly once, via the manual promote commit into
`devlog/`. The SSG only ever reads from within `interstellar-website`.
**When to use:** Always, for this project — the studio vault is a private ops vault with
drafts, session logs, and unrelated content; it must not become a build dependency (no network
fetch, no submodule, no cross-repo CI trigger).
**Trade-offs:** Requires the human promote step to stay a deliberate, reviewed action (good —
matches the VOICE.md "human reviews + promotes" gate already in place); means the SSG can never
"self-update" from studio-side edits without a new commit to this repo, which is the intended
publish gate, not a limitation.

### Pattern 3: Collection-driven RSS, page-driven standalone routes

**What:** RSS generation queries the SAME `devlog` collection object that drives the archive
listing and the `[slug]` post route — never a hand-maintained separate list. Standalone pages
(`how-its-made`, `roadmap`) are excluded from that collection entirely (Pattern 1's boundary)
so they can never leak into the feed by accident.
**When to use:** Any blog-shaped static site with more than one thing being called "content."
**Trade-offs:** None significant — this is strictly safer than a second list to keep in sync,
and it's the default pattern in every mainstream SSG's RSS integration (`@astrojs/rss` takes a
collection query directly; Eleventy's RSS plugin does the same off a collection; Hugo's
built-in RSS template iterates `.Pages` scoped by section).

## Data Flow

### Content-to-page flow

```
studio/vault/devlog/drafts/m0.X-*.md   (frontmatter + VOICE.md canon, human-drafted)
    │  MANUAL promote (git mv/cp + commit) — no script exists today
    ▼
interstellar-website/devlog/YYYY-MM-DD-slug.md
    │  read at BUILD time only (never runtime — this is a static site)
    ▼
SSG content-collection loader → schema validation (fallbacks applied) → parsed entry list
    │                                                            │
    ▼                                                            ▼
Post route template ([slug].astro)                    Archive/index template
    │                                                            │
    ▼                                                            ▼
Static HTML per post                                   Static HTML archive page
    │                                                            │
    └──────────────────────┬─────────────────────────────────────┘
                            ▼
                   Same collection object → RSS integration → feed.xml
```

### Standalone-page flow (roadmap, how-its-made)

```
pages/how-its-made.md (promoted from studio, same manual hop)
pages/roadmap.md (authored directly in this repo)
    ▼
Page-specific route/template (not the post [slug] route, not in the RSS query)
    ▼
Static HTML — linked from nav, never appears in the devlog archive/RSS
```

### Deploy flow

```
git push to main (post or page content, or code change)
    ▼
GitHub Actions workflow triggers (on: push: branches: [main])
    ▼
checkout → setup toolchain → npm/pnpm install → SSG build → dist/ output
    ▼
actions/upload-pages-artifact (uploads dist/)
    ▼
actions/deploy-pages (publishes to GitHub Pages "Deploy from GitHub Actions" source)
    ▼
Live at https://spoods-studios.github.io/interstellar-website/ (or custom domain, later)
```

### Key data flows

1. **Studio → repo (content authorship):** One-directional, human-gated, git-commit granularity. No build-time coupling to the studio repo. This is the flow PROJECT.md requires to "keep working" — nothing in the SSG choice should require reshaping `devlog/`'s location or naming.
2. **Repo → live site (build/deploy):** One-directional, triggered by any push to `main` that touches content or code. Build order matters here — content-collection parsing must complete and validate BEFORE templates render, which must complete BEFORE RSS generation runs (RSS reads the same parsed collection), which must all complete before the Actions workflow uploads the artifact.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Launch (~9 posts + 2 pages) | Current design as-is; full static rebuild on every push is instant at this size (sub-second to a few seconds SSG build time) |
| 1-2 years of devlog (~30-50 posts) | No architecture change needed — flat `devlog/` dir with filename-sorted date scales fine for hundreds of files; consider pagination on the archive page for UX, not performance |
| Multi-hundred posts / assets-heavy | Only if hero visuals move to Git LFS or a CDN would this need a second look — out of scope pre-EA; PROJECT.md already excludes heavy asset pipelines from this repo (assets live in `setare-assets/`, dormant) |

### Scaling Priorities

1. **First "bottleneck" (not really a bottleneck at this scale):** Human promote-step friction, not compute — 8 posts are already drafted and waiting on a manual copy step. This is a process gap, not an architecture gap; worth flagging for the roadmap as a candidate for a small promote script (studio-side, out of this repo's scope) once the manual pattern is proven a few times.
2. **Second:** Hero-visual asset weight if devlog posts start embedding large images/video inline — GitHub Pages has repo size practicalities (soft ~1GB guidance) well before post count becomes an issue; not a near-term concern given the current text-first VOICE.md format.

## Anti-Patterns

### Anti-Pattern 1: Moving or renaming `devlog/` to fit the SSG's default content folder

**What people do:** Pick an SSG, then reorganize the repo to match its README's "put your
posts in `src/content/blog/`" convention, migrating `devlog/*.md` in the process.
**Why it's wrong:** Breaks the promote pipeline's fixed drop target (PROJECT.md is explicit:
"devlog `.md` files remain the source of truth... promote pipeline keeps landing them in
`devlog/`"). Every SSG in this class supports pointing its loader at a non-default path — there
is no functional reason to move the directory, only a convention-following one, and the
convention loses to the constraint here.
**Do this instead:** Configure the collection loader's `base`/glob path to point at `devlog/`
in place. If a migration ever becomes unavoidable (e.g. an SSG with a truly hardcoded content
path), document it as an explicit decision with the promote-pipeline update it requires — never
silently.

### Anti-Pattern 2: Requiring full frontmatter before content can render

**What people do:** Write a strict schema (all fields required) because "the template" defines
frontmatter that way, then the build breaks the moment a file doesn't match (as the manifesto
already doesn't).
**Why it's wrong:** The one piece of live content in this repo today would fail that schema
immediately. The studio-side promote flow is manual and human-paced — mandating perfect
frontmatter compliance before every promotion adds a blocking review step this project doesn't
have resourcing for (T3 gate tier, solo dev).
**Do this instead:** Pattern 1 (filename-derived fallback schema) — make the schema permissive
by design, matching what's actually landing in the directory.

### Anti-Pattern 3: Treating `how-its-made.md` / `roadmap.md` as devlog posts with a "type" flag

**What people do:** Add a `type: page` frontmatter field to standalone content and filter it
out of the archive/RSS query at every call site.
**Why it's wrong:** Every new "not actually a post" file requires remembering to add the flag
AND every archive/RSS query must remember to filter it. One missed filter leaks a standalone
page into the feed.
**Do this instead:** Pattern 3 — separate directory (`pages/`), separate collection, so the
boundary is structural (can't be forgotten) rather than a filter condition (can be forgotten).

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| GitHub Pages | GitHub Actions "Deploy from GitHub Actions" source (not legacy `gh-pages` branch) | Requires repo Settings → Pages → Source = GitHub Actions, set once; workflow needs `pages: write` + `id-token: write` permissions |
| Discord | Outbound only — this site is linked FROM Discord #devlog posts, and links TO Discord via a CTA button; no API integration needed for launch | `discord_post_id` frontmatter field (present in studio drafts) is for the studio side's own tracking, not consumed by the site build |
| Privacy analytics (Plausible/GoatCounter class) | Client-side `<script>` embed in base layout, pointed at the vendor's hosted collector | No cookies, no consent banner needed; vendor choice is a STACK.md decision, zero build-time coupling either way |
| Custom domain (deferred) | `CNAME` file in build output / Pages settings, when attached | PROJECT.md explicitly defers this — architecture should not block on it (avoid hardcoding the `github.io` path into content, e.g. via `Astro.site`/base-URL config rather than literal links) |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `studio` repo ↔ `interstellar-website` repo | Manual git commit (human promote step), one file at a time, no automation today | The one boundary PROJECT.md requires to "keep working" unchanged — architecture must not add friction here |
| `devlog/` (posts) ↔ `pages/` (standalone) | Separate directories, separate content collections, no shared query | Prevents accidental cross-contamination (Anti-Pattern 3) |
| Content layer ↔ template layer | Collection query → props, one-directional | Standard SSG data flow; templates never write back to content |
| Template layer ↔ RSS generator | Same collection object, different output format | Guarantees feed and archive never drift out of sync (Pattern 3) |
| Build ↔ deploy (GitHub Actions) | Build job produces `dist/` artifact → separate deploy job consumes it | Two-job workflow (build, deploy) is GitHub's own recommended Pages-via-Actions pattern — keeps build logs and deploy logs separable |

## Sources

- Repo state read directly this session (HIGH confidence, cited inline above):
  `interstellar-website/devlog/`, `interstellar-website/PROJECT.md`, `interstellar-website/RUNBOOK.md`,
  `studio/vault/devlog/_TEMPLATE.md`, `studio/vault/devlog/drafts/*.md`, `~/.claude/skills/draft-devblog/SKILL.md`,
  `interstellar-website` git log.
- [Deploy your Astro Site to GitHub Pages | Docs](https://docs.astro.build/en/guides/deploy/github/) — MEDIUM (web search, cross-checked, matches official docs domain)
- [Content collections - Astro Docs](https://docs.astro.build/en/guides/content-collections/) — MEDIUM
- [GitHub - withastro/action](https://github.com/withastro/action) — MEDIUM
- [RSS feed generator from Markdown files - WarpBuild Blog](https://www.warpbuild.com/blog/rss-feed-generator) — MEDIUM (cross-checked against Astro/Eleventy/Hugo RSS conventions, converges with training knowledge)
- General SSG RSS/frontmatter convention findings — MEDIUM (web search, cross-checked across two independent search rounds converging on the same pattern: collection-driven feed generation, filename-fallback slugs)

---
*Architecture research for: Markdown-sourced static devblog site with externally-fed content pipeline*
*Researched: 2026-07-13*

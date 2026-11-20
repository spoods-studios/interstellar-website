# Architecture

<!-- components, how they connect, boundaries, where code lives -->

## Components

- Astro static site (`astro.config.mjs`) with two content collections defined in `src/content.config.ts`: `roadmap` and `pages`, loaded from repo-root `roadmap/` and `pages/` markdown directories.
- `astro.config.mjs` registers the `sitemap()` integration alongside the Sätteri markdown processor and a `SLUG_REDIRECTS` map sending every taken-down path to the site root.
- `src/layouts/BaseLayout.astro` is the shared HTML shell (head/meta/OG tags, header nav (Roadmap, Feedback, Discord CTA), footer, GoatCounter script, build-sha marker) used by every page; it imports no animation code.
- `src/layouts/PostLayout.astro` wraps `BaseLayout` and adds breadcrumbs, meta line, table of contents and back link; used by the roadmap routes.
- `src/pages/index.astro` renders the showcase: hero still, chapter sections with stills and clips, an upcoming section linking `/roadmap/`, and the Discord CTA.
  Its bundled `<script>` is the only importer of `src/scripts/clip-play.ts` and `src/scripts/showcase-motion.ts`.
- `src/components/ShowcaseClip.astro` renders one `<video>` with WebM and MP4 sources, a poster from `src/assets/showcase/<name>-poster.png` and a caption dated from `captures.json`; it throws when either is missing.
- `src/scripts/clip-play.ts` plays clips through an `IntersectionObserver` (200px margin, max two at once, never under reduced motion or Save-Data) and imports no animation library.
- `src/scripts/showcase-motion.ts` drives Lenis smooth scroll and the scroll-drawn trajectory SVG through Motion; it returns before building anything when `prefers-reduced-motion: reduce` matches.
- `src/pages/roadmap/index.astro` renders `pages/roadmap.md` plus a generated list of links to closed-milestone detail pages.
- `src/pages/roadmap/[milestone].astro` renders one static page per visible `roadmap` entry.
- `src/pages/legal/[doc].astro` renders one `/legal/<doc>/` page per `pages/legal/*.md` entry through `PostLayout`, with a meta line from the entry's `version` and `effective` frontmatter.
  The `pages` loader in `src/content.config.ts` fails the build when a legal file lacks either field.
- `src/pages/404.astro` renders a static not-found page through `BaseLayout`.
- `src/pages/feedback.astro` renders the `/feedback/` report page through `BaseLayout`: a Bug/Suggestion choice, a textarea capped at 4000 code points, an off-screen honeypot and a noscript Discord fallback; with an empty `FEEDBACK_URL` it renders the Discord fallback in place of the form.
  Its bundled `<script>` is the only importer of `src/scripts/feedback-form.ts`, which reads the Worker URL from the form's `data-endpoint`, posts the report through the pure helpers in `src/lib/feedback.ts` and writes the outcome state inline.
- `src/lib/*` holds cross-route shared logic: `content-guards.ts` (empty-collection assert, draft-visibility filter), `describe-entry.ts` (OG descriptions), `title-from-h1.ts`, `milestone-key.ts`, `toc.ts`, `feedback.ts` (code-point count, report payload, response-to-state mapping), `site.mjs` (site-wide constants and build-time config guards).
- `src/components/TableOfContents.astro` renders the heading list PostLayout passes down.
- `tools/showcase-encode.sh` turns an engine capture directory into the committed clip (WebM and MP4) or still (PNG); `tools/perf-log.sh` prints the home page's eager byte count from `dist/`.

## Boundaries

- Content lives in flat markdown trees outside `src/` (`roadmap/`, `pages/`), never inside `src/content/`; `src/content.config.ts` is the only place that binds them into collections.
- `src/lib/site.mjs` is plain ESM with no Astro imports so `astro.config.mjs` can evaluate it at config-load time; it is the single source of the Discord invite, GoatCounter code, OG copy, the feedback Worker URL `FEEDBACK_URL` and their build-time assertions.
- `FEEDBACK_URL` is the site's only Worker reference; `assertFeedbackConfigured` returns null while it is empty and fails the build on a non-https value.
- Markdown rendering runs through Sätteri (`@astrojs/markdown-satteri`), configured once in `astro.config.mjs` (`mdastPlugins`, Shiki theme).
  `validateContentLoudFail` over `CONTENT_TREES` re-runs every `roadmap/` and `pages/` file at config-load time so a markdown error fails the build.
- `pages/legal/` is a subdirectory of the `pages` tree; its `CONTENT_TREES` entry is `recursive` so the loud-fail validation covers it.
- The `BaseLayout.astro` footer links `/legal/eula/` and `/legal/privacy/` on every page.
- `isVisible` (`src/lib/content-guards.ts`) is the one draft-filter every route and generated cross-link must call — no route re-implements visibility.
- Motion and Lenis load only through `src/pages/index.astro`; roadmap, feedback and 404 ship no animation JS.
  Hidden initial states exist only in CSS under `prefers-reduced-motion: no-preference` and a `.js` class.
- Showcase stills are PNG sources in `src/assets/showcase/` delivered through `astro:assets`; clips are plain git files in `public/showcase/`, never LFS, with URLs composed from `import.meta.env.BASE_URL`.
- `SLUG_REDIRECTS` in `astro.config.mjs` is the one place a removed or renamed path is redirected; destinations must be base-composed (`${NORMALIZED_BASE}...`) because Astro emits string redirect destinations verbatim into the stub.
- GitHub Pages deploy is defined in `.github/workflows/deploy.yml`; `base` in `astro.config.mjs` (`/interstellar-website`) and `BASE_URL`-relative links throughout `src/` keep routes portable under that subpath.
- No server/backend: the site is fully static output from `astro build`; client scripts are the optional GoatCounter tag, the showcase bundle on `/` and the feedback form script on `/feedback/`, which posts reports to the external Worker at `FEEDBACK_URL`.

## Layout

- `roadmap/`, `pages/` — markdown content trees at repo root, one per content collection.
- `src/content.config.ts` — collection schemas and loaders.
- `src/pages/` — file-based routes: `index.astro` (showcase), `roadmap/index.astro`, `roadmap/[milestone].astro`, `feedback.astro`, `legal/[doc].astro`, `404.astro`.
- `src/layouts/` — `BaseLayout.astro` (shell) and `PostLayout.astro` (content-page chrome).
- `src/components/` — `TableOfContents.astro`, `ShowcaseClip.astro`.
- `src/scripts/` — `clip-play.ts`, `showcase-motion.ts`, `feedback-form.ts`.
- `src/lib/` — shared TypeScript/JS helpers consumed across routes and `astro.config.mjs`.
- `src/assets/` — `fonts/` (self-hosted Archivo and Source Serif 4), `showcase/` (stills, clip posters, `captures.json` capture dates), and the static default OG image.
- `public/showcase/` — encoded clips.
- `src/styles/global.css` — the site's one stylesheet.
- `public/` — static passthrough files (favicon, default OG image, clips).
- `tests/` — shell smoke tests driven by `run-all.sh`, a bare-Node `lib.smoke.mjs` and `live-probe.sh` for post-deploy checks.
- `~/.local/state/forge/interstellar-website/archive/gsd/` — historical planning/research documents from the original build, not current architecture.

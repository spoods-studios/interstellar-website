# Architecture

<!-- components, how they connect, boundaries, where code lives -->

## Components

- Astro static site (`astro.config.mjs`) with three content collections defined in `src/content.config.ts`: `devlog`, `roadmap`, `pages`, loaded from repo-root `devlog/`, `roadmap/`, `pages/` markdown directories.
- `src/layouts/BaseLayout.astro` is the shared HTML shell (head/meta/OG tags, header nav, footer, GoatCounter script, build-sha marker) used by every page.
- `src/layouts/PostLayout.astro` wraps `BaseLayout` and adds breadcrumbs, meta line, table of contents, and prev/next nav; used by every content-bearing route (devlog post, roadmap index/detail, how-its-made).
- `src/pages/index.astro` renders the devblog archive (flat, reverse-chronological list of visible `devlog` entries).
- `src/pages/devlog/[slug].astro` renders one static page per visible devlog entry, with prev/next chain from the shared sort order.
- `src/pages/roadmap/index.astro` renders `pages/roadmap.md` plus a generated list of links to closed-milestone detail pages.
- `src/pages/roadmap/[milestone].astro` renders one static page per visible `roadmap` entry, with a breadcrumb back to its announcement when one exists.
- `src/pages/how-its-made.astro` renders the standalone `pages/how-its-made.md` entry.
- `src/pages/rss.xml.ts` builds the RSS feed via Astro's Container API (`AstroContainer.renderToString`), reusing the same collection query, visibility filter and sort order as the homepage archive.
- `src/lib/*` holds cross-route shared logic: `content-guards.ts` (empty-collection assert, draft-visibility filter), `devlog-meta.ts` (title/date/sort helpers), `describe-entry.ts` (OG/RSS descriptions), `title-from-h1.ts`, `milestone-key.ts`, `hero-image.ts`/`hero-assets.ts` (hero image lookup from `src/assets/*.png`), `toc.ts`, `escape-html.ts`, `site.mjs` (site-wide constants and build-time config guards).
- `src/components/TableOfContents.astro` renders the heading list PostLayout passes down.

## Boundaries

- Content lives in flat markdown trees outside `src/` (`devlog/`, `roadmap/`, `pages/`), never inside `src/content/`; `src/content.config.ts` is the only place that binds them into collections.
- `src/lib/site.mjs` is plain ESM with no Astro imports so `astro.config.mjs` can evaluate it at config-load time; it is the single source of the Discord invite, GoatCounter code, site copy and their build-time assertions.
- Markdown rendering runs through Sätteri (`@astrojs/markdown-satteri`), configured once in `astro.config.mjs` (`mdastPlugins`, Shiki theme); `astro.config.mjs` also re-runs every content file through the same pipeline at config-load time (`validateContentLoudFail`) so a markdown/plugin error fails the build instead of shipping an empty page.
- `isVisible` (`src/lib/content-guards.ts`) is the one draft-filter every route, the feed and generated cross-links must call — no route re-implements visibility.
- `sortEntriesNewestFirst` (`src/lib/devlog-meta.ts`) is the one ordering expression shared by the archive, the post route's prev/next chain and the feed.
- `rss.xml.ts` renders content through the Container API rather than a second markdown parser or pre-rendered HTML, so feed HTML matches page HTML byte-for-byte and custom mdast plugins still apply.
- GitHub Pages deploy is defined in `.github/workflows/deploy.yml`; `base` in `astro.config.mjs` (`/interstellar-website`) and `BASE_URL`-relative links throughout `src/` keep routes portable under that subpath.
- No server/backend: the site is fully static output from `astro build`; the only client-side script is the optional GoatCounter pageview tag in `BaseLayout.astro`.

## Layout

- `devlog/`, `roadmap/`, `pages/` — markdown content trees at repo root, one per content collection.
- `src/content.config.ts` — collection schemas and loaders.
- `src/pages/` — file-based routes: `index.astro` (archive), `devlog/[slug].astro`, `roadmap/index.astro`, `roadmap/[milestone].astro`, `how-its-made.astro`, `rss.xml.ts`, `404.astro`.
- `src/layouts/` — `BaseLayout.astro` (shell) and `PostLayout.astro` (content-page chrome).
- `src/components/` — `TableOfContents.astro`.
- `src/lib/` — shared TypeScript/JS helpers consumed across routes and `astro.config.mjs`.
- `src/assets/` — hero/OG images consumed via `import.meta.glob` in `hero-assets.ts`.
- `src/styles/global.css` — the site's one stylesheet.
- `public/` — static passthrough files (favicon, default OG image).
- `tests/` — shell-driven smoke tests (`run-all.sh` entry point) covering build, collections, markdown, roadmap, site and post rendering.
- `.forge/archive/gsd/` — historical planning/research documents from the original build, not current architecture.

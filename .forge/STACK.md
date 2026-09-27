# Stack

<!-- languages, frameworks, runtime, build/run/deploy commands -->

## Languages and frameworks

- Astro 7 static site (`astro.config.mjs`) with TypeScript, Content Collections (`src/content.config.ts`), `@astrojs/rss`, `@astrojs/sitemap`, `sanitize-html`.
- Markdown renders through Sätteri (`@astrojs/markdown-satteri`, `satteri`), configured via `markdown.processor` in `astro.config.mjs`, not the classic remark/rehype pipeline.
- Content lives in three glob-loaded trees: `devlog/`, `roadmap/`, `pages/` (`src/content.config.ts`, `CONTENT_TREES` in `astro.config.mjs`).
- GitHub Pages hosting, deployed via GitHub Actions (`.github/workflows/deploy.yml`), served at `spoods-studios.github.io/interstellar-website`.
- GoatCounter for cookieless analytics, loaded client-side from `BaseLayout.astro` only when a site code is configured (`src/lib/site.mjs`).

## Commands

- `npm run dev`, `npm run build`, `npm run preview` (Astro CLI).
- `npm test` runs `bash tests/run-all.sh`.
- Deploy: push to `main` triggers `.github/workflows/deploy.yml` (build via `withastro/action`, `actions/deploy-pages`, then `tests/live-probe.sh` smoke-checks the live site).

# Stack

<!-- languages, frameworks, runtime, build/run/deploy commands -->

## Languages and frameworks

- Astro 7 static site with Content Collections, `@astrojs/rss`, `@astrojs/sitemap`, `sanitize-html`; Node 24 (fnm).
- GitHub Pages via GitHub Actions (`.github/workflows/deploy.yml`), live at `spoods-studios.github.io/interstellar-website`.
- GoatCounter for cookieless analytics (`GOATCOUNTER_CODE` in `src/lib/site.mjs`).

## Commands

- `npm run dev`, `npm run build`, `npm run preview`.
- Deploy: push `main` to `origin`; the Forgejo mirror carries it to `github`, which runs the Pages deploy.

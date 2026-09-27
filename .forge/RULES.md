# Rules

<!-- invariants that must never break, each with the test or gate enforcing it -->

## Invariants

- A deployed devlog or roadmap URL is permanent; renaming a promoted file needs a `SLUG_REDIRECTS` entry in `astro.config.mjs` in the same commit, with a base-free key and a destination composed from `NORMALIZED_BASE` (pinned by the smoke harness).
- `devlog/`, `roadmap/` and `pages/` are drop targets for the studio promote pipeline; never move, rename, restyle or restructure their `.md` files. The site renders them as-is (VOICE.md is locked studio-side).
- GitHub Pages deploys only when `main` reaches the `github` remote. Push to `origin` only: `.forgejo/workflows/release.yml` mirrors every `main` push to `github`, where `.github/workflows/deploy.yml` publishes. Never add a manual `git push github main`.
- A red post-deploy live-probe smoke job means readers see a broken site; fix it before anything else.
- No cookies and no invasive tracking; analytics stay cookieless (GoatCounter) or absent.

# Integrations

<!-- external services and APIs, how credentials are supplied -->

## Services

- GitHub Pages: static hosting and deploy target (`.github/workflows/deploy.yml`).
- GoatCounter (`gc.zgo.at/count.js`): pageview analytics, injected in `src/layouts/BaseLayout.astro` when a site code is set.
- Discord: invite link rendered as a CTA, sourced from `DISCORD_INVITE_URL` in `src/lib/site.mjs`.

## Credentials

- `GOATCOUNTER_CODE` — GoatCounter site code, a literal constant in `src/lib/site.mjs` (not an env var); build fails if it's the placeholder, warns if unset.
- `DISCORD_INVITE_URL` — Discord invite URL, a literal constant in `src/lib/site.mjs`; build fails if unset or the placeholder.
- `GITHUB_SHA` — CI-supplied commit SHA read via `process.env.GITHUB_SHA` in `src/layouts/BaseLayout.astro` for the build-freshness stamp; not a secret, falls back to `'local'`.

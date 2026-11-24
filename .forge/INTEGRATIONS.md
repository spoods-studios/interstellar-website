# Integrations

<!-- external services and APIs, how credentials are supplied -->

## Services

- GitHub Pages: static hosting and deploy target (`.github/workflows/deploy.yml`).
- GoatCounter (`gc.zgo.at/count.js`): pageview analytics, injected in `src/layouts/BaseLayout.astro` when a site code is set.
- Discord: invite link rendered as a CTA, sourced from `DISCORD_INVITE_URL` in `src/lib/site.mjs`.
- Feedback Worker: external endpoint that receives reports posted by `src/scripts/feedback-form.ts` as JSON (`kind`, `source`, `text`, `homepage`).
  It answers 202 on accept, 429 with `Retry-After` when rate limited and 4xx with an `error` string on refusal.
- Buttondown: newsletter provider; the form in `src/components/NewsletterForm.astro` posts natively to its embed-subscribe URL and the site loads nothing from it.

## Credentials

- `GOATCOUNTER_CODE` — GoatCounter site code, a literal constant in `src/lib/site.mjs` (not an env var); build fails if it's the placeholder, warns if unset.
- `DISCORD_INVITE_URL` — Discord invite URL, a literal constant in `src/lib/site.mjs`; build fails if unset or the placeholder.
- `FEEDBACK_URL` — the Worker's https reports URL, a literal constant in `src/lib/site.mjs`; empty swaps the form for a Discord fallback and a non-https value fails the build.
  It is a public URL, not a secret, and reaches the page only through the form's `data-endpoint`.
- `NEWSLETTER_URL` — the Buttondown embed-subscribe https URL, a literal constant in `src/lib/site.mjs`; empty swaps every form for a Discord fallback and a non-https value fails the build.
- `GITHUB_SHA` — CI-supplied commit SHA read via `process.env.GITHUB_SHA` in `src/layouts/BaseLayout.astro` for the build-freshness stamp; not a secret, falls back to `'local'`.

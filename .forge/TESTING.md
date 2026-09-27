# Testing

<!-- test layout, commands, markers, which tests enforce which rules -->

Tests that bind ports add `FORGE_PORT_OFFSET` to their base port and tests that create databases use the name in `FORGE_TEST_DB`; when they are unset, the offset is 0 and the default DB is used.

## Layout

- `tests/lib.smoke.mjs`: committed assertion script for pure `src/lib/*.ts` helpers, run directly with `node`.
- `tests/*.smoke.sh`: shell smoke scripts, each doing a clean `npm run build` and asserting against `dist/` output (canonical links, sitemap, favicon, no stray scripts, dead links, page-count, build-sha stamp, analytics gating, redirect stub contract, schema-violation fixture).
- `tests/run-all.sh`: runs `node tests/lib.smoke.mjs` then every `tests/*.smoke.sh` in sorted order; adding a new smoke script needs no harness edit.
- `tests/live-probe.sh`: probes the deployed GitHub Pages site after deploy (not run locally as part of `npm test`).

## Commands

- `npm test` runs `bash tests/run-all.sh`.

## Gates

- `.github/workflows/deploy.yml`: `build` (via `withastro/action`) then `deploy` to GitHub Pages on every push to `main`, then a `smoke` job that runs `tests/live-probe.sh` against the live URL.
- `tests/*.smoke.sh` and `tests/lib.smoke.mjs` are not run in CI; they are local-only harnesses (`tests/hardening.smoke.sh` mutates the working tree with fixtures and does full rebuilds, deliberately kept out of the push-gated pipeline).

## Known failures

- On `main` as of 2026-09-27, `tests/build.smoke.sh`, `collections.smoke.sh`, `post.smoke.sh` and `roadmap.smoke.sh` fail (build.smoke.sh at its manifesto-title assertion), so `npm test` stops at build.smoke.sh; `lib.smoke.mjs` and the other five smoke scripts pass.

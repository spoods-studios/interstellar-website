# Testing

<!-- test layout, commands, markers, which tests enforce which rules -->

Tests that bind ports add `FORGE_PORT_OFFSET` to their base port and tests that create databases use the name in `FORGE_TEST_DB`; when they are unset, the offset is 0 and the default DB is used.

## Layout

- `tests/lib.smoke.mjs`: committed assertion script for pure `src/lib/*.ts` helpers, run directly with `node`.
- `tests/*.smoke.sh`: shell smoke scripts, each doing a clean `npm run build` and asserting against `dist/` output (build, collections, distribution, hardening, markdown, post, roadmap, shell, site).
- `tests/run-all.sh`: runs `node tests/lib.smoke.mjs` then every `tests/*.smoke.sh` in sorted order; adding a new smoke script needs no harness edit.
- `tests/live-probe.sh`: probes the deployed GitHub Pages site after deploy, not run locally as part of `npm test`.
- `tests/hardening.smoke.sh` mutates the working tree with fixtures and does full rebuilds.

## Commands

- `npm test` runs `bash tests/run-all.sh`.

## Gates

- `.github/workflows/deploy.yml`: `build` job (`withastro/action`) then `deploy` to GitHub Pages on every push to `main`, then a `smoke` job that runs `tests/live-probe.sh` against the live `page_url`.
- `tests/*.smoke.sh` and `tests/lib.smoke.mjs` are not run in CI; they are local-only harnesses.

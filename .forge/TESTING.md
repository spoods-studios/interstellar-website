# Testing

<!-- test layout, commands, markers, which tests enforce which rules -->

Tests that bind ports add `FORGE_PORT_OFFSET` to their base port and tests that create databases use the name in `FORGE_TEST_DB`; when they are unset, the offset is 0 and the default DB is used.

## Layout

- `tests/lib.smoke.mjs`: committed assertion script for pure `src/lib/*.ts` helpers, run directly with `node`.
- `tests/*.smoke.sh`: shell smoke scripts, each doing a clean `npm run build` and asserting against `dist/` output, one per area (e.g. build, media, showcase, takedown).
  `showcase.smoke.sh` pins the single JS module on `dist/index.html`, the reduced-motion gate and the `<video>` attributes.
- `media.smoke.sh` pins media size caps; `takedown.smoke.sh` pins the root redirects and the absent feed.
- `tests/run-all.sh`: runs `node tests/lib.smoke.mjs` then every `tests/*.smoke.sh` in sorted order; adding a new smoke script needs no harness edit.
  Given script paths, it runs only those.
- `tests/changed.sh`: maps changed paths to scripts: a changed script runs itself, a changed `src/lib` helper runs `lib.smoke.mjs`, and changed site source or content runs `site.smoke.sh` plus scripts naming the file's stem.
- Build config, lockfiles, `tests/helpers/` and the runners run the full suite; paths outside the site run nothing.
- `tests/live-probe.sh`: probes the deployed GitHub Pages site after deploy, not run locally as part of `npm test`.
- `tests/hardening.smoke.sh` mutates the working tree with fixtures and does full rebuilds.

## Commands

- `npm test` runs `bash tests/run-all.sh`.
- Setup: `npm ci`
- All tests: `npm test`
- CI full suite: `test`
- Test: `bash tests/run-all.sh {test}` (a script path, e.g. `tests/post.smoke.sh`).
- Changed tests: `bash tests/changed.sh {files}`
- Perf log: `npm run build && bash tools/perf-log.sh`

## Gates

- `.github/workflows/deploy.yml`: `test` job, then `build` job (`withastro/action`), then `deploy` to GitHub Pages, then a `smoke` job that runs `tests/live-probe.sh` against the live `page_url`, on every push to `main`.
- The GitHub `test` job in `deploy.yml` runs `npm ci --ignore-scripts` then `npm test` (`tests/lib.smoke.mjs` plus every `tests/*.smoke.sh`) before `build`; `build` needs it, so a failing suite skips build, deploy and smoke.
- `.forgejo/workflows/test.yml`: on branch push and `pull_request`, runs `npm ci --ignore-scripts` then `npm test` (`GITHUB_SHA` unset) in a pinned `node:22-bookworm` container on the `linux-engine` runner; it uses no secrets, only reports, and is not in `release.yml`'s mirror `needs:`.

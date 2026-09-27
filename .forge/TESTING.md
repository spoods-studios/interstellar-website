# Testing

<!-- test layout, commands, markers, which tests enforce which rules -->

Tests that bind ports add `FORGE_PORT_OFFSET` to their base port and tests that create databases use the name in `FORGE_TEST_DB`; when they are unset, the offset is 0 and the default DB is used.

## Layout

Shell smoke tests in `tests/*.smoke.sh` plus `tests/lib.smoke.mjs`, run by `tests/run-all.sh`. `tests/live-probe.sh` probes the deployed site.

## Commands

- `npm test` runs `bash tests/run-all.sh`.

## Gates

- `deploy.yml` runs a post-deploy live-probe smoke job (homepage, feed, launch post, 404-under-base, redirect stub).

## Known failures

These already fail on `main` before the forge migration: `tests/build.smoke.sh`, `tests/collections.smoke.sh`, `tests/post.smoke.sh`, `tests/roadmap.smoke.sh`.

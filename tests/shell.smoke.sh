#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 02 (site shell: global.css, BaseLayout,
# favicon, 404). Model: tests/build.smoke.sh (Plan 01, same wave) -- do not
# edit that file from here, it is Plan 01's harness.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Build =="
npm run build

echo "== 404 page and favicon land at the artifact root =="
test -f dist/404.html
test -f dist/favicon.svg

echo "== 404 copy (D-19 Copywriting Contract) =="
grep -q 'Page not found' dist/404.html
grep -q 'Back home' dist/404.html

echo "== 404 carries the shared BaseLayout chrome =="
# index.astro has not adopted BaseLayout yet (Phase 2's own comment marks it
# "replaced wholesale by Phase 2 templating" -- a later plan's job), so there
# is no second migrated page to diff the footer against yet. Assert 404's own
# chrome directly instead: this is the same wordmark/footer markup every
# future BaseLayout-consuming page will render (D-19).
grep -q 'Interstellar Engine' dist/404.html
grep -q '&#169; 2026 Spoods Studios\|© 2026 Spoods Studios' dist/404.html

echo "ALL CHECKS PASSED"

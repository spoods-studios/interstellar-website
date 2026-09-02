#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 03, Task 3 (sitemap -- D-22/D-41/SITE-04).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Build over the whole corpus =="
npm run build

echo "== Sitemap is emitted with base-prefixed URLs =="
ls dist/sitemap*.xml >/dev/null
grep -q "interstellar-website/" dist/sitemap-index.xml
echo "sitemap OK"

echo "== Zero client JS beyond the analytics tag (D-60/D-61) =="
RENDERED="dist/index.html"
test -f "$RENDERED"
test "$(grep -o '<script' "$RENDERED" | wc -l)" -eq "$(grep -o 'gc\.zgo\.at' "$RENDERED" | wc -l)"
echo "no-extra-JS OK"

echo "ALL CHECKS PASSED"

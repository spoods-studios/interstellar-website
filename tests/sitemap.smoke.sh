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

echo "ALL CHECKS PASSED"

#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 03, Task 3 (Sätteri wikilink plugin,
# light-theme Shiki, sitemap -- D-22/D-39/D-41/SITE-04).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Build over the whole corpus =="
npm run build

echo "== Sitemap is emitted with base-prefixed URLs =="
ls dist/sitemap*.xml >/dev/null
grep -q "interstellar-website/" dist/sitemap-index.xml
echo "sitemap OK"

echo "== Wikilink resolves to a real internal anchor, Shiki ships light-theme inline styles, zero client JS =="
RENDERED="dist/markdown-render-check/index.html"
test -f "$RENDERED"
grep -q '<a href="/interstellar-website/technical/m0.1/phase-03-rendering-pipeline/"' "$RENDERED"
grep -q 'background-color:#fff' "$RENDERED"
! grep -q '<script' "$RENDERED"
echo "wikilink + Shiki + zero-JS OK"

echo "ALL CHECKS PASSED"

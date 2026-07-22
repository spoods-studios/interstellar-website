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
# Repointed off the removed markdown-render-check.astro diagnostic route
# (02-08 orchestrator note) onto the real rendered deep-dive page for the same
# entry (m0.3/phase-14.5-swapchain-acquire-fix) -- Plan 06's real
# [milestone]/[slug] route makes the diagnostic route redundant, but this
# assertion set (end-to-end proof the Satteri plugin runs in the real
# pipeline, not just via direct markdownToHtml() calls in tests/lib.smoke.mjs)
# must survive the move unweakened.
RENDERED="dist/technical/m0.3/phase-14.5-swapchain-acquire-fix/index.html"
test -f "$RENDERED"
grep -q '<a href="/interstellar-website/technical/m0.1/phase-03-rendering-pipeline/"' "$RENDERED"
grep -q 'background-color:#fff' "$RENDERED"
! grep -q '<script' "$RENDERED"
echo "wikilink + Shiki + zero-JS OK"

echo "ALL CHECKS PASSED"

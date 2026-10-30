#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 03, Task 2 (Astro collections,
# per-tree filename rules -- CONT-03/04, D-38).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Positive check: all collections resolve at their exact expected counts =="
# Counting built dist/ routes catches RESEARCH Pitfall 1 (glob()'s
# silent-empty-collection landmine): a misconfigured loader base produces zero
# getCollection() results, so getStaticPaths generates zero pages regardless
# of how many source files exist on disk.
npm run build
ROADMAP_COUNT=$(find dist/roadmap -mindepth 2 -maxdepth 2 -name index.html | wc -l)
PAGES_COUNT=0
test -f dist/roadmap/index.html && PAGES_COUNT=$((PAGES_COUNT + 1))
EXPECTED_ROADMAP=$(node tests/helpers/content-expectations.mjs roadmap_count)
EXPECTED_PAGES=$(node tests/helpers/content-expectations.mjs pages_count)
echo "roadmap:$ROADMAP_COUNT pages:$PAGES_COUNT"
test "$ROADMAP_COUNT" -eq "$EXPECTED_ROADMAP"
test "$PAGES_COUNT" -eq "$EXPECTED_PAGES"
echo "counts OK (roadmap $EXPECTED_ROADMAP / pages $EXPECTED_PAGES)"

echo "ALL CHECKS PASSED"

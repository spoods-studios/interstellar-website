#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 03, Task 2 (Astro collections,
# per-tree filename rules, loud failure -- CONT-02/03/04, D-32/D-38).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Positive check: all collections resolve at their exact expected counts =="
# Repointed off the removed collection-counts.json.ts diagnostic route (02-08
# orchestrator note) onto the real index/route output. This still catches
# RESEARCH Pitfall 1 (glob()'s silent-empty-collection landmine): a
# misconfigured loader base produces zero getCollection() results, so
# getStaticPaths generates zero pages regardless of how many source files
# exist on disk -- counting built dist/ routes is exactly as sensitive to that
# regression as the old getCollection()-backed JSON endpoint was.
npm run build
# CONT-06/D-65: redirect stubs (meta-refresh pages from astro.config.mjs's
# SLUG_REDIRECTS) land under dist/devlog/ too but are not collection pages --
# exclude them by the same predicate the other harnesses use, so this stays a
# count of reader-facing devlog routes.
DEVLOG_COUNT=0
while IFS= read -r f; do
  if grep -q 'http-equiv="refresh"' "$f"; then continue; fi
  DEVLOG_COUNT=$((DEVLOG_COUNT + 1))
done < <(find dist/devlog -name index.html)
ROADMAP_COUNT=$(find dist/roadmap -mindepth 2 -maxdepth 2 -name index.html | wc -l)
PAGES_COUNT=0
test -f dist/how-its-made/index.html && PAGES_COUNT=$((PAGES_COUNT + 1))
test -f dist/roadmap/index.html && PAGES_COUNT=$((PAGES_COUNT + 1))
EXPECTED_DEVLOG=$(node tests/helpers/content-expectations.mjs devlog_count)
EXPECTED_ROADMAP=$(node tests/helpers/content-expectations.mjs roadmap_count)
EXPECTED_PAGES=$(node tests/helpers/content-expectations.mjs pages_count)
echo "devlog:$DEVLOG_COUNT roadmap:$ROADMAP_COUNT pages:$PAGES_COUNT"
test "$DEVLOG_COUNT" -eq "$EXPECTED_DEVLOG"
test "$ROADMAP_COUNT" -eq "$EXPECTED_ROADMAP"
test "$PAGES_COUNT" -eq "$EXPECTED_PAGES"
echo "counts OK (devlog $EXPECTED_DEVLOG / roadmap $EXPECTED_ROADMAP / pages $EXPECTED_PAGES)"

echo "ALL CHECKS PASSED"

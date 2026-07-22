#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 03, Task 2 (four Astro collections,
# per-tree filename rules, loud failure -- CONT-02/03/04, D-32/D-33/D-38).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Positive check: all four collections resolve at their exact expected counts =="
# Repointed off the removed collection-counts.json.ts diagnostic route (02-08
# orchestrator note) onto the real index/route output. This still catches
# RESEARCH Pitfall 1 (glob()'s silent-empty-collection landmine): a
# misconfigured loader base produces zero getCollection() results, so
# getStaticPaths generates zero pages regardless of how many source files
# exist on disk -- counting built dist/ routes is exactly as sensitive to that
# regression as the old getCollection()-backed JSON endpoint was.
npm run build
DEVLOG_COUNT=$(find dist/devlog -name index.html | wc -l)
TECHNICAL_COUNT=$(( $(find dist/technical -path 'dist/technical/m0.*/phase-*' -name index.html | wc -l) + 1 )) # +1 for how-to-read
ROADMAP_COUNT=$(find dist/roadmap -mindepth 2 -maxdepth 2 -name index.html | wc -l)
PAGES_COUNT=0
test -f dist/how-its-made/index.html && PAGES_COUNT=$((PAGES_COUNT + 1))
test -f dist/roadmap/index.html && PAGES_COUNT=$((PAGES_COUNT + 1))
echo "devlog:$DEVLOG_COUNT technical:$TECHNICAL_COUNT roadmap:$ROADMAP_COUNT pages:$PAGES_COUNT"
test "$DEVLOG_COUNT" -eq 9
test "$TECHNICAL_COUNT" -eq 56
test "$ROADMAP_COUNT" -eq 8
test "$PAGES_COUNT" -eq 2
echo "counts OK (devlog 9 / technical 56 / roadmap 8 / pages 2)"

echo "== Negative check (D-33): malformed technical/ filename fails the build loudly =="
MARKER="technical/m0.1/not-a-conforming-name.md"
trap 'rm -f "$MARKER"' EXIT
printf '# Not a real deep-dive\n\nbody\n' > "$MARKER"
if npm run build > /tmp/gsd-d33.log 2>&1; then
  rm -f "$MARKER"
  echo "D-33 FAIL: build did not error on malformed technical/ filename"
  exit 1
fi
grep -q "not-a-conforming-name.md" /tmp/gsd-d33.log
rm -f "$MARKER"
if git status --porcelain technical/ | grep -q .; then
  echo "D-33 FAIL: technical/ left dirty"
  exit 1
fi
echo "D-33 OK: build failed loudly naming the offending file; technical/ clean"

echo "== Rebuild clean after negative-case fixture removal =="
npm run build
echo "rebuild OK"

echo "ALL CHECKS PASSED"

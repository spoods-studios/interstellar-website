#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 03, Task 2 (four Astro collections,
# per-tree filename rules, loud failure -- CONT-02/03/04, D-32/D-33/D-38).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Positive check: all four collections resolve at their exact expected counts =="
npm run build
COUNTS="$(cat dist/collection-counts.json)"
echo "$COUNTS"
echo "$COUNTS" | grep -q '"devlog":9'
echo "$COUNTS" | grep -q '"technical":56'
echo "$COUNTS" | grep -q '"roadmap":8'
echo "$COUNTS" | grep -q '"pages":2'
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

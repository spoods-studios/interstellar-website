#!/usr/bin/env bash
# Smoke-test harness for Phase 1 Plan 01, Task 3 (ingest -> render slice, CONT-01/D-01/D-02/D-07/D-10).
# No JS test framework this phase (D-03/D-09, RESEARCH.md Validation Architecture) --
# `npm run build` IS the test; this script codifies the plan's <verify> checks as a
# committed, re-runnable RED/GREEN harness instead of a one-off shell command.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Positive check: manifesto ingests and renders =="
npm run build
grep -q "Devblog" dist/index.html
grep -q "Why I'm Building a Hyperrealistic Space Sim from Scratch" dist/index.html
grep -q "2026-04-07" dist/index.html
! grep -rIn -e 'github\.io' -e '/interstellar-website' src/
echo "positive check OK"

echo "== Positive check: full nine-announcement archive (CONT-02) =="
# grep -c counts matching LINES, not occurrences -- Astro's production build
# minifies dist/index.html to a single line, so -c always reports 1 regardless
# of post count. grep -o | wc -l counts actual occurrences instead. Match the
# full '<li>' opening tag, not the bare '<li' substring -- '<li' also matches
# inside '<link rel="canonical" ...>', which was silently inflating the count.
test "$(grep -o '<li>' dist/index.html | wc -l)" -eq 9
echo "nine-announcement check OK"

echo "== Negative check (D-10): malformed devlog file fails the build loudly =="
MARKER="zzz-not-a-post.md"
trap 'rm -f "devlog/$MARKER"' EXIT
printf 'garbage body no h1\n' > "devlog/$MARKER"
if npm run build > /tmp/gsd-d10.log 2>&1; then
  rm -f "devlog/$MARKER"
  echo "D-10 FAIL: build did not error on malformed file"
  exit 1
fi
grep -q "$MARKER" /tmp/gsd-d10.log
rm -f "devlog/$MARKER"
if git status --porcelain devlog/ | grep -q .; then
  echo "D-10 FAIL: devlog/ left dirty"
  exit 1
fi
echo "D-10 OK: build failed loudly naming $MARKER; devlog/ clean"

echo "ALL CHECKS PASSED"

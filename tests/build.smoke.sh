#!/usr/bin/env bash
# Smoke-test harness for the build: the site builds, the showcase index
# renders, and a malformed content file fails the build loudly.
set -euo pipefail

cd "$(dirname "$0")/.."
. tests/helpers/build.sh

echo "== Positive check: the site builds and the showcase index renders =="
build_site
test -f dist/index.html
grep -q '<h1[^>]*>Setare Aerospace</h1>' dist/index.html
grep -q 'href="[^"]*roadmap/"' dist/index.html
if grep -q 'devlog/' dist/index.html; then
  echo "FAIL: the index still links to a devlog post"
  exit 1
fi
echo "positive check OK"

echo "== Negative check (D-38): malformed roadmap filename fails the build loudly =="
MARKER="Mzzz-not-a-milestone.md"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
scratch_tree "$T/site"
printf '# Not a milestone\n' > "$T/site/roadmap/$MARKER"
if build_in "$T/site" > "$T/build.log" 2>&1; then
  echo "D-38 FAIL: build did not error on malformed file"
  exit 1
fi
grep -q "$MARKER" "$T/build.log"
echo "D-38 OK: build failed loudly naming $MARKER"

echo "ALL CHECKS PASSED"

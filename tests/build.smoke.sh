#!/usr/bin/env bash
# Smoke-test harness for the build: the site builds, the showcase index
# renders, and a malformed content file fails the build loudly.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Positive check: the site builds and the showcase index renders =="
npm run build
test -f dist/index.html
grep -q '<h1[^>]*>Setare Aerospace</h1>' dist/index.html
if grep -rIn -e 'github\.io' -e '/interstellar-website' src/; then
  echo "FAIL: hardcoded host/base string under src/"
  exit 1
fi

# D-16: the developer-approved sentence must ship verbatim.
grep -qF "A space engine built from scratch on real n-body physics." dist/index.html
grep -q 'href="[^"]*roadmap/"' dist/index.html
if grep -q 'devlog/' dist/index.html; then
  echo "FAIL: the index still links to a devlog post"
  exit 1
fi

# No client JS beyond the sanctioned analytics tag and the showcase's one
# hashed motion module (D-60/D-61: the script-tag count must equal the
# analytics-tag count plus that module in either constant state).
BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
test "$(grep -o '<script' dist/index.html | wc -l)" -eq "$(( $(grep -o 'gc\.zgo\.at' dist/index.html | wc -l) + 1 ))"
test "$(grep -oE "<script type=\"module\" src=\"${NORMALIZED_BASE}_astro/[^\"/]+\\.js\"></script>" dist/index.html | wc -l)" -eq 1
echo "positive check OK"

echo "== Negative check (D-38): malformed roadmap filename fails the build loudly =="
MARKER="Mzzz-not-a-milestone.md"
trap 'rm -f "roadmap/$MARKER"' EXIT
printf '# Not a milestone\n' > "roadmap/$MARKER"
if npm run build > /tmp/gsd-d38.log 2>&1; then
  rm -f "roadmap/$MARKER"
  echo "D-38 FAIL: build did not error on malformed file"
  exit 1
fi
grep -q "$MARKER" /tmp/gsd-d38.log
rm -f "roadmap/$MARKER"
if git status --porcelain roadmap/ | grep -q .; then
  echo "D-38 FAIL: roadmap/ left dirty"
  exit 1
fi
echo "D-38 OK: build failed loudly naming $MARKER; roadmap/ clean"

echo "ALL CHECKS PASSED"

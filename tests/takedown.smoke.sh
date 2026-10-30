#!/usr/bin/env bash
# Smoke-test harness for the site takedown (SSC-01/SSC-07): the devlog, How
# It's Made and the RSS feed no longer build, and every removed path builds a
# redirect stub to the site root.
set -euo pipefail

cd "$(dirname "$0")/.."

BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"

REMOVED_PATHS=(
  /devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim
  /devlog/2026-04-13-before-the-galaxy-a-triangle
  /devlog/2026-04-25-a-coordinate-system-that-doesnt-lie
  /devlog/2026-06-05-a-moon-that-actually-orbits
  /devlog/2026-06-14-from-one-world-to-many
  /devlog/2026-06-19-teaching-the-engine-to-fast-forward
  /devlog/2026-06-25-shipping-the-warp-lever-with-a-bouncer-on-the-door
  /devlog/2026-07-10-warping-without-losing-the-moon
  /devlog/2026-07-13-making-mercury-precess
  /devlog/2026-07-30-first-burn
  /devlog/2026-08-11-the-line-you-fly
  /devlog/2026-08-11-three-small-fixes-before-closing-the-books
  /devlog/2026-07-30-demo-old-slug
  /how-its-made
)

mapfile -t REDIRECT_KEYS < <(sed -n '/^const SLUG_REDIRECTS = {/,/^};/p' astro.config.mjs | grep -oP "^\s*'\K/[^']+(?=':)")

echo "== Build =="
npm run build

echo "== Every removed path is a SLUG_REDIRECTS key =="
for path in "${REMOVED_PATHS[@]}"; do
  if ! printf '%s\n' "${REDIRECT_KEYS[@]}" | grep -qxF "$path"; then
    echo "FAIL: $path has no SLUG_REDIRECTS entry"
    exit 1
  fi
done

echo "== Every SLUG_REDIRECTS key builds a stub refreshing to the site root =="
test "${#REDIRECT_KEYS[@]}" -ge "${#REMOVED_PATHS[@]}"
for key in "${REDIRECT_KEYS[@]}"; do
  STUB="dist${key}/index.html"
  if [ ! -f "$STUB" ]; then
    echo "FAIL: $key built no stub at $STUB"
    exit 1
  fi
  TARGET=$(grep -oP 'http-equiv="refresh" content="[0-9]+;url=\K[^"]+' "$STUB" || true)
  if [ "$TARGET" != "$NORMALIZED_BASE" ]; then
    echo "FAIL: $STUB refreshes to '$TARGET', expected '$NORMALIZED_BASE'"
    exit 1
  fi
done
test -f dist/index.html

echo "== No feed is built =="
if [ -e dist/rss.xml ]; then
  echo "FAIL: dist/rss.xml still exists"
  exit 1
fi

echo "== No built page references the feed or links to How It's Made =="
CHROME_FAIL=0
while IFS= read -r f; do
  if grep -qF 'rss.xml' "$f"; then
    echo "FAIL: $f references rss.xml"
    CHROME_FAIL=1
  fi
  if grep -qF 'application/rss+xml' "$f"; then
    echo "FAIL: $f carries an application/rss+xml link"
    CHROME_FAIL=1
  fi
  if grep -q 'href="[^"]*how-its-made' "$f"; then
    echo "FAIL: $f links to how-its-made"
    CHROME_FAIL=1
  fi
done < <(find dist -name "*.html")
[ "$CHROME_FAIL" -eq 0 ]

echo "== dist/devlog/ holds only redirect stubs =="
while IFS= read -r f; do
  case $f in
    */index.html) grep -q 'http-equiv="refresh"' "$f" || { echo "FAIL: $f is not a redirect stub"; exit 1; } ;;
    *) echo "FAIL: $f is not a redirect stub"; exit 1 ;;
  esac
done < <(find dist/devlog -type f)

echo "ALL CHECKS PASSED"

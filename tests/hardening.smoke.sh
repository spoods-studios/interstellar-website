#!/usr/bin/env bash
# Deploy-hardening smoke harness for Phase 4 (analytics, launch content,
# deploy hardening). Proves SITE-03 (schema/content errors fail the build
# loudly, and every built page carries the freshness marker the post-deploy
# probe greps for), plus the phase's new mechanisms as later plans land them:
# CONT-06/D-65 (slug redirect stubs, Plan 04-04), ANLT-01/D-61 (gated
# analytics tag, Plan 04-03), and D-68 (the build-sha stamp, this file).
#
# Everything here is offline and asserted against real build output. What
# genuinely cannot be proven offline is deliberately NOT faked with a
# build-time proxy: that the LIVE site serves the deploying commit's SHA is
# owned by tests/live-probe.sh run from the CI smoke job (Plan 04-05), and
# the GoatCounter dashboard check is a human verification (Plan 04-03).
#
# Later plans in this phase append their own `== section ==` blocks to this
# file, before the final clean-rebuild tail.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Clean build =="
rm -rf dist
npm run build

# --- Derive SITE/BASE from astro.config.mjs itself (SITE-02: the site/base
# live in one config location, never repeated as literals in assertions). ---
SITE=$(grep -oP "site:\s*'\K[^']+" astro.config.mjs)
BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
echo "site=$SITE base=$NORMALIZED_BASE"

# grep's count flag counts matching LINES, and Astro's build minifies each
# dist/*.html page to a single line -- a line count therefore always reports 1
# no matter how many matches a page carries (the Phase 02-01 trap). Count
# occurrences instead. `|| n=0` keeps a zero-match page reportable under set -e.
count_occurrences() {
  local n
  n=$(grep -o "$1" "$2" | wc -l) || n=0
  printf '%s' "$n"
}

echo "== D-68: every built page carries exactly one build-sha stamp =="
STAMP_FAIL=0
while IFS= read -r f; do
  COUNT=$(count_occurrences '<meta name="build-sha"' "$f")
  if [ "$COUNT" -ne 1 ]; then
    echo "FAIL: $f carries $COUNT build-sha stamps (expected exactly 1)"
    STAMP_FAIL=1
  fi
done < <(find dist -name "*.html")
[ "$STAMP_FAIL" -eq 0 ]
echo "stamp coverage OK"

echo "== D-68: a build without GITHUB_SHA stamps the literal 'local' =="
LOCAL_FAIL=0
while IFS= read -r f; do
  if [ "$(count_occurrences '<meta name="build-sha" content="local"' "$f")" -ne 1 ]; then
    echo "FAIL: $f local-build stamp is not the literal 'local'"
    LOCAL_FAIL=1
  fi
done < <(find dist -name "*.html")
[ "$LOCAL_FAIL" -eq 0 ]
echo "local fallback OK"

echo "== D-68: the stamp tracks GITHUB_SHA when exported for the build =="
SYNTHETIC_SHA="cafef00dcafef00dcafef00dcafef00dcafef00d"
GITHUB_SHA="$SYNTHETIC_SHA" npm run build > /dev/null
TRACK_FAIL=0
while IFS= read -r f; do
  if [ "$(count_occurrences "<meta name=\"build-sha\" content=\"$SYNTHETIC_SHA\"" "$f")" -ne 1 ]; then
    echo "FAIL: $f does not carry the exported GITHUB_SHA value in its stamp"
    TRACK_FAIL=1
  fi
done < <(find dist -name "*.html")
[ "$TRACK_FAIL" -eq 0 ]
echo "SHA tracking OK"

echo "== Final clean rebuild: leave dist/ as a plain local build =="
npm run build > /dev/null

echo "ALL CHECKS PASSED"

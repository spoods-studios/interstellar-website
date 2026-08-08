#!/usr/bin/env bash
# Live freshness probe for SITE-03's post-deploy half (D-67/D-68).
#
# Usage: tests/live-probe.sh <base-url-ending-with-slash> <expected-sha> \
#          [launch-post-path] [feed-path] [redirect-stub-path]
#
# Succeeds only when the served page's body carries the D-68 build-sha stamp
# with exactly the expected SHA. An HTTP 200 alone is NEVER accepted as proof
# of freshness: the failure mode this probe exists to catch is a perfectly
# valid 200 serving a stale CDN copy of the previous deploy (04-RESEARCH
# Pitfall 8). For the same reason the retry loop is hand-written rather than
# delegated to curl's built-in retry flag, which only retries transport and
# 5xx errors -- a stale 200 would sail straight through it.
#
# After freshness succeeds, four route legs run once each (no per-leg retry:
# a slow content-delivery layer produces one bounded wait above, not five):
#   feed          -- the feed route answers with an RSS document
#   launch-post   -- the promoted launch post carries the same stamp as the
#                    homepage, proving it is part of this deployed build and
#                    not a surviving artifact of an older one
#   custom-404    -- a dead path under the base returns HTTP 404, serves the
#                    site's own 404 page, and carries the stamp (closes the
#                    live check deferred from Phase 2)
#   redirect-stub -- the demonstration stub's old URL serves the refresh
#                    directive (proves CONT-06 live)
#
# Retry budget is environment-tunable so CI and local runs share one script:
#   PROBE_ATTEMPTS (default 12) x PROBE_DELAY (default 15s) ~= a 3-minute
#   ceiling against deploys that normally finish in ~40s (STATE.md).
#
# The URL is always an argument -- never derived or hardcoded here (SITE-02).
# Plan 04-05's smoke job supplies the deploy action's own page_url output.
set -euo pipefail

if [ "$#" -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  echo "usage: $0 <base-url-ending-with-slash> <expected-sha> [launch-post-path] [feed-path] [redirect-stub-path]" >&2
  echo "  example: $0 https://example.github.io/repo/ \$(git rev-parse HEAD)" >&2
  exit 2
fi

# Normalized rather than trusted: every route leg concatenates onto this, so
# a slash-less base would fail with errors naming the routes, not the cause.
BASE_URL="${1%/}/"
EXPECTED_SHA="$2"
# Route arguments are optional and base-free (appended to BASE_URL). The
# defaults name the routes the site currently ships, so a future rename
# changes one default here rather than five call sites.
LAUNCH_POST_PATH="${3:-devlog/2026-07-30-first-burn/}"
FEED_PATH="${4:-rss.xml}"
STUB_PATH="${5:-devlog/2026-07-30-demo-old-slug/}"
PROBE_ATTEMPTS="${PROBE_ATTEMPTS:-12}"
PROBE_DELAY="${PROBE_DELAY:-15}"

# Every fetch in this script appends the same cache-busting query string, so a
# CDN edge cannot answer any leg from a cache entry older than this deploy.
BUST="?probe=${EXPECTED_SHA}"
STAMP="name=\"build-sha\" content=\"${EXPECTED_SHA}\""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for i in $(seq 1 "$PROBE_ATTEMPTS"); do
  # A curl failure (DNS, 404, 5xx) is treated the same as stale content:
  # not fresh yet, keep probing -- never converted into a pass.
  if curl -fsSL "${BASE_URL}${BUST}" | grep -q "$STAMP"; then
    echo "fresh after ${i} probe(s): ${BASE_URL} serves build-sha ${EXPECTED_SHA}"
    break
  fi
  if [ "$i" -eq "$PROBE_ATTEMPTS" ]; then
    fail "${BASE_URL} never served build-sha ${EXPECTED_SHA} after ${PROBE_ATTEMPTS} attempt(s)"
  fi
  sleep "$PROBE_DELAY"
done

# --- Route legs. Each captures its fetch explicitly: a failed fetch fails the
# leg with the URL named -- no captured value ever defaults to something that
# would then compare equal.

FEED_URL="${BASE_URL}${FEED_PATH}${BUST}"
FEED_BODY=$(curl -fsSL "$FEED_URL") || fail "feed leg: fetch failed: ${FEED_URL}"
grep -q '<rss' <<<"$FEED_BODY" \
  || fail "feed leg: ${FEED_URL} did not answer with an RSS document (expected '<rss')"
echo "feed leg passed: ${FEED_URL}"

POST_URL="${BASE_URL}${LAUNCH_POST_PATH}${BUST}"
POST_BODY=$(curl -fsSL "$POST_URL") || fail "launch-post leg: fetch failed: ${POST_URL}"
grep -q "$STAMP" <<<"$POST_BODY" \
  || fail "launch-post leg: ${POST_URL} does not carry build-sha ${EXPECTED_SHA}"
echo "launch-post leg passed: ${POST_URL}"

# Status and body are captured separately: the status must be 404, the body
# must be the site's own 404 page (its heading), and the body must carry the
# stamp -- a platform fallback error page would fail the second check.
NOT_FOUND_URL="${BASE_URL}definitely-not-a-page-${EXPECTED_SHA}/${BUST}"
NOT_FOUND_BODY_FILE=$(mktemp)
trap 'rm -f "$NOT_FOUND_BODY_FILE"' EXIT
NOT_FOUND_STATUS=$(curl -sS -o "$NOT_FOUND_BODY_FILE" -w '%{http_code}' "$NOT_FOUND_URL") \
  || fail "custom-404 leg: fetch failed: ${NOT_FOUND_URL}"
[ "$NOT_FOUND_STATUS" = "404" ] \
  || fail "custom-404 leg: ${NOT_FOUND_URL} returned HTTP ${NOT_FOUND_STATUS}, expected 404"
grep -q '<h1>Page not found.</h1>' "$NOT_FOUND_BODY_FILE" \
  || fail "custom-404 leg: ${NOT_FOUND_URL} body lacks the custom 404 page's heading"
grep -q "$STAMP" "$NOT_FOUND_BODY_FILE" \
  || fail "custom-404 leg: ${NOT_FOUND_URL} body does not carry build-sha ${EXPECTED_SHA}"
echo "custom-404 leg passed: ${NOT_FOUND_URL}"

STUB_URL="${BASE_URL}${STUB_PATH}${BUST}"
STUB_BODY=$(curl -fsSL "$STUB_URL") || fail "redirect-stub leg: fetch failed: ${STUB_URL}"
grep -q 'http-equiv="refresh"' <<<"$STUB_BODY" \
  || fail "redirect-stub leg: ${STUB_URL} lacks the refresh directive"
echo "redirect-stub leg passed: ${STUB_URL}"

echo "all live-probe legs passed against ${BASE_URL}"

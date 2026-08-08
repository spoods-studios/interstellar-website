#!/usr/bin/env bash
# Live freshness probe for SITE-03's post-deploy half (D-67/D-68).
#
# Usage: tests/live-probe.sh <base-url-ending-with-slash> <expected-sha>
#
# Succeeds only when the served page's body carries the D-68 build-sha stamp
# with exactly the expected SHA. An HTTP 200 alone is NEVER accepted as proof
# of freshness: the failure mode this probe exists to catch is a perfectly
# valid 200 serving a stale CDN copy of the previous deploy (04-RESEARCH
# Pitfall 8). For the same reason the retry loop is hand-written rather than
# delegated to curl's built-in retry flag, which only retries transport and
# 5xx errors -- a stale 200 would sail straight through it.
#
# Retry budget is environment-tunable so CI and local runs share one script:
#   PROBE_ATTEMPTS (default 12) x PROBE_DELAY (default 15s) ~= a 3-minute
#   ceiling against deploys that normally finish in ~40s (STATE.md).
#
# The URL is always an argument -- never derived or hardcoded here (SITE-02).
# Plan 04-05's smoke job supplies the deploy action's own page_url output.
set -euo pipefail

if [ "$#" -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  echo "usage: $0 <base-url-ending-with-slash> <expected-sha>" >&2
  echo "  example: $0 https://example.github.io/repo/ \$(git rev-parse HEAD)" >&2
  exit 2
fi

BASE_URL="$1"
EXPECTED_SHA="$2"
PROBE_ATTEMPTS="${PROBE_ATTEMPTS:-12}"
PROBE_DELAY="${PROBE_DELAY:-15}"

for i in $(seq 1 "$PROBE_ATTEMPTS"); do
  # The cache-busting query string is built from the expected SHA, so a CDN
  # edge cannot answer from a cache entry created before this deploy existed.
  # A curl failure (DNS, 404, 5xx) is treated the same as stale content:
  # not fresh yet, keep probing -- never converted into a pass.
  if curl -fsSL "${BASE_URL}?probe=${EXPECTED_SHA}" \
    | grep -q "name=\"build-sha\" content=\"${EXPECTED_SHA}\""; then
    echo "fresh after ${i} probe(s): ${BASE_URL} serves build-sha ${EXPECTED_SHA}"
    exit 0
  fi
  if [ "$i" -lt "$PROBE_ATTEMPTS" ]; then
    sleep "$PROBE_DELAY"
  fi
done

echo "FAIL: ${BASE_URL} never served build-sha ${EXPECTED_SHA} after ${PROBE_ATTEMPTS} attempt(s)" >&2
exit 1

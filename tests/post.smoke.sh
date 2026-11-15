#!/usr/bin/env bash
# Smoke-test harness for the shared PostLayout and TOC (D-13/D-42), exercised
# through the roadmap detail pages, the layout's remaining users.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Build =="
npm run build

BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
PAGE=dist/roadmap/m0.3/index.html
test -f "$PAGE"

echo "== PostLayout renders the back link to the roadmap =="
grep -qP "<a [^>]*href=\"${NORMALIZED_BASE}roadmap/\"[^>]*>Back to roadmap</a>" "$PAGE"

echo "ALL CHECKS PASSED"

#!/usr/bin/env bash
# Smoke-test harness for the shared PostLayout and TOC (D-13/D-42), exercised
# through the roadmap detail pages, the layout's remaining users.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Build =="
npm run build

PAGE=dist/roadmap/m0.3/index.html
test -f "$PAGE"

echo "== PostLayout renders the meta line, the TOC and the back link =="
grep -q 'class="meta">M0.3<' "$PAGE"
test "$(grep -o 'class="toc"' "$PAGE" | wc -l)" -ge 1
NAV=$(grep -o 'class="post-nav">.*' "$PAGE" | sed 's|</nav>.*|</nav>|')
grep -q 'Back to roadmap' <<<"$NAV"

echo "== No neighbour navigation and no breadcrumbs survive =="
if grep -q -e '&larr;' -e '&rarr;' -e '←' -e '→' <<<"$NAV"; then
  echo "FAIL: post-nav still carries a previous/next link"
  exit 1
fi
if grep -q 'class="breadcrumbs"' "$PAGE"; then
  echo "FAIL: roadmap detail page still renders breadcrumbs"
  exit 1
fi

echo "== No client JS beyond the sanctioned analytics tag (D-60/D-61) =="
test "$(grep -o '<script' "$PAGE" | wc -l)" -eq "$(grep -o 'gc\.zgo\.at' "$PAGE" | wc -l)"

echo "== No hardcoded host/base string under src/ (T-02-07) =="
if grep -rIn -e 'github\.io' -e '/interstellar-website' src/; then
  echo "FAIL: hardcoded host/base string under src/"
  exit 1
fi

echo "ALL CHECKS PASSED"

#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 04 (shared PostLayout, TOC, and the
# announcement post route -- CONT-02, D-11/D-13/D-14/D-15/D-42).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Build =="
npm run build

echo "== All nine announcements built =="
test "$(find dist/devlog -name index.html | wc -l)" -eq 9

echo "== Manifesto and a full-frontmatter post both exist =="
test -f dist/devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim/index.html
test -f dist/devlog/2026-07-13-making-mercury-precess/index.html

echo "== Manifesto renders its body H1 title and carries no fabricated milestone tag (D-14/D-11) =="
grep -q "Why I" dist/devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim/index.html
if grep -o 'class="meta">[^<]*' dist/devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim/index.html | grep -q 'M0\.'; then
  echo "FAIL: manifesto meta line fabricated a milestone tag"
  exit 1
fi

echo "== A milestone post's page carries its milestone tag and date (D-11) =="
grep -q "M0.3" dist/devlog/2026-06-05-a-moon-that-actually-orbits/index.html
grep -q "June 5, 2026" dist/devlog/2026-06-05-a-moon-that-actually-orbits/index.html

echo "== Back-to-archive link present (D-15) =="
test "$(grep -o 'Back to devblog' dist/devlog/2026-06-05-a-moon-that-actually-orbits/index.html | wc -l)" -ge 1

echo "== Neighbour navigation: oldest has next-only, newest has previous-only =="
OLDEST=dist/devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim/index.html
NEWEST=dist/devlog/2026-07-13-making-mercury-precess/index.html
grep -q 'class="post-nav"' "$OLDEST"
if grep -o 'class="post-nav">[^Z]*' "$OLDEST" | grep -q '&larr;'; then
  echo "FAIL: oldest post has a previous link"
  exit 1
fi
grep -q '&rarr;' "$OLDEST"
grep -q '&larr;' "$NEWEST"
if grep -o 'class="post-nav">[^Z]*' "$NEWEST" | grep -q '&rarr;'; then
  echo "FAIL: newest post has a next link"
  exit 1
fi

echo "== An embedded body image resolves to a real built asset (D-28) =="
IMG_POST=dist/devlog/2026-07-10-warping-without-losing-the-moon/index.html
test "$(grep -o '<img' "$IMG_POST" | wc -l)" -ge 1
SRC=$(grep -o 'src="[^"]*"' "$IMG_POST" | head -1 | sed 's/src="//;s/"$//')
ASSET_PATH="dist${SRC#/interstellar-website}"
test -f "$ASSET_PATH"

echo "== No client JS on any announcement page =="
test "$(grep -c '<script' dist/devlog/2026-04-13-before-the-galaxy-a-triangle/index.html)" -eq 0

echo "== No hardcoded host/base string under src/ (T-02-07) =="
! grep -rIn -e 'github\.io' -e '/interstellar-website' src/

echo "ALL CHECKS PASSED"

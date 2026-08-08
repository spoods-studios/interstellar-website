#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 04 (shared PostLayout, TOC, and the
# announcement post route -- CONT-02, D-11/D-13/D-14/D-15/D-42).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Build =="
npm run build

echo "== All ten announcements built =="
# CONT-06/D-65: redirect stubs (meta-refresh pages from astro.config.mjs's
# SLUG_REDIRECTS) land under dist/devlog/ too but are not announcement pages --
# exclude them by the same predicate the other harnesses use.
ANNOUNCEMENT_COUNT=0
while IFS= read -r f; do
  if grep -q 'http-equiv="refresh"' "$f"; then continue; fi
  ANNOUNCEMENT_COUNT=$((ANNOUNCEMENT_COUNT + 1))
done < <(find dist/devlog -name index.html)
test "$ANNOUNCEMENT_COUNT" -eq 10

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
NEWEST=dist/devlog/2026-07-30-first-burn/index.html
grep -q 'class="post-nav"' "$OLDEST"
# Bound the nav window at its own closing tag (cut at the first </nav>), not
# at an arbitrary content byte -- same anchoring as the breadcrumbs extraction
# in technical.smoke.sh.
OLDEST_NAV=$(grep -o 'class="post-nav">.*' "$OLDEST" | sed 's|</nav>.*|</nav>|')
if grep -q '&larr;' <<<"$OLDEST_NAV"; then
  echo "FAIL: oldest post has a previous link"
  exit 1
fi
grep -q '&rarr;' "$OLDEST"
grep -q '&larr;' "$NEWEST"
NEWEST_NAV=$(grep -o 'class="post-nav">.*' "$NEWEST" | sed 's|</nav>.*|</nav>|')
if grep -q '&rarr;' <<<"$NEWEST_NAV"; then
  echo "FAIL: newest post has a next link"
  exit 1
fi

echo "== An embedded body image resolves to a real built asset (D-28) =="
IMG_POST=dist/devlog/2026-07-10-warping-without-losing-the-moon/index.html
test "$(grep -o '<img' "$IMG_POST" | wc -l)" -ge 1
# Scope src= extraction to <img> tags: once the D-61 analytics script is
# configured, the page's first bare src= is the script's, not an image's.
SRC=$(grep -o '<img[^>]*src="[^"]*"' "$IMG_POST" | head -1 | grep -o 'src="[^"]*"' | sed 's/src="//;s/"$//')
ASSET_PATH="dist${SRC#/interstellar-website}"
test -f "$ASSET_PATH"

echo "== No client JS beyond the sanctioned analytics tag on any announcement page (D-60/D-61) =="
POST_JS_PAGE=dist/devlog/2026-04-13-before-the-galaxy-a-triangle/index.html
test "$(grep -o '<script' "$POST_JS_PAGE" | wc -l)" -eq "$(grep -o 'gc\.zgo\.at' "$POST_JS_PAGE" | wc -l)"

echo "== No hardcoded host/base string under src/ (T-02-07) =="
! grep -rIn -e 'github\.io' -e '/interstellar-website' src/

echo "ALL CHECKS PASSED"

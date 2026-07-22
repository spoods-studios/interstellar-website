#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 06 (technical deep-dive reading pages,
# how-to-read legend, full/per-milestone indexes, and D-35 bidirectional
# cross-links -- CONT-02).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Build =="
npm run build

echo "== All 55 deep-dives plus the legend built (56 technical pages) =="
test "$(find dist/technical -path 'dist/technical/m0.*/phase-*' -name index.html | wc -l)" -eq 55
test -f dist/technical/how-to-read/index.html

echo "== Spot-check the two decimal-numbered phases at the ends of the corpus =="
test -f dist/technical/m0.3/phase-14.5-swapchain-acquire-fix/index.html
test -f dist/technical/m0.8/phase-46.1-all-planet-validation-seeds/index.html

echo "== D-39: the phase-14.5 page's one real wikilink resolves to an internal anchor, no raw bracketed source survives =="
PAGE_14_5="dist/technical/m0.3/phase-14.5-swapchain-acquire-fix/index.html"
grep -q 'href="/interstellar-website/technical/m0.1/phase-03-rendering-pipeline/"' "$PAGE_14_5"
if grep -q '\[\[' "$PAGE_14_5"; then
  echo "FAIL: raw bracketed wikilink source text survived in $PAGE_14_5"
  exit 1
fi

echo "== T-02-12: the C++ [[nodiscard]] attribute renders verbatim inside a code element, untouched by the wikilink plugin =="
NODISCARD_PAGE="dist/technical/m0.2/phase-07-core-vector-types/index.html"
test "$(grep -c '<pre' "$NODISCARD_PAGE")" -ge 1
if ! sed 's/<[^>]*>//g' "$NODISCARD_PAGE" | grep -q '\[\[nodiscard\]\]'; then
  echo "FAIL: [[nodiscard]] did not render verbatim in $NODISCARD_PAGE"
  exit 1
fi

echo "== Shiki light-theme inline styles present, zero client JS =="
PAGE_01="dist/technical/m0.1/phase-01-window-surface/index.html"
grep -q 'background-color:#fff' "$PAGE_01"
test "$(grep -c '<script' "$PAGE_01")" -eq 0
test "$(grep -c '<script' dist/technical/how-to-read/index.html)" -eq 0

echo "== Body H1 title and milestone/phase meta line, no fabricated date (D-33) =="
grep -q 'Phase 14.5' "$PAGE_14_5"
grep -q 'Swapchain Acquire Fix' "$PAGE_14_5"
META_LINE=$(grep -o 'class="meta">[^<]*' "$PAGE_14_5")
echo "$META_LINE"
if echo "$META_LINE" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}|January|February|March|April|May|June|July|August|September|October|November|December'; then
  echo "FAIL: technical deep-dive meta line contains a fabricated date"
  exit 1
fi

echo "== D-35: a deep-dive page carries both breadcrumbs (announcement + roadmap) =="
BREADCRUMBS=$(grep -o 'class="breadcrumbs">.*</nav>' "$PAGE_14_5")
echo "$BREADCRUMBS" | grep -q 'devlog/2026-06-05-a-moon-that-actually-orbits'
echo "$BREADCRUMBS" | grep -q 'roadmap/m0.3'

echo "== No hardcoded host/base string under src/ (T-02-07) =="
! grep -rIn -e 'github\.io' -e '/interstellar-website' src/

echo "== D-40: full index links all 55 deep-dives, links the legend, and carries a data-driven era heading =="
test -f dist/technical/index.html
test "$(grep -o 'href="[^"]*technical/m0\.[0-9]*\(\.[0-9]*\)\?/phase-[^"]*"' dist/technical/index.html | wc -l)" -eq 55
grep -q 'technical/how-to-read/' dist/technical/index.html
grep -q 'Era 0 (engine foundations)' dist/technical/index.html

echo "== Eight per-milestone index pages exist =="
for m in m0.1 m0.2 m0.3 m0.4 m0.5 m0.6 m0.7 m0.8; do
  test -f "dist/technical/$m/index.html"
done

echo "== D-34: decimal phase numbers sort between their integer neighbours, not lexically =="
M03_IDX="dist/technical/m0.3/index.html"
OFF14=$(grep -boF 'phase-14-threading-coordinate-integration' "$M03_IDX" | head -1 | cut -d: -f1)
OFF145=$(grep -boF 'phase-14.5-swapchain-acquire-fix' "$M03_IDX" | head -1 | cut -d: -f1)
OFF15=$(grep -boF 'phase-15-validation' "$M03_IDX" | head -1 | cut -d: -f1)
test "$OFF14" -lt "$OFF145"
test "$OFF145" -lt "$OFF15"

M08_IDX="dist/technical/m0.8/index.html"
OFF46=$(grep -boF 'phase-46-perturbation' "$M08_IDX" | head -1 | cut -d: -f1)
OFF461=$(grep -boF 'phase-46.1-all-planet' "$M08_IDX" | head -1 | cut -d: -f1)
OFF47=$(grep -boF 'phase-47-findings' "$M08_IDX" | head -1 | cut -d: -f1)
test "$OFF46" -lt "$OFF461"
test "$OFF461" -lt "$OFF47"

echo "== D-35: an announcement page lists its milestone's deep-dives, isVisible-filtered =="
M03_POST="dist/devlog/2026-06-05-a-moon-that-actually-orbits/index.html"
test "$(grep -o 'href="[^"]*technical/m0\.3/[^"]*"' "$M03_POST" | wc -l)" -eq 8

echo "== The manifesto (no milestone) carries no deep-dive list =="
if grep -q 'Technical deep-dives for this milestone' dist/devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim/index.html; then
  echo "FAIL: manifesto page carries a deep-dive list despite having no milestone"
  exit 1
fi

echo "== Zero client JS on the full index =="
test "$(grep -c '<script' dist/technical/index.html)" -eq 0

echo "ALL CHECKS PASSED"

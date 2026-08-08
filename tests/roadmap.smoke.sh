#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 07 (roadmap detail pages with resolved
# deep-dive links, the roadmap overview, and the How It's Made standalone
# page -- CONT-03/CONT-04).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Build =="
npm run build

echo "== Nine roadmap detail pages built =="
for m in m0.1 m0.2 m0.3 m0.4 m0.5 m0.6 m0.7 m0.8 m1.1; do
  test -f "dist/roadmap/$m/index.html"
done

echo "== A detail page contains its milestone name, phase headings, and a TOC =="
M03_PAGE="dist/roadmap/m0.3/index.html"
grep -q 'M0.3' "$M03_PAGE"
grep -q 'Force Model' "$M03_PAGE"
grep -q 'Integrator Core' "$M03_PAGE"
test "$(grep -c 'class="toc"' "$M03_PAGE")" -ge 1

echo "== Discord-era placeholder wording survives nowhere in built roadmap pages =="
if grep -rq 'technical-devlog' dist/roadmap/; then
  echo "FAIL: Discord-era placeholder text survived in dist/roadmap/"
  exit 1
fi

echo "== Each roadmap detail page carries at least one anchor into its own milestone's technical tree =="
for m in m0.1 m0.2 m0.3 m0.4 m0.5 m0.6 m0.7 m0.8 m1.1; do
  COUNT=$(grep -o "href=\"[^\"]*technical/$m/[^\"]*\"" "dist/roadmap/$m/index.html" | wc -l)
  test "$COUNT" -ge 1
done

echo "== M0.3 detail page carries at least 8 anchors into technical/m0.3/ =="
test "$(grep -o 'href="[^"]*technical/m0\.3/[^"]*"' "$M03_PAGE" | wc -l)" -ge 8

echo "== A breadcrumb to the M0.1 announcement is present =="
grep -q 'devlog/2026-04-13-before-the-galaxy-a-triangle' dist/roadmap/m0.1/index.html

echo "== No client JS beyond the analytics tag on roadmap detail pages (D-60/D-61) =="
RM_PAGE=dist/roadmap/m0.1/index.html
test "$(grep -o '<script' "$RM_PAGE" | wc -l)" -eq "$(grep -o 'gc\.zgo\.at' "$RM_PAGE" | wc -l)"

echo "== Roadmap overview and How It's Made standalone pages both build =="
test -f dist/roadmap/index.html
test -f dist/how-its-made/index.html

echo "== Overview carries exactly 9 generated milestone links, including the M1.1 detail link =="
OVERVIEW="dist/roadmap/index.html"
# Href regex widened off the m0 anchor (04-02) so a new milestone's link counts.
test "$(grep -o 'href="[^"]*roadmap/m[0-9]*\.[0-9]*/"' "$OVERVIEW" | sort -u | wc -l)" -eq 9
# Inverted from the pre-promote negative (04-02): src/pages/roadmap/index.astro
# generates one link per visible roadmap collection entry, so once roadmap/M1.1.md
# is promoted this link is required, not forbidden.
grep -q 'roadmap/m1\.1' "$OVERVIEW"

echo "== Overview carries the authored era-arc prose, presents M1.1 as closed, and names M1.2 as next =="
grep -q 'Era 0' "$OVERVIEW"
grep -q 'Era 1' "$OVERVIEW"
M11_ROW=$(grep -o '<strong>M1.1 Spacecraft Control</strong>[^<]*' "$OVERVIEW" | head -1)
echo "$M11_ROW" | grep -q '✅'
if echo "$M11_ROW" | grep -qi 'in progress'; then
  echo "FAIL: overview still presents M1.1 as in progress"
  exit 1
fi
M12_ROW=$(grep -o '<strong>M1.2[^<]*</strong>[^<]*' "$OVERVIEW" | head -1)
echo "$M12_ROW" | grep -qi 'next'

echo "== How It's Made page carries its title and a last-updated meta line =="
HIM="dist/how-its-made/index.html"
grep -q 'How It' "$HIM"
grep -oE 'class="meta">Last updated: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$HIM"

echo "== Neither standalone page's slug appears in the archive's post list (nav chrome is exempt -- scope to <main>) =="
ARCHIVE_MAIN=$(grep -o '<main>.*</main>' dist/index.html)
if echo "$ARCHIVE_MAIN" | grep -q 'how-its-made\|/roadmap/'; then
  echo "FAIL: a standalone page slug leaked into the archive's post list"
  exit 1
fi

echo "== No client JS beyond the analytics tag on the overview and How It's Made pages (D-60/D-61) =="
test "$(grep -o '<script' "$OVERVIEW" | wc -l)" -eq "$(grep -o 'gc\.zgo\.at' "$OVERVIEW" | wc -l)"
test "$(grep -o '<script' "$HIM" | wc -l)" -eq "$(grep -o 'gc\.zgo\.at' "$HIM" | wc -l)"

echo "ALL CHECKS PASSED"

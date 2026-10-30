#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 07 (roadmap detail pages, the roadmap
# and the roadmap overview -- CONT-03/CONT-04).
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

echo "== No roadmap page links to a devlog announcement =="
if grep -rq 'devlog/' dist/roadmap/; then
  echo "FAIL: a built roadmap page still links into devlog/"
  exit 1
fi

echo "== No client JS beyond the analytics tag on roadmap detail pages (D-60/D-61) =="
RM_PAGE=dist/roadmap/m0.1/index.html
test "$(grep -o '<script' "$RM_PAGE" | wc -l)" -eq "$(grep -o 'gc\.zgo\.at' "$RM_PAGE" | wc -l)"

echo "== Roadmap overview builds =="
test -f dist/roadmap/index.html

echo "== Overview carries a generated milestone link per roadmap entry, including the M1.1 detail link =="
OVERVIEW="dist/roadmap/index.html"
# Href regex widened off the m0 anchor (04-02) so a new milestone's link counts.
EXPECTED_ROADMAP_LINKS=$(node tests/helpers/content-expectations.mjs roadmap_count)
test "$(grep -o 'href="[^"]*roadmap/m[0-9]*\.[0-9]*/"' "$OVERVIEW" | sort -u | wc -l)" -eq "$EXPECTED_ROADMAP_LINKS"
# Inverted from the pre-promote negative (04-02): src/pages/roadmap/index.astro
# generates one link per visible roadmap collection entry, so once roadmap/M1.1.md
# is promoted this link is required, not forbidden.
grep -q 'roadmap/m1\.1' "$OVERVIEW"

echo "== Overview carries the authored era-arc prose and presents every promoted milestone as closed =="
# Only completed milestones are ever promoted into roadmap/ -- unlike a
# fixed "M1.2 is next" pin (which goes stale the moment M1.2 itself ships),
# this holds for every row regardless of how many milestones land.
grep -q 'Era 0' "$OVERVIEW"
grep -q 'Era 1' "$OVERVIEW"
if grep -qi 'devblog announcement' "$OVERVIEW"; then
  echo "FAIL: overview still promises a devblog announcement"
  exit 1
fi
M11_ROW=$(grep -o '<strong>M1.1 Spacecraft Control</strong>[^<]*' "$OVERVIEW" | head -1)
echo "$M11_ROW" | grep -q '✅'
if echo "$M11_ROW" | grep -qi 'in progress'; then
  echo "FAIL: overview still presents M1.1 as in progress"
  exit 1
fi
while IFS= read -r ROW; do
  if ! echo "$ROW" | grep -q '✅'; then
    echo "FAIL: a promoted roadmap row is not marked closed: $ROW"
    exit 1
  fi
  if echo "$ROW" | grep -qi 'in progress'; then
    echo "FAIL: a promoted roadmap row still presents as in progress: $ROW"
    exit 1
  fi
done < <(grep -o '<strong>M[0-9][^<]*</strong>[^<]*' "$OVERVIEW")

echo "== No client JS beyond the analytics tag on the overview (D-60/D-61) =="
test "$(grep -o '<script' "$OVERVIEW" | wc -l)" -eq "$(grep -o 'gc\.zgo\.at' "$OVERVIEW" | wc -l)"

echo "ALL CHECKS PASSED"

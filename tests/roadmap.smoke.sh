#!/usr/bin/env bash
# Smoke-test harness for Phase 2 Plan 07 (roadmap detail pages with resolved
# deep-dive links, the roadmap overview, and the How It's Made standalone
# page -- CONT-03/CONT-04).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Build =="
npm run build

echo "== Eight roadmap detail pages built =="
for m in m0.1 m0.2 m0.3 m0.4 m0.5 m0.6 m0.7 m0.8; do
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
for m in m0.1 m0.2 m0.3 m0.4 m0.5 m0.6 m0.7 m0.8; do
  COUNT=$(grep -o "href=\"[^\"]*technical/$m/[^\"]*\"" "dist/roadmap/$m/index.html" | wc -l)
  test "$COUNT" -ge 1
done

echo "== M0.3 detail page carries at least 8 anchors into technical/m0.3/ =="
test "$(grep -o 'href="[^"]*technical/m0\.3/[^"]*"' "$M03_PAGE" | wc -l)" -ge 8

echo "== A breadcrumb to the M0.1 announcement is present =="
grep -q 'devlog/2026-04-13-before-the-galaxy-a-triangle' dist/roadmap/m0.1/index.html

echo "== Zero client JS on roadmap detail pages =="
test "$(grep -c '<script' dist/roadmap/m0.1/index.html)" -eq 0

echo "== Roadmap overview and How It's Made standalone pages both build =="
test -f dist/roadmap/index.html
test -f dist/how-its-made/index.html

echo "== Overview carries exactly 8 generated milestone links, zero M1.1 detail link =="
OVERVIEW="dist/roadmap/index.html"
test "$(grep -o 'href="[^"]*roadmap/m0\.[0-9]*/"' "$OVERVIEW" | sort -u | wc -l)" -eq 8
if grep -q 'roadmap/m1\.1' "$OVERVIEW"; then
  echo "FAIL: overview links to a nonexistent M1.1 roadmap detail page"
  exit 1
fi

echo "== Overview carries the authored era-arc prose and mentions M1.1 as in progress =="
grep -q 'Era 0' "$OVERVIEW"
grep -q 'Era 1' "$OVERVIEW"
grep -q 'M1.1' "$OVERVIEW"

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

echo "== Zero client JS on the overview and How It's Made pages =="
test "$(grep -c '<script' "$OVERVIEW")" -eq 0
test "$(grep -c '<script' "$HIM")" -eq 0

echo "ALL CHECKS PASSED"

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

echo "ALL CHECKS PASSED"

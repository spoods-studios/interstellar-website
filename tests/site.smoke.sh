#!/usr/bin/env bash
# Whole-site smoke harness for Phase 2 Plan 08. Task 1: SITE-04 close-out
# sweep -- canonical coverage, sitemap completeness, dead-link sweep, zero
# client JS. Task 2: trap-and-restore fixtures proving the D-39 (unresolvable
# wikilink), D-30 (draft leak into generated cross-link chrome) and
# roadmap-deep-dive-resolution loud-fail paths against the real build, not
# just tests/lib.smoke.mjs's isolated markdownToHtml() calls. Every other
# tests/*.smoke.sh file proves its own plan's slice; this is the only script
# that proves the whole site, because Plans 05, 06 and 07 each generated
# links into routes another plan owned -- no single plan's harness can catch
# that kind of cross-plan breakage.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Clean build =="
rm -rf dist
npm run build

# --- Derive the expected canonical/sitemap URL prefix from astro.config.mjs
# itself (SITE-02: the site/base live in one config location, never a literal
# repeated here). ---
SITE=$(grep -oP "site:\s*'\K[^']+" astro.config.mjs)
BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
PREFIX="${SITE}${NORMALIZED_BASE}"
echo "expected canonical/sitemap prefix: $PREFIX"

# CONT-06/D-65: redirect stubs are machine-facing artifacts, not pages a
# reader lands on -- Astro's stub template carries a refresh directive and
# none of the reader-facing chrome. Every sweep below that asserts a
# reader-facing per-page invariant skips them by this predicate; the stub's
# own contract is asserted in tests/hardening.smoke.sh instead. The invariants
# themselves are unchanged -- this is a page-selection predicate only.
is_redirect_stub() {
  grep -q 'http-equiv="refresh"' "$1"
}

echo "== Canonical coverage: every built page carries exactly one canonical link, base-prefixed =="
CANON_FAIL=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
  COUNT=$(grep -o '<link rel="canonical"' "$f" | wc -l)
  if [ "$COUNT" -ne 1 ]; then
    echo "FAIL: $f has $COUNT canonical link elements (expected exactly 1)"
    CANON_FAIL=1
    continue
  fi
  HREF=$(grep -o '<link rel="canonical" href="[^"]*"' "$f" | sed -E 's/.*href="([^"]*)".*/\1/')
  case "$HREF" in
    "$PREFIX"*) ;;
    *)
      echo "FAIL: $f canonical href '$HREF' does not carry the expected prefix '$PREFIX'"
      CANON_FAIL=1
      ;;
  esac
done < <(find dist -name "*.html")
[ "$CANON_FAIL" -eq 0 ]
echo "canonical coverage OK"

echo "== Sitemap completeness: URL count matches built page count (404 excluded), all base-prefixed =="
ls dist/sitemap*.xml >/dev/null
SITEMAP_FILE="dist/sitemap-0.xml"
[ -f "$SITEMAP_FILE" ] || SITEMAP_FILE="dist/sitemap.xml"
SITEMAP_URLS=$(grep -o '<loc>[^<]*</loc>' "$SITEMAP_FILE" | wc -l)
# Redirect stubs are subtracted on the same predicate terms as every other
# sweep, so this stays an EQUALITY between reader-facing pages and sitemap
# entries -- never loosened to an inequality.
BUILT_PAGES=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
  BUILT_PAGES=$((BUILT_PAGES + 1))
done < <(find dist -name "*.html" ! -name "404.html")
if [ "$SITEMAP_URLS" -ne "$BUILT_PAGES" ]; then
  echo "FAIL: sitemap lists $SITEMAP_URLS URLs but $BUILT_PAGES non-404 reader-facing pages were built (counts must match)"
  exit 1
fi
if ! grep -q "$PREFIX" "$SITEMAP_FILE"; then
  echo "FAIL: sitemap URLs do not carry the expected prefix $PREFIX"
  exit 1
fi
echo "sitemap OK ($SITEMAP_URLS sitemap URLs == $BUILT_PAGES built non-404 pages)"

echo "== Favicon reference on every built page =="
FAVICON_FAIL=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
  grep -q 'favicon.svg' "$f" || { echo "FAIL: $f has no favicon reference"; FAVICON_FAIL=1; }
done < <(find dist -name "*.html")
[ "$FAVICON_FAIL" -eq 0 ]
echo "favicon coverage OK"

echo "== Every script tag anywhere in dist/ is the sanctioned analytics tag (D-60/D-61) =="
# State-free: while GOATCOUNTER_CODE is unset both totals are zero; once it is
# set both are one per page. A stray script breaks it in either state.
test "$(grep -ro '<script' dist/ | wc -l)" -eq "$(grep -ro 'gc\.zgo\.at' dist/ | wc -l)"
echo "no-extra-JS OK"

echo "== Dead-link sweep: every internal href resolves to a real file in dist/ =="
DEADLINKS_LOG=/tmp/gsd-site-deadlinks.log
: > "$DEADLINKS_LOG"
while IFS= read -r f; do
  while IFS= read -r href; do
    case "$href" in
      ""|\#*|http://*|https://*|mailto:*) continue ;;
    esac
    path="${href%%#*}"
    case "$path" in
      "$BASE"*) rel="${path#"$BASE"}" ;;
      *) rel="$path" ;;
    esac
    rel="${rel#/}"
    if [ -z "$rel" ]; then
      target="dist/index.html"
    elif [[ "$rel" == */ ]]; then
      target="dist/${rel}index.html"
    elif [ -d "dist/${rel}" ]; then
      target="dist/${rel}/index.html"
    else
      target="dist/${rel}"
    fi
    if [ ! -f "$target" ]; then
      echo "DEAD LINK: $href (in $f) -> looked for $target" >> "$DEADLINKS_LOG"
    fi
  done < <(grep -o 'href="[^"]*"' "$f" | sed -E 's/^href="//; s/"$//')
done < <(find dist -name "*.html")
if [ -s "$DEADLINKS_LOG" ]; then
  cat "$DEADLINKS_LOG"
  echo "dead-link sweep FAILED"
  exit 1
fi
echo "dead-link sweep OK (zero dead internal targets)"

echo "== Expected total page count sanity check (four trees + indexes + standalone + error pages) =="
# Composed by tests/helpers/content-expectations.mjs from the four content
# trees plus the route-shaped structural singletons (technical index, one
# per-milestone technical index, roadmap overview, how-its-made, homepage,
# 404) -- see its site_page_count derivation for the exact arithmetic. The
# two Plan 02-03 diagnostic routes (collection-counts.json.ts,
# markdown-render-check.astro) are already deleted, so they're not counted.
EXPECTED_PAGES=$(node tests/helpers/content-expectations.mjs site_page_count)
# The enumeration above counts reader-facing pages; redirect stubs (CONT-06)
# are excluded on the same predicate terms as every other sweep.
ACTUAL_PAGES=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
  ACTUAL_PAGES=$((ACTUAL_PAGES + 1))
done < <(find dist -name "*.html")
if [ "$ACTUAL_PAGES" -ne "$EXPECTED_PAGES" ]; then
  echo "FAIL: expected $EXPECTED_PAGES built reader-facing HTML pages, found $ACTUAL_PAGES"
  exit 1
fi
echo "page count OK ($ACTUAL_PAGES)"

echo "== Diagnostic routes from Plan 02-03 are gone (orchestrator note) =="
[ ! -f dist/collection-counts.json ]
[ ! -d dist/markdown-render-check ]
echo "diagnostic routes absent OK"

echo "== D-39 fixture: an unresolvable wikilink in a technical document fails the build loudly, naming the file and the link =="
D39_FILE="technical/m0.1/phase-06-ci-pipeline.md"
D39_BACKUP=$(mktemp)
cp "$D39_FILE" "$D39_BACKUP"
trap 'cp "$D39_BACKUP" "$D39_FILE" 2>/dev/null || true; rm -f "$D39_BACKUP"' EXIT
printf '\nDangling [[m9.9/phase-99-does-not-exist]] link.\n' >> "$D39_FILE"
if npm run build > /tmp/gsd-site-d39.log 2>&1; then
  cp "$D39_BACKUP" "$D39_FILE"
  echo "D-39 FIXTURE FAIL: build did not error on an unresolvable wikilink"
  exit 1
fi
grep -q "phase-06-ci-pipeline.md" /tmp/gsd-site-d39.log
grep -q "m9.9/phase-99-does-not-exist" /tmp/gsd-site-d39.log
cp "$D39_BACKUP" "$D39_FILE"
if git status --porcelain devlog/ technical/ roadmap/ pages/ | grep -q .; then
  echo "D-39 FIXTURE FAIL: a content tree was left dirty"
  exit 1
fi
echo "D-39 fixture OK: build failed loudly naming the file and the unresolved link; content trees clean"

echo "== D-30 fixture: a drafted technical entry disappears from the milestone index, the full index, and its announcement's deep-dive list =="
D30_FILE="technical/m0.4/phase-19-n-body-direct-force.md"
D30_BACKUP=$(mktemp)
cp "$D30_FILE" "$D30_BACKUP"
trap 'cp "$D30_BACKUP" "$D30_FILE" 2>/dev/null || true; rm -f "$D30_BACKUP"' EXIT
{ printf -- '---\nstatus: draft\n---\n\n'; cat "$D30_BACKUP"; } > "$D30_FILE"
npm run build
D30_LEAK=0
if grep -q 'phase-19-n-body-direct-force' dist/technical/m0.4/index.html; then
  echo "D-30 FIXTURE FAIL: drafted entry leaked into the m0.4 milestone index"
  D30_LEAK=1
fi
if grep -q 'phase-19-n-body-direct-force' dist/technical/index.html; then
  echo "D-30 FIXTURE FAIL: drafted entry leaked into the full technical index"
  D30_LEAK=1
fi
if grep -q 'phase-19-n-body-direct-force' dist/devlog/2026-06-14-from-one-world-to-many/index.html; then
  echo "D-30 FIXTURE FAIL: drafted entry leaked into its milestone announcement's deep-dive list"
  D30_LEAK=1
fi
if [ -f dist/technical/m0.4/phase-19-n-body-direct-force/index.html ]; then
  echo "D-30 FIXTURE FAIL: drafted entry's own page still built"
  D30_LEAK=1
fi
cp "$D30_BACKUP" "$D30_FILE"
if [ "$D30_LEAK" -ne 0 ]; then
  exit 1
fi
if git status --porcelain devlog/ technical/ roadmap/ pages/ | grep -q .; then
  echo "D-30 FIXTURE FAIL: a content tree was left dirty"
  exit 1
fi
echo "D-30 fixture OK: drafted entry absent from all three generated lists; content trees clean"

echo "== Deep-dive resolution fixture: renumbering a technical file breaks its roadmap phase link, failing loudly and naming the roadmap file =="
DD_FILE="technical/m0.2/phase-08-layer-conversions.md"
DD_RENAMED="technical/m0.2/phase-80-layer-conversions.md"
trap 'mv "$DD_RENAMED" "$DD_FILE" 2>/dev/null || true' EXIT
mv "$DD_FILE" "$DD_RENAMED"
if npm run build > /tmp/gsd-site-deepdive.log 2>&1; then
  mv "$DD_RENAMED" "$DD_FILE"
  echo "DEEP-DIVE FIXTURE FAIL: build did not error on the broken roadmap phase resolution"
  exit 1
fi
grep -q "roadmap/M0.2.md" /tmp/gsd-site-deepdive.log
mv "$DD_RENAMED" "$DD_FILE"
if git status --porcelain devlog/ technical/ roadmap/ pages/ | grep -q .; then
  echo "DEEP-DIVE FIXTURE FAIL: a content tree was left dirty"
  exit 1
fi
echo "deep-dive resolution fixture OK: build failed loudly naming the offending roadmap file; content trees clean"

trap - EXIT

echo "== Final clean rebuild after all fixtures restored =="
npm run build
if git status --porcelain devlog/ technical/ roadmap/ pages/ | grep -q .; then
  echo "FAIL: content trees not clean after the full fixture run"
  exit 1
fi

echo "ALL CHECKS PASSED"

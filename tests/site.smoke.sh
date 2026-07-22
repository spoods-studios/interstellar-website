#!/usr/bin/env bash
# Whole-site smoke harness for Phase 2 Plan 08 (SITE-04 close-out sweep --
# canonical coverage, sitemap completeness, dead-link sweep, zero client JS).
# Every other tests/*.smoke.sh file proves its own plan's slice; this is the
# only script that proves the whole site, because Plans 05, 06 and 07 each
# generated links into routes another plan owned -- no single plan's harness
# can catch that kind of cross-plan breakage.
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

echo "== Canonical coverage: every built page carries exactly one canonical link, base-prefixed =="
CANON_FAIL=0
while IFS= read -r f; do
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
BUILT_PAGES=$(find dist -name "*.html" ! -name "404.html" | wc -l)
if [ "$SITEMAP_URLS" -ne "$BUILT_PAGES" ]; then
  echo "FAIL: sitemap lists $SITEMAP_URLS URLs but $BUILT_PAGES non-404 pages were built (counts must match)"
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
  grep -q 'favicon.svg' "$f" || { echo "FAIL: $f has no favicon reference"; FAVICON_FAIL=1; }
done < <(find dist -name "*.html")
[ "$FAVICON_FAIL" -eq 0 ]
echo "favicon coverage OK"

echo "== Zero client JS anywhere in dist/ =="
test "$(grep -rl '<script' dist/ | wc -l)" -eq 0
echo "zero-JS OK"

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
# devlog 9 + technical 55 deep-dives + how-to-read 1 + technical indexes 9
# (full + 8 per-milestone) + roadmap 8 detail + roadmap overview 1 +
# how-its-made 1 + homepage 1 + 404 1 = 86. The two Plan 02-03 diagnostic
# routes (collection-counts.json.ts, markdown-render-check.astro) are already
# deleted, so they're not counted here.
EXPECTED_PAGES=86
ACTUAL_PAGES=$(find dist -name "*.html" | wc -l)
if [ "$ACTUAL_PAGES" -ne "$EXPECTED_PAGES" ]; then
  echo "FAIL: expected $EXPECTED_PAGES built HTML pages, found $ACTUAL_PAGES"
  exit 1
fi
echo "page count OK ($ACTUAL_PAGES)"

echo "== Diagnostic routes from Plan 02-03 are gone (orchestrator note) =="
[ ! -f dist/collection-counts.json ]
[ ! -d dist/markdown-render-check ]
echo "diagnostic routes absent OK"

echo "ALL CHECKS PASSED"

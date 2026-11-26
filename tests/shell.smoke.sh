#!/usr/bin/env bash
# Smoke-test harness for the site shell (BaseLayout, self-hosted fonts,
# favicon, 404). Every assertion runs against a clean build's dist/ output.
set -euo pipefail

cd "$(dirname "$0")/.."
. tests/helpers/build.sh

echo "== Clean build =="
build_site

BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
INVITE=$(site_value DISCORD_INVITE_URL)

is_redirect_stub() {
  grep -q 'http-equiv="refresh"' "$1"
}

count_occurrences() {
  local n
  n=$(grep -o "$1" <<<"$2" | wc -l) || n=0
  printf '%s' "$n"
}

echo "== 404 page and favicon land at the artifact root =="
test -f dist/404.html
test -f dist/favicon.svg

echo "== 404 keeps its heading and renders through the shell =="
grep -q '<h1>Page not found.</h1>' dist/404.html
grep -q "<a href=\"${NORMALIZED_BASE}\">Go to the home page</a>" dist/404.html

echo "== Footer and running head on every page =="
SHELL_FAIL=0
PAGES=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
  PAGES=$((PAGES + 1))
  HTML=$(tr '\n' ' ' < "$f")

  FOOTER_HTML=$(grep -oP '<footer\b.*?</footer>' <<<"$HTML" || true)
  if [ "$(grep -c . <<<"$FOOTER_HTML")" -ne 1 ]; then
    echo "FAIL: $f does not carry exactly one <footer>"
    SHELL_FAIL=1
  fi

  HEAD_HTML=$(grep -oP '<header\b.*?</header>' <<<"$HTML" || true)
  if [ -z "$HEAD_HTML" ]; then
    echo "FAIL: $f has no <header> running head"
    SHELL_FAIL=1
    continue
  fi
  if ! grep -qP "<a [^>]*href=\"${NORMALIZED_BASE}\"" <<<"$HEAD_HTML"; then
    echo "FAIL: $f running head has no link to the site root"
    SHELL_FAIL=1
  fi
  NAV_HTML=$(grep -oP '<nav>.*?</nav>' <<<"$HEAD_HTML" || true)
  NAV_LINKS=$(grep -oP '<a [^>]*>.*?</a>' <<<"$NAV_HTML" || true)
  ROADMAP_LINK=$(grep -F "href=\"${NORMALIZED_BASE}roadmap/\"" <<<"$NAV_LINKS" || true)
  FEEDBACK_LINK=$(grep -F "href=\"${NORMALIZED_BASE}feedback/\"" <<<"$NAV_LINKS" || true)
  CTA_LINK=$(grep -F "href=\"${INVITE}\"" <<<"$NAV_LINKS" || true)
  if [ -z "$ROADMAP_LINK" ] || [ -z "$FEEDBACK_LINK" ] || [ -z "$CTA_LINK" ]; then
    echo "FAIL: $f header nav lacks the Roadmap link, the Feedback link or the Discord invite"
    SHELL_FAIL=1
    continue
  fi
  CURRENT_LINK=""
  case "$f" in
    dist/roadmap/*) CURRENT_LINK=$ROADMAP_LINK ;;
    dist/feedback/*) CURRENT_LINK=$FEEDBACK_LINK ;;
  esac
  if [ "$(count_occurrences 'aria-current' "$HEAD_HTML")" -ne "$(count_occurrences 'aria-current="page"' "$CURRENT_LINK")" ]; then
    echo "FAIL: $f running head carries aria-current outside the link of the page being viewed"
    SHELL_FAIL=1
  fi
  if [ -n "$CURRENT_LINK" ] && ! grep -qF 'aria-current="page"' <<<"$CURRENT_LINK"; then
    echo "FAIL: $f nav link of the page being viewed lacks aria-current=\"page\""
    SHELL_FAIL=1
  fi
  for want in "href=\"${INVITE}\"" 'target="_blank"' 'rel="noopener noreferrer"' 'Join the Discord</a>'; do
    if ! grep -qF "$want" <<<"$CTA_LINK"; then
      echo "FAIL: $f Discord CTA lacks $want"
      SHELL_FAIL=1
    fi
  done
done < <(find dist -name '*.html')
[ "$PAGES" -gt 0 ]
[ "$SHELL_FAIL" -eq 0 ]
echo "shell OK across $PAGES pages"

echo "== No page or stylesheet references Google Fonts =="
if grep -rlE 'fonts\.googleapis\.com|fonts\.gstatic\.com' dist; then
  echo "FAIL: built output references Google Fonts"
  exit 1
fi

echo "== Every woff2 font the built output references ships under the base =="
mapfile -t FONT_URLS < <(grep -rhoE 'url\([^)]*\.woff2[^)]*\)' dist --include='*.css' --include='*.html' | sed -E "s/^url\([\"']?//; s/[\"']?\)$//" | sort -u)
if [ "${#FONT_URLS[@]}" -eq 0 ]; then
  echo "FAIL: the built output references no woff2 font"
  exit 1
fi
for url in "${FONT_URLS[@]}"; do
  case $url in
    "${NORMALIZED_BASE}_astro/"*) ;;
    *) echo "FAIL: font $url is not under ${NORMALIZED_BASE}_astro/"; exit 1 ;;
  esac
  if [ ! -f "dist/${url#"$NORMALIZED_BASE"}" ]; then
    echo "FAIL: font $url does not resolve to a built file"
    exit 1
  fi
done
FONT_DISPLAY=$(grep -rhoE 'font-display: *[a-z]+' dist --include='*.css' --include='*.html' | tr -d ' ' | sort -u)
if [ "$FONT_DISPLAY" != "font-display:swap" ]; then
  echo "FAIL: built @font-face rules use '$FONT_DISPLAY', expected only font-display: swap"
  exit 1
fi

echo "== Perf log prints one structured page-load metric =="
PERF_OUT=$(bash tools/perf-log.sh)
node -e '
const out = process.argv[1];
const lines = out.split("\n").filter((l) => l.length > 0);
if (lines.length !== 1) throw new Error(`perf log printed ${lines.length} lines: ${out}`);
const rec = JSON.parse(lines[0]);
const keys = Object.keys(rec).sort().join(",");
if (keys !== "at,kind,metric,unit,value") throw new Error(`perf log keys are ${keys}`);
if (typeof rec.metric !== "string" || rec.metric.length === 0) throw new Error("perf log metric is not a non-empty string");
if (typeof rec.value !== "number" || !Number.isFinite(rec.value) || rec.value < 0) throw new Error(`perf log value ${rec.value} is not a number >= 0`);
if (typeof rec.unit !== "string" || rec.unit.length === 0) throw new Error("perf log unit is not a non-empty string");
if (rec.kind !== "count") throw new Error(`perf log kind is ${rec.kind}`);
const iso = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;
if (typeof rec.at !== "string" || !iso.test(rec.at) || Number.isNaN(Date.parse(rec.at))) throw new Error(`perf log at ${rec.at} is not an ISO-8601 time`);
' "$PERF_OUT"
echo "perf log: $PERF_OUT"

echo "ALL CHECKS PASSED"

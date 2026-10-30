#!/usr/bin/env bash
# Smoke-test harness for the site shell (global.css, BaseLayout, self-hosted
# fonts, favicon, 404) in the Astrodynamics Plate design (SSC-05). Every
# assertion runs against a clean build's dist/ output, except the token check,
# which reads src/styles/global.css because the showcase page consumes those
# custom-property names.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Clean build =="
rm -rf dist
npm run build

BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
INVITE=$(grep -oP "^export const DISCORD_INVITE_URL = '\K[^']+" src/lib/site.mjs)
EXPECTED_FOOTER="© 2026 Spoods Studios · Join the Discord"

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
grep -q '<header class="head">' dist/404.html
grep -q '<main class="page">' dist/404.html

echo "== Footer, running head and theme-color on every page =="
SHELL_FAIL=0
PAGES=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
  PAGES=$((PAGES + 1))
  HTML=$(tr '\n' ' ' < "$f")

  FOOTER_HTML=$(grep -oP '<footer>.*?</footer>' <<<"$HTML" || true)
  if [ "$(grep -c . <<<"$FOOTER_HTML")" -ne 1 ]; then
    echo "FAIL: $f does not carry exactly one bare <footer>"
    SHELL_FAIL=1
  fi
  FOOTER_TEXT=$(sed -E 's/<[^>]*>//g; s/[[:space:]]+/ /g; s/^ //; s/ $//' <<<"$FOOTER_HTML")
  if [ "$FOOTER_TEXT" != "$EXPECTED_FOOTER" ]; then
    echo "FAIL: $f footer text is '$FOOTER_TEXT'"
    SHELL_FAIL=1
  fi
  if grep -qi 'rss\|class="ai"' <<<"$FOOTER_HTML"; then
    echo "FAIL: $f footer carries an RSS link or an AI disclosure line"
    SHELL_FAIL=1
  fi

  HEAD_HTML=$(grep -oP '<header class="head">.*?</header>' <<<"$HTML" || true)
  if [ -z "$HEAD_HTML" ]; then
    echo "FAIL: $f has no <header class=\"head\"> running head"
    SHELL_FAIL=1
    continue
  fi
  if ! grep -qP "<a class=\"mark\" href=\"${NORMALIZED_BASE}\">Interstellar Engine <span>/ Setare Aerospace</span></a>" <<<"$HEAD_HTML"; then
    echo "FAIL: $f running head has no wordmark linking the site root"
    SHELL_FAIL=1
  fi
  NAV_HTML=$(grep -oP '<nav>.*?</nav>' <<<"$HEAD_HTML" || true)
  NAV_LINKS=$(grep -oP '<a [^>]*>.*?</a>' <<<"$NAV_HTML" || true)
  if [ "$(grep -c . <<<"$NAV_LINKS")" -ne 2 ]; then
    echo "FAIL: $f header nav does not hold exactly two links"
    SHELL_FAIL=1
    continue
  fi
  ROADMAP_LINK=$(sed -n 1p <<<"$NAV_LINKS")
  CTA_LINK=$(sed -n 2p <<<"$NAV_LINKS")
  case "$f" in
    dist/roadmap/*) WANT_ROADMAP="<a href=\"${NORMALIZED_BASE}roadmap/\" aria-current=\"page\">Roadmap</a>" ;;
    *) WANT_ROADMAP="<a href=\"${NORMALIZED_BASE}roadmap/\">Roadmap</a>" ;;
  esac
  if [ "$ROADMAP_LINK" != "$WANT_ROADMAP" ]; then
    echo "FAIL: $f first nav link is '$ROADMAP_LINK' (expected '$WANT_ROADMAP')"
    SHELL_FAIL=1
  fi
  if [ "$(count_occurrences 'aria-current' "$HEAD_HTML")" -ne "$(count_occurrences 'aria-current' "$ROADMAP_LINK")" ]; then
    echo "FAIL: $f running head carries aria-current outside the Roadmap link"
    SHELL_FAIL=1
  fi
  for want in 'class="cta"' "href=\"${INVITE}\"" 'target="_blank"' 'rel="noopener noreferrer"' '<svg ' 'Join the Discord</a>'; do
    if ! grep -qF "$want" <<<"$CTA_LINK"; then
      echo "FAIL: $f Discord CTA lacks $want"
      SHELL_FAIL=1
    fi
  done

  THEME=$(grep -oP '<meta name="theme-color" content="\K[^"]*' <<<"$HTML" || true)
  if [ "$THEME" != "#14233b" ] && [ "$THEME" != "#dfe6e1" ]; then
    echo "FAIL: $f theme-color is '$THEME' (expected the ink or vellum token value)"
    SHELL_FAIL=1
  fi
done < <(find dist -name '*.html')
[ "$PAGES" -gt 0 ]
[ "$SHELL_FAIL" -eq 0 ]
echo "shell OK across $PAGES pages"

echo "== No page or stylesheet references Google Fonts =="
if grep -rlE 'fonts\.googleapis\.com|fonts\.gstatic\.com' dist; then
  echo "FAIL: built output references Google Fonts"
  exit 1
fi

echo "== Self-hosted woff2 fonts ship hashed under the base =="
for stem in archivo-latin-wdth-wght source-serif-4-latin-opsz-wght source-serif-4-latin-italic-400; do
  if ! compgen -G "dist/_astro/${stem}.*.woff2" > /dev/null; then
    echo "FAIL: dist/_astro/ holds no ${stem} woff2"
    exit 1
  fi
  if ! grep -rqE "${NORMALIZED_BASE}_astro/${stem}\.[A-Za-z0-9_-]+\.woff2" dist; then
    echo "FAIL: no built stylesheet references ${stem} under ${NORMALIZED_BASE}_astro/"
    exit 1
  fi
done

echo "== global.css carries the Astrodynamics Plate tokens =="
FLAT_CSS=$(tr -d ' \t\n' < src/styles/global.css)
for token in \
  '--vellum:#dfe6e1;' \
  '--vellum-deep:#d3dcd6;' \
  '--ink:#14233b;' \
  '--ink-soft:#3b4d63;' \
  '--rule:rgba(20,35,59,.18);' \
  '--grid:rgba(20,35,59,.07);' \
  '--verm:#d9481f;' \
  '--verm-ink:#a8340f;' \
  '--plate:#0d1626;' \
  '--s:1.0625rem;' \
  '--l:clamp(2.6rem,6.2vw,5.6rem);' \
  '--cell:24px;' \
  '--gut:clamp(16px,4vw,56px);' \
  '--ease:cubic-bezier(.16,1,.3,1);'; do
  if ! grep -qF -- "$token" <<<"$FLAT_CSS"; then
    echo "FAIL: src/styles/global.css lacks $token"
    exit 1
  fi
done
grep -qF 'font-display:swap;' <<<"$FLAT_CSS"

echo "ALL CHECKS PASSED"

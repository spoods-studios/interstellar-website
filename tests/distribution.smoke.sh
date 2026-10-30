#!/usr/bin/env bash
# Distribution smoke harness (OpenGraph, Discord CTA). Proves DIST-02 (every
# built page carries a complete, absolute, resolvable OpenGraph block) and
# DIST-03 (every page carries both CTA placements), including the D-54
# loud-failure path for the invite constant. The RSS feed and the devlog were
# taken down (SSC-07), so no feed or hero-image assertions remain.
#
# Everything here is offline and asserted against real build output. That
# Discord actually renders an embed cannot be proven this way and stays a
# human verification.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Clean build =="
rm -rf dist
npm run build

# --- Derive the expected absolute-URL prefix from astro.config.mjs itself
# (SITE-02: the site/base live in one config location, never a literal
# repeated here). The invite comes from src/lib/site.mjs for the same reason. ---
SITE=$(grep -oP "site:\s*'\K[^']+" astro.config.mjs)
BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
PREFIX="${SITE}${NORMALIZED_BASE}"
INVITE=$(grep -oP "^export const DISCORD_INVITE_URL = '\K[^']+" src/lib/site.mjs)
echo "expected absolute-URL prefix: $PREFIX"

# grep's count flag counts matching LINES, and Astro's build minifies each
# dist/*.html page to a single line -- a line count therefore always reports 1
# no matter how many matches a page carries. Count occurrences instead.
# `|| n=0` keeps a zero-match page reportable rather than tripping set -e.
count_occurrences() {
  local n
  n=$(grep -o "$1" "$2" | wc -l) || n=0
  printf '%s' "$n"
}

attr_value() {
  grep -o "$1 content=\"[^\"]*\"" "$2" | sed -E 's/.*content="([^"]*)".*/\1/'
}

# CONT-06/D-65: redirect stubs are machine-facing artifacts, not pages a
# reader lands on -- Astro's stub template carries a refresh directive and
# none of the reader-facing chrome (no OpenGraph block, no CTA). The per-page sweeps below skip them by this predicate; the
# stub's own contract lives in tests/hardening.smoke.sh. The invariants
# themselves are unchanged -- this is a page-selection predicate only.
is_redirect_stub() {
  grep -q 'http-equiv="refresh"' "$1"
}

echo "== DIST-02: metadata coverage, absolute URLs, and resolvable images on every built page =="
META_FAIL=0
UNCONDITIONAL_TAGS=(
  '<meta name="description"'
  '<meta property="og:type"'
  '<meta property="og:site_name"'
  '<meta property="og:title"'
  '<meta property="og:description"'
  '<meta property="og:url"'
  '<meta property="og:image"'
  '<meta property="og:image:width"'
  '<meta property="og:image:height"'
  '<meta property="og:image:alt"'
  '<meta name="twitter:card"'
  '<meta name="theme-color"'
)
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
  for tag in "${UNCONDITIONAL_TAGS[@]}"; do
    COUNT=$(count_occurrences "$tag" "$f")
    if [ "$COUNT" -ne 1 ]; then
      echo "FAIL: $f has $COUNT occurrences of '$tag' (expected exactly 1)"
      META_FAIL=1
    fi
  done

  OG_URL=$(attr_value 'property="og:url"' "$f")
  case "$OG_URL" in
    "$PREFIX"*) ;;
    *) echo "FAIL: $f og:url '$OG_URL' does not carry the expected prefix '$PREFIX'"; META_FAIL=1 ;;
  esac

  OG_IMAGE=$(attr_value 'property="og:image"' "$f")
  case "$OG_IMAGE" in
    "$PREFIX"*) ;;
    *)
      echo "FAIL: $f og:image '$OG_IMAGE' does not carry the expected prefix '$PREFIX'"
      META_FAIL=1
      continue
      ;;
  esac
  # A tag-presence check would pass while a renamed or deleted card silently
  # blanked every embed -- resolve the emitted URL back to a real build artifact.
  OG_IMAGE_REL="${OG_IMAGE#"$PREFIX"}"
  if [ ! -f "dist/${OG_IMAGE_REL}" ]; then
    echo "FAIL: $f og:image '$OG_IMAGE' does not resolve to a file (looked for dist/${OG_IMAGE_REL})"
    META_FAIL=1
  fi

  # Below 1200x630 Discord downgrades the large card to a thumbnail.
  OG_W=$(attr_value 'property="og:image:width"' "$f")
  OG_H=$(attr_value 'property="og:image:height"' "$f")
  if [ "$OG_W" -lt 1200 ] || [ "$OG_H" -lt 630 ]; then
    echo "FAIL: $f declares ${OG_W}x${OG_H}, below the 1200x630 large-embed threshold"
    META_FAIL=1
  fi
done < <(find dist -name "*.html")
[ "$META_FAIL" -eq 0 ]
echo "metadata coverage OK"

echo "== DIST-02: og:title is never doubled with the site name =="
# og:site_name already carries the brand, so a title that also ends with it
# renders the brand twice in the embed and pushes the visible title past
# Discord's truncation point. Permanent gate: nothing else in the harness would
# catch a route that started passing an already-suffixed title.
if grep -rq 'og:title" content="[^"]*— Interstellar Engine"' dist --include='*.html'; then
  echo "FAIL: an og:title value ends with the site-name suffix (the brand is already in og:site_name)"
  grep -rlo 'og:title" content="[^"]*— Interstellar Engine"' dist --include='*.html'
  exit 1
fi
echo "og:title de-duplication OK"

echo "== DIST-02: every page uses the default card, at the embed threshold =="
DISTINCT_IMAGES=$(grep -rho '<meta property="og:image" content="[^"]*"' dist --include='*.html' \
  | sed -E 's/.*content="([^"]*)".*/\1/' | sort -u)
DISTINCT_IMAGE_COUNT=$(printf '%s\n' "$DISTINCT_IMAGES" | wc -l)
if ! [ "$DISTINCT_IMAGE_COUNT" -eq 1 ]; then
  echo "FAIL: expected 1 distinct og:image value (the default card), found $DISTINCT_IMAGE_COUNT"
  printf '%s\n' "$DISTINCT_IMAGES"
  exit 1
fi
# `identify` is an ImageMagick system tool used only by this local harness --
# it is not an npm dependency and the deploy never runs the suite. Fail loudly
# naming it rather than silently skipping the one assertion that proves the
# card's real pixel dimensions rather than its declared ones.
if ! command -v identify > /dev/null 2>&1; then
  echo "FAIL: identify (ImageMagick) is not on PATH -- required for the default card dimension assertion"
  exit 1
fi
DEFAULT_CARD_DIMENSIONS=$(identify -format '%wx%h' dist/og-default.png)
if [ "$DEFAULT_CARD_DIMENSIONS" != "1200x630" ]; then
  echo "FAIL: dist/og-default.png is ${DEFAULT_CARD_DIMENSIONS}, expected exactly 1200x630"
  exit 1
fi
echo "card images OK (default card $DEFAULT_CARD_DIMENSIONS)"

echo "== DIST-02: descriptions are not collapsed onto shared boilerplate =="
# If the extractor ever stopped skipping a shared leading blockquote/heading,
# every page's description would collapse onto one sentence while every
# per-page assertion above still passed -- guard relative to the actual page
# count so a new content drop can never turn this red on its own.
TOTAL_PAGES=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
  TOTAL_PAGES=$((TOTAL_PAGES + 1))
done < <(find dist -name "*.html")
DISTINCT_DESCRIPTIONS=$(grep -rho '<meta name="description" content="[^"]*"' dist --include='*.html' \
  | sed -E 's/.*content="([^"]*)".*/\1/' | sort -u | wc -l)
if [ "$DISTINCT_DESCRIPTIONS" -le "$((TOTAL_PAGES / 2))" ]; then
  echo "FAIL: only $DISTINCT_DESCRIPTIONS distinct description values across $TOTAL_PAGES pages (expected more than half distinct)"
  exit 1
fi
echo "description variety OK ($DISTINCT_DESCRIPTIONS distinct values across $TOTAL_PAGES pages)"

echo "== DIST-03: CTA placements on every built page =="
# Every page carries the header-nav and footer invites; the interim homepage
# (src/pages/index.astro) adds one more in its body.
CTA_FAIL=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
  EXPECTED_INVITES=2
  if [ "$f" = "dist/index.html" ]; then EXPECTED_INVITES=3; fi
  INVITE_COUNT=$(count_occurrences "$INVITE" "$f")
  if [ "$INVITE_COUNT" -ne "$EXPECTED_INVITES" ]; then
    echo "FAIL: $f carries $INVITE_COUNT invite links (expected exactly $EXPECTED_INVITES)"
    CTA_FAIL=1
  fi
  REL_COUNT=$(count_occurrences 'rel="noopener noreferrer"' "$f")
  if [ "$REL_COUNT" -ne "$EXPECTED_INVITES" ]; then
    echo "FAIL: $f carries $REL_COUNT external-link rel pairs (expected exactly $EXPECTED_INVITES)"
    CTA_FAIL=1
  fi
done < <(find dist -name "*.html")
[ "$CTA_FAIL" -eq 0 ]
echo "CTA coverage OK"

echo "== DIST-03: the footer is exactly the copyright line and the Discord link =="
FOOTER=$(grep -o '<footer>.*</footer>' dist/index.html | sed -E 's/<[^>]*>//g; s/^[[:space:]]+//; s/[[:space:]]+$//')
if [ "$FOOTER" != "© 2026 Spoods Studios · Join the Discord" ]; then
  echo "FAIL: footer text is '$FOOTER'"
  exit 1
fi
echo "footer OK"

echo "== DIST-02: two consecutive builds emit identical metadata (content-hashed URLs are stable) =="
capture_metadata() {
  grep -rho '<meta property="og:\(image\|url\)" content="[^"]*"' dist --include='*.html' \
    | sed -E 's/.*content="([^"]*)".*/\1/' | sort
}
METADATA_BEFORE=$(capture_metadata)
npm run build
METADATA_AFTER=$(capture_metadata)
if [ "$METADATA_BEFORE" != "$METADATA_AFTER" ]; then
  echo "FAIL: a rebuild from unchanged inputs changed the emitted og:image/og:url set"
  diff <(printf '%s\n' "$METADATA_BEFORE") <(printf '%s\n' "$METADATA_AFTER") || true
  exit 1
fi
echo "build determinism OK"

echo "== D-54 fixture: an unset, blank or placeholder invite constant fails the build, naming the constant =="
SITE_LIB="src/lib/site.mjs"
# Snapshot, don't demand emptiness: the fixture must leave the trees exactly
# as it found them, but a set-and-not-yet-committed GOATCOUNTER_CODE (the
# D-61 post-signup state) is legitimate src/ dirt, not fixture damage.
PRE_FIXTURE_STATUS=$(git status --porcelain roadmap/ pages/ src/)
SITE_LIB_BACKUP=$(mktemp)
cp "$SITE_LIB" "$SITE_LIB_BACKUP"
INVITE_PLACEHOLDER=$(grep -oP "^export const INVITE_PLACEHOLDER = '\K[^']+" "$SITE_LIB")
trap 'cp "$SITE_LIB_BACKUP" "$SITE_LIB" 2>/dev/null || true; rm -f "$SITE_LIB_BACKUP"' EXIT
# A near-miss value must be rejected too -- the requirement is that no page can
# ever ship a CTA with a blank or scaffold href, not merely that an empty
# constant breaks something.
for BAD_INVITE in "" "   " "$INVITE_PLACEHOLDER"; do
  sed "s|^export const DISCORD_INVITE_URL = '.*';|export const DISCORD_INVITE_URL = '${BAD_INVITE}';|" \
    "$SITE_LIB_BACKUP" > "$SITE_LIB"
  if npm run build > /tmp/gsd-dist-d54.log 2>&1; then
    cp "$SITE_LIB_BACKUP" "$SITE_LIB"
    echo "D-54 FIXTURE FAIL: build succeeded with the invite constant set to '${BAD_INVITE}'"
    exit 1
  fi
  if ! grep -q "DISCORD_INVITE_URL" /tmp/gsd-dist-d54.log; then
    cp "$SITE_LIB_BACKUP" "$SITE_LIB"
    echo "D-54 FIXTURE FAIL: the failure for '${BAD_INVITE}' did not name the constant"
    exit 1
  fi
done
cp "$SITE_LIB_BACKUP" "$SITE_LIB"
if [ "$(git status --porcelain roadmap/ pages/ src/)" != "$PRE_FIXTURE_STATUS" ]; then
  echo "D-54 FIXTURE FAIL: a tree was left in a different state than the fixture found it"
  exit 1
fi
echo "D-54 fixture OK: unset, blank and placeholder invites all fail loudly naming the constant; trees restored"

trap - EXIT
rm -f "$SITE_LIB_BACKUP"

echo "== Final clean rebuild after all fixtures restored =="
npm run build
if [ "$(git status --porcelain roadmap/ pages/ src/)" != "$PRE_FIXTURE_STATUS" ]; then
  echo "FAIL: trees not restored to their pre-fixture state after the full fixture run"
  exit 1
fi

echo "ALL CHECKS PASSED"

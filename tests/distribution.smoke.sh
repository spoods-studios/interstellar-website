#!/usr/bin/env bash
# Distribution smoke harness for Phase 3 (RSS, OpenGraph, Discord CTA).
# Proves DIST-01 (the feed builds, is well-formed, and cannot drift from the
# homepage archive), DIST-02 (every built page carries a complete, absolute,
# resolvable OpenGraph block) and DIST-03 (every page carries both CTA
# placements plus feed autodiscovery), including the three loud-failure paths
# this phase introduced (D-48 hero path, D-54 invite constant, D-30 draft).
#
# Everything here is offline and asserted against real build output. The two
# things that genuinely cannot be proven this way -- that Discord actually
# renders an embed, and that the W3C feed service reports zero errors -- are
# deliberately NOT faked with a build-time proxy (D-57's split acceptance
# criterion); they are human verifications owned by Plan 03-06.
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

echo "== DIST-02: exactly three distinct card images site-wide, all at or above the embed threshold =="
DISTINCT_IMAGES=$(grep -rho '<meta property="og:image" content="[^"]*"' dist --include='*.html' \
  | sed -E 's/.*content="([^"]*)".*/\1/' | sort -u)
DISTINCT_IMAGE_COUNT=$(printf '%s\n' "$DISTINCT_IMAGES" | wc -l)
if [ "$DISTINCT_IMAGE_COUNT" -ne 3 ]; then
  echo "FAIL: expected 3 distinct og:image values (default card + 2 hero plots), found $DISTINCT_IMAGE_COUNT"
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
echo "card images OK (3 distinct, default card $DEFAULT_CARD_DIMENSIONS)"

echo "== DIST-02: descriptions are not collapsed onto shared boilerplate =="
# The 55 deep-dives all open with an identical blockquote; if the extractor ever
# stopped skipping it they would collapse onto one sentence while every
# per-page assertion above still passed.
DISTINCT_DESCRIPTIONS=$(grep -rho '<meta name="description" content="[^"]*"' dist --include='*.html' \
  | sed -E 's/.*content="([^"]*)".*/\1/' | sort -u | wc -l)
if [ "$DISTINCT_DESCRIPTIONS" -le 60 ]; then
  echo "FAIL: only $DISTINCT_DESCRIPTIONS distinct description values across the site (expected more than 60)"
  exit 1
fi
echo "description variety OK ($DISTINCT_DESCRIPTIONS distinct values)"

echo "== DIST-03: CTA placements and feed autodiscovery on every built page =="
CTA_FAIL=0
while IFS= read -r f; do
  INVITE_COUNT=$(count_occurrences "$INVITE" "$f")
  if [ "$INVITE_COUNT" -ne 2 ]; then
    echo "FAIL: $f carries $INVITE_COUNT invite links (expected exactly 2: header nav + footer)"
    CTA_FAIL=1
  fi
  REL_COUNT=$(count_occurrences 'rel="noopener noreferrer"' "$f")
  if [ "$REL_COUNT" -ne 2 ]; then
    echo "FAIL: $f carries $REL_COUNT external-link rel pairs (expected exactly 2)"
    CTA_FAIL=1
  fi
  FEED_LINK_COUNT=$(count_occurrences 'rel="alternate" type="application/rss+xml"' "$f")
  if [ "$FEED_LINK_COUNT" -ne 1 ]; then
    echo "FAIL: $f carries $FEED_LINK_COUNT feed autodiscovery links (expected exactly 1)"
    CTA_FAIL=1
  fi
done < <(find dist -name "*.html")
[ "$CTA_FAIL" -eq 0 ]
echo "CTA and autodiscovery coverage OK"

echo "== DIST-03: footer order is copyright, RSS, then Discord =="
FOOTER=$(grep -o '<footer>.*</footer>' dist/index.html)
FOOTER_FEED_OFFSET=$(printf '%s' "$FOOTER" | grep -bo 'rss.xml' | head -1 | cut -d: -f1)
FOOTER_INVITE_OFFSET=$(printf '%s' "$FOOTER" | grep -boF "$INVITE" | head -1 | cut -d: -f1)
if [ "$FOOTER_FEED_OFFSET" -ge "$FOOTER_INVITE_OFFSET" ]; then
  echo "FAIL: the footer's feed link does not precede its invite link"
  exit 1
fi
echo "footer order OK"

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

echo "== DIST-01: the feed is well-formed XML =="
# This is only the OFFLINE half of D-57's split acceptance criterion: it proves
# the document parses, not that it is semantically valid RSS 2.0. The other
# half -- submitting the deployed feed to the W3C feed validation service --
# is a network service and stays a human verification in Plan 03-06. Do not
# bolt a network validator into this harness to "finish" this check.
xmllint --noout dist/rss.xml
echo "feed well-formedness OK"

echo "== DIST-01/D-45: the feed and the homepage archive cannot drift =="
FEED_ITEMS=$(grep -o '<item>' dist/rss.xml | wc -l)
ARCHIVE_LINKS=$(grep -o 'href="[^"]*devlog/[^"]*/"' dist/index.html | wc -l)
if [ "$FEED_ITEMS" -ne "$ARCHIVE_LINKS" ]; then
  echo "FAIL: the feed carries $FEED_ITEMS items but the homepage archive lists $ARCHIVE_LINKS announcements"
  exit 1
fi
# Equal counts are not equal ordering. This build tree is the only place in the
# phase where both artifacts exist together -- Plans 03-02 and 03-04 are wave
# siblings, so neither could assert across the pair. 03-04 put the archive onto
# the same shared comparator the feed uses; this diff is what makes that
# permanent, and it is the only check that would catch a reintroduced inline
# comparator on either side.
if ! diff \
  <(grep -o 'href="[^"]*devlog/[^"]*/"' dist/index.html | sed -E 's#.*devlog/([^"]+)/"#\1#') \
  <(grep -oP '<guid[^>]*>\K[^<]+' dist/rss.xml | sed -E 's#.*devlog/([^/]+)/$#\1#'); then
  echo "FAIL: the homepage archive and the feed list announcements in different orders"
  exit 1
fi
if grep -qE 'entryDate\(b\)\.getTime\(\)' src/pages/index.astro "src/pages/devlog/[slug].astro" src/pages/rss.xml.ts; then
  echo "FAIL: an inline ordering comparator was reintroduced alongside the shared sortEntriesNewestFirst()"
  exit 1
fi
echo "feed/archive drift lock OK ($FEED_ITEMS items, identical order, one shared comparator)"

echo "== DIST-01: channel shape =="
CHANNEL_COUNT=$(grep -o '<channel>' dist/rss.xml | wc -l)
if [ "$CHANNEL_COUNT" -ne 1 ]; then
  echo "FAIL: expected exactly 1 channel element, found $CHANNEL_COUNT"
  exit 1
fi
grep -q '<title>' dist/rss.xml
grep -q '<link>' dist/rss.xml
grep -q '<description>' dist/rss.xml
grep -q '<language>' dist/rss.xml
# D-57: the self-referencing atom link pre-empts the one recommendation the
# W3C feed validation service predictably raises.
grep -q 'rel="self"' dist/rss.xml
# The package declares the content module namespace automatically whenever an
# item carries `content`; a second occurrence means it was also declared by hand.
CONTENT_NS_COUNT=$(grep -o 'xmlns:content' dist/rss.xml | wc -l)
if [ "$CONTENT_NS_COUNT" -ne 1 ]; then
  echo "FAIL: xmlns:content declared $CONTENT_NS_COUNT times (expected exactly 1)"
  exit 1
fi
echo "channel shape OK"

echo "== DIST-01: item shape -- absolute links, unique guids, RFC-822 dates =="
ITEM_FAIL=0
while IFS= read -r url; do
  case "$url" in
    "$PREFIX"*) ;;
    *) echo "FAIL: feed link '$url' does not carry the expected prefix '$PREFIX'"; ITEM_FAIL=1 ;;
  esac
done < <(grep -oP '<link>\K[^<]+' dist/rss.xml)
while IFS= read -r guid; do
  case "$guid" in
    "$PREFIX"*) ;;
    *) echo "FAIL: feed guid '$guid' does not carry the expected prefix '$PREFIX'"; ITEM_FAIL=1 ;;
  esac
done < <(grep -oP '<guid[^>]*>\K[^<]+' dist/rss.xml)
GUID_COUNT=$(grep -oP '<guid[^>]*>\K[^<]+' dist/rss.xml | wc -l)
DISTINCT_GUIDS=$(grep -oP '<guid[^>]*>\K[^<]+' dist/rss.xml | sort -u | wc -l)
if [ "$GUID_COUNT" -ne "$FEED_ITEMS" ] || [ "$DISTINCT_GUIDS" -ne "$FEED_ITEMS" ]; then
  echo "FAIL: $FEED_ITEMS items carry $GUID_COUNT guids, $DISTINCT_GUIDS of them distinct (both must equal the item count)"
  ITEM_FAIL=1
fi
PUBDATE_COUNT=$(grep -oP '<pubDate>\K[^<]+' dist/rss.xml | wc -l)
if [ "$PUBDATE_COUNT" -ne "$FEED_ITEMS" ]; then
  echo "FAIL: $FEED_ITEMS items carry $PUBDATE_COUNT publication dates"
  ITEM_FAIL=1
fi
# A zero non-matching count makes the counting grep exit 1, which set -e would
# otherwise read as a script failure -- the opposite of what a clean result means.
BAD_DATES=$(grep -oP '<pubDate>\K[^<]+' dist/rss.xml | grep -cvP '^[A-Z][a-z]{2}, [0-9]{2} [A-Z][a-z]{2} [0-9]{4} ') || true
if [ "$BAD_DATES" -ne 0 ]; then
  echo "FAIL: $BAD_DATES publication dates are not RFC-822 shaped"
  ITEM_FAIL=1
fi
[ "$ITEM_FAIL" -eq 0 ]
echo "item shape OK ($GUID_COUNT unique, absolute, RFC-822-dated items)"

echo "== DIST-01: content fidelity -- absolutized images, no second-parse artifacts =="
# @astrojs/rss@4.0.19 emits content:encoded as XML-ESCAPED markup, not a CDATA
# block, so the rendered attributes read `src=&quot;https://…&quot;`. Every
# assertion below targets that escaped form; a pattern written against the raw
# quote would pass vacuously forever.
HERO_URLS=$(grep -o "${SITE}[^&\"]*_astro/[^&\"]*\.webp" dist/rss.xml | wc -l)
if [ "$HERO_URLS" -ne 2 ]; then
  echo "FAIL: expected 2 absolute hero image URLs in the feed, found $HERO_URLS"
  exit 1
fi
# A root-relative src is broken in every reader; the pattern is built from the
# derived BASE, never typed.
if grep -q "src=&quot;${BASE}" dist/rss.xml || grep -q "src=\"${BASE}" dist/rss.xml; then
  echo "FAIL: the feed carries a root-relative image source -- absolutize() did not fire"
  exit 1
fi
# absolutize()'s href branch is currently unexercised: no devlog body contains
# an anchor (03-02 logged this as partial coverage rather than papering over
# it). This assertion is deliberately a live gate rather than a fixture -- the
# moment a post does add a link, a non-absolute href fails here instead of
# shipping a dead URL to every reader.
if grep -q "href=&quot;${BASE}" dist/rss.xml || grep -q "href=&quot;\.\." dist/rss.xml; then
  echo "FAIL: the feed carries a non-absolute anchor href -- absolutize()'s href branch did not fire"
  exit 1
fi
# Both of these exit 0 and are invisible in the feed source: a pre-rendered
# content field ships unresolved image placeholders, and a second Markdown
# parser never sees this repo's wikilink plugin.
if grep -qF '__ASTRO_IMAGE_' dist/rss.xml; then
  echo "FAIL: the feed carries unresolved Astro image placeholders"
  exit 1
fi
if grep -qF '[[' dist/rss.xml; then
  echo "FAIL: the feed carries an unresolved wikilink delimiter"
  exit 1
fi
echo "content fidelity OK"

echo "== DIST-01: no second Markdown parser was adopted =="
# The published recipe for this task recommends one; adopting it would silently
# emit feed content that differs from the site's own rendering.
if grep -q 'markdown-it' package.json; then
  echo "FAIL: a second Markdown parser dependency appeared in package.json"
  exit 1
fi
echo "dependency hygiene OK"

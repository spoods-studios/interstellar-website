#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

LEGAL_FILE="pages/legal/eula.md"
PRE_PAGES_STATUS=$(git status --porcelain pages/)
WORK=$(mktemp -d)
cp "$LEGAL_FILE" "$WORK/legal.md"
MUTATED=
trap 'if [ -n "$MUTATED" ]; then cp "$WORK/legal.md" "$LEGAL_FILE"; fi; rm -rf "$WORK"' EXIT

echo "== Clean build =="
rm -rf dist
npm run build

SITE=$(grep -oP "site:\s*'\K[^']+" astro.config.mjs)
BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
SITEMAP_FILE="dist/sitemap-0.xml"
[ -f "$SITEMAP_FILE" ] || SITEMAP_FILE="dist/sitemap.xml"

echo "== Each legal page builds with its frontmatter version and effective date, is in the sitemap, and adds no cookie or script =="
for DOC in eula privacy; do
  SRC="pages/legal/$DOC.md"
  PAGE="dist/legal/$DOC/index.html"
  VERSION=$(grep -oP '^version:\s*"?\K[^"\s]+' "$SRC")
  EFFECTIVE=$(grep -oP '^effective:\s*\K\d{4}-\d{2}-\d{2}' "$SRC")
  if [ ! -f "$PAGE" ]; then
    echo "LEGAL FAIL: $PAGE not built"
    exit 1
  fi
  if ! grep -qwF "$VERSION" "$PAGE" || ! grep -qF "$EFFECTIVE" "$PAGE"; then
    echo "LEGAL FAIL: $PAGE lacks version $VERSION or effective date $EFFECTIVE from $SRC"
    exit 1
  fi
  if ! grep -qF "<loc>${SITE}${NORMALIZED_BASE}legal/$DOC/</loc>" "$SITEMAP_FILE"; then
    echo "LEGAL FAIL: ${SITE}${NORMALIZED_BASE}legal/$DOC/ missing from $SITEMAP_FILE"
    exit 1
  fi
  if [ "$(grep -o '<script' "$PAGE" | wc -l)" -ne "$(grep -o 'gc\.zgo\.at' "$PAGE" | wc -l)" ]; then
    echo "LEGAL FAIL: $PAGE loads a script beyond the GoatCounter tag"
    exit 1
  fi
  if grep -qiE 'document\.cookie|cookieStore|http-equiv="set-cookie"' "$PAGE"; then
    echo "LEGAL FAIL: $PAGE touches a cookie"
    exit 1
  fi
done
echo "Legal pages OK"

echo "== A legal file missing version, then effective, fails the build naming the file =="
MUTATED=1
for FIELD in version effective; do
  sed "/^${FIELD}:/d" "$WORK/legal.md" > "$LEGAL_FILE"
  if grep -q "^${FIELD}:" "$LEGAL_FILE"; then
    echo "LEGAL FAIL: fixture still sets ${FIELD} in $LEGAL_FILE"
    exit 1
  fi
  if npm run build > "$WORK/build.log" 2>&1; then
    echo "LEGAL FAIL: build succeeded with ${FIELD} removed from $LEGAL_FILE"
    exit 1
  fi
  if ! grep -qF "$LEGAL_FILE" "$WORK/build.log"; then
    cat "$WORK/build.log"
    echo "LEGAL FAIL: the build without ${FIELD} did not name $LEGAL_FILE"
    exit 1
  fi
  cp "$WORK/legal.md" "$LEGAL_FILE"
done

if [ "$(git status --porcelain pages/)" != "$PRE_PAGES_STATUS" ]; then
  echo "LEGAL FAIL: pages/ changed by the fixture"
  exit 1
fi
echo "Legal schema fixture OK"

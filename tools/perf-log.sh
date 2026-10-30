#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PAGE=dist/roadmap/index.html
if [ ! -f "$PAGE" ]; then
  echo "perf-log: $PAGE is missing; run npm run build first" >&2
  exit 1
fi

to_dist_path() {
  printf 'dist/_astro/%s\n' "${1##*/_astro/}"
}

STYLESHEETS=$(grep -oE '<link[^>]*rel="stylesheet"[^>]*>' "$PAGE" \
  | grep -oE 'href="[^"]*/_astro/[^"]*\.css"' \
  | sed -E 's/^href="//; s/"$//' \
  | while IFS= read -r href; do to_dist_path "$href"; done \
  | sort -u || true)

for css in $STYLESHEETS; do
  if [ ! -f "$css" ]; then
    echo "perf-log: $PAGE links $css, which is missing" >&2
    exit 1
  fi
done

FONTS=$(cat "$PAGE" $STYLESHEETS \
  | grep -oE '[^"'"'"'( ]*/_astro/[^"'"'"') ]*\.woff2' \
  | while IFS= read -r url; do to_dist_path "$url"; done \
  | sort -u || true)

for font in $FONTS; do
  if [ ! -f "$font" ]; then
    echo "perf-log: $PAGE references $font, which is missing" >&2
    exit 1
  fi
done

BYTES=0
for f in "$PAGE" $STYLESHEETS $FONTS; do
  BYTES=$((BYTES + $(wc -c < "$f")))
done

printf '{"metric":"roadmap_eager_bytes","value":%d,"unit":"bytes","kind":"count","at":"%s"}\n' \
  "$BYTES" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

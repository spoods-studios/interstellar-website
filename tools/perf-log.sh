#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PAGE=dist/index.html
if [ ! -f "$PAGE" ]; then
  echo "perf-log: $PAGE is missing; run npm run build first" >&2
  exit 1
fi

HTML=$(tr '\n' ' ' < "$PAGE")

to_dist_path() {
  printf 'dist/_astro/%s\n' "${1##*/_astro/}"
}

require_file() {
  if [ ! -f "$1" ]; then
    echo "perf-log: $PAGE references $1, which is missing" >&2
    exit 1
  fi
}

STYLESHEETS=$(grep -oE '<link[^>]*rel="stylesheet"[^>]*>' <<<"$HTML" \
  | grep -oE 'href="[^"]*/_astro/[^"]*\.css"' \
  | sed -E 's/^href="//; s/"$//' \
  | while IFS= read -r href; do to_dist_path "$href"; done \
  | sort -u || true)
for css in $STYLESHEETS; do require_file "$css"; done

FONTS=$(cat "$PAGE" $STYLESHEETS \
  | grep -oE '[^"'"'"'( ]*/_astro/[^"'"'"') ]*\.woff2' \
  | while IFS= read -r url; do to_dist_path "$url"; done \
  | sort -u || true)
for font in $FONTS; do require_file "$font"; done

QUEUE=($(grep -oE '<script[^>]*>' <<<"$HTML" \
  | grep 'type="module"' \
  | grep -oE 'src="[^"]*/_astro/[^"]*\.js"' \
  | sed -E 's/^src="//; s/"$//' \
  | while IFS= read -r src; do to_dist_path "$src"; done || true))
declare -A SEEN=()
SCRIPTS=()
while [ "${#QUEUE[@]}" -gt 0 ]; do
  js=${QUEUE[0]}
  QUEUE=("${QUEUE[@]:1}")
  [ -z "${SEEN[$js]:-}" ] || continue
  require_file "$js"
  SEEN[$js]=1
  SCRIPTS+=("$js")
  for imp in $(grep -oE '(from|import)[[:space:]]*"[^"]*\.js"' "$js" | grep -oE '"[^"]*"' | tr -d '"' || true); do
    case $imp in
      ./*) QUEUE+=("$(dirname "$js")/${imp#./}") ;;
      */_astro/*) QUEUE+=("$(to_dist_path "$imp")") ;;
    esac
  done
done

HERO=$(grep -oP '<picture\b[^>]*>.*?</picture>' <<<"$HTML" | grep 'fetchpriority="high"' || true)
if [ "$(grep -c . <<<"$HERO")" -ne 1 ]; then
  echo "perf-log: $PAGE does not carry exactly one <picture> with fetchpriority=\"high\" (the hero still)" >&2
  exit 1
fi
HERO_AVIF=$(grep -oP '<source[^>]*type="image/avif"[^>]*>' <<<"$HERO" \
  | grep -oP 'srcset="\K[^"]*' \
  | tr ',' '\n' \
  | awk '{print $1}' \
  | while IFS= read -r url; do [ -z "$url" ] || to_dist_path "$url"; done || true)
if [ -z "$HERO_AVIF" ]; then
  echo "perf-log: the hero still in $PAGE has no AVIF srcset candidate" >&2
  exit 1
fi
HERO_BYTES=0
for f in $HERO_AVIF; do
  require_file "$f"
  size=$(wc -c < "$f")
  [ "$size" -le "$HERO_BYTES" ] || HERO_BYTES=$size
done

BYTES=$HERO_BYTES
for f in "$PAGE" $STYLESHEETS $FONTS "${SCRIPTS[@]}"; do
  BYTES=$((BYTES + $(wc -c < "$f")))
done

printf '{"metric":"home_eager_bytes","value":%d,"unit":"bytes","kind":"count","at":"%s"}\n' \
  "$BYTES" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

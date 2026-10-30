#!/usr/bin/env bash
# Usage: showcase-encode.sh <capture-dir> <media-name> (--clip <start-frame> [--seconds <4-8>] | --still <frame>)
set -euo pipefail

die() { echo "showcase-encode: $*" >&2; exit 1; }

[ $# -ge 2 ] || die "usage: showcase-encode.sh <capture-dir> <media-name> (--clip <start-frame> [--seconds <4-8>] | --still <frame>)"
CAP=$(realpath -m -- "$1")
NAME=$2
shift 2
MODE= INDEX= SECONDS_=6
while [ $# -gt 0 ]; do
  case $1 in
    --clip | --still) MODE=${1#--}; INDEX=${2:?$1 needs a frame index}; shift 2 ;;
    --seconds) SECONDS_=${2:?--seconds needs a value}; shift 2 ;;
    *) die "unknown option '$1'" ;;
  esac
done
[ -n "$MODE" ] || die "give --clip <start-frame> or --still <frame>"
[[ $NAME =~ ^[a-z0-9-]+$ ]] || die "media name must match [a-z0-9-]+, got '$NAME'"
[[ $INDEX =~ ^[0-9]+$ ]] || die "frame index must be a non-negative integer, got '$INDEX'"
[[ $SECONDS_ =~ ^[4-8]$ ]] || die "clip length must be 4 to 8 seconds, got '$SECONDS_'"

META=$CAP/capture.meta LOG=$CAP/capture.log MANIFEST=$CAP/capture.manifest
for f in "$META" "$LOG" "$MANIFEST"; do [ -r "$f" ] || die "$f is missing; $CAP is not a capture directory"; done
meta() { sed -n "s/^$1=//p" "$META" | head -1; }
[ "$(meta status)" = complete ] || die "$META status is '$(meta status)', not complete"
[ "$(meta extent)" = 1280x720 ] || die "$META extent is '$(meta extent)', not 1280x720"
! grep -q 'terrain disabled' "$LOG" || die "$LOG reports terrain disabled; recapture with the dataset reachable"
FRAMES=$(meta frames)
SCRIPT=$(meta script)
[ -n "$SCRIPT" ] && [[ $FRAMES =~ ^[0-9]+$ ]] || die "$META has no script or frame count"

PROVENANCE=$(grep -m1 '^showcase-capture: build_sha=' "$LOG") || die "$LOG has no showcase-capture provenance line"
BUILD_SHA= BIN= SHOT=
read -ra tokens <<< "${PROVENANCE#showcase-capture: }"
for t in "${tokens[@]}"; do
  case $t in
    build_sha=*) BUILD_SHA=${t#*=} ;;
    bin=*) BIN=${t#*=} ;;
    lookdev_shot=*) SHOT=${t#*=} ;;
  esac
done
[ -n "$BUILD_SHA" ] && [ "$BUILD_SHA" != unknown ] || die "$LOG records build_sha=${BUILD_SHA:-unknown}; rebuild build-release and recapture"
if [ -n "$SHOT" ]; then
  ENGINE=$(dirname "$(dirname "$(dirname "$BIN")")")
  SHOT=${SHOT#"$ENGINE"/}
fi
GPU=$(sed -n 's/^vk_device=//p' "$MANIFEST" | head -1)
[ -n "$GPU" ] || die "$MANIFEST names no vk_device"
CAPTURED=$(date -r "$META" +%F)

ROOT=${SHOWCASE_ROOT:-$(dirname "$(dirname "$(realpath "$0")")")}
CLIPS=$ROOT/public/showcase
STILLS=$ROOT/src/assets/showcase
mkdir -p "$CLIPS" "$STILLS"
command -v ffmpeg > /dev/null || die "ffmpeg is not on PATH"
command -v oxipng > /dev/null || die "oxipng is not on PATH (pacman -S oxipng)"

frame() { printf '%s/frames/%06d.ppm' "$CAP" "$1"; }
size_ok() { [ "$(stat -c %s "$1")" -le "$2" ]; }

png() {
  local src out=$2
  src=$(frame "$1")
  [ -f "$src" ] || die "$src does not exist"
  ffmpeg -y -nostdin -i "$src" "$out"
  oxipng -o 4 --strip safe "$out"
  size_ok "$out" 2000000 || die "$out is $(stat -c %s "$out") bytes, over the 2 MB cap"
}

encode() {
  local out=$1 cap=$2 crf=$3 tries=0
  shift 3
  while :; do
    "$@" "$crf"
    size_ok "$out" "$cap" && return
    [ $tries -lt 2 ] || die "$out is $(stat -c %s "$out") bytes, over the $cap byte cap after crf $crf"
    tries=$((tries + 1)) crf=$((crf + 2))
  done
}

if [ "$MODE" = still ]; then
  [ "$INDEX" -lt "$FRAMES" ] || die "frame $INDEX is past the capture's $FRAMES frames"
  png "$INDEX" "$STILLS/$NAME.png"
  RANGE=$(jq -n --argjson f "$INDEX" '{frame: $f}')
else
  END=$((INDEX + SECONDS_ * 60 - 1))
  [ "$END" -lt "$FRAMES" ] || die "window $INDEX..$END is past the capture's $FRAMES frames"
  SCRATCH=$(mktemp -d)
  trap 'rm -rf "$SCRATCH"' EXIT
  IN=(-y -nostdin -framerate 60 -start_number 0 -ss "$(awk -v f="$INDEX" 'BEGIN { printf "%.6f", int(f * 1000000 / 60) / 1000000 }')" -t "$SECONDS_" -i "$CAP/frames/%06d.ppm")
  vp9() {
    local base=(ffmpeg "${IN[@]}" -vf 'fps=30,scale=1280:720:flags=lanczos,format=yuv420p' -c:v libvpx-vp9 -b:v 0 -crf "$1" -g 60 -row-mt 1 -passlogfile "$SCRATCH/vp9")
    "${base[@]}" -pass 1 -an -f null /dev/null
    "${base[@]}" -deadline good -cpu-used 1 -pass 2 -an "$CLIPS/$NAME.webm"
  }
  h264() {
    ffmpeg "${IN[@]}" -vf 'fps=30,scale=1280:720:flags=lanczos:out_color_matrix=bt709,format=yuv420p' -c:v libx264 -preset veryslow -crf "$1" -profile:v high -level 4.1 -maxrate 1500k -bufsize 3000k -g 60 -colorspace bt709 -color_primaries bt709 -color_trc bt709 -movflags +faststart -an "$CLIPS/$NAME.mp4"
  }
  encode "$CLIPS/$NAME.webm" 1000000 34 vp9
  encode "$CLIPS/$NAME.mp4" 1500000 27 h264
  png "$INDEX" "$STILLS/$NAME-poster.png"
  RANGE=$(jq -n --argjson s "$INDEX" --argjson e "$END" '{frames: {start: $s, end: $e}}')
fi

JSON=$STILLS/captures.json
[ -f "$JSON" ] || echo '{}' > "$JSON"
jq --indent 2 --arg n "$NAME" --arg script "$SCRIPT" --arg shot "$SHOT" --arg kind "$MODE" \
  --arg captured "$CAPTURED" --arg sha "$BUILD_SHA" --arg gpu "$GPU" --argjson range "$RANGE" \
  '.[$n] = ({script: $script} + (if $shot == "" then {} else {lookdev_shot: $shot} end)
    + {kind: $kind, captured: $captured, build_sha: $sha, gpu: $gpu} + $range)' \
  "$JSON" > "$JSON.tmp"
mv "$JSON.tmp" "$JSON"
echo "showcase-encode: $NAME ($MODE) recorded in $JSON"

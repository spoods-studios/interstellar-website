#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
ENCODE="$PWD/tools/showcase-encode.sh"

T=$(realpath "$(mktemp -d)")
trap 'rm -rf "$T"' EXIT

mkdir -p "$T/bin"
cat > "$T/bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$STUB_LOG"
[ -z "${STUB_FFMPEG_FAIL:-}" ] || exit 1
out=${!#}
[ "$out" != /dev/null ] || exit 0
crf=none
prev=
for a in "$@"; do
  [ "$prev" != -crf ] || crf=$a
  prev=$a
done
ext=${out##*.}
var=STUB_SIZE_${ext}_${crf}
[ "$ext" != png ] || var=STUB_SIZE_png
head -c "${!var:-1000}" /dev/zero > "$out"
EOF
cat > "$T/bin/oxipng" <<'EOF'
#!/usr/bin/env bash
echo "oxipng $*" >> "$STUB_LOG"
EOF
chmod +x "$T/bin/ffmpeg" "$T/bin/oxipng"
export PATH="$T/bin:$PATH"
export STUB_LOG="$T/ffmpeg.log"

make_capture() {
  local dir=$1 script=$2 extra=${3:-}
  mkdir -p "$dir/frames"
  touch "$dir/frames/000030.ppm" "$dir/frames/000100.ppm" "$dir/frames/000120.ppm"
  printf 'script=%s\nkind=capture\nstatus=complete\nextent=1280x720\ntick_s=0.0166667\nframes=601\n' "$script" > "$dir/capture.meta"
  touch -d '2026-10-21 12:00' "$dir/capture.meta"
  printf 'showcase-capture: build_sha=abc123 binary_sha256=ff bin=/eng/build-release/engine/interstellar%s linear=0 clouds=0 photo_match=none\n[capture] script=%s preset=L4_AERIAL frames=601 status=complete\n' "$extra" "$script" > "$dir/capture.log"
  printf 'manifest_version=3\nbuild_sha=abc123\nvk_device=AMD Radeon RX 7700S (RADV NAVI33)\n' > "$dir/capture.manifest"
}

fail() { echo "FAIL: $*" >&2; exit 1; }

run() {
  : > "$STUB_LOG"
  SHOWCASE_ROOT="$T/site" bash "$ENCODE" "$@" > "$T/out" 2> "$T/err"
}

refuses() {
  local why=$1; shift
  if run "$@"; then fail "$why: expected a refusal"; fi
}

record() { jq -c --arg n "$1" ".[\$n]$2" "$T/site/src/assets/showcase/captures.json"; }

CAP="$T/cap/showcase_buildup_l4-1"
make_capture "$CAP" showcase_buildup_l4
mkdir -p "$T/site"

echo "== clip: two-pass VP9, H.264, poster and record =="
run "$CAP" buildup-l4 --clip 30 || { cat "$T/err"; fail "clip encode exited non-zero"; }
for f in public/showcase/buildup-l4.webm public/showcase/buildup-l4.mp4 src/assets/showcase/buildup-l4-poster.png src/assets/showcase/captures.json; do
  test -f "$T/site/$f" || fail "missing $f"
done
[ "$(cd "$T/site" && find . -type f | sort | tr '\n' ' ')" = "./public/showcase/buildup-l4.mp4 ./public/showcase/buildup-l4.webm ./src/assets/showcase/buildup-l4-poster.png ./src/assets/showcase/captures.json " ] \
  || fail "unexpected files in the site tree: $(cd "$T/site" && find . -type f)"
p1=$(grep -e '-pass 1' "$STUB_LOG") || fail "no VP9 pass 1"
p2=$(grep -e '-pass 2' "$STUB_LOG") || fail "no VP9 pass 2"
mp4=$(grep -e 'libx264' "$STUB_LOG") || fail "no H.264 encode"
for l in "$p1" "$p2" "$mp4"; do
  [[ "$l" == *"-framerate 60 -start_number 0 -ss 0.500000 -t 6 -i $CAP/frames/%06d.ppm"* ]] || fail "input trim not on the input: $l"
  [[ "$l" == *" -an "* ]] || fail "audio not dropped: $l"
done
[[ "$p1" == *"-vf fps=30,scale=1280:720:flags=lanczos,format=yuv420p -c:v libvpx-vp9 -b:v 0 -crf 34 -g 60 -row-mt 1"* ]] || fail "VP9 pass 1 args: $p1"
[[ "$p1" == *"-pass 1 -an -f null /dev/null" ]] || fail "VP9 pass 1 output: $p1"
[[ "$p2" == *"-crf 34"* && "$p2" == *"-deadline good -cpu-used 1 -pass 2 -an $T/site/public/showcase/buildup-l4.webm" ]] || fail "VP9 pass 2 args: $p2"
[[ "$mp4" == *"-vf fps=30,scale=1280:720:flags=lanczos:out_color_matrix=bt709,format=yuv420p -c:v libx264 -preset veryslow -crf 27 -profile:v high -level 4.1 -maxrate 1500k -bufsize 3000k -g 60 -colorspace bt709 -color_primaries bt709 -color_trc bt709 -movflags +faststart -an $T/site/public/showcase/buildup-l4.mp4" ]] || fail "H.264 args: $mp4"
plog=$(sed -n 's/.*-passlogfile \([^ ]*\).*/\1/p' "$STUB_LOG" | sort -u)
[ "$(echo "$plog" | wc -l)" = 1 ] || fail "both passes must share one pass log: $plog"
[[ "$plog" != "$T/site"* && "$plog" != "$PWD"* ]] || fail "pass log inside a repo: $plog"
[ ! -e "$(dirname "$plog")" ] || fail "scratch dir left behind: $(dirname "$plog")"
grep -qxF -- "-y -nostdin -i $CAP/frames/000030.ppm $T/site/src/assets/showcase/buildup-l4-poster.png" "$STUB_LOG" || fail "poster is not the clip's first frame"
grep -q "^oxipng .*$T/site/src/assets/showcase/buildup-l4-poster.png" "$STUB_LOG" || fail "poster not optimized"
[ "$(record buildup-l4 '')" = '{"script":"showcase_buildup_l4","kind":"clip","captured":"2026-10-21","build_sha":"abc123","gpu":"AMD Radeon RX 7700S (RADV NAVI33)","frames":{"start":30,"end":389}}' ] \
  || fail "clip record: $(record buildup-l4 '')"

echo "== clip: --seconds sets the window =="
run "$CAP" buildup-l4 --clip 30 --seconds 4 || fail "4 s clip refused"
grep -qe '-ss 0.500000 -t 4 -i' "$STUB_LOG" || fail "4 s window not passed"
[ "$(record buildup-l4 .frames)" = '{"start":30,"end":269}' ] || fail "4 s range: $(record buildup-l4 .frames)"

echo "== still: PNG from the chosen frame, oxipng, upsert keeps other records =="
STILL="$T/cap/showcase_buildup_l0-1"
make_capture "$STILL" showcase_buildup_l0
run "$STILL" buildup-l0 --still 100 || { cat "$T/err"; fail "still exited non-zero"; }
grep -qxF -- "-y -nostdin -i $STILL/frames/000100.ppm $T/site/src/assets/showcase/buildup-l0.png" "$STUB_LOG" || fail "still not from frame 100"
grep -q "^oxipng .*$T/site/src/assets/showcase/buildup-l0.png" "$STUB_LOG" || fail "still not optimized"
! grep -qe 'libvpx\|libx264' "$STUB_LOG" || fail "still ran a clip encode"
[ "$(record buildup-l0 '')" = '{"script":"showcase_buildup_l0","kind":"still","captured":"2026-10-21","build_sha":"abc123","gpu":"AMD Radeon RX 7700S (RADV NAVI33)","frame":100}' ] \
  || fail "still record: $(record buildup-l0 '')"
[ "$(record buildup-l4 .kind)" = '"clip"' ] || fail "upsert dropped the clip record"

echo "== still: rerun replaces the record =="
run "$STILL" buildup-l0 --still 120 || fail "rerun refused"
[ "$(record buildup-l0 .frame)" = 120 ] || fail "record not replaced"
[ "$(jq 'keys | length' "$T/site/src/assets/showcase/captures.json")" = 2 ] || fail "duplicate records"

echo "== lookdev shot recorded relative to the engine repo =="
LD="$T/cap/photo_match-1"
make_capture "$LD" photo_match ' lookdev_shot=/eng/lookdev/shots/lookdev.json#terminator'
run "$LD" terminator --still 100 || fail "lookdev still refused"
[ "$(record terminator .lookdev_shot)" = '"lookdev/shots/lookdev.json#terminator"' ] || fail "lookdev shot: $(record terminator '')"
[ "$(record terminator .script)" = '"photo_match"' ] || fail "lookdev script"

echo "== cap overflow retries with crf +2 =="
STUB_SIZE_webm_34=1100000 STUB_SIZE_webm_36=900000 STUB_SIZE_mp4_27=1600000 STUB_SIZE_mp4_29=1400000 \
  run "$CAP" buildup-l4 --clip 30 || { cat "$T/err"; fail "retry run exited non-zero"; }
grep -qe 'libvpx-vp9 -b:v 0 -crf 36 .*-pass 2' "$STUB_LOG" || fail "VP9 not retried at crf 36"
grep -qe 'libx264 -preset veryslow -crf 29' "$STUB_LOG" || fail "H.264 not retried at crf 29"
[ "$(stat -c %s "$T/site/public/showcase/buildup-l4.webm")" = 900000 ] || fail "webm not the retried encode"
[ "$(stat -c %s "$T/site/public/showcase/buildup-l4.mp4")" = 1400000 ] || fail "mp4 not the retried encode"

echo "== cap overflow after two retries fails naming the file =="
SPOT="$T/cap/showcase_spot_ksc-1"
make_capture "$SPOT" showcase_spot_ksc
if STUB_SIZE_webm_34=1100000 STUB_SIZE_webm_36=1100000 STUB_SIZE_webm_38=1100000 run "$SPOT" spot-ksc --clip 30; then
  fail "oversized webm accepted"
fi
grep -q 'spot-ksc.webm' "$T/err" || fail "error does not name the webm: $(cat "$T/err")"
! grep -qe '-crf 40' "$STUB_LOG" || fail "more than two retries"
[ "$(record spot-ksc '')" = null ] || fail "record written for a failed encode"
if STUB_SIZE_mp4_27=1600000 STUB_SIZE_mp4_29=1600000 STUB_SIZE_mp4_31=1600000 run "$SPOT" spot-ksc --clip 30; then
  fail "oversized mp4 accepted"
fi
grep -q 'spot-ksc.mp4' "$T/err" || fail "error does not name the mp4"
if STUB_SIZE_png=2100000 run "$SPOT" spot-ksc --clip 30; then fail "oversized poster accepted"; fi
grep -q 'spot-ksc-poster.png' "$T/err" || fail "error does not name the poster"
if STUB_SIZE_png=2100000 run "$STILL" buildup-l1 --still 100; then fail "oversized still accepted"; fi
grep -q 'buildup-l1.png' "$T/err" || fail "error does not name the still"

echo "== refusals =="
refuses "no mode" "$CAP" x
refuses "bad name" "$CAP" ../x --still 100
refuses "missing frame" "$CAP" x --still 200
refuses "frame past the end" "$CAP" x --still 601
refuses "window past the end" "$CAP" x --clip 300
refuses "window too long" "$CAP" x --clip 30 --seconds 9
refuses "window too short" "$CAP" x --clip 30 --seconds 3
STUB_FFMPEG_FAIL=1 refuses "ffmpeg failure" "$CAP" x --clip 30
BAD="$T/cap/bad"
make_capture "$BAD" showcase_spot_ksc
sed -i 's/status=complete/status=aborted/' "$BAD/capture.meta"
refuses "incomplete capture" "$BAD" x --still 100
make_capture "$BAD" showcase_spot_ksc
sed -i '1s/build_sha=abc123/build_sha=unknown/' "$BAD/capture.log"
refuses "unknown build" "$BAD" x --still 100
make_capture "$BAD" showcase_spot_ksc
echo '[terrain] no usable dataset at /x (ManifestParseError 1) — terrain disabled for this run' >> "$BAD/capture.log"
refuses "terrain disabled" "$BAD" x --still 100
make_capture "$BAD" showcase_spot_ksc
sed -i 's/extent=1280x720/extent=2560x1440/' "$BAD/capture.meta"
refuses "wrong extent" "$BAD" x --still 100
make_capture "$BAD" showcase_spot_ksc
sed -i '/^vk_device=/d' "$BAD/capture.manifest"
refuses "no GPU" "$BAD" x --still 100
[ "$(record x '')" = null ] || fail "a refused run wrote a record"

echo "ALL CHECKS PASSED"

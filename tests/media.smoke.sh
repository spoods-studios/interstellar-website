#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

shopt -s nullglob

WEBM_CAP=1000000
MP4_CAP=1500000
PNG_CAP=2000000
TREE_CAP=40000000
MAX_CLIPS=8
MAX_STILLS=12
MEDIA_DIRS=(public/showcase src/assets/showcase)

fail() {
  echo "FAIL: $*"
  bad=1
}

check_cap() {
  local file=$1 cap=$2 size
  size=$(stat -c %s "$file")
  [ "$size" -le "$cap" ] || fail "${file#"$root"/} is $size bytes, over the $cap-byte cap"
}

check_media() {
  local root=$1 bad=0 f name total=0 stills=0 records attrs
  local pub=$root/public/showcase assets=$root/src/assets/showcase
  local -A clips=()
  local files=() dirs=() probes=()

  for f in "$pub"/*.webm; do
    check_cap "$f" "$WEBM_CAP"
    name=${f##*/}
    clips[${name%.webm}]=1
  done
  for f in "$pub"/*.mp4; do
    check_cap "$f" "$MP4_CAP"
    name=${f##*/}
    clips[${name%.mp4}]=1
  done
  for f in "$assets"/*.png; do
    check_cap "$f" "$PNG_CAP"
    case $f in *-poster.png) ;; *) stills=$((stills + 1)) ;; esac
  done
  [ "${#clips[@]}" -le "$MAX_CLIPS" ] || fail "${#clips[@]} clips, over the limit of $MAX_CLIPS"
  [ "$stills" -le "$MAX_STILLS" ] || fail "$stills stills, over the limit of $MAX_STILLS"

  for name in "${!clips[@]}"; do
    [ -f "$pub/$name.webm" ] || fail "clip $name has no public/showcase/$name.webm"
    [ -f "$pub/$name.mp4" ] || fail "clip $name has no public/showcase/$name.mp4"
    [ -f "$assets/$name-poster.png" ] || fail "clip $name has no src/assets/showcase/$name-poster.png"
  done
  if [ "${#clips[@]}" -gt 0 ]; then
    if ! records=$(node -e '
      const records = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
      if (typeof records !== "object" || records === null || Array.isArray(records))
        throw new Error("not an object keyed by media name");
      for (const name of process.argv.slice(2))
        if (typeof records[name] !== "object" || records[name] === null || !Object.hasOwn(records, name))
          console.log(name);
    ' "$assets/captures.json" "${!clips[@]}" 2>&1); then
      fail "src/assets/showcase/captures.json is unreadable: $records"
    else
      for name in $records; do fail "clip $name has no captures.json record"; done
    fi
  fi

  for f in "${MEDIA_DIRS[@]}"; do
    [ ! -d "$root/$f" ] || dirs+=("$root/$f")
    probes+=("$f/probe.webm" "$f/probe.mp4" "$f/probe.png" "$f/captures.json")
  done
  [ "${#dirs[@]}" -eq 0 ] || mapfile -d '' files < <(find "${dirs[@]}" -type f -print0)
  for f in "${files[@]}"; do
    total=$((total + $(stat -c %s "$f")))
    if head -c 64 "$f" | LC_ALL=C grep -qa '^version https://git-lfs\.github\.com/spec/'; then
      fail "${f#"$root"/} is a Git LFS pointer"
    fi
    probes+=("${f#"$root"/}")
  done
  [ "$total" -le "$TREE_CAP" ] || fail "media tree is $total bytes, over the $TREE_CAP-byte cap"

  if ! attrs=$(git -C "$root" check-attr filter -- "${probes[@]}"); then
    fail "git check-attr failed in $root"
  else
    while IFS= read -r f; do
      case $f in *': filter: lfs') fail "${f%: filter: lfs} is under the LFS filter" ;; esac
    done <<<"$attrs"
  fi

  return "$bad"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fixture() {
  local dir=$tmp/$1
  mkdir -p "$dir/public/showcase" "$dir/src/assets/showcase"
  git -C "$dir" init -q
  truncate -s 1000 "$dir/public/showcase/demo.webm" "$dir/public/showcase/demo.mp4"
  truncate -s 1000 "$dir/src/assets/showcase/demo-poster.png" "$dir/src/assets/showcase/still.png"
  printf '{"demo":{"kind":"clip"},"still":{"kind":"still"}}\n' >"$dir/src/assets/showcase/captures.json"
  echo "$dir"
}

expect_fail() {
  local dir=$1 message=$2 out
  if out=$(check_media "$dir"); then
    echo "FAIL: fixture ${dir##*/} passed, expected: $message"
    exit 1
  fi
  if ! grep -qF -- "$message" <<<"$out"; then
    echo "FAIL: fixture ${dir##*/} did not report '$message', got:"
    echo "$out"
    exit 1
  fi
}

echo "== A complete fixture media tree passes =="
d=$(fixture ok)
check_media "$d"

echo "== Each size cap rejects a file one byte over it =="
d=$(fixture webm-cap)
truncate -s 1000001 "$d/public/showcase/demo.webm"
expect_fail "$d" "public/showcase/demo.webm is 1000001 bytes, over the 1000000-byte cap"
d=$(fixture mp4-cap)
truncate -s 1500001 "$d/public/showcase/demo.mp4"
expect_fail "$d" "public/showcase/demo.mp4 is 1500001 bytes, over the 1500000-byte cap"
d=$(fixture png-cap)
truncate -s 2000001 "$d/src/assets/showcase/still.png"
expect_fail "$d" "src/assets/showcase/still.png is 2000001 bytes, over the 2000000-byte cap"

echo "== Clip and still counts are capped at 8 and 12 =="
d=$(fixture clip-count)
for i in 1 2 3 4 5 6 7 8; do truncate -s 10 "$d/public/showcase/c$i.webm"; done
expect_fail "$d" "9 clips, over the limit of 8"
d=$(fixture still-count)
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do truncate -s 10 "$d/src/assets/showcase/s$i.png"; done
expect_fail "$d" "13 stills, over the limit of 12"

echo "== The whole media tree is capped at 40 MB =="
d=$(fixture tree-cap)
truncate -s 39995951 "$d/public/showcase/extra.bin"
expect_fail "$d" "media tree is 40000001 bytes, over the 40000000-byte cap"

echo "== Each clip needs both encodes, a poster and a captures.json record =="
d=$(fixture no-mp4)
rm "$d/public/showcase/demo.mp4"
expect_fail "$d" "clip demo has no public/showcase/demo.mp4"
d=$(fixture no-webm)
rm "$d/public/showcase/demo.webm"
expect_fail "$d" "clip demo has no public/showcase/demo.webm"
d=$(fixture no-poster)
rm "$d/src/assets/showcase/demo-poster.png"
expect_fail "$d" "clip demo has no src/assets/showcase/demo-poster.png"
d=$(fixture no-record)
printf '{"still":{"kind":"still"}}\n' >"$d/src/assets/showcase/captures.json"
expect_fail "$d" "clip demo has no captures.json record"
d=$(fixture no-captures)
rm "$d/src/assets/showcase/captures.json"
expect_fail "$d" "src/assets/showcase/captures.json is unreadable"
d=$(fixture bad-captures)
printf '["demo"]\n' >"$d/src/assets/showcase/captures.json"
expect_fail "$d" "src/assets/showcase/captures.json is unreadable"

echo "== No LFS pointer file or LFS filter rule covers the media paths =="
d=$(fixture lfs-pointer)
printf 'version https://git-lfs.github.com/spec/v1\noid sha256:%064d\nsize 1000\n' 0 >"$d/src/assets/showcase/still.png"
expect_fail "$d" "src/assets/showcase/still.png is a Git LFS pointer"
d=$(fixture lfs-public)
echo 'public/showcase/** filter=lfs diff=lfs merge=lfs -text' >"$d/.gitattributes"
expect_fail "$d" "public/showcase/demo.webm is under the LFS filter"
d=$(fixture lfs-assets)
echo '*.png filter=lfs diff=lfs merge=lfs -text' >"$d/.gitattributes"
expect_fail "$d" "src/assets/showcase/still.png is under the LFS filter"
d=$(fixture lfs-empty)
rm "$d"/public/showcase/* "$d"/src/assets/showcase/*
echo '*.webm filter=lfs diff=lfs merge=lfs -text' >"$d/public/showcase/.gitattributes"
expect_fail "$d" "public/showcase/probe.webm is under the LFS filter"

echo "== The repo media tree passes every check =="
check_media .

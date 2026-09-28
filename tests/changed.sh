#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

scripts=()
for f in "$@"; do
  name=${f##*/}
  case $f in
    package.json | package-lock.json | astro.config.mjs | tsconfig.json | src/content.config.ts | tests/helpers/* | tests/run-all.sh | tests/changed.sh)
      exec bash tests/run-all.sh ;;
    tests/*.smoke.sh | tests/lib.smoke.mjs)
      [ ! -e "$f" ] || scripts+=("$f") ;;
    src/* | devlog/* | roadmap/* | pages/* | public/* | assets/*)
      ! grep -qF "$name" tests/helpers/*.mjs || exec bash tests/run-all.sh
      ! grep -qF "$name" tests/lib.smoke.mjs || scripts+=(tests/lib.smoke.mjs)
      mapfile -t -O "${#scripts[@]}" scripts < <(echo tests/site.smoke.sh; grep -lF -- "${name%.*}" tests/*.smoke.sh) ;;
  esac
done

[ ${#scripts[@]} -gt 0 ] || { echo "no tests cover the changed files"; exit 0; }
mapfile -t scripts < <(printf '%s\n' "${scripts[@]}" | sort -u)
exec bash tests/run-all.sh "${scripts[@]}"

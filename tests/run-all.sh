#!/usr/bin/env bash
# Harness runner: runs the JS assertion script, then every tests/*.smoke.sh in
# sorted order. Later plans in this phase each add their own tests/<area>.smoke.sh
# file -- this is the only place that ever needs to know they exist, so no
# shared harness file has to be edited (and no parallel-plan collision risk).
set -euo pipefail

cd "$(dirname "$0")/.."

[ $# -gt 0 ] || set -- tests/lib.smoke.mjs tests/*.smoke.sh

for script in "$@"; do
  echo "== running $script =="
  case $script in
    *.mjs) node "$script" ;;
    *) bash "$script" ;;
  esac
done

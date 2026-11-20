#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

LEGAL_FILE="pages/legal/eula.md"
PRE_PAGES_STATUS=$(git status --porcelain pages/)
WORK=$(mktemp -d)
cp "$LEGAL_FILE" "$WORK/legal.md"
trap 'cp "$WORK/legal.md" "$LEGAL_FILE" 2>/dev/null || true; rm -rf "$WORK"' EXIT

echo "== Clean build =="
rm -rf dist
npm run build

echo "== A legal file missing version, then effective, fails the build naming the file =="
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

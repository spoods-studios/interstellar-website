#!/usr/bin/env bash
# Deploy-hardening smoke harness for Phase 4 (analytics, launch content,
# deploy hardening). Proves SITE-03 (schema/content errors fail the build
# loudly, and every built page carries the freshness marker the post-deploy
# probe greps for), plus the phase's new mechanisms as later plans land them:
# CONT-06/D-65 (slug redirect stubs, Plan 04-04), ANLT-01/D-61 (gated
# analytics tag, Plan 04-03), and D-68 (the build-sha stamp, this file).
#
# Everything here is offline and asserted against real build output. What
# genuinely cannot be proven offline is deliberately NOT faked with a
# build-time proxy: that the LIVE site serves the deploying commit's SHA is
# owned by tests/live-probe.sh run from the CI smoke job (Plan 04-05), and
# the GoatCounter dashboard check is a human verification (Plan 04-03).
#
# Later plans in this phase append their own `== section ==` blocks to this
# file, before the final clean-rebuild tail.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Clean build =="
rm -rf dist
npm run build

# --- Derive SITE/BASE from astro.config.mjs itself (SITE-02: the site/base
# live in one config location, never repeated as literals in assertions). ---
SITE=$(grep -oP "site:\s*'\K[^']+" astro.config.mjs)
BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
echo "site=$SITE base=$NORMALIZED_BASE"

# grep's count flag counts matching LINES, and Astro's build minifies each
# dist/*.html page to a single line -- a line count therefore always reports 1
# no matter how many matches a page carries (the Phase 02-01 trap). Count
# occurrences instead. `|| n=0` keeps a zero-match page reportable under set -e.
count_occurrences() {
  local n
  n=$(grep -o "$1" "$2" | wc -l) || n=0
  printf '%s' "$n"
}

echo "== D-68: every built page carries exactly one build-sha stamp =="
STAMP_FAIL=0
while IFS= read -r f; do
  COUNT=$(count_occurrences '<meta name="build-sha"' "$f")
  if [ "$COUNT" -ne 1 ]; then
    echo "FAIL: $f carries $COUNT build-sha stamps (expected exactly 1)"
    STAMP_FAIL=1
  fi
done < <(find dist -name "*.html")
[ "$STAMP_FAIL" -eq 0 ]
echo "stamp coverage OK"

echo "== D-68: a build without GITHUB_SHA stamps the literal 'local' =="
LOCAL_FAIL=0
while IFS= read -r f; do
  if [ "$(count_occurrences '<meta name="build-sha" content="local"' "$f")" -ne 1 ]; then
    echo "FAIL: $f local-build stamp is not the literal 'local'"
    LOCAL_FAIL=1
  fi
done < <(find dist -name "*.html")
[ "$LOCAL_FAIL" -eq 0 ]
echo "local fallback OK"

echo "== D-68: the stamp tracks GITHUB_SHA when exported for the build =="
SYNTHETIC_SHA="cafef00dcafef00dcafef00dcafef00dcafef00d"
GITHUB_SHA="$SYNTHETIC_SHA" npm run build > /dev/null
TRACK_FAIL=0
while IFS= read -r f; do
  if [ "$(count_occurrences "<meta name=\"build-sha\" content=\"$SYNTHETIC_SHA\"" "$f")" -ne 1 ]; then
    echo "FAIL: $f does not carry the exported GITHUB_SHA value in its stamp"
    TRACK_FAIL=1
  fi
done < <(find dist -name "*.html")
[ "$TRACK_FAIL" -eq 0 ]
echo "SHA tracking OK"

# --- SITE-03 loud-fail audit conclusion (04-RESEARCH, verified against the
# installed astro@7.0.9 source and proven empirically by the fixture below):
# every schema/content error class is already a loud build failure, each with
# an owning decision -- frontmatter schema violations (this fixture; Zod enum
# via parseData, which sits OUTSIDE the glob loader's try/catch), filename
# violations (D-10 devlog, D-33 technical, D-38 roadmap: generateId throws),
# render-time wikilink/deep-dive placeholder failures (D-39: the config-load
# preflight re-runs the full mdast pipeline and crashes the process), empty
# collections (assertNonEmpty at every query site), missing body heroes
# (D-48: lookupHero throws; Astro's ImageNotFound fires upstream), and an
# unset/blank/placeholder invite constant (D-54: config-load assert).
# Three residual silent classes are ACCEPTED, per the 04-RESEARCH audit:
#   1. unreadable-file skip (glob loader logs and skips) -- near-impossible in
#      a clean git checkout, and the exact-count assertions catch it locally;
#   2. duplicate-collection-id overwrite (warn-only, last-write-wins) --
#      structurally impossible here: every id derives from a unique path;
#   3. this smoke harness itself does not run in CI -- deliberate: it performs
#      several full rebuilds and mutates the working tree with fixtures, and
#      D-08 means every push deploys, so gating deploys on it would trade a
#      small silent-failure class for a large flaky-deploy class. The CI build
#      already fails loudly on every schema and content error class above,
#      which is SITE-03's build-side letter.
echo "== SITE-03 fixture: an out-of-enum frontmatter status fails the build, naming the file =="
# The fixture filename conforms to YYYY-MM-DD-slug.md so the D-10 filename
# guard is NOT what fires -- only the schema enum can reject it. The status
# value is the exact one the studio's unpublished how-this-gets-built.md
# carries: the landmine this fixture retires (04-CONTEXT).
SCHEMA_FIXTURE="2026-01-01-schema-audit-fixture.md"
trap 'rm -f "devlog/$SCHEMA_FIXTURE"' EXIT
printf -- '---\nstatus: skeleton\n---\n\n# Schema Audit Fixture\n\nfixture body\n' > "devlog/$SCHEMA_FIXTURE"
if npm run build > /tmp/gsd-hardening-schema.log 2>&1; then
  rm -f "devlog/$SCHEMA_FIXTURE"
  echo "SITE-03 FIXTURE FAIL: build succeeded with an out-of-enum status value"
  exit 1
fi
if ! grep -q "2026-01-01-schema-audit-fixture" /tmp/gsd-hardening-schema.log; then
  rm -f "devlog/$SCHEMA_FIXTURE"
  echo "SITE-03 FIXTURE FAIL: the failure output did not name the offending file"
  exit 1
fi
rm -f "devlog/$SCHEMA_FIXTURE"
trap - EXIT
if git status --porcelain devlog/ | grep -q .; then
  echo "SITE-03 FIXTURE FAIL: devlog/ left dirty"
  exit 1
fi
echo "SITE-03 fixture OK: schema violation failed the build loudly naming the file; devlog/ clean"

echo "== D-61 fixture: an unset site code warns and builds; a placeholder or malformed one fails loudly =="
SITE_LIB="src/lib/site.mjs"
SITE_LIB_BACKUP=$(mktemp)
cp "$SITE_LIB" "$SITE_LIB_BACKUP"
# Derive the sentinel from the module itself (the D-54 idiom in
# tests/distribution.smoke.sh) rather than repeating it as a literal the
# module could silently drift away from.
GC_PLACEHOLDER=$(grep -oP "^export const GOATCOUNTER_PLACEHOLDER = '\K[^']+" "$SITE_LIB")
trap 'cp "$SITE_LIB_BACKUP" "$SITE_LIB" 2>/dev/null || true; rm -f "$SITE_LIB_BACKUP"' EXIT
# D-61 legs 1-2: unset and whitespace-only are the same expected pre-signup
# state -- the build must WARN naming the constant and still exit 0, because
# D-08 means every push deploys and a hard block would freeze the pipeline.
for SOFT_CODE in "" "   "; do
  sed "s|^export const GOATCOUNTER_CODE = '.*';|export const GOATCOUNTER_CODE = '${SOFT_CODE}';|" \
    "$SITE_LIB_BACKUP" > "$SITE_LIB"
  if ! npm run build > /tmp/gsd-hardening-d61.log 2>&1; then
    cp "$SITE_LIB_BACKUP" "$SITE_LIB"
    echo "D-61 FIXTURE FAIL: build failed with the site code set to '${SOFT_CODE}' (unset must warn, not throw)"
    exit 1
  fi
  if ! grep -q "GOATCOUNTER_CODE" /tmp/gsd-hardening-d61.log; then
    cp "$SITE_LIB_BACKUP" "$SITE_LIB"
    echo "D-61 FIXTURE FAIL: the build for '${SOFT_CODE}' did not warn naming the constant"
    exit 1
  fi
done
# D-61 legs 3-4: the placeholder sentinel and an out-of-charset value are NOT
# the unset state -- both must fail the build loudly naming the constant, so
# the two adjacent states can never collapse into each other.
for BAD_CODE in "$GC_PLACEHOLDER" "Bad/Code" "not valid"; do
  sed "s|^export const GOATCOUNTER_CODE = '.*';|export const GOATCOUNTER_CODE = '${BAD_CODE}';|" \
    "$SITE_LIB_BACKUP" > "$SITE_LIB"
  if npm run build > /tmp/gsd-hardening-d61.log 2>&1; then
    cp "$SITE_LIB_BACKUP" "$SITE_LIB"
    echo "D-61 FIXTURE FAIL: build succeeded with the site code set to '${BAD_CODE}'"
    exit 1
  fi
  if ! grep -q "GOATCOUNTER_CODE" /tmp/gsd-hardening-d61.log; then
    cp "$SITE_LIB_BACKUP" "$SITE_LIB"
    echo "D-61 FIXTURE FAIL: the failure for '${BAD_CODE}' did not name the constant"
    exit 1
  fi
done
# D-61 leg 5: a well-formed code builds clean with no warning naming the
# constant -- the post-signup push must not cry wolf.
sed "s|^export const GOATCOUNTER_CODE = '.*';|export const GOATCOUNTER_CODE = 'interstellar-smoke';|" \
  "$SITE_LIB_BACKUP" > "$SITE_LIB"
if ! npm run build > /tmp/gsd-hardening-d61.log 2>&1; then
  cp "$SITE_LIB_BACKUP" "$SITE_LIB"
  echo "D-61 FIXTURE FAIL: build failed with a well-formed site code"
  exit 1
fi
if grep -q "GOATCOUNTER_CODE" /tmp/gsd-hardening-d61.log; then
  cp "$SITE_LIB_BACKUP" "$SITE_LIB"
  echo "D-61 FIXTURE FAIL: a well-formed site code still produced a warning naming the constant"
  exit 1
fi
cp "$SITE_LIB_BACKUP" "$SITE_LIB"
rm -f "$SITE_LIB_BACKUP"
trap - EXIT
if git status --porcelain src/ | grep -q .; then
  echo "D-61 FIXTURE FAIL: src/ left dirty"
  exit 1
fi
echo "D-61 fixture OK: unset/blank warn and build; placeholder/malformed fail loudly; valid is silent; src/ clean"

echo "== Final clean rebuild: leave dist/ as a plain local build =="
npm run build > /dev/null

echo "ALL CHECKS PASSED"

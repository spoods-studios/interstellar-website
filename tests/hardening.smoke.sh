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
. tests/helpers/build.sh

echo "== Build =="
build_site
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

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

# CONT-06/D-65: redirect stubs are machine-facing artifacts, not pages a
# reader lands on -- Astro's stub template carries a refresh directive and
# none of the reader-facing chrome (no BaseLayout stamp, no analytics tag).
# The per-page sweeps below skip them by this predicate; the stub is instead
# held to its own contract in the CONT-06 section near the end of this file.
# The invariants themselves are unchanged -- this is a page-selection
# predicate only.
is_redirect_stub() {
  grep -q 'http-equiv="refresh"' "$1"
}

echo "== D-68: every built page carries exactly one build-sha stamp =="
STAMP_FAIL=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
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
  if is_redirect_stub "$f"; then continue; fi
  if [ "$(count_occurrences '<meta name="build-sha" content="local"' "$f")" -ne 1 ]; then
    echo "FAIL: $f local-build stamp is not the literal 'local'"
    LOCAL_FAIL=1
  fi
done < <(find dist -name "*.html")
[ "$LOCAL_FAIL" -eq 0 ]
echo "local fallback OK"

echo "== D-68: the stamp tracks GITHUB_SHA when exported for the build =="
SYNTHETIC_SHA="cafef00dcafef00dcafef00dcafef00dcafef00d"
build_variant "$T/sha" GITHUB_SHA="$SYNTHETIC_SHA" > /dev/null
TRACK_FAIL=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
  if [ "$(count_occurrences "<meta name=\"build-sha\" content=\"$SYNTHETIC_SHA\"" "$f")" -ne 1 ]; then
    echo "FAIL: $f does not carry the exported GITHUB_SHA value in its stamp"
    TRACK_FAIL=1
  fi
done < <(find "$T/sha/dist" -name "*.html")
[ "$TRACK_FAIL" -eq 0 ]
echo "SHA tracking OK"

# --- SITE-03 loud-fail audit conclusion (04-RESEARCH, verified against the
# installed astro@7.0.9 source and proven empirically by the fixture below):
# every schema/content error class is already a loud build failure, each with
# an owning decision -- frontmatter schema violations (this fixture; Zod enum
# via parseData, which sits OUTSIDE the glob loader's try/catch), filename
# violations (D-38 roadmap: generateId throws), empty collections
# (assertNonEmpty at every query site), and an unset/blank/placeholder invite
# constant (D-54: config-load assert).
# Three residual silent classes are ACCEPTED, per the 04-RESEARCH audit:
#   1. unreadable-file skip (glob loader logs and skips) -- near-impossible in
#      a clean git checkout, and the exact-count assertions catch it locally;
#   2. duplicate-collection-id overwrite (warn-only, last-write-wins) --
#      structurally impossible here: every id derives from a unique path;
#   3. this smoke harness itself does not run in CI -- deliberate: it performs
#      several full rebuilds, and
#      D-08 means every push deploys, so gating deploys on it would trade a
#      small silent-failure class for a large flaky-deploy class. The CI build
#      already fails loudly on every schema and content error class above,
#      which is SITE-03's build-side letter.
echo "== SITE-03 fixture: an out-of-enum frontmatter status fails the build, naming the file =="
# The pages collection's status enum is the only guard that can reject this
# fixture. The status value is the exact one the studio's unpublished
# how-this-gets-built.md carries: the landmine this fixture retires
# (04-CONTEXT).
SCHEMA_FIXTURE="schema-audit-fixture.md"
scratch_tree "$T/schema"
printf -- '---\nstatus: skeleton\n---\n\n# Schema Audit Fixture\n\nfixture body\n' > "$T/schema/pages/$SCHEMA_FIXTURE"
if build_in "$T/schema" > "$T/schema.log" 2>&1; then
  echo "SITE-03 FIXTURE FAIL: build succeeded with an out-of-enum status value"
  exit 1
fi
if ! grep -q "schema-audit-fixture" "$T/schema.log"; then
  echo "SITE-03 FIXTURE FAIL: the failure output did not name the offending file"
  exit 1
fi
echo "SITE-03 fixture OK: schema violation failed the build loudly naming the file"

echo "== D-61 fixture: an unset site code warns and builds; a placeholder or malformed one fails loudly =="
# Derive the sentinel from the module itself (the D-54 idiom in
# tests/distribution.smoke.sh) rather than repeating it as a literal the
# module could silently drift away from.
GC_PLACEHOLDER=$(grep -oP "^export const GOATCOUNTER_PLACEHOLDER = '\K[^']+" src/lib/site.mjs)
scratch_tree "$T/gc"
# D-61 legs 1-2: unset and whitespace-only are the same expected pre-signup
# state -- the build must WARN naming the constant and still exit 0, because
# D-08 means every push deploys and a hard block would freeze the pipeline.
for SOFT_CODE in "" "   "; do
  if ! build_in "$T/gc" GOATCOUNTER_CODE="$SOFT_CODE" > "$T/d61.log" 2>&1; then
    echo "D-61 FIXTURE FAIL: build failed with the site code set to '${SOFT_CODE}' (unset must warn, not throw)"
    exit 1
  fi
  if ! grep -q "GOATCOUNTER_CODE" "$T/d61.log"; then
    echo "D-61 FIXTURE FAIL: the build for '${SOFT_CODE}' did not warn naming the constant"
    exit 1
  fi
done
# D-61 legs 3-4: the placeholder sentinel and an out-of-charset value are NOT
# the unset state -- both must fail the build loudly naming the constant, so
# the two adjacent states can never collapse into each other.
for BAD_CODE in "$GC_PLACEHOLDER" "Bad/Code" "not valid"; do
  if build_in "$T/gc" GOATCOUNTER_CODE="$BAD_CODE" > "$T/d61.log" 2>&1; then
    echo "D-61 FIXTURE FAIL: build succeeded with the site code set to '${BAD_CODE}'"
    exit 1
  fi
  if ! grep -q "GOATCOUNTER_CODE" "$T/d61.log"; then
    echo "D-61 FIXTURE FAIL: the failure for '${BAD_CODE}' did not name the constant"
    exit 1
  fi
done
# D-61 leg 5: a well-formed code builds clean with no warning naming the
# constant -- the post-signup push must not cry wolf.
TEST_CODE="interstellar-smoke"
if ! build_in "$T/gc" GOATCOUNTER_CODE="$TEST_CODE" > "$T/d61.log" 2>&1; then
  echo "D-61 FIXTURE FAIL: build failed with a well-formed site code"
  exit 1
fi
if grep -q "GOATCOUNTER_CODE" "$T/d61.log"; then
  echo "D-61 FIXTURE FAIL: a well-formed site code still produced a warning naming the constant"
  exit 1
fi
echo "D-61 fixture OK: unset/blank warn and build; placeholder/malformed fail loudly; valid is silent"

echo "== ANLT-01/D-62: analytics emission matches the configured state on every page, the 404 included =="
GC_CODE=$(site_value GOATCOUNTER_CODE | tr -d '[:space:]')
if [ -n "$GC_CODE" ]; then EXPECTED=1; else EXPECTED=0; fi
GATE_FAIL=0
SAW_404=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
  COUNT=$(count_occurrences 'gc\.zgo\.at' "$f")
  if [ "$COUNT" -ne "$EXPECTED" ]; then
    echo "FAIL: $f carries $COUNT analytics tags (expected exactly $EXPECTED on every page)"
    GATE_FAIL=1
  fi
  case "$f" in */404.html) SAW_404=1 ;; esac
done < <(find dist -name "*.html")
[ "$GATE_FAIL" -eq 0 ]
[ "$SAW_404" -eq 1 ]
echo "analytics gating OK (expected $EXPECTED per page, 404 covered)"

echo "== ANLT-01/D-62 fixture: a configured code puts exactly one tag on every page =="
SET_FAIL=0
SET_SAW_404=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
  if [ "$(count_occurrences 'gc\.zgo\.at' "$f")" -ne 1 ]; then
    echo "FAIL: $f does not carry exactly one analytics tag with the code set"
    SET_FAIL=1
  fi
  if ! grep -q "data-goatcounter=\"https://${TEST_CODE}.goatcounter.com/count\"" "$f"; then
    echo "FAIL: $f analytics endpoint does not carry the configured site code"
    SET_FAIL=1
  fi
  if ! grep -o '<script[^>]*>' "$f" | grep 'gc\.zgo\.at' | grep -q 'async'; then
    echo "FAIL: $f analytics tag does not carry the async attribute"
    SET_FAIL=1
  fi
  if ! grep -q 'count\.js"></script>' "$f"; then
    echo "FAIL: $f analytics tag is not an empty-bodied external src reference"
    SET_FAIL=1
  fi
  case "$f" in */404.html) SET_SAW_404=1 ;; esac
done < <(find "$T/gc/dist" -name "*.html")
[ "$SET_FAIL" -eq 0 ]
[ "$SET_SAW_404" -eq 1 ]
echo "ANLT-01/D-62 fixture OK: one tag everywhere incl. 404, endpoint carries the code, async, empty body"

echo "== CONT-06/D-65: redirect stub contract -- root target, noindex, canonical, resolvable destination =="
# Derive the keys from astro.config.mjs itself (the SITE-02 idiom: no base or
# slug literal repeated here). Every takedown entry's destination is exactly
# `${NORMALIZED_BASE}`, so each emitted stub must refresh to the derived base
# and resolve to dist/index.html. `|| true` keeps a missing map reportable
# under pipefail rather than a silent exit.
mapfile -t REDIRECT_KEYS < <(sed -n '/^const SLUG_REDIRECTS = {/,/^};/p' astro.config.mjs \
  | grep -oP "^\s*'\K/[^']+(?=': \`\\$\{NORMALIZED_BASE\}\`,?\s*$)") || true
if [ "${#REDIRECT_KEYS[@]}" -eq 0 ]; then
  echo "FAIL: no SLUG_REDIRECTS entry with a root destination in astro.config.mjs (CONT-06)"
  exit 1
fi
if [ ! -f dist/index.html ]; then
  echo "FAIL: the root destination ${NORMALIZED_BASE} does not resolve to a built file (looked for dist/index.html)"
  exit 1
fi
for REDIRECT_KEY in "${REDIRECT_KEYS[@]}"; do
  STUB_FILE="dist${REDIRECT_KEY}/index.html"
  if [ ! -f "$STUB_FILE" ]; then
    echo "FAIL: redirect stub missing at $STUB_FILE for map key $REDIRECT_KEY"
    exit 1
  fi
  if ! grep -q 'http-equiv="refresh"' "$STUB_FILE"; then
    echo "FAIL: $STUB_FILE carries no meta refresh directive"
    exit 1
  fi
  if ! grep -q '<meta name="robots" content="noindex"' "$STUB_FILE"; then
    echo "FAIL: $STUB_FILE carries no robots noindex directive"
    exit 1
  fi
  if ! grep -q '<link rel="canonical"' "$STUB_FILE"; then
    echo "FAIL: $STUB_FILE carries no canonical link"
    exit 1
  fi
  REFRESH_TARGET=$(grep -oP 'http-equiv="refresh" content="[0-9]+;url=\K[^"]+' "$STUB_FILE") || true
  # Pitfall 1 (04-RESEARCH): Astro emits string destinations VERBATIM into the
  # refresh URL while applying the base only to the match side -- a base-less
  # destination builds clean and sends readers to a path that does not exist.
  if [ "$REFRESH_TARGET" != "$NORMALIZED_BASE" ]; then
    echo "FAIL: $STUB_FILE refresh target '$REFRESH_TARGET' is not the site root '$NORMALIZED_BASE'"
    exit 1
  fi
done
echo "redirect stub contract OK (${#REDIRECT_KEYS[@]} stubs -> $NORMALIZED_BASE)"

echo "ALL CHECKS PASSED"

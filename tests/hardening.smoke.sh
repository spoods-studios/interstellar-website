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
GITHUB_SHA="$SYNTHETIC_SHA" npm run build > /dev/null
TRACK_FAIL=0
while IFS= read -r f; do
  if is_redirect_stub "$f"; then continue; fi
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
# Snapshot, don't demand emptiness: the fixtures must leave src/ exactly as
# they found it, but a set-and-not-yet-committed GOATCOUNTER_CODE (the D-61
# post-signup state) is legitimate dirt that must not read as fixture damage.
PRE_SRC_STATUS=$(git status --porcelain src/)
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
if [ "$(git status --porcelain src/)" != "$PRE_SRC_STATUS" ]; then
  echo "D-61 FIXTURE FAIL: src/ left in a different state than the fixture found it"
  exit 1
fi
echo "D-61 fixture OK: unset/blank warn and build; placeholder/malformed fail loudly; valid is silent; src/ restored"

echo "== ANLT-01/D-62: analytics emission matches the configured state on every page, the 404 included =="
# Rebuild first: earlier fixtures leave dist/ from a mutated module, and this
# section's whole point is that dist/ agrees with the module AS COMMITTED.
npm run build > /dev/null 2>&1
# sed, not grep -oP: the captured value is legitimately empty while the code
# is unset, and a zero-length grep match is not a portable exit-0.
GC_CODE=$(sed -n "s|^export const GOATCOUNTER_CODE = '\(.*\)';\$|\1|p" "$SITE_LIB" | tr -d '[:space:]')
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
GC_BACKUP=$(mktemp)
cp "$SITE_LIB" "$GC_BACKUP"
trap 'cp "$GC_BACKUP" "$SITE_LIB" 2>/dev/null || true; rm -f "$GC_BACKUP"' EXIT
TEST_CODE="interstellar-smoke"
sed "s|^export const GOATCOUNTER_CODE = '.*';|export const GOATCOUNTER_CODE = '${TEST_CODE}';|" \
  "$GC_BACKUP" > "$SITE_LIB"
npm run build > /dev/null 2>&1
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
done < <(find dist -name "*.html")
cp "$GC_BACKUP" "$SITE_LIB"
rm -f "$GC_BACKUP"
trap - EXIT
[ "$SET_FAIL" -eq 0 ]
[ "$SET_SAW_404" -eq 1 ]
if [ "$(git status --porcelain src/)" != "$PRE_SRC_STATUS" ]; then
  echo "ANLT-01 FIXTURE FAIL: src/ left in a different state than the fixture found it"
  exit 1
fi
echo "ANLT-01/D-62 fixture OK: one tag everywhere incl. 404, endpoint carries the code, async, empty body; src/ restored"

echo "== CONT-06/D-65: redirect stub contract -- base-prefixed target, noindex, canonical, resolvable destination =="
# Derive the map's single key and destination suffix from astro.config.mjs
# itself (the SITE-02 idiom: no base or slug literal repeated here). The
# config composes its destination from NORMALIZED_BASE, so recompose it here
# from the same derived value and demand the emitted stub agrees. `|| true`
# keeps a missing map reportable under pipefail rather than a silent exit.
REDIRECT_KEY=$(sed -n '/^const SLUG_REDIRECTS = {/,/^};/p' astro.config.mjs | grep -oP "'\K/[^']+(?=':)" | head -1) || true
REDIRECT_DEST_SUFFIX=$(sed -n '/^const SLUG_REDIRECTS = {/,/^};/p' astro.config.mjs | grep -oP '\$\{NORMALIZED_BASE\}\K[^`]+' | head -1) || true
if [ -z "$REDIRECT_KEY" ] || [ -z "$REDIRECT_DEST_SUFFIX" ]; then
  echo "FAIL: no SLUG_REDIRECTS entry in astro.config.mjs -- the demonstration stub cannot exist (CONT-06)"
  exit 1
fi
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
REFRESH_TARGET=$(grep -oP 'http-equiv="refresh" content="[0-9]+;url=\K[^"]+' "$STUB_FILE")
# Pitfall 1 (04-RESEARCH): Astro emits string destinations VERBATIM into the
# refresh URL while applying the base only to the match side -- a base-less
# destination builds clean and sends readers to a path that does not exist.
case "$REFRESH_TARGET" in
  "$NORMALIZED_BASE"*) ;;
  *)
    echo "FAIL: stub refresh target '$REFRESH_TARGET' does not start with the configured base '$NORMALIZED_BASE'"
    exit 1
    ;;
esac
if [ "$REFRESH_TARGET" != "${NORMALIZED_BASE}${REDIRECT_DEST_SUFFIX}" ]; then
  echo "FAIL: emitted refresh target '$REFRESH_TARGET' differs from the config's composed destination '${NORMALIZED_BASE}${REDIRECT_DEST_SUFFIX}'"
  exit 1
fi
# Astro never validates concrete-path destinations -- a typo'd one builds
# fine and redirects every reader to a 404. Resolve the emitted target to a
# real build artifact, not merely a non-empty string.
TARGET_REL="${REFRESH_TARGET#"$NORMALIZED_BASE"}"
TARGET_REL="${TARGET_REL%%#*}"
if [ -z "$TARGET_REL" ]; then
  TARGET_FILE="dist/index.html"
elif [[ "$TARGET_REL" == */ ]]; then
  TARGET_FILE="dist/${TARGET_REL}index.html"
else
  TARGET_FILE="dist/${TARGET_REL}"
fi
if [ ! -f "$TARGET_FILE" ]; then
  echo "FAIL: stub refresh target '$REFRESH_TARGET' does not resolve to a built file (looked for $TARGET_FILE)"
  exit 1
fi
echo "redirect stub contract OK ($REDIRECT_KEY -> $REFRESH_TARGET)"

echo "== Final clean rebuild: leave dist/ as a plain local build =="
npm run build > /dev/null

echo "ALL CHECKS PASSED"

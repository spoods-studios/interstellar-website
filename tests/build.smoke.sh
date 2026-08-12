#!/usr/bin/env bash
# Smoke-test harness for Phase 1 Plan 01, Task 3 (ingest -> render slice, CONT-01/D-01/D-02/D-07/D-10).
# No JS test framework this phase (D-03/D-09, RESEARCH.md Validation Architecture) --
# `npm run build` IS the test; this script codifies the plan's <verify> checks as a
# committed, re-runnable RED/GREEN harness instead of a one-off shell command.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Positive check: manifesto ingests and renders =="
npm run build
grep -q "Devblog" dist/index.html
grep -q "Why I'm Building a Hyperrealistic Space Sim from Scratch" dist/index.html
# Plan 05 switched the meta line from the throwaway page's raw ISO date to
# formatDate()'s long-form rendering (matches the post route's meta line).
grep -q "April 7, 2026" dist/index.html
! grep -rIn -e 'github\.io' -e '/interstellar-website' src/
echo "positive check OK"

echo "== Positive check: full announcement archive (CONT-02/CONT-03/CONT-05) =="
# grep -c counts matching LINES, not occurrences -- Astro's production build
# minifies dist/index.html to a single line, so -c always reports 1 regardless
# of post count. grep -o | wc -l counts actual occurrences instead. Assert on
# the archive row's href shape rather than a bare '<li>' count, matching the
# plan's own acceptance criterion ("N links whose href matches the devlog
# post path shape"), where N is derived from the visible devlog corpus.
DEVLOG_COUNT=$(node tests/helpers/content-expectations.mjs devlog_count)
test "$(grep -o 'href="[^"]*devlog/[^"]*/"' dist/index.html | wc -l)" -eq "$DEVLOG_COUNT"

# D-16: the developer-approved sentence must ship verbatim; the UI-SPEC
# placeholder must not.
grep -qF "A space engine built from scratch on real n-body physics." dist/index.html
! grep -qF "A from-scratch physics-accurate space engine, built in the open." dist/index.html

# Newest-first ordering (D-12): the newest entry's own devlog/<id>/ href must
# appear at a smaller byte offset than the oldest entry's, both ids derived
# through the site's own compareNewestFirst comparator (tie-break included).
# Comparing hrefs rather than rendered titles also removes the latent
# HTML-escaping trap in matching title text against built markup.
NEWEST_ID=$(node tests/helpers/content-expectations.mjs newest_devlog_id)
OLDEST_ID=$(node tests/helpers/content-expectations.mjs oldest_devlog_id)
NEWEST_OFFSET=$(grep -boF "devlog/${NEWEST_ID}/" dist/index.html | head -1 | cut -d: -f1)
OLDEST_OFFSET=$(grep -boF "devlog/${OLDEST_ID}/" dist/index.html | head -1 | cut -d: -f1)
test "$NEWEST_OFFSET" -lt "$OLDEST_OFFSET"

# Milestone tags render (spot-check the newest, the newest m0-era, and the
# oldest milestone posts).
test "$(grep -o 'M1.1' dist/index.html | wc -l)" -ge 1
test "$(grep -o 'M0.8' dist/index.html | wc -l)" -ge 1
test "$(grep -o 'M0.1' dist/index.html | wc -l)" -ge 1

# No client JS beyond the sanctioned analytics tag (D-60/D-61: the script-tag
# count must equal the analytics-tag count in either constant state).
test "$(grep -o '<script' dist/index.html | wc -l)" -eq "$(grep -o 'gc\.zgo\.at' dist/index.html | wc -l)"

# T-02-03/D-26/D-31: neither standalone page (pages/how-its-made.md,
# pages/roadmap.md) may leak into the archive listing. A whole-page substring
# check would false-positive on BaseLayout's own site-wide nav, which
# legitimately links to /how-its-made/ and /roadmap/ on every page including
# this one -- so this scopes the check to the <ul> archive list itself, the
# one place a leaked standalone-page row would actually appear.
ARCHIVE_LIST=$(grep -o '<ul>.*</ul>' dist/index.html)
if echo "$ARCHIVE_LIST" | grep -q 'how-its-made'; then
  echo "FAIL: how-its-made page leaked into the archive list"
  exit 1
fi
if echo "$ARCHIVE_LIST" | grep -q 'roadmap'; then
  echo "FAIL: roadmap page leaked into the archive list"
  exit 1
fi
echo "ten-announcement check OK"

echo "== Negative check (D-10): malformed devlog file fails the build loudly =="
MARKER="zzz-not-a-post.md"
trap 'rm -f "devlog/$MARKER"' EXIT
printf 'garbage body no h1\n' > "devlog/$MARKER"
if npm run build > /tmp/gsd-d10.log 2>&1; then
  rm -f "devlog/$MARKER"
  echo "D-10 FAIL: build did not error on malformed file"
  exit 1
fi
grep -q "$MARKER" /tmp/gsd-d10.log
rm -f "devlog/$MARKER"
if git status --porcelain devlog/ | grep -q .; then
  echo "D-10 FAIL: devlog/ left dirty"
  exit 1
fi
echo "D-10 OK: build failed loudly naming $MARKER; devlog/ clean"

echo "ALL CHECKS PASSED"

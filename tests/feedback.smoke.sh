#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SITE=$(grep -oP "site:\s*'\K[^']+" astro.config.mjs)
BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
INVITE=$(grep -oP "^export const DISCORD_INVITE_URL = '\K[^']+" src/lib/site.mjs)
SITE_LIB="src/lib/site.mjs"
PAGE="dist/feedback/index.html"
FIXTURE_HOST="feedback-fixture.example.workers.dev"
FIXTURE_URL="https://${FIXTURE_HOST}/reports"

main_invites() {
  local n
  n=$(tr '\n' ' ' < "$1" | grep -oP '<main\b.*?</main>' | sed 's|<noscript>.*</noscript>||' | grep -oF "href=\"${INVITE}\"" | wc -l) || n=0
  printf '%s' "$n"
}

PRE_SRC_STATUS=$(git status --porcelain src/)
SITE_LIB_BACKUP=$(mktemp)
cp "$SITE_LIB" "$SITE_LIB_BACKUP"
trap 'cp "$SITE_LIB_BACKUP" "$SITE_LIB" 2>/dev/null || true; rm -f "$SITE_LIB_BACKUP"' EXIT

set_feedback_url() {
  sed "s|^export const FEEDBACK_URL = '.*';|export const FEEDBACK_URL = '$1';|" "$SITE_LIB_BACKUP" > "$SITE_LIB"
  grep -qF "export const FEEDBACK_URL = '$1';" "$SITE_LIB"
}

echo "== Build with a fixture https FEEDBACK_URL =="
set_feedback_url "$FIXTURE_URL"
rm -rf dist
npm run build

echo "== /feedback/ carries the form, kind choice, textarea, honeypot and noscript Discord fallback =="
test -f "$PAGE"
node -e '
const fs = require("fs");
const path = require("path");
const [base, invite, fixtureUrl, fixtureHost, site] = process.argv.slice(1);
const page = "dist/feedback/index.html";
const html = fs.readFileSync(page, "utf8");
const fails = [];
const fail = (m) => fails.push(m);
const attrs = (tag) => Object.fromEntries([...tag.matchAll(/([\w:-]+)(?:="([^"]*)")?/g)].slice(1).map((m) => [m[1], m[2] ?? ""]));
const tags = (name) => [...html.matchAll(new RegExp(`<${name}\\b[^>]*>`, "g"))].map((m) => attrs(m[0]));

if (tags("form").length !== 1) fail(`${page} carries ${tags("form").length} forms (expected 1)`);
const kinds = tags("input").filter((a) => a.type === "radio" && a.name === "kind").map((a) => a.value).sort();
if (kinds.join(",") !== "bug,suggestion") fail(`${page} kind choice is [${kinds}] (expected bug and suggestion)`);
if (tags("textarea").length !== 1) fail(`${page} carries ${tags("textarea").length} textareas (expected 1)`);
const honeypots = tags("input").filter((a) => a.tabindex === "-1");
if (honeypots.length !== 1) fail(`${page} carries ${honeypots.length} out-of-tab-order inputs (expected the one honeypot)`);
for (const h of honeypots) {
  if (h.autocomplete !== "off") fail(`${page} honeypot has autocomplete="${h.autocomplete}" (expected off)`);
  if (h.type === "hidden") fail(`${page} honeypot is type=hidden, which bots skip`);
}
if (!html.includes(fixtureUrl)) fail(`${page} does not carry the configured FEEDBACK_URL for its script`);
const noscript = html.match(/<noscript>([\s\S]*?)<\/noscript>/);
if (!noscript) fail(`${page} has no noscript fallback`);
else if (!noscript[1].includes(`href="${invite}"`)) fail(`${page} noscript fallback does not link the Discord invite`);

const siteHost = new URL(site).host;
const queue = [];
let scripts = 0;
for (const m of html.matchAll(/(<script\b[^>]*>)([\s\S]*?)<\/script>/g)) {
  const a = attrs(m[1]);
  if (a.src === undefined) { scripts += 1; queue.push({ f: `${page} inline script`, text: m[2] }); continue; }
  if (/(^|\/\/)gc\.zgo\.at\//.test(a.src)) continue;
  if (!a.src.startsWith(`${base}_astro/`)) { fail(`${page} loads the script ${a.src} from outside ${base}_astro/`); continue; }
  scripts += 1;
  queue.push({ f: "dist/" + a.src.slice(base.length) });
}
if (scripts === 0) fail(`${page} loads no form script`);
const seen = new Set();
while (queue.length) {
  const { f, text = fs.readFileSync(f, "utf8") } = queue.shift();
  if (seen.has(f)) continue;
  seen.add(f);
  if (/document\.cookie|cookieStore/.test(text)) fail(`${f} touches cookies`);
  if (text.includes(fixtureHost)) fail(`${f} carries the Worker host`);
  for (const o of text.matchAll(/(?:https?:\/\/|["\x27`]\/\/)([a-z0-9-]+(?:\.[a-z0-9-]+)+)/gi)) {
    const host = o[1].toLowerCase();
    if (host !== siteHost && host !== "www.w3.org") fail(`${f} references the origin ${host}`);
  }
  for (const i of text.matchAll(/(?:\bfrom|\bimport)\s*\(?\s*["\x27`]([^"\x27`]+\.js)["\x27`]/g)) {
    const spec = i[1];
    if (spec.startsWith("./") || spec.startsWith("../")) queue.push({ f: path.join(path.dirname(f), spec) });
    else if (spec.startsWith(`${base}_astro/`)) queue.push({ f: "dist/" + spec.slice(base.length) });
    else fail(`${f} imports ${spec}, outside ${base}_astro/`);
  }
}
if (/document\.cookie|cookieStore/.test(html)) fail(`${page} touches cookies`);

if (fails.length) {
  for (const f of fails) console.log(`FAIL: ${f}`);
  process.exit(1);
}
' "$NORMALIZED_BASE" "$INVITE" "$FIXTURE_URL" "$FIXTURE_HOST" "$SITE"
if grep -rlF "$FIXTURE_HOST" dist --include='*.js'; then
  echo "FAIL: a built script carries the Worker host"
  exit 1
fi
FORM_MAIN_INVITES=$(main_invites "$PAGE")
echo "fixture page OK"

echo "== Build with an empty FEEDBACK_URL: the Discord fallback replaces the form =="
set_feedback_url ""
npm run build
test -f "$PAGE"
if grep -qE '<form\b|<textarea\b' "$PAGE"; then
  echo "FAIL: $PAGE renders the form while FEEDBACK_URL is empty"
  exit 1
fi
EMPTY_MAIN_INVITES=$(main_invites "$PAGE")
if [ "$EMPTY_MAIN_INVITES" -le "$FORM_MAIN_INVITES" ]; then
  echo "FAIL: $PAGE with an empty FEEDBACK_URL links Discord $EMPTY_MAIN_INVITES times in its body, no more than the form page's $FORM_MAIN_INVITES (no visible fallback)"
  exit 1
fi
echo "empty-URL fallback OK"

cp "$SITE_LIB_BACKUP" "$SITE_LIB"
rm -f "$SITE_LIB_BACKUP"
trap - EXIT
if [ "$(git status --porcelain src/)" != "$PRE_SRC_STATUS" ]; then
  echo "FAIL: src/ left in a different state than the test found it"
  exit 1
fi

echo "ALL CHECKS PASSED"

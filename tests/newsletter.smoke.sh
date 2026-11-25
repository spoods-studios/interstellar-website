#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Gate script: submit waits for a valid email and the age box =="
node --input-type=module -e '
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
const { initNewsletterForm } = await import(pathToFileURL(process.argv[1]).href);
assert.equal(typeof initNewsletterForm, "function", "newsletter-form.ts exports no initNewsletterForm");

const node = (props) => {
  const listeners = [];
  return Object.assign({ listeners, addEventListener: (type, l) => listeners.push([type, l]), removeEventListener() {} }, props);
};
const form = node({});
const email = node({ type: "email", name: "email", value: "" });
Object.defineProperty(email, "validity", { get: () => ({ valid: /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.value) }) });
email.checkValidity = () => email.validity.valid;
const box = node({ type: "checkbox", checked: false });
const button = node({ type: "submit", disabled: false });
form.querySelector = (selector) =>
  selector.includes("email") ? email : selector.includes("checkbox") ? box : selector.includes("submit") || selector.includes("button") ? button : null;

const fire = (el, ...types) => {
  for (const type of types) {
    const event = { type, target: el, currentTarget: el, preventDefault() {} };
    for (const [t, l] of [...el.listeners, ...form.listeners]) if (t === type) l(event);
  }
};
const typeEmail = (value) => { email.value = value; fire(email, "input"); };
const tick = (checked) => { box.checked = checked; fire(box, "input", "change"); };

initNewsletterForm(form);
assert.equal(button.disabled, true, "submit is enabled after init with an empty form");
typeEmail("pilot@example.com");
assert.equal(button.disabled, true, "submit is enabled with only a valid email");
typeEmail("");
tick(true);
assert.equal(button.disabled, true, "submit is enabled with only the age box ticked");
typeEmail("pilot@example.com");
assert.equal(button.disabled, false, "submit stays disabled with a valid email and the box ticked");
tick(false);
assert.equal(button.disabled, true, "submit stays enabled after the box is unticked");
console.log("newsletter-form OK");
' "$PWD/src/scripts/newsletter-form.ts"

SITE=$(grep -oP "site:\s*'\K[^']+" astro.config.mjs)
BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
INVITE=$(grep -oP "^export const DISCORD_INVITE_URL = '\K[^']+" src/lib/site.mjs)
SITE_LIB="src/lib/site.mjs"
PAGE="dist/newsletter/index.html"
FIXTURE_URL="https://buttondown.com/api/emails/embed-subscribe/fixture-user"

region_invites() {
  local n
  n=$(tr '\n' ' ' < "$1" | grep -oP "<$2\\b.*?</$2>" | grep -oF "href=\"${INVITE}\"" | wc -l) || n=0
  printf '%s' "$n"
}

PRE_SRC_STATUS=$(git status --porcelain src/)
SITE_LIB_BACKUP=$(mktemp)
cp "$SITE_LIB" "$SITE_LIB_BACKUP"
trap 'cp "$SITE_LIB_BACKUP" "$SITE_LIB" 2>/dev/null || true; rm -f "$SITE_LIB_BACKUP"' EXIT

set_newsletter_url() {
  sed "s|^export const NEWSLETTER_URL = '.*';|export const NEWSLETTER_URL = '$1';|" "$SITE_LIB_BACKUP" > "$SITE_LIB"
  grep -qF "export const NEWSLETTER_URL = '$1';" "$SITE_LIB"
}

echo "== Build with a fixture Buttondown NEWSLETTER_URL =="
set_newsletter_url "$FIXTURE_URL"
rm -rf dist
npm run build

echo "== Every footer and /newsletter/ carry a native form posting to the fixture =="
test -f "$PAGE"
node -e '
const fs = require("fs");
const path = require("path");
const [base, invite, fixtureUrl] = process.argv.slice(1);
const fails = [];
const fail = (m) => fails.push(m);
const attrs = (tag) => Object.fromEntries([...tag.matchAll(/([\w:-]+)(?:="([^"]*)")?/g)].slice(1).map((m) => [m[1], m[2] ?? ""]));
const tags = (html, name) => [...html.matchAll(new RegExp(`<${name}\\b[^>]*>`, "g"))].map((m) => attrs(m[0]));
const region = (html, name) => (html.match(new RegExp(`<${name}\\b[\\s\\S]*?</${name}>`)) || [""])[0];
const forms = (html) => [...html.matchAll(/<form\b[^>]*>[\s\S]*?<\/form>/g)].map((m) => m[0]);
const signupForms = (html) => forms(html).filter((form) => /buttondown\.com/i.test(attrs(form.match(/<form\b[^>]*>/)[0]).action || ""));
const checkSignup = (where, html) => {
  const found = signupForms(html);
  if (found.length === 0) fail(`${where} has no form posting to the newsletter provider`);
  for (const form of found) checkForm(where, form);
};

const checkForm = (where, form) => {
  const f = attrs(form.match(/<form\b[^>]*>/)[0]);
  if ((f.method || "").toLowerCase() !== "post") fail(`${where} form method is "${f.method}" (expected post)`);
  if (f.action !== fixtureUrl) fail(`${where} form action is "${f.action}" (expected the configured NEWSLETTER_URL)`);
  if ("target" in f) fail(`${where} form has target="${f.target}"`);
  const inputs = tags(form, "input");
  const email = inputs.find((a) => a.name === "email");
  if (!email) fail(`${where} form has no input named email`);
  else {
    if (email.type !== "email") fail(`${where} email input is type="${email.type}"`);
    if (!("required" in email)) fail(`${where} email input is not required`);
    if (!email.id || !tags(form, "label").some((l) => l.for === email.id)) fail(`${where} email input has no matching label`);
  }
  if (!inputs.some((a) => a.type === "hidden" && a.name === "embed" && a.value === "1")) fail(`${where} form has no hidden embed=1`);
  if (!inputs.some((a) => a.type === "checkbox" && "required" in a)) fail(`${where} form has no required checkbox`);
  const submits = tags(form, "button").filter((a) => a.type === "submit");
  if (submits.length !== 1) fail(`${where} form has ${submits.length} submit buttons`);
  else if ("disabled" in submits[0]) fail(`${where} submit button is disabled in the HTML`);
};

const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)]));
const files = walk("dist");
let pages = 0;
for (const f of files.filter((f) => f.endsWith(".html"))) {
  const html = fs.readFileSync(f, "utf8");
  if (/<iframe\b/i.test(html)) fail(`${f} has an iframe`);
  for (const m of html.matchAll(/<(?:script|img)\b[^>]*>/gi)) if (/buttondown\.com/i.test(attrs(m[0]).src || "")) fail(`${f} loads ${attrs(m[0]).src}`);
  for (const m of html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)) if (/buttondown\.com/i.test(m[1])) fail(`${f} has an inline script carrying buttondown.com`);
  if (/document\.cookie|cookieStore/.test(html)) fail(`${f} touches cookies`);
  if (html.includes(`http-equiv="refresh"`)) continue;
  pages += 1;
  const footer = region(html, "footer");
  checkSignup(`${f} footer`, footer);
  for (const href of [`${base}legal/privacy/`, `${base}newsletter/`]) if (!footer.includes(`href="${href}"`)) fail(`${f} footer does not link ${href}`);
}
if (pages === 0) fail("no built pages found");
for (const f of files.filter((f) => f.endsWith(".js"))) {
  const js = fs.readFileSync(f, "utf8");
  if (/document\.cookie|cookieStore/.test(js)) fail(`${f} touches cookies`);
  if (/buttondown\.com/i.test(js)) fail(`${f} carries buttondown.com`);
}

const page = "dist/newsletter/index.html";
const main = region(fs.readFileSync(page, "utf8"), "main");
checkSignup(`${page} main`, main);
if (!main.includes(`href="${base}legal/privacy/"`)) fail(`${page} main does not link ${base}legal/privacy/`);
if (!main.includes(`href="${invite}"`)) fail(`${page} main does not link the Discord invite`);

if (fails.length) {
  for (const f of fails) console.log(`FAIL: ${f}`);
  process.exit(1);
}
console.log(`newsletter forms OK across ${pages} pages`);
' "$NORMALIZED_BASE" "$INVITE" "$FIXTURE_URL"

echo "== /newsletter/ is a permanent sitemap URL, never a redirect =="
SITEMAP_FILE="dist/sitemap-0.xml"
[ -f "$SITEMAP_FILE" ] || SITEMAP_FILE="dist/sitemap.xml"
if ! grep -qF "<loc>${SITE}${NORMALIZED_BASE}newsletter/</loc>" "$SITEMAP_FILE"; then
  echo "FAIL: ${SITE}${NORMALIZED_BASE}newsletter/ missing from $SITEMAP_FILE"
  exit 1
fi
if sed -n '/^const SLUG_REDIRECTS = {/,/^};/p' astro.config.mjs | grep -qP "^\s*'/newsletter/?'"; then
  echo "FAIL: /newsletter/ is a SLUG_REDIRECTS key"
  exit 1
fi
echo "sitemap and redirects OK"

echo "== Build with an empty NEWSLETTER_URL: the Discord fallback replaces the forms =="
set_newsletter_url ""
npm run build
test -f "$PAGE"
if grep -rlP '<form\b[^>]*\b(method="post"|action=)' dist --include='*.html'; then
  echo "FAIL: a page renders a posting form while NEWSLETTER_URL is empty"
  exit 1
fi
EMPTY_FOOTER_INVITES=$(region_invites dist/index.html footer)
EMPTY_MAIN_INVITES=$(region_invites "$PAGE" main)
if [ "$EMPTY_FOOTER_INVITES" -lt 1 ] || [ "$EMPTY_MAIN_INVITES" -lt 1 ]; then
  echo "FAIL: with an empty NEWSLETTER_URL the footer or /newsletter/ main does not link the Discord invite"
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

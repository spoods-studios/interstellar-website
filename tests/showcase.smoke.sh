#!/usr/bin/env bash
# Smoke-test harness for the showcase page at the site root (SSC-04, SSC-05):
# chapter structure, clip markup, still and poster byte caps, capture dates,
# and the eager and worst-case full-scroll byte budgets (PERF-06, PERF-07).
# Every budget is a byte count against a clean build's dist/, never wall-clock.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Clip playback: near the viewport, at most two, never under reduced motion =="
node --input-type=module -e '
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
const file = process.argv[1];
const { setupClipPlay } = await import(pathToFileURL(file).href);
assert.equal(typeof setupClipPlay, "function", "clip-play.ts exports no setupClipPlay");

const world = ({ reduce = false, saveData = false, count = 4 } = {}) => {
  const touched = [];
  const videos = Array.from({ length: count }, (_, i) => {
    const v = { id: i, paused: true, plays: 0, pauses: 0 };
    v.play = () => { v.plays++; v.paused = false; return Promise.resolve(); };
    v.pause = () => { v.pauses++; v.paused = true; };
    Object.defineProperty(v, "currentTime", { get: () => { touched.push(i); return 0; }, set: () => touched.push(i) });
    return v;
  });
  const observers = [];
  class IntersectionObserver {
    constructor(callback, options) { this.callback = callback; this.options = options; this.targets = []; observers.push(this); }
    observe(t) { this.targets.push(t); }
    unobserve() {}
    disconnect() {}
  }
  const listeners = [];
  const mq = { matches: reduce, media: "(prefers-reduced-motion: reduce)", addEventListener: (type, l) => { assert.equal(type, "change"); listeners.push(l); }, removeEventListener() {} };
  const queries = [];
  const matchMedia = function (q) { queries.push(q); return mq; };
  setupClipPlay(videos, { IntersectionObserver, matchMedia, saveData });
  assert.equal(observers.length, 1, "expected one IntersectionObserver");
  const io = observers[0];
  const fire = (entries) => io.callback(entries.map(([v, isIntersecting]) => ({ target: v, isIntersecting })), io);
  const setReduce = (matches) => { mq.matches = matches; for (const l of listeners) l({ matches, media: mq.media }); };
  const playing = () => videos.filter((v) => !v.paused).length;
  return { videos, io, fire, setReduce, playing, touched, queries };
};

{
  const w = world();
  assert.deepEqual(w.io.targets, w.videos, "observer does not watch every clip");
  assert.ok(w.queries.includes("(prefers-reduced-motion: reduce)"), "never queries prefers-reduced-motion: reduce");
  w.fire([[w.videos[0], true]]);
  assert.equal(w.videos[0].plays, 1, "an intersecting clip did not play");
  w.fire([[w.videos[0], false]]);
  assert.equal(w.videos[0].pauses, 1, "a leaving clip did not pause");
  assert.equal(w.playing(), 0);
}
{
  const w = world();
  w.fire(w.videos.map((v) => [v, true]));
  assert.ok(w.playing() <= 2, `${w.playing()} clips playing with four near`);
  assert.equal(w.playing(), 2, "two near clips should play");
  const first = w.videos.find((v) => !v.paused);
  w.fire([[first, false]]);
  assert.equal(w.playing(), 2, "a waiting near clip should take the freed slot");
  assert.ok(first.paused);
}
{
  const w = world({ reduce: true });
  w.fire(w.videos.map((v) => [v, true]));
  w.fire(w.videos.map((v) => [v, false]));
  w.fire(w.videos.map((v) => [v, true]));
  assert.equal(w.videos.reduce((n, v) => n + v.plays, 0), 0, "play() was called under reduced motion");
}
{
  const w = world();
  w.fire(w.videos.map((v) => [v, true]));
  assert.equal(w.playing(), 2);
  w.setReduce(true);
  assert.equal(w.playing(), 0, "a switch to reduce left clips playing");
  const plays = w.videos.reduce((n, v) => n + v.plays, 0);
  w.fire(w.videos.map((v) => [v, true]));
  assert.equal(w.videos.reduce((n, v) => n + v.plays, 0), plays, "play() was called after the switch to reduce");
  assert.deepEqual(w.touched, [], "currentTime was touched");
}
{
  const w = world({ saveData: true });
  w.fire(w.videos.map((v) => [v, true]));
  assert.equal(w.videos.reduce((n, v) => n + v.plays, 0), 0, "play() was called with saveData on");
}
console.log("clip-play OK");
' "$PWD/src/scripts/clip-play.ts"

echo "== Motion module: reduced motion starts nothing and touches no page element =="
node --import 'data:text/javascript,import { register } from "node:module"; register("data:text/javascript,export async function load(url, context, next) { return url.endsWith(\".css\") ? { format: \"module\", source: \"\", shortCircuit: true } : next(url, context); }");' --input-type=module -e '
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
const touched = [];
Object.defineProperty(globalThis, "document", { configurable: true, get: () => { touched.push("document"); return undefined; } });
const queries = [];
globalThis.matchMedia = (q) => { queries.push(q); return { matches: true, media: q, addEventListener() { touched.push("listener"); }, removeEventListener() {} }; };
const { initShowcaseMotion } = await import(pathToFileURL(process.argv[1]).href);
initShowcaseMotion();
assert.deepEqual(queries, ["(prefers-reduced-motion: reduce)"]);
assert.deepEqual(touched, [], "showcase motion touched the page under reduced motion");
globalThis.matchMedia = (q) => ({ matches: false, media: q, addEventListener() {}, removeEventListener() {} });
assert.throws(() => initShowcaseMotion());
assert.ok(touched.includes("document"), "showcase motion never touched the page without reduced motion");
console.log("showcase-motion OK");
' "$PWD/src/scripts/showcase-motion.ts"

echo "== Clean build =="
rm -rf dist
npm run build

BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
PAGE=dist/index.html
test -f "$PAGE"

echo "== Perf log reports the home page's eager bytes =="
PERF_OUT=$(bash tools/perf-log.sh)
echo "perf log: $PERF_OUT"
EAGER=$(node -e '
const rec = JSON.parse(process.argv[1]);
if (rec.metric !== "home_eager_bytes") throw new Error(`perf log metric is ${rec.metric}, expected home_eager_bytes`);
if (typeof rec.value !== "number" || !Number.isFinite(rec.value) || rec.value <= 0) throw new Error(`perf log value ${rec.value} is not a positive number`);
console.log(rec.value);
' "$PERF_OUT")

echo "== Page structure, clips, stills, dates and budgets =="
node -e '
const fs = require("fs");
const [page, base, capturesPath, eagerRaw] = process.argv.slice(1);
const html = fs.readFileSync(page, "utf8");
const captures = JSON.parse(fs.readFileSync(capturesPath, "utf8"));
const fails = [];
const fail = (m) => fails.push(m);

const attrs = (tag) => {
  const map = new Map();
  const body = tag.replace(/^<[a-z]+/i, "").replace(/\/?>$/, "");
  for (const m of body.matchAll(/([^\s=]+)(?:="([^"]*)")?/g)) map.set(m[1].toLowerCase(), m[2] ?? "");
  return map;
};
const distPath = (url) => {
  if (!url.startsWith(base)) { fail(`${url} is not under ${base}`); return null; }
  const p = "dist/" + decodeURI(url.slice(base.length));
  if (!fs.existsSync(p)) { fail(`${url} does not resolve to ${p}`); return null; }
  return p;
};
const size = (p) => (p ? fs.statSync(p).size : 0);
const candidates = (srcset) =>
  (srcset ?? "").split(",").map((c) => c.trim()).filter(Boolean).map((c) => {
    const [url, descriptor = ""] = c.split(/\s+/);
    return { url, descriptor };
  });

const h1s = [...html.matchAll(/<h1\b[^>]*>([\s\S]*?)<\/h1>/g)].map((m) => m[1].replace(/<[^>]*>/g, "").trim());
if (h1s.length !== 1 || h1s[0] !== "Setare Aerospace") fail(`H1s are ${JSON.stringify(h1s)}, expected exactly ["Setare Aerospace"]`);

const sections = [...html.matchAll(/<section\b[^>]*>[\s\S]*?<\/section>/g)].map((m) => m[0]);
const next = sections.filter((s) => />Next milestones<\/h2>/.test(s));
if (next.length !== 1) fail(`found ${next.length} sections headed Next milestones`);
else if (!next[0].includes(`href="${base}roadmap/"`)) fail(`the Next milestones section has no link to ${base}roadmap/`);

let posterBytes = 0;
let clipBytes = 0;
const videos = [...html.matchAll(/<video\b[^>]*>[\s\S]*?<\/video>/g)].map((m) => m[0]);
if (videos.length < 1 || videos.length > 8) fail(`${videos.length} <video> elements, expected 1 to 8`);
const clipNames = new Set();
for (const v of videos) {
  const a = attrs(v.match(/^<video\b[^>]*>/)[0]);
  for (const flag of ["muted", "loop", "playsinline", "disableremoteplayback"]) if (!a.has(flag)) fail(`a <video> lacks ${flag}`);
  for (const banned of ["autoplay", "controls"]) if (a.has(banned)) fail(`a <video> carries ${banned}`);
  if (a.get("preload") !== "none") fail(`a <video> has preload=${a.get("preload")}`);
  if (a.get("width") !== "1280" || a.get("height") !== "720") fail(`a <video> is ${a.get("width")}x${a.get("height")}, expected 1280x720`);
  const poster = a.get("poster") ?? "";
  if (!poster.endsWith(".webp")) fail(`a <video> poster is "${poster}", expected a webp`);
  else {
    const bytes = size(distPath(poster));
    if (bytes > 80000) fail(`poster ${poster} is ${bytes} bytes, over 80000`);
    posterBytes += bytes;
  }
  const sources = [...v.matchAll(/<source\b[^>]*>/g)].map((m) => attrs(m[0]));
  const want = [["video/webm", ".webm"], ["video/mp4", ".mp4"]];
  if (sources.length !== 2) { fail(`a <video> has ${sources.length} <source> elements, expected 2`); continue; }
  let larger = 0;
  sources.forEach((s, i) => {
    const [type, ext] = want[i];
    const src = s.get("src") ?? "";
    if (s.get("type") !== type || !src.startsWith(`${base}showcase/`) || !src.endsWith(ext))
      fail(`<source> ${i + 1} is ${s.get("type")} ${src}, expected ${type} under ${base}showcase/ ending ${ext}`);
    larger = Math.max(larger, size(distPath(src)));
    clipNames.add(src.slice(`${base}showcase/`.length).replace(/\.(webm|mp4)$/, ""));
  });
  clipBytes += larger;
}
for (const [name, rec] of Object.entries(captures))
  if (rec.kind === "clip" && !clipNames.has(name)) fail(`clip ${name} from captures.json is not on the page`);

let lazyStillBytes = 0;
const pictures = [...html.matchAll(/<picture\b[^>]*>[\s\S]*?<\/picture>/g)].map((m) => m[0]);
if (pictures.length < 1 || pictures.length > 12) fail(`${pictures.length} <picture> elements, expected 1 to 12`);
pictures.forEach((pic, index) => {
  const sources = [...pic.matchAll(/<source\b[^>]*>/g)].map((m) => attrs(m[0]));
  const img = attrs((pic.match(/<img\b[^>]*>/) ?? [""])[0]);
  const sets = [
    ["image/avif", candidates(sources.find((s) => s.get("type") === "image/avif")?.get("srcset")), 150000],
    ["image/webp", candidates(sources.find((s) => s.get("type") === "image/webp")?.get("srcset")), 150000],
    ["image/jpeg", candidates(img.get("srcset")), 250000],
  ];
  if (!(img.get("src") ?? "").endsWith(".jpg")) fail(`still ${img.get("src")} falls back to a non-jpg`);
  let largest = size(distPath(img.get("src") ?? ""));
  for (const [type, list, cap] of sets) {
    const at1280 = list.find((c) => c.descriptor === "1280w");
    if (!at1280) { fail(`still ${img.get("src")} has no 1280w ${type} candidate`); continue; }
    const bytes = size(distPath(at1280.url));
    if (bytes > cap) fail(`${at1280.url} (${type} 1280w) is ${bytes} bytes, over ${cap}`);
    for (const c of list) largest = Math.max(largest, size(distPath(c.url)));
  }
  const hero = img.get("fetchpriority") === "high";
  if (index === 0) {
    if (!hero || img.get("loading") !== "eager") fail("the first still (Fig. 1) is not eager with fetchpriority high");
  } else {
    if (hero || img.get("loading") !== "lazy" || img.get("decoding") !== "async") fail(`still ${img.get("src")} is not lazy and async`);
    lazyStillBytes += largest;
  }
});

for (const [name, rec] of Object.entries(captures))
  if (!html.includes(rec.captured)) fail(`the page does not carry ${name}'"'"'s capture date ${rec.captured}`);

const eager = Number(eagerRaw);
if (!(eager <= 500000)) fail(`eager bytes ${eager} exceed 500000`);
const worst = eager + lazyStillBytes + posterBytes + clipBytes;
console.log(`eager=${eager} lazy_stills=${lazyStillBytes} posters=${posterBytes} clips=${clipBytes} worst_case=${worst}`);
if (worst > 8000000) fail(`worst-case full scroll ${worst} bytes exceeds 8000000`);

if (fails.length) {
  for (const f of fails) console.log(`FAIL: ${f}`);
  process.exit(1);
}
' "$PAGE" "$NORMALIZED_BASE" src/assets/showcase/captures.json "$EAGER"
echo "showcase OK"

echo "== Motion module: one hashed script on / beyond those every page carries, none on roadmap or 404, gzip budget, reduced-motion CSS gate =="
node -e '
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const [base, site] = process.argv.slice(1);
const fails = [];
const fail = (m) => fails.push(m);

const scriptsBesidesAnalytics = (file) =>
  [...fs.readFileSync(file, "utf8").matchAll(/<script\b[^>]*>[\s\S]*?<\/script>/g)].map((m) => m[0]).filter((s) => !s.includes("gc.zgo.at"));

const pages = fs.readdirSync("dist", { recursive: true }).filter((p) => p.endsWith(".html")).map((p) => `dist/${p}`).filter((p) => !fs.readFileSync(p, "utf8").includes(`http-equiv="refresh"`));
const shared = scriptsBesidesAnalytics("dist/index.html").filter((s) => pages.every((p) => scriptsBesidesAnalytics(p).includes(s)));
const pageOwnScripts = (file) => scriptsBesidesAnalytics(file).filter((s) => !shared.includes(s));

const home = pageOwnScripts("dist/index.html");
const escapedBase = base.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const moduleSrc = new RegExp("^" + escapedBase + "_astro/[^\"/]+\\.[A-Za-z0-9_-]{6,}\\.js$");
let entry = null;
if (home.length !== 1) fail(`dist/index.html carries ${home.length} scripts besides GoatCounter and those every page carries, expected 1`);
else {
  const m = home[0].match(/^<script type="module" src="([^"]+)"><\/script>$/);
  if (!m || !moduleSrc.test(m[1])) fail(`the script on dist/index.html is ${home[0].slice(0, 160)}, expected a hashed module under ${base}_astro/`);
  else entry = "dist/" + m[1].slice(base.length);
}
for (const page of ["dist/roadmap/index.html", "dist/404.html"]) {
  const extra = pageOwnScripts(page);
  if (extra.length) fail(`${page} carries ${extra.length} scripts besides GoatCounter and those every page carries`);
}

if (entry) {
  const seen = new Set();
  const queue = [entry];
  while (queue.length) {
    const f = queue.shift();
    if (seen.has(f)) continue;
    if (!fs.existsSync(f)) { fail(`${f} is imported but missing`); continue; }
    seen.add(f);
    for (const m of fs.readFileSync(f, "utf8").matchAll(/(?:\bfrom|\bimport)\s*\(?\s*["\x27`]([^"\x27`]+\.js)["\x27`]/g)) {
      const spec = m[1];
      if (spec.startsWith("./") || spec.startsWith("../")) queue.push(path.join(path.dirname(f), spec));
      else if (spec.startsWith(`${base}_astro/`)) queue.push("dist/" + spec.slice(base.length));
      else fail(`${f} imports ${spec}, outside ${base}_astro/`);
    }
  }
  const gz = [...seen].reduce((sum, f) => sum + execFileSync("gzip", ["-c"], { input: fs.readFileSync(f) }).length, 0);
  console.log(`animation JS: ${[...seen].join(" ")} gzip=${gz}`);
  if (gz > 20000) fail(`animation JS is ${gz} bytes gzip, over 20000`);
}

const html = fs.readFileSync("dist/index.html", "utf8");
const css = [
  ...[...html.matchAll(/<link\b[^>]*rel="stylesheet"[^>]*>/g)].map((m) => {
    const href = (m[0].match(/href="([^"]+)"/) ?? [])[1] ?? "";
    if (!href.startsWith(base)) { fail(`stylesheet ${href} is not under ${base}`); return ""; }
    return fs.readFileSync("dist/" + href.slice(base.length), "utf8");
  }),
  ...[...html.matchAll(/<style\b[^>]*>([\s\S]*?)<\/style>/g)].map((m) => m[1]),
].join("\n").replace(/\/\*[\s\S]*?\*\//g, "");
const rules = [];
const stack = [];
let buf = "";
for (const ch of css) {
  if (ch === "{") { stack.push(buf.slice(buf.lastIndexOf(";") + 1).trim()); buf = ""; }
  else if (ch === "}") {
    const prelude = stack.pop();
    if (prelude !== undefined && !prelude.startsWith("@")) rules.push({ selector: prelude, body: buf, parents: [...stack] });
    buf = "";
  } else buf += ch;
}
const gated = (r) => r.parents.some((p) => /^@media\b/.test(p) && /prefers-reduced-motion\s*:\s*no-preference/.test(p));
const jsScoped = (r) => /\.js(?![\w-])/.test(r.selector);
const transparent = (r) => /(?:^|;)\s*opacity\s*:\s*0*(?:\.0*)?\s*(?:!important\s*)?(?:;|$)/.test(r.body);
const moved = (r) => /(?:^|;)\s*(?:transform|translate|rotate|scale|filter)\s*:\s*(?!none\s*(?:!important\s*)?(?:;|$))/.test(r.body);
if (!/@media[^{]*prefers-reduced-motion\s*:\s*no-preference/.test(css)) fail("the CSS on dist/index.html has no prefers-reduced-motion: no-preference media block");
const hidden = rules.filter((r) => jsScoped(r) && (transparent(r) || moved(r)));
if (!hidden.some(gated)) fail("no .js hidden-state rule sits inside the no-preference media block");
for (const r of hidden) if (!gated(r)) fail(`.js hidden-state rule "${r.selector}" sits outside the no-preference media block`);
for (const r of rules) if (/\.enter\b/.test(r.selector) && transparent(r) && !jsScoped(r)) fail(`"${r.selector}" hides content without the .js scope`);

const siteHost = new URL(site).host;
const jsFiles = [];
const walk = (dir) => {
  for (const d of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, d.name);
    if (d.isDirectory()) walk(p);
    else if (/\.m?js$/.test(d.name)) jsFiles.push(p);
  }
};
walk("dist");
for (const f of jsFiles) {
  const text = fs.readFileSync(f, "utf8");
  if (text.includes("document.cookie")) fail(`${f} references document.cookie`);
  for (const m of text.matchAll(/(?:https?:\/\/|["\x27`]\/\/)([a-z0-9-]+(?:\.[a-z0-9-]+)+)/gi)) {
    const host = m[1].toLowerCase();
    if (host !== siteHost && host !== "www.w3.org") fail(`${f} references the origin ${host}`);
  }
}

if (fails.length) {
  for (const f of fails) console.log(`FAIL: ${f}`);
  process.exit(1);
}
' "$NORMALIZED_BASE" "$(grep -oP "site:\s*'\K[^']+" astro.config.mjs)"
echo "motion module OK"

echo "ALL CHECKS PASSED"

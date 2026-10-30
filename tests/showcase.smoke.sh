#!/usr/bin/env bash
# Smoke-test harness for the showcase page at the site root (SSC-04, SSC-05):
# chapter structure, clip markup, still and poster byte caps, capture dates,
# and the eager and worst-case full-scroll byte budgets (PERF-06, PERF-07).
# Every budget is a byte count against a clean build's dist/, never wall-clock.
set -euo pipefail

cd "$(dirname "$0")/.."

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

const wantHeadings = ["Layer buildup", "Launch-site terrain", "Lighting", "Orbital mechanics", "Next milestones", "Discord"];
const headings = [...html.matchAll(/<h2\b[^>]*>([\s\S]*?)<\/h2>/g)].map((m) => m[1].replace(/<[^>]*>/g, "").trim());
if (JSON.stringify(headings) !== JSON.stringify(wantHeadings)) fail(`chapter headings are ${JSON.stringify(headings)}`);

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
if (html.includes("2026-10-21")) fail("the page carries the mockup date 2026-10-21");

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

echo "ALL CHECKS PASSED"

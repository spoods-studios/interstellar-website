#!/usr/bin/env node
// Single source of derived test expectations for tests/*.smoke.sh. Every
// corpus-sized assertion in the harness reads its expected value from this
// CLI at run time instead of a hardcoded literal, so a new devlog/technical/
// roadmap content drop can never turn the suite red on its own.
//
// devlog-meta.ts's isAddendum()/entryDate() logic is deliberately mirrored
// here rather than imported: its extensionless relative imports
// (./title-from-h1, ./entry-order) do not resolve under bare Node -- there is
// no bundler here to rewrite them. entry-order.ts is import-free on purpose
// (see its own header comment) and is the one file in src/lib/ that CAN be
// imported directly from a plain Node CLI, so the newest/oldest derivation
// below imports compareNewestFirst from it and nothing else.
//
// Usage: node tests/helpers/content-expectations.mjs <key>
// Prints exactly one bare value on stdout, no label, so bash can consume it
// with plain command substitution.

import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { compareNewestFirst } from '../../src/lib/entry-order.ts';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '../..');

const ADDENDUM_TAG = 'milestone-addendum';
const DEVLOG_FILENAME_RE = /^(\d{4}-\d{2}-\d{2})-.+\.md$/;
const MILESTONE_DIR_RE = /^m\d+(?:\.\d+)?$/i;
const DEEPDIVE_FILENAME_RE = /^phase-\d+(?:\.\d+)?-.+\.md$/;
const ROADMAP_FILENAME_RE = /^M\d+(?:\.\d+)?\.md$/i;
// Matches ![alt](path) and ![alt](path "title"); captures the path only.
const IMAGE_RE = /!\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/;

// Deliberately minimal line scanner -- no YAML dependency, and not the
// js-yaml that happens to sit in node_modules as an Astro transitive. Reads
// only the leading `---` fenced block, and only the handful of keys this
// helper needs. Anything shaped differently than every current post throws
// naming the file, rather than silently guessing.
function readFrontmatter(filePath) {
  const text = readFileSync(filePath, 'utf8');
  const lines = text.split(/\r?\n/);
  if (lines[0] !== '---') {
    return { data: {}, body: text };
  }
  let end = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === '---') {
      end = i;
      break;
    }
  }
  if (end === -1) {
    return { data: {}, body: text };
  }
  const data = {};
  for (let i = 1; i < end; i++) {
    const match = lines[i].match(/^([A-Za-z_]+):\s*(.*)$/);
    if (!match) continue;
    const [, key, rawValue] = match;
    let value = rawValue.trim();
    if (key === 'status') {
      // devlog frontmatter carries a trailing inline comment, e.g.
      // "published   # draft | published" -- strip it.
      value = value.split('#')[0].trim();
    }
    if (key === 'tags') {
      if (!value.startsWith('[') || !value.endsWith(']')) {
        throw new Error(
          `${filePath}: tags line is not the inline-array form every current post uses: ${rawValue}`
        );
      }
      value = value
        .slice(1, -1)
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);
    }
    data[key] = value;
  }
  const body = lines.slice(end + 1).join('\n');
  return { data, body };
}

function isDraft(data) {
  return data.status === 'draft';
}

function listMarkdownFiles(dir) {
  return readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.md'))
    .map((entry) => entry.name);
}

function deriveDevlogEntries() {
  const dir = path.join(ROOT, 'devlog');
  const entries = [];
  for (const name of listMarkdownFiles(dir)) {
    if (name === '_TEMPLATE.md') continue;
    const match = name.match(DEVLOG_FILENAME_RE);
    if (!match) continue;
    const { data } = readFrontmatter(path.join(dir, name));
    if (isDraft(data)) continue;
    const id = name.replace(/\.md$/, '');
    const date = data.date
      ? new Date(`${data.date}T00:00:00Z`)
      : new Date(`${match[1]}T00:00:00Z`);
    const isAddendum = Array.isArray(data.tags) && data.tags.includes(ADDENDUM_TAG);
    entries.push({ id, date, isAddendum });
  }
  if (entries.length === 0) {
    throw new Error('devlog/: derived zero visible entries');
  }
  return [...entries].sort(compareNewestFirst);
}

function deriveTechnical() {
  const dir = path.join(ROOT, 'technical');
  const dirents = readdirSync(dir, { withFileTypes: true });
  const milestoneDirs = dirents
    .filter((entry) => entry.isDirectory() && MILESTONE_DIR_RE.test(entry.name))
    .map((entry) => entry.name);
  if (milestoneDirs.length === 0) {
    throw new Error('technical/: derived zero milestone directories');
  }

  let deepdiveCount = 0;
  for (const milestone of milestoneDirs) {
    const milestoneDir = path.join(dir, milestone);
    for (const name of listMarkdownFiles(milestoneDir)) {
      if (!DEEPDIVE_FILENAME_RE.test(name)) continue;
      const { data } = readFrontmatter(path.join(milestoneDir, name));
      if (isDraft(data)) continue;
      deepdiveCount++;
    }
  }
  if (deepdiveCount === 0) {
    throw new Error('technical/: derived zero deep-dive pages');
  }

  const legendPath = path.join(dir, '_how-to-read.md');
  const { data: legendData } = readFrontmatter(legendPath);
  const legendCount = isDraft(legendData) ? 0 : 1;

  return { deepdiveCount, legendCount, milestoneCount: milestoneDirs.length };
}

function deriveRoadmapCount() {
  const dir = path.join(ROOT, 'roadmap');
  const files = listMarkdownFiles(dir).filter((name) => ROADMAP_FILENAME_RE.test(name));
  const visible = files.filter((name) => !isDraft(readFrontmatter(path.join(dir, name)).data));
  if (visible.length === 0) {
    throw new Error('roadmap/: derived zero milestone files');
  }
  return visible.length;
}

function derivePagesCount() {
  const dir = path.join(ROOT, 'pages');
  const files = listMarkdownFiles(dir);
  const visible = files.filter((name) => !isDraft(readFrontmatter(path.join(dir, name)).data));
  if (visible.length === 0) {
    throw new Error('pages/: derived zero standalone pages');
  }
  return visible.length;
}

// D-48/hero-assets.ts: the og:image hero is resolved from the entry's FIRST
// body image import, never the hero_visual frontmatter field -- two posts
// put a prose sentence there with no file behind it. Mirror that here by
// scanning the body (post-frontmatter) for the first Markdown image
// reference and reducing it to its basename.
function firstBodyImageBasename(body) {
  const match = body.match(IMAGE_RE);
  if (!match) return null;
  return path.basename(match[1]);
}

function deriveOgImageCount(devlogEntries) {
  const dir = path.join(ROOT, 'devlog');
  const basenames = new Set();
  for (const entry of devlogEntries) {
    const { body } = readFrontmatter(path.join(dir, `${entry.id}.md`));
    const basename = firstBodyImageBasename(body);
    if (basename) basenames.add(basename);
  }
  return basenames.size + 1; // +1 for the default card, used by heroless entries
}

function deriveAll() {
  const devlogEntries = deriveDevlogEntries();
  const technical = deriveTechnical();
  const roadmapCount = deriveRoadmapCount();
  const pagesCount = derivePagesCount();
  const ogImageCount = deriveOgImageCount(devlogEntries);

  const technicalPageCount = technical.deepdiveCount + technical.legendCount;

  // Structural singletons: these routes exist once no matter how much
  // devlog/technical/roadmap content lands -- they are route-shaped, not
  // content-shaped, so they stay named constants rather than derived counts.
  const TECHNICAL_INDEX_SINGLETON = 1; // dist/technical/index.html
  const ROADMAP_OVERVIEW_SINGLETON = 1; // dist/roadmap/index.html
  const HOW_ITS_MADE_SINGLETON = 1; // dist/how-its-made/index.html
  const HOMEPAGE_SINGLETON = 1; // dist/index.html
  const NOT_FOUND_SINGLETON = 1; // dist/404.html

  const sitePageCount =
    devlogEntries.length +
    technical.deepdiveCount +
    technical.legendCount +
    TECHNICAL_INDEX_SINGLETON +
    technical.milestoneCount +
    roadmapCount +
    ROADMAP_OVERVIEW_SINGLETON +
    HOW_ITS_MADE_SINGLETON +
    HOMEPAGE_SINGLETON +
    NOT_FOUND_SINGLETON;

  return {
    devlog_count: devlogEntries.length,
    technical_deepdive_count: technical.deepdiveCount,
    technical_page_count: technicalPageCount,
    technical_milestone_count: technical.milestoneCount,
    roadmap_count: roadmapCount,
    pages_count: pagesCount,
    site_page_count: sitePageCount,
    og_image_count: ogImageCount,
    newest_devlog_id: devlogEntries[0].id,
    oldest_devlog_id: devlogEntries[devlogEntries.length - 1].id,
  };
}

function main() {
  const key = process.argv[2];
  const values = deriveAll();
  if (!key || !(key in values)) {
    const validKeys = Object.keys(values).join(', ');
    console.error(`content-expectations: unrecognised key '${key ?? ''}' -- valid keys: ${validKeys}`);
    process.exit(1);
  }
  console.log(values[key]);
}

main();

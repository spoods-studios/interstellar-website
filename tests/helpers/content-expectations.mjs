#!/usr/bin/env node
// Single source of derived test expectations for tests/*.smoke.sh. Every
// corpus-sized assertion in the harness reads its expected value from this
// CLI at run time instead of a hardcoded literal, so a new roadmap content
// drop can never turn the suite red on its own.
//
// Usage: node tests/helpers/content-expectations.mjs <key>
// Prints exactly one bare value on stdout, no label, so bash can consume it
// with plain command substitution.

import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '../..');

const ROADMAP_FILENAME_RE = /^M\d+(?:\.\d+)?\.md$/i;

// Deliberately minimal line scanner -- no YAML dependency, and not the
// js-yaml that happens to sit in node_modules as an Astro transitive. Reads
// only the leading `---` fenced block as flat `key: value` lines.
function readFrontmatter(filePath) {
  const text = readFileSync(filePath, 'utf8');
  const lines = text.split(/\r?\n/);
  if (lines[0] !== '---') {
    return {};
  }
  let end = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === '---') {
      end = i;
      break;
    }
  }
  if (end === -1) {
    return {};
  }
  const data = {};
  for (let i = 1; i < end; i++) {
    const match = lines[i].match(/^([A-Za-z_]+):\s*(.*)$/);
    if (!match) continue;
    data[match[1]] = match[2].trim();
  }
  return data;
}

function isDraft(data) {
  return data.status === 'draft';
}

function listMarkdownFiles(dir) {
  return readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.md'))
    .map((entry) => entry.name);
}

function deriveRoadmapCount() {
  const dir = path.join(ROOT, 'roadmap');
  const files = listMarkdownFiles(dir).filter((name) => ROADMAP_FILENAME_RE.test(name));
  const visible = files.filter((name) => !isDraft(readFrontmatter(path.join(dir, name))));
  if (visible.length === 0) {
    throw new Error('roadmap/: derived zero milestone files');
  }
  return visible.length;
}

function derivePagesCount() {
  const dir = path.join(ROOT, 'pages');
  const files = listMarkdownFiles(dir);
  const visible = files.filter((name) => !isDraft(readFrontmatter(path.join(dir, name))));
  if (visible.length === 0) {
    throw new Error('pages/: derived zero standalone pages');
  }
  return visible.length;
}

function deriveAll() {
  const roadmapCount = deriveRoadmapCount();
  const pagesCount = derivePagesCount();

  // Structural singletons: these routes exist once no matter how much
  // roadmap content lands -- they are route-shaped, not content-shaped, so
  // they stay named constants rather than derived counts.
  const ROADMAP_OVERVIEW_SINGLETON = 1; // dist/roadmap/index.html
  const HOMEPAGE_SINGLETON = 1; // dist/index.html
  const NOT_FOUND_SINGLETON = 1; // dist/404.html

  const sitePageCount =
    roadmapCount +
    ROADMAP_OVERVIEW_SINGLETON +
    HOMEPAGE_SINGLETON +
    NOT_FOUND_SINGLETON;

  return {
    roadmap_count: roadmapCount,
    pages_count: pagesCount,
    site_page_count: sitePageCount,
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
  console.log(String(values[key]));
}

main();

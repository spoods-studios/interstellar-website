import { defineConfig } from 'astro/config';
import { satteri } from '@astrojs/markdown-satteri';
import { markdownToHtml } from 'satteri';
import sitemap from '@astrojs/sitemap';
import fs from 'node:fs';
import nodePath from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createWikilinkResolver } from './src/lib/wikilink-resolver.mjs';
import { createWikilinkPlugin } from './src/lib/mdast-wikilinks.mjs';
import { createDeepDiveLinkPlugin } from './src/lib/mdast-deepdive-links.mjs';

const BASE = '/interstellar-website';
const NORMALIZED_BASE = BASE.endsWith('/') ? BASE : `${BASE}/`;
const TECHNICAL_ROOT = fileURLToPath(new URL('./technical', import.meta.url));

const wikilinkResolver = createWikilinkResolver({
  base: BASE,
  technicalRoot: TECHNICAL_ROOT,
});

// D-35/D-38: maps a roadmap phase number to its technical/ deep-dive URL by
// walking technical/<milestone>/ once per milestone and matching filenames'
// own phase-number capture (never a hand-written mapping table).
const PHASE_FILE_RE = /^phase-(\d+(?:\.\d+)?)-(.+)\.md$/;
const deepDivePhaseMapCache = new Map();

function resolvePhase(milestone, phaseNumber) {
  const milestoneDir = milestone.toLowerCase();
  if (!deepDivePhaseMapCache.has(milestoneDir)) {
    const map = new Map();
    let files = [];
    try {
      files = fs.readdirSync(nodePath.join(TECHNICAL_ROOT, milestoneDir));
    } catch {
      // milestone directory doesn't exist -- leave the map empty, caller
      // treats a missed lookup as an unresolvable phase.
    }
    for (const file of files) {
      const match = file.match(PHASE_FILE_RE);
      if (!match) continue;
      map.set(parseFloat(match[1]), `${milestoneDir}/phase-${match[1]}-${match[2]}`);
    }
    deepDivePhaseMapCache.set(milestoneDir, map);
  }
  const id = deepDivePhaseMapCache.get(milestoneDir).get(phaseNumber);
  return id ? `${NORMALIZED_BASE}technical/${id}/` : null;
}

const ROADMAP_ROOT = fileURLToPath(new URL('./roadmap', import.meta.url));
const mdastPlugins = [
  createWikilinkPlugin({ resolve: wikilinkResolver.resolve }),
  createDeepDiveLinkPlugin({ resolvePhase }),
];

// 02-08 Task 2 finding: Astro's own glob loader (astro@7.0.9's
// content/loaders/glob.js) catches every render() error per-entry, logs it as
// `[ERROR] [glob-loader] ...`, and stores the entry with empty rendered
// content -- it never rethrows, so `astro build` exits 0 and silently ships
// an empty page even when a wikilink or deep-dive placeholder is
// unresolvable. That defeats D-39's "loud failure, never a silent
// passthrough" guarantee at the one layer (the real build) that actually
// matters -- tests/lib.smoke.mjs's direct markdownToHtml() calls only prove
// the plugins throw in isolation, not that the throw survives the real
// pipeline. Fail loud and early instead: re-run every technical/ and
// roadmap/ file through the exact same mdastPlugins pipeline at config-load
// time, before Astro's own build/dev server starts, letting a thrown error
// crash the process with a non-zero exit code the way a config-load failure
// always does.
function validateContentLoudFail() {
  const technicalFiles = [];
  for (const dirent of fs.readdirSync(TECHNICAL_ROOT, { withFileTypes: true })) {
    if (dirent.isFile() && dirent.name.endsWith('.md')) {
      technicalFiles.push(nodePath.join(TECHNICAL_ROOT, dirent.name));
    } else if (dirent.isDirectory()) {
      for (const file of fs.readdirSync(nodePath.join(TECHNICAL_ROOT, dirent.name))) {
        if (file.endsWith('.md')) technicalFiles.push(nodePath.join(TECHNICAL_ROOT, dirent.name, file));
      }
    }
  }
  const roadmapFiles = fs
    .readdirSync(ROADMAP_ROOT)
    .filter((file) => file.endsWith('.md'))
    .map((file) => nodePath.join(ROADMAP_ROOT, file));

  for (const filePath of [...technicalFiles, ...roadmapFiles]) {
    const source = fs.readFileSync(filePath, 'utf8');
    // Errors here propagate straight out of config evaluation -- unlike the
    // glob loader's own try/catch, nothing downstream swallows this one.
    markdownToHtml(source, { mdastPlugins, fileURL: pathToFileURL(filePath) });
  }
}

validateContentLoudFail();

export default defineConfig({
  site: 'https://spoods-studios.github.io',
  base: BASE,
  integrations: [sitemap()],
  markdown: {
    // D-39, amended: registered via Sätteri's own mdastPlugins option, not the
    // classic remark/rehype pipeline. mdastPlugins are additive -- Astro's own
    // heading-id, image and Shiki plugins survive, so Plan 04's TOC anchors
    // keep matching.
    processor: satteri({ mdastPlugins }),
    shikiConfig: {
      theme: 'github-light', // Astro/Shiki default is github-dark -- must override (D-22/D-41)
    },
  },
});

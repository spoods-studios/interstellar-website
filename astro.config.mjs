import { defineConfig } from 'astro/config';
import { satteri } from '@astrojs/markdown-satteri';
import sitemap from '@astrojs/sitemap';
import fs from 'node:fs';
import nodePath from 'node:path';
import { fileURLToPath } from 'node:url';
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

export default defineConfig({
  site: 'https://spoods-studios.github.io',
  base: BASE,
  integrations: [sitemap()],
  markdown: {
    // D-39, amended: registered via Sätteri's own mdastPlugins option, not the
    // classic remark/rehype pipeline. mdastPlugins are additive -- Astro's own
    // heading-id, image and Shiki plugins survive, so Plan 04's TOC anchors
    // keep matching.
    processor: satteri({
      mdastPlugins: [
        createWikilinkPlugin({ resolve: wikilinkResolver.resolve }),
        createDeepDiveLinkPlugin({ resolvePhase }),
      ],
    }),
    shikiConfig: {
      theme: 'github-light', // Astro/Shiki default is github-dark -- must override (D-22/D-41)
    },
  },
});

import { defineConfig } from 'astro/config';
import { satteri } from '@astrojs/markdown-satteri';
import { markdownToHtml } from 'satteri';
import sitemap from '@astrojs/sitemap';
import fs from 'node:fs';
import nodePath from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { assertInviteConfigured, assertGoatcounterConfigured } from './src/lib/site.mjs';

const BASE = '/interstellar-website';
const NORMALIZED_BASE = BASE.endsWith('/') ? BASE : `${BASE}/`;

// D-65/CONT-06 takedown redirects: the devlog and How It's Made were taken
// down, and a deployed URL is permanent, so every removed path lands here
// pointing at the site root. Keys are base-FREE old paths because Astro
// applies the base to the match side itself; destinations MUST be
// base-composed (never a literal) because Astro emits string destinations
// verbatim into the stub's meta-refresh URL -- a base-less destination builds
// clean and sends readers to a path that does not exist. The demo-old-slug
// entry was never published; it stays so the harness keeps exercising the
// mechanism end-to-end.
const SLUG_REDIRECTS = {
  '/devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim': `${NORMALIZED_BASE}`,
  '/devlog/2026-04-13-before-the-galaxy-a-triangle': `${NORMALIZED_BASE}`,
  '/devlog/2026-04-25-a-coordinate-system-that-doesnt-lie': `${NORMALIZED_BASE}`,
  '/devlog/2026-06-05-a-moon-that-actually-orbits': `${NORMALIZED_BASE}`,
  '/devlog/2026-06-14-from-one-world-to-many': `${NORMALIZED_BASE}`,
  '/devlog/2026-06-19-teaching-the-engine-to-fast-forward': `${NORMALIZED_BASE}`,
  '/devlog/2026-06-25-shipping-the-warp-lever-with-a-bouncer-on-the-door': `${NORMALIZED_BASE}`,
  '/devlog/2026-07-10-warping-without-losing-the-moon': `${NORMALIZED_BASE}`,
  '/devlog/2026-07-13-making-mercury-precess': `${NORMALIZED_BASE}`,
  '/devlog/2026-07-30-first-burn': `${NORMALIZED_BASE}`,
  '/devlog/2026-08-11-the-line-you-fly': `${NORMALIZED_BASE}`,
  '/devlog/2026-08-11-three-small-fixes-before-closing-the-books': `${NORMALIZED_BASE}`,
  '/devlog/2026-07-30-demo-old-slug': `${NORMALIZED_BASE}`,
  '/how-its-made': `${NORMALIZED_BASE}`,
};

const ROADMAP_ROOT = fileURLToPath(new URL('./roadmap', import.meta.url));
const PAGES_ROOT = fileURLToPath(new URL('./pages', import.meta.url));
const mdastPlugins = [];

// CR-01 fix (02-REVIEW.md): mdastPlugins above runs on every content tree
// (see content.config.ts's `collections` export), so the preflight below
// must walk all of them too -- this list is the single place that
// determines preflight coverage. A new tree can only escape validation by
// someone forgetting to add a line here, not by the preflight silently
// scoping itself to whichever trees happened to exist when it was written
// (which is exactly how pages/ was missed originally).
const CONTENT_TREES = [
  { root: ROADMAP_ROOT },
  { root: PAGES_ROOT },
];

function collectMarkdownFiles(root, { recursive = false, exclude = [] } = {}) {
  const files = [];
  for (const dirent of fs.readdirSync(root, { withFileTypes: true })) {
    if (dirent.isFile() && dirent.name.endsWith('.md') && !exclude.includes(dirent.name)) {
      files.push(nodePath.join(root, dirent.name));
    } else if (recursive && dirent.isDirectory()) {
      for (const file of fs.readdirSync(nodePath.join(root, dirent.name))) {
        if (file.endsWith('.md')) files.push(nodePath.join(root, dirent.name, file));
      }
    }
  }
  return files;
}

// 02-08 Task 2 finding: Astro's own glob loader (astro@7.0.9's
// content/loaders/glob.js) catches every render() error per-entry, logs it as
// `[ERROR] [glob-loader] ...`, and stores the entry with empty rendered
// content -- it never rethrows, so `astro build` exits 0 and silently ships
// an empty page even when a wikilink or deep-dive placeholder is
// unresolvable. That defeats D-39's "loud failure, never a silent
// passthrough" guarantee at the one layer (the real build) that actually
// matters -- tests/lib.smoke.mjs's direct markdownToHtml() calls only prove
// the plugins throw in isolation, not that the throw survives the real
// pipeline. Fail loud and early instead: re-run every file in every
// CONTENT_TREES root through the exact same mdastPlugins pipeline at
// config-load time, before Astro's own build/dev server starts, letting a
// thrown error crash the process with a non-zero exit code the way a
// config-load failure always does.
function validateContentLoudFail() {
  for (const { root, recursive, exclude } of CONTENT_TREES) {
    for (const filePath of collectMarkdownFiles(root, { recursive, exclude })) {
      const source = fs.readFileSync(filePath, 'utf8');
      // Errors here propagate straight out of config evaluation -- unlike the
      // glob loader's own try/catch, nothing downstream swallows this one.
      markdownToHtml(source, { mdastPlugins, fileURL: pathToFileURL(filePath) });
    }
  }
}

validateContentLoudFail();

// D-54: same reasoning as validateContentLoudFail() above -- config evaluation
// is the layer nothing downstream swallows, so an unset invite crashes the
// build here rather than shipping a CTA with an empty href.
assertInviteConfigured();

// D-61: same layer as assertInviteConfigured() -- config evaluation is where
// nothing downstream swallows a throw. Unset only warns here (pre-signup is
// an expected state and every push deploys), but a placeholder or malformed
// code crashes the build before it can silently send pageviews nowhere.
assertGoatcounterConfigured();

export default defineConfig({
  site: 'https://spoods-studios.github.io',
  base: BASE,
  redirects: SLUG_REDIRECTS,
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

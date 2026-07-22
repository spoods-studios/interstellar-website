import { defineConfig } from 'astro/config';
import { satteri } from '@astrojs/markdown-satteri';
import sitemap from '@astrojs/sitemap';
import { fileURLToPath } from 'node:url';
import { createWikilinkResolver } from './src/lib/wikilink-resolver.mjs';
import { createWikilinkPlugin } from './src/lib/mdast-wikilinks.mjs';

const BASE = '/interstellar-website';

const wikilinkResolver = createWikilinkResolver({
  base: BASE,
  technicalRoot: fileURLToPath(new URL('./technical', import.meta.url)),
});

export default defineConfig({
  site: 'https://spoods-studios.github.io',
  base: BASE,
  integrations: [sitemap()],
  markdown: {
    // D-39, amended: registered via Sätteri's own mdastPlugins option, not the
    // classic remark/rehype pipeline. mdastPlugins are additive -- Astro's own
    // heading-id, image and Shiki plugins survive, so Plan 04's TOC anchors
    // keep matching.
    processor: satteri({ mdastPlugins: [createWikilinkPlugin({ resolve: wikilinkResolver.resolve })] }),
    shikiConfig: {
      theme: 'github-light', // Astro/Shiki default is github-dark -- must override (D-22/D-41)
    },
  },
});

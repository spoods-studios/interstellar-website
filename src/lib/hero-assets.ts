import type { ImageMetadata } from 'astro';
import { lookupHero, type HeroRecord } from './hero-image';

// Two facts measured against this repo (03-RESEARCH Pattern 2):
//
// 1. assetImports is `undefined`, not an empty array, on the 73 entries with no
//    body image -- so its mere presence is the detector. The hero_visual
//    frontmatter field is NOT usable for this: two announcements carry prose
//    sentences there with no file behind them, so parsing it would fabricate a
//    path and trip the D-48 loud-fail on posts that are legitimately imageless.
// 2. The eager glob pulls both PNGs into every consuming page's module graph, so
//    both are emitted regardless of use -- which is exactly what makes a hero URL
//    resolvable from a shared layout without a per-route import.
//
// D-59: glob *.png only. The bundler's PNG and the Markdown pipeline's WebP of
// the same source coexist in dist/ under different hashes; the PNG is the safe
// one for Twitter Card.
const heroes = import.meta.glob<{ default: ImageMetadata }>('../../assets/*.png', { eager: true });

const byName = new Map<string, HeroRecord>(
  Object.entries(heroes).map(([p, m]) => [p.split('/').pop()!, m.default])
);

export function heroFor(entry: { id: string; assetImports?: string[] }): HeroRecord | null {
  return lookupHero(byName, entry.assetImports?.[0], entry.id);
}

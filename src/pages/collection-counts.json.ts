// Build-time regression guard for RESEARCH Pitfall 1 (glob()'s silent-empty-
// collection landmine): a typo'd loader `base` produces an empty collection
// with only a console warning, not a build failure, so an actual collection
// count -- not just a source-tree file count -- is the only thing that
// catches it. No page-level route in this phase queries all four collections
// at once yet, so this endpoint is the "small build-time check" tests/collections.smoke.sh
// asserts against until later plans' index routes make it redundant.
import { getCollection } from 'astro:content';
import { assertNonEmpty } from '../lib/content-guards';

export async function GET() {
  const [devlog, technical, roadmap, pages] = await Promise.all([
    getCollection('devlog'),
    getCollection('technical'),
    getCollection('roadmap'),
    getCollection('pages'),
  ]);

  assertNonEmpty(devlog, 'devlog');
  assertNonEmpty(technical, 'technical');
  assertNonEmpty(roadmap, 'roadmap');
  assertNonEmpty(pages, 'pages');

  return new Response(
    JSON.stringify({
      devlog: devlog.length,
      technical: technical.length,
      roadmap: roadmap.length,
      pages: pages.length,
    })
  );
}

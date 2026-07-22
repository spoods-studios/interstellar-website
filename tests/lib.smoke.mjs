#!/usr/bin/env node
// Committed assertion script for the pure build-pipeline helpers this phase adds
// (D-34 phase sort, D-35 milestone key, D-01/D-33 title fallback, D-30 draft guard,
// D-42 TOC threshold). No test framework is installed (RESEARCH.md Validation
// Architecture) -- plain top-level assertions mirroring tests/build.smoke.sh's
// committed-script precedent.
import assert from 'node:assert/strict';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

import { parsePhaseNumber, sortByPhaseNumber } from '../src/lib/phase-sort.ts';
import { normalizeMilestone, milestoneSortKey } from '../src/lib/milestone-key.ts';
import { titleFromH1 } from '../src/lib/title-from-h1.ts';
import { assertNonEmpty, isVisible } from '../src/lib/content-guards.ts';
import { buildToc } from '../src/lib/toc.ts';
import { createWikilinkResolver } from '../src/lib/wikilink-resolver.mjs';
import { createWikilinkPlugin } from '../src/lib/mdast-wikilinks.mjs';
import { markdownToHtml } from 'satteri';

const REPO_ROOT = fileURLToPath(new URL('..', import.meta.url));

console.log('== phase-sort ==');
assert.equal(parsePhaseNumber('m0.3/phase-14.5-swapchain-acquire-fix'), 14.5);
assert.equal(parsePhaseNumber('m0.1/phase-01-window-surface'), 1);
assert.throws(() => parsePhaseNumber('how-to-read'), /how-to-read/);
{
  const ids = [
    'm0.x/phase-17-slug',
    'm0.x/phase-14-slug',
    'm0.x/phase-16-slug',
    'm0.x/phase-14.5-slug',
    'm0.x/phase-15-slug',
    'm0.x/phase-15.5-slug',
  ].map((id) => ({ id }));
  const sorted = sortByPhaseNumber(ids).map((e) => e.id);
  assert.deepEqual(sorted, [
    'm0.x/phase-14-slug',
    'm0.x/phase-14.5-slug',
    'm0.x/phase-15-slug',
    'm0.x/phase-15.5-slug',
    'm0.x/phase-16-slug',
    'm0.x/phase-17-slug',
  ]);
  const original = ids.map((e) => e.id);
  sortByPhaseNumber(ids);
  assert.deepEqual(ids.map((e) => e.id), original, 'sortByPhaseNumber must not mutate its input');
}
console.log('phase-sort OK');

console.log('== milestone-key ==');
assert.equal(normalizeMilestone('M0.1'), 'm0.1');
assert.equal(normalizeMilestone('m0.1'), 'm0.1');
assert.equal(normalizeMilestone('M0.1.md'), 'm0.1');
assert.ok(milestoneSortKey('M0.10') > milestoneSortKey('M0.9'));
console.log('milestone-key OK');

console.log('== title-from-h1 ==');
assert.equal(
  titleFromH1('# A Moon That Actually Orbits\n\nbody', 'fallback'),
  'A Moon That Actually Orbits'
);
assert.equal(titleFromH1('no heading here', 'fallback'), 'fallback');
assert.equal(titleFromH1('text with a # not at line start', 'fallback'), 'fallback');
console.log('title-from-h1 OK');

console.log('== content-guards ==');
assert.throws(() => assertNonEmpty([], 'technical'), /technical/);
{
  const entries = [{}];
  assert.deepEqual(assertNonEmpty(entries, 'technical'), entries);
}
assert.equal(isVisible({ data: { status: 'draft' } }), false);
assert.equal(isVisible({ data: { status: 'published' } }), true);
assert.equal(isVisible({ data: { status: 'final' } }), true);
assert.equal(isVisible({ data: {} }), true);
console.log('content-guards OK');

console.log('== toc ==');
{
  const headings = [
    { depth: 1, slug: 'title', text: 'Title' },
    { depth: 2, slug: 'a', text: 'A' },
    { depth: 3, slug: 'a-1', text: 'A.1' },
    { depth: 2, slug: 'b', text: 'B' },
    { depth: 3, slug: 'b-1', text: 'B.1' },
    { depth: 2, slug: 'c', text: 'C' },
    { depth: 4, slug: 'c-1-1', text: 'C.1.1' },
  ];
  const toc = buildToc(headings);
  assert.equal(toc.length, 5);
  assert.deepEqual(
    toc.map((h) => h.slug),
    ['a', 'a-1', 'b', 'b-1', 'c']
  );
}
{
  const headings = [
    { depth: 2, slug: 'a', text: 'A' },
    { depth: 2, slug: 'b', text: 'B' },
  ];
  assert.equal(buildToc(headings), null);
}
console.log('toc OK');

console.log('== wikilink-resolver ==');
{
  const base = '/interstellar-website';
  const resolver = createWikilinkResolver({
    base,
    technicalRoot: path.join(REPO_ROOT, 'technical'),
  });

  assert.equal(
    resolver.resolve('../m0.1/phase-03-rendering-pipeline', 'm0.3/phase-14.5-swapchain-acquire-fix'),
    '/interstellar-website/technical/m0.1/phase-03-rendering-pipeline/'
  );
  assert.equal(
    resolver.resolve('../_how-to-read', 'm0.3/phase-14.5-swapchain-acquire-fix'),
    '/interstellar-website/technical/how-to-read/'
  );
  assert.equal(
    resolver.resolve('m0.1/phase-01-window-surface', 'm0.2/phase-07-anything'),
    '/interstellar-website/technical/m0.1/phase-01-window-surface/'
  );
  assert.equal(resolver.resolve('nodiscard', 'm0.2/phase-07-anything'), null);
  assert.equal(
    resolver.resolve('../m9.9/phase-99-does-not-exist', 'm0.1/phase-01-window-surface'),
    null
  );
}
console.log('wikilink-resolver OK');

console.log('== mdast-wikilinks plugin (compile assertions) ==');
{
  const base = '/interstellar-website';
  const resolver = createWikilinkResolver({
    base,
    technicalRoot: path.join(REPO_ROOT, 'technical'),
  });
  const plugin = createWikilinkPlugin({ resolve: resolver.resolve });

  // Labelled wikilink compiles to an anchor carrying the resolved href and the label as its text.
  {
    const source = 'See the [[m0.1/phase-01-window-surface|window surface post]] for detail.';
    const result = markdownToHtml(source, {
      mdastPlugins: [plugin],
      fileURL: pathToFileURL(path.join(REPO_ROOT, 'technical/m0.2/phase-07-anything.md')),
    });
    assert.match(
      result.html,
      /<a href="\/interstellar-website\/technical\/m0\.1\/phase-01-window-surface\/">window surface post<\/a>/
    );
  }

  // Fenced C++ code containing [[nodiscard]] compiles unchanged, no anchor produced.
  {
    const source = '```cpp\n[[nodiscard]] inline int foo();\n```\n';
    const result = markdownToHtml(source, { mdastPlugins: [plugin] });
    assert.match(result.html, /\[\[nodiscard\]\]/);
    assert.doesNotMatch(result.html, /<a /);
  }

  // Inline backtick-wrapped [[nodiscard]] also survives untouched.
  {
    const source = 'Mark it `[[nodiscard]]` in the header.';
    const result = markdownToHtml(source, { mdastPlugins: [plugin] });
    assert.match(result.html, /\[\[nodiscard\]\]/);
    assert.doesNotMatch(result.html, /<a /);
  }

  // Unresolvable target throws naming both the file and the bracketed text.
  {
    const source = 'Dangling [[m9.9/phase-99-does-not-exist]] link.';
    let threw = false;
    try {
      markdownToHtml(source, {
        mdastPlugins: [plugin],
        fileURL: pathToFileURL(path.join(REPO_ROOT, 'technical/m0.1/phase-01-window-surface.md')),
      });
    } catch (err) {
      threw = true;
      assert.match(err.message, /phase-01-window-surface\.md/);
      assert.match(err.message, /m9\.9\/phase-99-does-not-exist/);
    }
    assert.ok(threw, 'expected an unresolvable wikilink target to throw');
  }

  // A text node with no bracket pair is left structurally untouched.
  {
    const source = 'Plain prose with no brackets at all.';
    const result = markdownToHtml(source, { mdastPlugins: [plugin] });
    assert.match(result.html, /Plain prose with no brackets at all\./);
  }
}
console.log('mdast-wikilinks plugin OK');

console.log('ALL CHECKS PASSED');

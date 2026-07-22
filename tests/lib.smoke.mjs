#!/usr/bin/env node
// Committed assertion script for the pure build-pipeline helpers this phase adds
// (D-34 phase sort, D-35 milestone key, D-01/D-33 title fallback, D-30 draft guard,
// D-42 TOC threshold). No test framework is installed (RESEARCH.md Validation
// Architecture) -- plain top-level assertions mirroring tests/build.smoke.sh's
// committed-script precedent.
import assert from 'node:assert/strict';

import { parsePhaseNumber, sortByPhaseNumber } from '../src/lib/phase-sort.ts';
import { normalizeMilestone, milestoneSortKey } from '../src/lib/milestone-key.ts';
import { titleFromH1 } from '../src/lib/title-from-h1.ts';
import { assertNonEmpty, isVisible } from '../src/lib/content-guards.ts';
import { buildToc } from '../src/lib/toc.ts';

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

console.log('ALL CHECKS PASSED');

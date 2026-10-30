#!/usr/bin/env node
// Committed assertion script for the pure build-pipeline helpers this phase adds
// (D-35 milestone key, D-01/D-33 title fallback, D-30 draft guard, D-42 TOC
// threshold). No test framework is installed (RESEARCH.md Validation
// Architecture) -- plain top-level assertions mirroring tests/build.smoke.sh's
// committed-script precedent.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import { normalizeMilestone, milestoneSortKey } from '../src/lib/milestone-key.ts';
import { titleFromH1 } from '../src/lib/title-from-h1.ts';
import { assertNonEmpty, isVisible } from '../src/lib/content-guards.ts';
import { buildToc } from '../src/lib/toc.ts';
import { firstProseBlock, stripInline, truncate, describeBody } from '../src/lib/describe-entry.ts';

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

console.log('== describe-entry ==');
// D-51: the first block that is not chrome. The H1, a leading hero image, the
// boilerplate blockquote opening all 55 deep-dives, list/table/rule blocks are
// all skipped -- what survives is the entry's first real sentence.
assert.equal(firstProseBlock('# Title\n\nReal prose here.'), 'Real prose here.');
assert.equal(
  firstProseBlock('# Title\n\n![alt](../assets/x.png)\n\nReal prose here.'),
  'Real prose here.'
);
assert.equal(
  firstProseBlock('# Title\n\n> Retroactive technical devlog. Code shown as built.\n\nReal prose here.'),
  'Real prose here.'
);
assert.equal(firstProseBlock('# Title\n\n- a\n- b\n\nReal prose here.'), 'Real prose here.');
assert.equal(firstProseBlock('# Title\n\n1. a\n2. b\n\nReal prose here.'), 'Real prose here.');
assert.equal(
  firstProseBlock('# Title\n\n| a | b |\n| - | - |\n\nReal prose here.'),
  'Real prose here.'
);
assert.equal(firstProseBlock('# Title\n\n---\n\nReal prose here.'), 'Real prose here.');
assert.equal(firstProseBlock('# Only a heading'), null);

assert.equal(
  stripInline('**bold** and *em* and `code` and [link](/x) and ![img](/y.png)'),
  'bold and em and code and link and'
);
assert.equal(stripInline('line one\nline two'), 'line one line two');

// D-52: unchanged under the limit; otherwise the last COMPLETE sentence, with
// no minimum-length floor -- a finished 53-char thought beats a severed 160.
assert.equal(truncate('Short sentence.', 160), 'Short sentence.');
{
  const two = `A short opening sentence. ${'padding word '.repeat(15)}end.`;
  assert.ok(two.length > 160);
  assert.equal(truncate(two, 160), 'A short opening sentence.');
}
{
  const oneSentence = `${'wordy '.repeat(33)}tail`;
  assert.equal(oneSentence.length, 202);
  const result = truncate(oneSentence, 160);
  assert.ok(result.endsWith('…'), 'no sentence break -> ellipsis');
  assert.ok(result.length <= 161, `expected <=161, got ${result.length}`);
  const body = result.slice(0, -1);
  assert.ok(oneSentence.startsWith(body), 'cut must be a prefix of the input');
  assert.equal(oneSentence[body.length], ' ', 'cut must land on a word boundary');
}
// A cut must never sever a surrogate pair -- the corpus is full of astral
// punctuation and a lone surrogate is an invalid attribute value.
{
  const hasLoneSurrogate = (s) =>
    [...s].some((ch) => {
      const cp = ch.codePointAt(0);
      return cp >= 0xd800 && cp <= 0xdfff;
    });
  const astral = '\u{1F680}'.repeat(100);
  assert.equal(astral.length, 200);
  assert.ok(!hasLoneSurrogate(truncate(astral, 160)), 'pure-astral cut split a pair');
  const mixed = `${'orbit \u{1F680} '.repeat(30)}tail`;
  assert.ok(mixed.length > 160);
  assert.ok(!hasLoneSurrogate(truncate(mixed, 160)), 'mixed cut split a pair');
}
// Curly quotes, em-dash and the prime mark must survive byte-identical.
assert.equal(
  truncate('He said “it drifts” — by 43″/century, exactly.', 160),
  'He said “it drifts” — by 43″/century, exactly.'
);

// D-58: a body with no extractable prose is a loud failure naming the entry,
// never an empty description.
assert.throws(() => describeBody('# Only a heading', 'devlog/example'), /devlog\/example/);
assert.equal(
  describeBody(
    "# How It's Made\n\nSetare Aerospace is built solo, and I use AI heavily. This page says exactly how —\nwhat AI does here, what it never does, and why you can trust the result anyway.\nIt's permanent, versioned, and I'll keep it current as the tooling changes.",
    'pages/how-its-made'
  ),
  'Setare Aerospace is built solo, and I use AI heavily.'
);
console.log('describe-entry OK');

console.log('== content-expectations ==');
{
  const helper = fileURLToPath(new URL('./helpers/content-expectations.mjs', import.meta.url));
  for (const key of ['roadmap_count', 'pages_count', 'site_page_count']) {
    const out = execFileSync('node', [helper, key], { env: { ...process.env, FORCE_COLOR: '3' }, encoding: 'utf8' });
    assert.match(out, /^\d+\n$/, key);
  }
}
console.log('content-expectations OK');

console.log('ALL CHECKS PASSED');

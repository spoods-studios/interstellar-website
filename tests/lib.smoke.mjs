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
import { firstProseBlock, stripInline, truncate, describeBody } from '../src/lib/describe-entry.ts';
import { compareNewestFirst } from '../src/lib/entry-order.ts';
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

console.log('== entry-order ==');
{
  const d = (s) => new Date(`${s}T00:00:00Z`);
  const a = { id: 'a', date: d('2026-01-01') };
  const b = { id: 'b', date: d('2026-07-13') };
  const c = { id: 'c', date: d('2026-04-07') };
  assert.deepEqual(
    [a, b, c].sort(compareNewestFirst).map((e) => e.id),
    ['b', 'c', 'a']
  );

  // Identical dates must tie-break on id, independent of input order --
  // otherwise the archive, the post route and the feed can disagree.
  const x = { id: 'alpha', date: d('2026-05-05') };
  const y = { id: 'beta', date: d('2026-05-05') };
  assert.deepEqual([x, y].sort(compareNewestFirst).map((e) => e.id), ['alpha', 'beta']);
  assert.deepEqual([y, x].sort(compareNewestFirst).map((e) => e.id), ['alpha', 'beta']);

  assert.equal(compareNewestFirst(x, x), 0);
}
console.log('entry-order OK');

console.log('ALL CHECKS PASSED');

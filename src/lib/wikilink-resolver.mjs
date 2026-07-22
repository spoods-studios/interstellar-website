// D-39: resolves Obsidian wikilink targets against the technical/ collection's
// known ids, returning a base-prefixed internal site path or null on a miss.
// The base path arrives as an argument from astro.config.mjs -- it is never a
// literal in this file (SITE-02 keeps the base/host in one config location).
import fs from 'node:fs';
import nodePath from 'node:path';
import path from 'node:path/posix';

const TECHNICAL_RE = /^(m\d+(?:\.\d+)?)\/phase-(\d+(?:\.\d+)?)-(.+)$/;

function collectKnownIds(technicalRoot) {
  const ids = new Set();
  for (const dirent of fs.readdirSync(technicalRoot, { withFileTypes: true })) {
    if (dirent.isFile() && dirent.name === '_how-to-read.md') {
      ids.add('how-to-read'); // D-32
      continue;
    }
    if (!dirent.isDirectory()) continue;
    const milestone = dirent.name;
    for (const file of fs.readdirSync(nodePath.join(technicalRoot, milestone))) {
      if (!file.endsWith('.md')) continue;
      const rel = `${milestone}/${file.slice(0, -3)}`;
      if (TECHNICAL_RE.test(rel)) ids.add(rel);
    }
  }
  return ids;
}

export function createWikilinkResolver({ base, technicalRoot }) {
  const normalizedBase = base.endsWith('/') ? base : `${base}/`;
  const knownIds = collectKnownIds(technicalRoot);

  function resolve(target, fromEntryPath) {
    const withoutExt = target.trim().replace(/\.md$/, '');

    let candidate = withoutExt.startsWith('.')
      ? path.normalize(path.join(path.dirname(fromEntryPath), withoutExt))
      : withoutExt;

    // D-32: the how-to-read file's on-disk name carries a leading underscore
    // (`_how-to-read.md`); its collection id drops it.
    if (path.basename(candidate) === '_how-to-read') {
      const dir = path.dirname(candidate);
      candidate = dir === '.' ? 'how-to-read' : path.join(dir, 'how-to-read');
    }

    if (!knownIds.has(candidate)) return null;
    return `${normalizedBase}technical/${candidate}/`;
  }

  return { resolve };
}

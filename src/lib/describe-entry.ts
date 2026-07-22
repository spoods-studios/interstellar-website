// D-51/D-52/D-58: every page's meta/OG description is derived from the entry's
// own body -- never hand-written, never omitted. Import-free on purpose so
// tests/lib.smoke.mjs can import this .ts directly under bare Node (no Vite
// globals, no extensionless relative specifiers).

const BLOCK_SKIP = [
  /^#/, // headings (the H1 title)
  /^!\[/, // leading hero image
  /^>/, // blockquote -- the identical boilerplate opening all 55 deep-dives (D-51)
  /^[-*+]\s|^\d+\.\s/, // lists
  /^\|/, // tables
  /^(-{3,}|\*{3,})$/, // thematic breaks
];

const HIGH_SURROGATE_MIN = 0xd800;
const HIGH_SURROGATE_MAX = 0xdbff;

// A slice at an arbitrary code-unit index can land between the halves of a
// surrogate pair; the orphaned half is an invalid character in an attribute.
function dropLoneHighSurrogate(s: string): string {
  const last = s.charCodeAt(s.length - 1);
  return last >= HIGH_SURROGATE_MIN && last <= HIGH_SURROGATE_MAX ? s.slice(0, -1) : s;
}

export function firstProseBlock(body: string): string | null {
  for (const block of body.split(/\n\s*\n/).map((b) => b.trim()).filter(Boolean)) {
    if (BLOCK_SKIP.some((re) => re.test(block))) continue;
    return block;
  }
  return null;
}

export function stripInline(s: string): string {
  return s
    .replace(/\s*\n\s*/g, ' ')
    .replace(/\[\[([^\]|]+)(\|[^\]]+)?\]\]/g, (_m, a, b) => (b ? b.slice(1) : a))
    .replace(/!\[[^\]]*\]\([^)]*\)/g, '')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/(?<!\*)\*([^*]+)\*(?!\*)/g, '$1')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/_([^_]+)_/g, '$1')
    .replace(/\s+/g, ' ')
    .trim();
}

// D-52, strict reading: the last COMPLETE sentence under the limit, with no
// minimum-length floor -- a finished 53-character thought reads better than a
// 160-character severed one.
export function truncate(s: string, max = 160): string {
  if (s.length <= max) return s;
  const cut = dropLoneHighSurrogate(s.slice(0, max + 1));
  const end = Math.max(cut.lastIndexOf('. '), cut.lastIndexOf('? '), cut.lastIndexOf('! '));
  if (end > 0) return cut.slice(0, end + 1);
  const lastSpace = cut.lastIndexOf(' ');
  const body = lastSpace > 0 ? cut.slice(0, lastSpace) : cut.slice(0, -1);
  return `${dropLoneHighSurrogate(body)}…`;
}

// D-58: no prose at all means the content file is malformed. Fail the build
// naming the entry rather than shipping an empty og:description.
export function describeBody(body: string, entryId: string): string {
  const block = firstProseBlock(body);
  if (block === null) {
    throw new Error(
      `${entryId}: entry body yields no extractable prose block — check that the file has a paragraph after its heading, image or blockquote chrome`
    );
  }
  return truncate(stripInline(block));
}

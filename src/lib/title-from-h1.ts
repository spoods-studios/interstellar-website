// D-33 (technical/roadmap trees carry no frontmatter title) and D-01 (the
// frontmatter-less manifesto) both fall back to the body's first H1.

const H1_RE = /^#\s+(.+)$/m;

export function titleFromH1(body: string | undefined, fallback: string): string {
  const match = body?.match(H1_RE);
  return match ? match[1].trim() : fallback;
}

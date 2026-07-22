// D-42, UI-SPEC "TOC placement and depth": H2+H3 only, and only when the
// entry has 3+ H2 headings -- otherwise a short post gets a one-line TOC box.
export interface MarkdownHeading {
  depth: number;
  slug: string;
  text: string;
}

export function buildToc(headings: MarkdownHeading[]): MarkdownHeading[] | null {
  const relevant = headings.filter((h) => h.depth === 2 || h.depth === 3);
  const h2Count = relevant.filter((h) => h.depth === 2).length;
  if (h2Count < 3) return null;
  return relevant;
}

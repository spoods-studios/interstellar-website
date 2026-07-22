// D-35: the join key for every cross-collection query in this phase and Plans
// 06/07. Announcement frontmatter carries "M0.1" (capital), technical/'s
// directories are "m0.1" (lowercase), and roadmap/'s filenames are "M0.1.md" --
// all three must normalize through this one helper before comparison.

const MILESTONE_RE = /^m?(\d+(?:\.\d+)?)/i;

export function normalizeMilestone(raw: string): string {
  const stripped = raw.replace(/\.md$/i, '');
  const match = stripped.match(MILESTONE_RE);
  if (!match) {
    throw new Error(`Cannot parse milestone from: ${raw}`);
  }
  return `m${match[1]}`;
}

export function milestoneSortKey(raw: string): number {
  // Not a decimal parse: "M0.10" is major 0, minor 10 -- parseFloat("0.10")
  // would collapse to 0.1, sorting it (wrongly) before "M0.9" (0.9). Compare
  // major/minor as separate integers instead.
  const [major, minor] = normalizeMilestone(raw)
    .slice(1)
    .split('.')
    .map((part) => parseInt(part, 10));
  return major * 100000 + (minor || 0);
}

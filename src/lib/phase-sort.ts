// D-34: phase numbers are decimal-aware (e.g. phase-14.5 sorts between
// phase-14 and phase-15), so a lexical string sort is wrong -- must parse
// and compare numerically.
// D-AJ (studio): sibling-repo entries carry a repo prefix and per-repo
// numbering (assets-phase-3-slug, combined assets-phases-1-3-slug). Within
// a milestone the engine's unprefixed entries sort first, then prefixed
// groups alphabetically, numerically within each group.

const PHASE_RE = /(?:^|\/)(?:([a-z][a-z0-9]*(?:-[a-z0-9]+)*)-)?phases?-(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?-/;

function parsePhase(idOrFilename: string): { prefix: string; first: number; second: number | null } {
  const match = idOrFilename.match(PHASE_RE);
  if (!match) {
    throw new Error(`Cannot parse phase number from: ${idOrFilename}`);
  }
  return {
    prefix: match[1] ?? '',
    first: parseFloat(match[2]),
    second: match[3] ? parseFloat(match[3]) : null,
  };
}

export function parsePhaseNumber(idOrFilename: string): number {
  return parsePhase(idOrFilename).first;
}

export function phaseLabel(idOrFilename: string): string {
  const { prefix, first, second } = parsePhase(idOrFilename);
  const repo = prefix ? `${prefix.charAt(0).toUpperCase()}${prefix.slice(1)} ` : '';
  return second === null ? `${repo}Phase ${first}` : `${repo}Phases ${first}–${second}`;
}

export function sortByPhaseNumber<T extends { id: string }>(entries: T[]): T[] {
  return [...entries].sort((a, b) => {
    const pa = parsePhase(a.id);
    const pb = parsePhase(b.id);
    if (pa.prefix !== pb.prefix) {
      if (pa.prefix === '') return -1;
      if (pb.prefix === '') return 1;
      return pa.prefix.localeCompare(pb.prefix);
    }
    return pa.first - pb.first;
  });
}

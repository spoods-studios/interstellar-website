// D-34: phase numbers are decimal-aware (e.g. phase-14.5 sorts between
// phase-14 and phase-15), so a lexical string sort is wrong -- must parse
// and compare numerically.

const PHASE_RE = /phase-(\d+(?:\.\d+)?)/;

export function parsePhaseNumber(idOrFilename: string): number {
  const match = idOrFilename.match(PHASE_RE);
  if (!match) {
    throw new Error(`Cannot parse phase number from: ${idOrFilename}`);
  }
  return parseFloat(match[1]);
}

export function sortByPhaseNumber<T extends { id: string }>(entries: T[]): T[] {
  return [...entries].sort((a, b) => parsePhaseNumber(a.id) - parsePhaseNumber(b.id));
}

// RESEARCH Pitfall 1: glob()'s loader only warns (never throws) on an empty
// result, so this assertion is the actual guard against a misconfigured
// loader `base` silently yielding an empty collection.
export function assertNonEmpty<T>(entries: T[], treeName: string): T[] {
  if (entries.length === 0) {
    throw new Error(
      `${treeName} collection resolved to zero entries — check the loader base path in src/content.config.ts`
    );
  }
  return entries;
}

// D-30: the single draft-filter implementation the whole site shares,
// including generated cross-link lists (T-02-03).
export function isVisible(entry: { data: { status?: string } }): boolean {
  return entry.data.status !== 'draft';
}

// The one newest-first ordering expression the archive, the announcement
// route's prev/next chain and the RSS feed all share -- two entries posted on
// the same day must never order differently between them. Import-free on
// purpose so tests/lib.smoke.mjs can import this .ts directly under bare Node.

export interface OrderableEntry {
  id: string;
  date: Date;
}

// Date descending, then id ascending as a deterministic tie-break: Array.sort
// is only stable with respect to input order, and the three consumers do not
// build their input arrays the same way.
export function compareNewestFirst(a: OrderableEntry, b: OrderableEntry): number {
  const byDate = b.date.getTime() - a.date.getTime();
  if (byDate !== 0) return byDate;
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

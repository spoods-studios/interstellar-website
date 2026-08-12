// The one newest-first ordering expression the archive, the announcement
// route's prev/next chain and the RSS feed all share -- two entries posted on
// the same day must never order differently between them. Import-free on
// purpose so tests/lib.smoke.mjs can import this .ts directly under bare Node.

export interface OrderableEntry {
  id: string;
  date: Date;
  isAddendum?: boolean;
}

// Date descending, then addendum-before-announcement, then id ascending as a
// deterministic tie-break: Array.sort is only stable with respect to input
// order, and the three consumers do not build their input arrays the same way.
export function compareNewestFirst(a: OrderableEntry, b: OrderableEntry): number {
  const byDate = b.date.getTime() - a.date.getTime();
  if (byDate !== 0) return byDate;
  // Same-day M1.2 pair: Discord snowflakes and git commit order both show the
  // announcement posted ~55min AFTER the addendum, but the addendum's own
  // opening line reads as coming after the milestone write-ups -- author
  // intent about reading order is the spec, not the same-day publish
  // timestamps. Do not "fix" this back to timestamp/id order.
  const aFlag = a.isAddendum ?? false;
  const bFlag = b.isAddendum ?? false;
  if (aFlag !== bFlag) return aFlag ? -1 : 1;
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

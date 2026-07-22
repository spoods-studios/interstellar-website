// Pulled out of src/pages/devlog/[slug].astro's frontmatter: Astro's compiler
// only hoists the exported getStaticPaths() function to real module scope --
// sibling helper functions declared in the same frontmatter block are only
// reachable from the per-page render body, not from getStaticPaths itself.
// Importing from here (a real module) keeps one date/title fallback
// implementation for both getStaticPaths' sort and the rendered page.
import type { CollectionEntry } from 'astro:content';
import { titleFromH1 } from './title-from-h1';
import { compareNewestFirst } from './entry-order';

const FILENAME_DATE_RE = /^(\d{4}-\d{2}-\d{2})/;

export function entryDate(entry: CollectionEntry<'devlog'>): Date {
  if (entry.data.date) return entry.data.date;
  const match = entry.id.match(FILENAME_DATE_RE);
  return match ? new Date(`${match[1]}T00:00:00Z`) : new Date(0);
}

export function entryTitle(entry: CollectionEntry<'devlog'>): string {
  return entry.data.title ?? titleFromH1(entry.body, entry.id);
}

// The archive, the announcement route's prev/next chain and the feed must all
// consume one ordering expression, so two entries sharing a date can never
// order differently between them. Returns a new array; never mutates the input.
export function sortEntriesNewestFirst(
  entries: CollectionEntry<'devlog'>[]
): CollectionEntry<'devlog'>[] {
  return [...entries].sort((a, b) =>
    compareNewestFirst(
      { id: a.id, date: entryDate(a) },
      { id: b.id, date: entryDate(b) }
    )
  );
}

export function formatDate(date: Date): string {
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    timeZone: 'UTC',
  });
}

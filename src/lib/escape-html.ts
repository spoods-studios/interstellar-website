// WR-01 (02-REVIEW.md): escapes only the characters that would actually
// break HTML parsing (&, <, >). Apostrophes/quotes are deliberately left
// untouched -- set:html was originally chosen at these call sites so
// contraction-heavy devblog titles ("Doesn't", "I'm") render as plain
// literal text instead of HTML entities; a blanket auto-escape (which also
// entity-encodes apostrophes) would regress that. & must be escaped first
// so a title's own literal "&" isn't double-escaped by the following
// replacements.
export function escapeHtml(input: string): string {
  return input.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

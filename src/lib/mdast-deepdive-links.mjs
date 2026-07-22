// D-35/D-38/D-39: resolves each roadmap phase entry's Discord-era deep-dive
// placeholder into a real link into the technical/ tree. Registered on
// `heading` (records the current phase number in the per-document data bag,
// which Sätteri shares across a single compile -- RESEARCH Pattern 2) and
// `text` (replaces the placeholder once a phase number has been recorded)
// -- mirrors mdast-wikilinks.mjs's shape.
//
// The corpus's actual placeholder wording is not fully uniform (confirmed by
// grepping all 8 files, not just the sampled M0.3): most phases carry a bold
// "**Deep-dive:** posted in #technical-devlog" line (the label renders as a
// separate `strong` node, so the `text` visitor only ever sees the plain
// remainder " posted in #technical-devlog"); a handful of phases in
// M0.5-M0.8 instead carry a plain, unbolded "Deep dive: posted in
// #technical-devlog." or "Deep dive: Phase N post in #technical-devlog."
// paragraph. MARKER_RE matches both shapes; the phase number always comes
// from the heading-tracked `ctx.data` value (per this plugin's own design),
// never re-parsed out of a placeholder's own wording, so a stray embedded
// number can't disagree with the section it actually sits in.
//
// Scoped to the roadmap/ tree only: this plugin is registered globally on
// the Markdown pipeline (alongside the wikilink plugin), so scoping by path
// is what keeps it off the other three trees (T-02-13).
import { defineMdastPlugin } from 'satteri';
import { fileURLToPath } from 'node:url';
import nodePath from 'node:path';
import path from 'node:path/posix';

const PHASE_HEADING_RE = /^Phase\s+(\d+(?:\.\d+)?):/;
// Matches the bold-remainder shape ("posted in #technical-devlog", no
// leading label, no trailing period) and the plain unbolded shape
// ("Deep dive: [Phase N ]post(ed) in #technical-devlog[.]"), trimmed and
// anchored so it only ever matches a standalone marker line/remainder, not
// prose mentioning the same channel in passing (see GENERIC_MENTION_RE).
const MARKER_RE = /^(?:Deep[\s-]dive:\s*(?:Phase\s+[\d.]+\s+)?)?post(?:ed)?\s+in\s+#technical-devlog\.?$/i;
// The intro blockquote on M0.5-M0.8 mentions this Discord channel in passing
// ("... Deep-dives:\nposted in #technical-devlog.") as part of a longer
// sentence, not as a standalone per-phase marker -- there's no phase to link
// it to. It still must not survive onto the page (the success criteria and
// acceptance grep require zero "technical-devlog" occurrences site-wide), so
// this clause is stripped rather than linked.
const GENERIC_MENTION_RE = /\s*Deep-dives:\s*posted in #technical-devlog\.?/;

function isRoadmapFile(fileURL) {
  if (!fileURL) return false;
  const absPath = fileURLToPath(fileURL).split(nodePath.sep).join('/');
  return absPath.includes('/roadmap/');
}

function milestoneFromFileURL(fileURL) {
  const absPath = fileURLToPath(fileURL).split(nodePath.sep).join('/');
  return path.basename(absPath).replace(/\.md$/i, '');
}

export function createDeepDiveLinkPlugin({ resolvePhase }) {
  return defineMdastPlugin({
    name: 'deepdive-links',
    heading(node, ctx) {
      if (!isRoadmapFile(ctx.fileURL)) return;
      const headingText = ctx.textContent(node);
      const match = headingText.match(PHASE_HEADING_RE);
      if (match) {
        ctx.data.deepDiveCurrentPhase = parseFloat(match[1]);
      }
    },
    text(node, ctx) {
      if (!isRoadmapFile(ctx.fileURL)) return;

      const trimmed = node.value.trim();
      if (!MARKER_RE.test(trimmed)) {
        // Not a standalone per-phase marker. It may still be the generic
        // intro mention above -- strip that clause, leave everything else in
        // the node untouched.
        if (GENERIC_MENTION_RE.test(node.value)) {
          ctx.setProperty(node, 'value', node.value.replace(GENERIC_MENTION_RE, ''));
        }
        return;
      }

      const sourceFile = ctx.fileURL ? fileURLToPath(ctx.fileURL) : '<unknown file>';
      const phaseNumber = ctx.data.deepDiveCurrentPhase;
      if (phaseNumber === undefined) {
        // D-10/D-39 loud-fail convention: never a silent passthrough of the
        // Discord-era placeholder text.
        throw new Error(
          `${sourceFile}: found the Deep-dive placeholder with no phase heading recorded before it`
        );
      }

      const milestone = milestoneFromFileURL(ctx.fileURL);
      const href = resolvePhase(milestone, phaseNumber);
      if (!href) {
        throw new Error(
          `${sourceFile}: resolvePhase found no technical/ entry for ${milestone} phase ${phaseNumber}`
        );
      }

      // The marker is matched against the trimmed value but sliced out of
      // the raw one, so any incidental leading/trailing whitespace in the
      // original node survives as separate text around the new link.
      const rawStart = node.value.indexOf(trimmed);
      const before = node.value.slice(0, rawStart);
      const after = node.value.slice(rawStart + trimmed.length);

      const newNodes = [];
      if (before) newNodes.push({ type: 'text', value: before });
      newNodes.push({
        type: 'link',
        url: href,
        children: [{ type: 'text', value: `Phase ${phaseNumber} deep-dive` }],
      });
      if (after) newNodes.push({ type: 'text', value: after });

      ctx.insertBefore(node, newNodes);
      ctx.removeNode(node);
    },
  });
}

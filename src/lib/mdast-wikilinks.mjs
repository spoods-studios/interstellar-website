// D-39: Sätteri mdast plugin resolving Obsidian wikilinks to internal anchors
// at build time. Registered on `text` nodes ONLY -- Sätteri routes fenced code
// (`code`) and inline code (`inlineCode`) to different visitor keys entirely,
// so this visitor structurally never sees the C++ `[[nodiscard]]` attribute
// (RESEARCH Pitfall 2). No string-matching defence is needed on top of that.
import { defineMdastPlugin } from 'satteri';
import { fileURLToPath } from 'node:url';
import nodePath from 'node:path';

function fromEntryPathFromFileURL(fileURL) {
  if (!fileURL) return '';
  const absPath = fileURLToPath(fileURL).split(nodePath.sep).join('/');
  const marker = '/technical/';
  const idx = absPath.lastIndexOf(marker);
  if (idx === -1) return '';
  return absPath.slice(idx + marker.length).replace(/\.md$/, '');
}

export function createWikilinkPlugin({ resolve }) {
  return defineMdastPlugin({
    name: 'wikilinks',
    text(node, ctx) {
      const wikilinkRe = /\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g;
      let match = wikilinkRe.exec(node.value);
      if (!match) return; // no bracket pair -- leave the node structurally untouched

      const fromEntryPath = fromEntryPathFromFileURL(ctx.fileURL);
      const newNodes = [];
      let lastIndex = 0;
      wikilinkRe.lastIndex = 0;
      while ((match = wikilinkRe.exec(node.value))) {
        const [full, target, label] = match;
        if (match.index > lastIndex) {
          newNodes.push({ type: 'text', value: node.value.slice(lastIndex, match.index) });
        }

        const trimmedTarget = target.trim();
        const href = resolve(trimmedTarget, fromEntryPath);
        if (href === null) {
          const sourceFile = ctx.fileURL ? fileURLToPath(ctx.fileURL) : '<unknown file>';
          const rawText = `[[${target}${label ? `|${label}` : ''}]]`;
          // D-39: loud build failure naming the file and the unresolved link.
          throw new Error(`Unresolvable wikilink in ${sourceFile}: ${rawText}`);
        }

        newNodes.push({
          type: 'link',
          url: href,
          children: [{ type: 'text', value: (label ?? target).trim() }],
        });
        lastIndex = match.index + full.length;
      }
      if (lastIndex < node.value.length) {
        newNodes.push({ type: 'text', value: node.value.slice(lastIndex) });
      }

      ctx.insertBefore(node, newNodes);
      ctx.removeNode(node);
    },
  });
}

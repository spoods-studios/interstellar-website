import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const FILENAME_RE = /^(\d{4}-\d{2}-\d{2})-(.+)\.md$/;

const devlog = defineCollection({
  loader: glob({
    pattern: ['**/*.md', '!_TEMPLATE.md'],
    // NOTE: glob()'s `base` resolves relative to the project root (config.root),
    // not relative to this file's directory — confirmed against the installed
    // astro package's own type declarations this session (Astro 7.0.9).
    // RESEARCH.md's Pattern 1 used '../devlog' (relative to src/), which is
    // wrong for this Astro version and pointed one level above the repo root.
    base: './devlog',
    generateId: ({ entry }) => {
      const match = entry.match(FILENAME_RE);
      if (!match) {
        // D-10: loud failure naming the offending file
        throw new Error(
          `devlog/${entry}: filename must match YYYY-MM-DD-slug.md (no valid frontmatter date/slug fallback found)`
        );
      }
      return `${match[1]}-${match[2]}`; // keep date in the id — guarantees uniqueness
    },
  }),
  schema: z.object({
    milestone: z.string().optional(),
    title: z.string().optional(),
    date: z.coerce.date().optional(),
    // 'final' added because the promoted M0.7/M0.8 announcements carry it verbatim (D-25);
    // it renders identically to 'published' — only 'draft' hides an entry (D-30).
    status: z.enum(['draft', 'published', 'final']).optional(),
    discord_post_id: z.string().optional(),
    audience: z.string().optional(),
    hero_visual: z.string().optional(),
  }),
});

const TECHNICAL_RE = /^(m\d+(?:\.\d+)?)\/phase-(\d+(?:\.\d+)?)-(.+)\.md$/;

const technical = defineCollection({
  loader: glob({
    pattern: ['**/*.md'],
    // NOTE: project-root-relative, same landmine as the devlog loader above.
    base: './technical',
    generateId: ({ entry }) => {
      if (entry === '_how-to-read.md') return 'how-to-read'; // D-32
      const match = entry.match(TECHNICAL_RE);
      if (!match) {
        // D-33: loud failure naming the offending file — this tree has no
        // frontmatter to fall back on.
        throw new Error(
          `technical/${entry}: filename must match m0.X/phase-NN[.N]-slug.md (D-33 — no frontmatter fallback exists for this tree)`
        );
      }
      const [, milestone, phaseNum, slug] = match;
      return `${milestone}/phase-${phaseNum}-${slug}`; // preserves D-32's URL shape directly
    },
  }),
  // D-33: no frontmatter fields at all — schema only rejects unexpected keys loudly.
  schema: z.object({}).strict(),
});

const ROADMAP_RE = /^M(\d+(?:\.\d+)?)\.md$/i;

const roadmap = defineCollection({
  loader: glob({
    pattern: ['M*.md'],
    base: './roadmap',
    generateId: ({ entry }) => {
      const match = entry.match(ROADMAP_RE);
      if (!match) {
        throw new Error(`roadmap/${entry}: filename must match M{milestone}.md (D-38)`);
      }
      return `m${match[1]}`; // normalize to lowercase — joins directly against technical/'s m0.X dirs
    },
  }),
  schema: z.object({}).strict(),
});

const pages = defineCollection({
  loader: glob({
    pattern: ['*.md'],
    base: './pages',
  }),
  // Mirrors devlog's permissive all-optional shape (D-20: standalone pages'
  // meta line reads from `updated`).
  schema: z.object({
    title: z.string().optional(),
    status: z.enum(['draft', 'published', 'final']).optional(),
    audience: z.string().optional(),
    updated: z.coerce.date().optional(),
  }),
});

export const collections = { devlog, technical, roadmap, pages };

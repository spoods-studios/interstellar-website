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
    status: z.enum(['draft', 'published']).optional(),
    discord_post_id: z.string().optional(),
    audience: z.string().optional(),
    hero_visual: z.string().optional(),
  }),
});

export const collections = { devlog };

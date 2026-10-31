import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

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
      return `m${match[1]}`; // normalize to lowercase
    },
  }),
  schema: z.object({}).strict(),
});

const pages = defineCollection({
  loader: glob({
    pattern: ['*.md'],
    base: './pages',
  }),
  // Permissive all-optional shape (D-20: standalone pages' meta line reads
  // from `updated`).
  schema: z.object({
    title: z.string().optional(),
    status: z.enum(['draft', 'published', 'final']).optional(),
    audience: z.string().optional(),
    updated: z.coerce.date().optional(),
  }),
});

export const collections = { roadmap, pages };

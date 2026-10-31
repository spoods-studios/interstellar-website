# Conventions

<!-- patterns specific to this project that the global rules don't cover -->

## Patterns

- No test framework is installed; `tests/lib.smoke.mjs` is a plain committed script of top-level `node:assert/strict` calls against `src/lib/*.ts` pure helpers.
- Content commits (promoted roadmap and page `.md` files) deploy on push and need no milestone or review ceremony.
- Repo decisions live in `.forge/REJECTED.md`; cross-repo decisions live in `../.forge/REJECTED.md`.
- `PROMOTE-MANIFEST.md` records which studio drafts (from `../vault/`) are promoted into `roadmap/`, `pages/`, and by what rule (byte-for-byte copy vs. authored rewrite).
- The single draft-visibility filter (`isVisible` in `src/lib/content-guards.ts`) is shared by every page and generated list; nothing re-implements the `status: draft` check.
- Site/base URL config lives only in `astro.config.mjs`; smoke tests derive it with `grep -oP` rather than repeating it as a literal.
- Content-schema and content-loader errors (empty collection, bad frontmatter enum, unresolved hero image reference) throw loudly naming the offending file/path, per `src/lib/content-guards.ts` and `src/lib/hero-image.ts`.
- A deployed page's URL is permanent (D-66): Discord embeds and studio links pin it; a broken link shows only as a 404 count.
  A rename or takedown adds the old path to `SLUG_REDIRECTS` in `astro.config.mjs` in the same commit.
  Keys are base-free; destinations are composed from `NORMALIZED_BASE`.
- Showcase copy uses the technical devlog voice (`vault/devlog/VOICE.md`) for every heading, caption and body line.
- Showcase media change only through `tools/showcase-encode.sh` from a verified engine capture; clips stay within 1.0 MB WebM and 1.5 MB MP4, stills within 2 MB.

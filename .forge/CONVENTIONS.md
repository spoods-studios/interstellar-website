# Conventions

<!-- patterns specific to this project that the global rules don't cover -->

## Patterns

- No test framework is installed; `tests/lib.smoke.mjs` is a plain committed script of top-level `node:assert/strict` calls against `src/lib/*.ts` pure helpers.
- Content commits (promoted devlog `.md` files) deploy on push and need no milestone or review ceremony.
- Repo-local context lives in `vault/` (`context.md`, `conventions.md`); cross-repo decisions live in `../vault/decisions/`.
- `PROMOTE-MANIFEST.md` records which studio drafts (from `../vault/`) are promoted into `devlog/`, `technical/`, `roadmap/`, `pages/`, and by what rule (byte-for-byte copy vs. authored rewrite).
- The single draft-visibility filter (`isVisible` in `src/lib/content-guards.ts`) is shared by every page and generated list; nothing re-implements the `status: draft` check.
- Site/base URL config lives only in `astro.config.mjs`; smoke tests derive it with `grep -oP` rather than repeating it as a literal.
- Content-schema and content-loader errors (empty collection, bad frontmatter enum, unresolved hero image reference) throw loudly naming the offending file/path, per `src/lib/content-guards.ts` and `src/lib/hero-image.ts`.

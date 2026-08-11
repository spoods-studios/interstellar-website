# Walking Skeleton — Interstellar Engine Website

**Phase:** 1
**Generated:** 2026-07-14

## Capability Proven End-to-End

> A visitor can load the deployed GitHub Pages site at `https://spoods-studios.github.io/interstellar-website/` and see the manifesto's title and date — rendered at build time from a frontmatter-less Markdown file in `devlog/`, with the whole ingest → build → deploy → serve path exercised in one page load.

This is deliberately the thinnest meaningful full-stack slice: it proves the Content Layer ingests real content, the build bakes it to static HTML, and the Actions pipeline publishes it live. Everything visual/structural is Phase 2+.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Framework | Astro 7.0.9 (SSG + Content Layer), plain `.astro` templates | Locked in `.claude/CLAUDE.md` from prior stack research; content-first, ships zero JS by default, first-party GitHub Pages Action keeps the site off the critical path (D-03) |
| Data layer | Content Layer `glob()` loader reading `./devlog/*.md` directly; no database | Markdown-in-git IS the CMS (REQUIREMENTS "out of scope"); `devlog/` is an external read-only promote-pipeline target the site never writes to (D-01, D-06) |
| Content schema | Single `devlog` collection; Zod schema mirroring the studio `_TEMPLATE.md` field set with EVERY field optional; date/slug fall back to the `YYYY-MM-DD-slug.md` filename; title falls back to the first `# H1` | D-01/D-02 — permissive ingestion tolerates the frontmatter-less manifesto while still type-checking frontmatter when present |
| Fail-loud policy | `generateId` throws (naming the file) on an unparseable filename; `index.astro` asserts the collection is non-empty | D-10 — the fully-optional schema is counterbalanced by explicit loud failure; Astro's glob loader fails silently on a bad base path (Pitfall 2), so the assertion is mandatory |
| URL / base path | `site` + `base` in `astro.config.mjs` only; templates resolve links via `import.meta.env.BASE_URL` | SITE-02, D-06 — one config location so a future custom domain (DIST-04, v2) is a one-file change; no hardcoded `github.io` in `src/` |
| Deployment target | GitHub Pages via GitHub Actions (`withastro/action@v6` build → `actions/deploy-pages@v5`), every push to `main`, no path filters | SITE-01, D-04/D-08/D-09 — Pages already enabled (`build_type=workflow`) this session; a path filter's silent-non-deploy risk is the exact failure Phase 4 guards against |
| Package manager | npm; caret ranges; committed `package-lock.json`; CI installs via `npm ci` | D-04/D-05 — "boring is correct", deliberate `npm update` only |
| Directory layout | Astro at repo root (`package.json`, `astro.config.mjs`, `src/`) beside existing `devlog/`, `vault/`, `.planning/`; no `site/` subdirectory | D-06 — manual scaffold (NOT `create-astro`, which aborts on the non-empty root — Pitfall 1) |

## Stack Touched in Phase 1

- [x] Project scaffold — Astro installed manually at root, build via `npm run build`
- [x] Routing — one real route, `src/pages/index.astro`
- [x] Data — one real read: Content Layer `glob()` ingests `devlog/*.md` at build time (there is no DB "write" in a static content site; the write side is an author committing Markdown into `devlog/`, out of the app's runtime)
- [x] UI — the index page renders the collection (title + date list) wired to the content query
- [x] Deployment — live on GitHub Pages via the Actions workflow (`https://spoods-studios.github.io/interstellar-website/`)

## Out of Scope (Deferred to Later Slices)

- Styling, layout, mobile-responsiveness, fonts/colors — Phase 2 (D-07: the Phase 1 page is deliberately unstyled throwaway markup)
- Archive index page, "How It's Made" + Roadmap standalone pages, custom 404, favicon, canonical URLs, sitemap — Phase 2 (CONT-02/03/04, SITE-04)
- RSS feed, OpenGraph/Twitter cards, Discord CTA — Phase 3 (DIST-01/02/03)
- Cookieless analytics, M1.1 launch post, post-deploy smoke check, redirect-stub mechanism, full loud-fail hardening — Phase 4 (ANLT-01, CONT-05/06, SITE-03)
- Dark mode, syntax highlighting + KaTeX, search/tag taxonomy, custom domain — v2 (SITE-05, CONT-07, CONT-08, DIST-04)
- Test framework (Vitest/Jest) — intentionally NOT introduced; `npm run build` (real Zod validation + the D-10 guard) is the correct-altitude check for a build-pipeline phase with no application logic

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions (same framework, same content collection, same one-config-location URL, same deploy pipeline):

- **Phase 2:** Full devblog archive + "How It's Made" + Roadmap pages render as readable, mobile-friendly pages with baseline polish — VOICE content untouched.
- **Phase 3:** RSS feed (same collection query as the archive), OpenGraph/Twitter cards for rich Discord embeds, and a Discord CTA on every page.
- **Phase 4:** Cookieless analytics, the M1.1 launch post, loud-fail deploy hardening + post-deploy smoke check, and a slug-redirect-stub mechanism.

# Phase 1: Stack & Scaffolding - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

The Astro pipeline deploys to GitHub Pages from a config-driven URL and ingests
devlog Markdown permissively — the foundation is green end-to-end on a trivial
page. Covers SITE-01 (Actions build+deploy on push to main), SITE-02
(config-driven URL/base path, one location), CONT-01 (permissive devlog
ingestion with `YYYY-MM-DD-slug.md` filename fallback). Real archive pages,
templating, and polish are Phase 2 — Phase 1's page output is throwaway proof.

</domain>

<decisions>
## Implementation Decisions

### Manifesto frontmatter & schema
- **D-01:** Filename fallback only — never edit `devlog/` files. The
  frontmatter-less manifesto stays as-is; date and slug derive from the
  `YYYY-MM-DD-slug.md` filename, title from the first `# H1`. No backfill,
  local or upstream.
- **D-02:** Content schema mirrors the FULL studio `_TEMPLATE.md` frontmatter
  set (`milestone`, `title`, `date`, `status`, `discord_post_id`, `audience`,
  `hero_visual`) with every field optional. Fields validate when present
  (typos caught); nothing is required. Later phases get typed access to
  `hero_visual` etc. for free.

### Scaffold
- **D-03:** Minimal/empty `create astro` template; Content Collections,
  layout, and pages wired manually — only code the phase demands, nothing to
  strip. NOT the blog template.
- **D-04:** npm as package manager (`package-lock.json` committed). Default
  `withastro/action` path, zero extra CI setup.
- **D-05:** Caret version ranges + committed lockfile; CI installs via
  `npm ci`. Upgrades happen only by deliberate `npm update`. No exact pins.

### Repo layout
- **D-06:** Astro project lives at repo root — `package.json`,
  `astro.config.mjs`, `src/` beside existing `devlog/`, `vault/`,
  `.planning/`. Content loader reads `./devlog/` directly (external-path
  loader, since content is outside `src/content/`). No `site/` subdirectory,
  no path inputs in the Actions workflow.

### Phase-1 page content
- **D-07:** The deployed trivial page is an unstyled ingestion-proof list:
  every devlog collection entry rendered as title + date (exercising the
  filename fallback live). Throwaway markup (~20 lines), replaced wholesale
  by Phase 2 templating. Not a bare placeholder, not an early archive.

### Deploy trigger & CI
- **D-08:** Deploy workflow triggers on EVERY push to main — no path filters.
  GSD's frequent `.planning/`/`vault/` commits will each burn ~1-2 min of free
  Actions quota; accepted. Rationale: a forgotten path filter = silent
  non-deploy, the exact failure mode Phase 4 exists to prevent.
- **D-09:** Deploy-only CI in Phase 1 — single workflow (build + deploy on
  push to main). No PR build check; solo push-to-main flow has nothing for it
  to guard. Revisit if PR flow ever starts.

### Malformed-content policy
- **D-10:** A `devlog/*.md` file with neither frontmatter nor a parseable
  `YYYY-MM-DD-slug.md` filename date FAILS THE BUILD LOUDLY in Phase 1, with
  an error naming the offending file. This pulls one slice of SITE-03 forward
  deliberately. Corollary: non-post `.md` files (e.g. a stray `_TEMPLATE.md`)
  need an explicit exclusion rule, not silent tolerance.

### Claude's Discretion
- Exact Content Collections loader mechanics (glob loader config, slug
  derivation implementation) — verify against current Astro docs at planning
  time; the research example in stack docs is illustrative, not canonical.
- Astro config details (TypeScript strictness, `.gitignore` additions,
  `dist/` handling) — standard defaults, planner's call.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Content contract
- `devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md` — the
  frontmatter-less manifesto; the concrete case the filename-fallback schema
  must ingest without modification
- `../studio/vault/devlog/_TEMPLATE.md` — studio drafting template defining
  the full frontmatter field set the schema mirrors (all-optional, D-02)

### Project ground truth
- `.planning/PROJECT.md` — constraints (GitHub Pages, vendor-conservative,
  privacy, timeline) and key decisions
- `.planning/REQUIREMENTS.md` — SITE-01, SITE-02, CONT-01 definitions
- `.planning/ROADMAP.md` — Phase 1 success criteria (the four TRUE statements)
- `CLAUDE.md` (repo root) — `devlog/` untouchability rule; stack research
  (Astro 7.0.9, `withastro/action` + `actions/deploy-pages@v5`, `@astrojs/rss`
  for Phase 3)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `devlog/` — one real post (the manifesto), no frontmatter; live test input
  for CONT-01
- No site code exists — repo is vault + planning + content only; Phase 1
  builds the first `src/`

### Established Patterns
- Studio promote pipeline drops `.md` files into `devlog/` — site layer must
  treat that directory as read-only input forever
- GSD commits `.planning/` and `vault/` to main frequently — informs D-08
  (every-push deploys accepted)

### Integration Points
- GitHub repo already hosts the code; Pages + Actions are the same platform —
  no external vendor to wire
- Future phases hang off this scaffold: `pages/` sibling collection (Phase 2),
  RSS from the same collection query (Phase 3)

</code_context>

<specifics>
## Specific Ideas

- Phase-1 page is explicitly a *proof artifact*: seeing manifesto title +
  2026-04-07 date rendered on the live GitHub Pages URL demonstrates the
  whole pipeline (ingest → build → deploy) in one glance
- "Boring is correct" runs through every choice: npm over pnpm, no path
  filters, caret+lockfile, minimal template

</specifics>

<deferred>
## Deferred Ideas

- PR build-check workflow — add only if a PR flow to this repo ever starts
  (D-09)
- Loud-fail hardening beyond the malformed-filename case + post-deploy smoke
  check — Phase 4 (SITE-03)
- Syntax highlighting / KaTeX support check — v2 (CONT-07), verify Astro
  support during setup but implement later

</deferred>

---

*Phase: 1-Stack & Scaffolding*
*Context gathered: 2026-07-14*

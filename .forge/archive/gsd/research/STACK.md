# Stack Research

**Domain:** Content-first static devblog / marketing site, GitHub Pages, solo developer
**Researched:** 2026-07-13
**Confidence:** MEDIUM (versions VERIFIED against registries this session; qualitative/comparative claims from web search are LOW-confidence per source-hierarchy classification, cross-checked across 2+ independent sources where noted)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Astro | 7.0.9 `[VERIFIED: npm registry, npm view astro version]` | Static site generator | Purpose-built for content-heavy, low-interactivity sites ("islands" architecture ships zero JS by default). First-party **official GitHub Action** (`withastro/action`) makes GitHub Pages deploy a copy-paste workflow — directly serves the "never becomes the long pole" constraint. Content Collections give schema-validated Markdown ingestion out of the box. Large, active community (not bleeding-edge — Astro has been the mainstream pick for content sites for several years running). `[MEDIUM — official docs fetched: docs.astro.build/en/guides/deploy/github/]` |
| Node.js | 24.x LTS (matches user's default fnm runtime, v24.15.0 per environment) | Astro build runtime | Astro requires Node 18.20.8+/20.3.0+/22+; user's existing fnm default already satisfies this — zero new toolchain to maintain. `[ASSUMED — Node version requirement from Astro's general engine range in training data; not re-verified this session, but low-risk since user's installed version is recent]` |
| @astrojs/rss | 4.0.19 `[VERIFIED: npm registry]` | RSS feed generation | Official Astro package. Generates the feed as a build-time API endpoint (`src/pages/rss.xml.js`); pulls items directly from `getCollection()` so the devblog archive and the RSS feed share one source of truth — no second content pipeline to maintain. `[MEDIUM — official docs fetched: docs.astro.build/en/guides/rss/]` |
| GitHub Actions (`withastro/action` + `actions/deploy-pages`) | `actions/deploy-pages@v5.0.0` `[VERIFIED: GitHub API, api.github.com/repos/actions/deploy-pages/releases/latest]` | Build + deploy to GitHub Pages | GitHub's own recommended path for **all** modern SSGs on Pages (Jekyll's legacy zero-config built-in build is now considered the *legacy* route, not the recommended one — see Jekyll note below). Astro's official action wraps this cleanly. `[MEDIUM]` |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `@astrojs/sitemap` | latest (installed via `astro add sitemap`) | XML sitemap generation | Add alongside RSS — near-zero cost, standard SEO hygiene for a marketing-facing site. `[ASSUMED — standard Astro integration, not independently version-checked this session]` |
| `sanitize-html` | latest | Sanitize rendered Markdown HTML before embedding in RSS `<content:encoded>` | Only needed if the RSS feed embeds full post HTML (not just excerpts) — recommended per Astro's own RSS docs to avoid malformed/unsafe markup leaking into feed readers. `[MEDIUM — mentioned in official RSS docs]` |
| Zod (bundled with Astro Content Collections) | bundled | Frontmatter schema validation | Use to define a `title`/`date`/`status` schema for the `devlog` collection. **Note:** the one devblog post already promoted into this repo (`devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md`) has **no YAML frontmatter at all** — just an `# H1` title. The studio-side `_TEMPLATE.md` used by the drafting pipeline *does* define frontmatter (`milestone`, `title`, `date`, `status`, `discord_post_id`, `audience`, `hero_visual`) — so future promoted posts should carry it, but this first one doesn't. Recommend either (a) making the schema fields optional with filename-date fallback, or (b) back-filling frontmatter on the existing post during implementation. Flag for phase planning, not just stack choice. `[HIGH — read directly from repo files this session: /home/spoods/Projects/spoods-studios/interstellar-website/devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md:1-3 (no frontmatter block); /home/spoods/Projects/spoods-studios/studio/vault/devlog/_TEMPLATE.md:1-9 (frontmatter schema)]` |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| GoatCounter (hosted, goatcounter.com) | Privacy-respecting, cookieless analytics | Free hosted tier for non-commercial/OSS use up to 100k pageviews/month, donation-supported — **no server to run**, which matters because this project has zero infra otherwise (GitHub Pages is static hosting). Single-script embed, no cookie banner needed. `[LOW — web search only, cross-checked across 2 sources: goatcounter.com homepage claim + analytics-alternatives.com review, both agreeing on the free non-commercial tier and 100k pageview limit]` |
| GitHub Actions (built-in to the repo) | CI: build Astro site, deploy to Pages | No separate CI vendor needed — GitHub Pages + GitHub Actions is already the same platform the repo lives on. |

## Installation

```bash
npm create astro@latest
# During setup: choose "blog" template as a starting scaffold, or empty + Content Collections added manually

# Core
npm install astro @astrojs/rss

# Supporting
npx astro add sitemap
npm install sanitize-html

# Dev dependencies
# (none beyond what `astro add` scaffolds — Astro ships its own dev server/build toolchain)
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Astro | **Eleventy (11ty)** — latest `@11ty/eleventy` = 3.1.6 `[VERIFIED: npm registry]` | If you want the absolute minimum abstraction over raw Markdown+templating with no build-time framework opinions at all. Eleventy "does the least," which some solo devs prefer for long-term low-maintenance (fewer breaking upgrades, no component model to learn). Needs `@11ty/eleventy-plugin-rss` (3.0.0, verified npm) added manually — RSS isn't built in. Reasonable second choice; didn't pick it because Astro's official GH Pages Action + built-in Content Collections schema validation directly reduce the "long pole" risk more than Eleventy's flexibility does. `[LOW — web search, single round, moderately corroborated across 3+ 2026-dated comparison articles]` |
| Astro | **Hugo** — latest `v0.164.0` `[VERIFIED: GitHub Releases API]` | If build speed at very large scale (1000s of pages) or a single static Go binary with zero Node/npm dependency chain is the top priority. Hugo has RSS built in (no plugin) and a mature GitHub Actions starter workflow. Didn't pick it because: (a) it's a second toolchain/language (Go templates) alongside the project's existing Node-based tooling elsewhere in the ecosystem gets no benefit from Go; (b) Hugo's templating language has a well-documented steeper learning curve for occasional maintenance touches. Reasonable if the maintainer strongly prefers avoiding Node entirely. `[LOW — web search]` |
| Astro | **Jekyll** | Only if you want GitHub's *legacy* zero-config Pages build path (push Markdown, GitHub builds it server-side, no Actions workflow at all). **Do not use for this project** — see "What NOT to Use." |
| Astro | **Zola** — latest `v0.22.1` `[VERIFIED: GitHub Releases API]` | Rust-based, single binary, built-in RSS/sitemap, fast. Smaller community/ecosystem than Astro/Hugo/Eleventy and fewer GitHub Pages deploy tutorials/prior art — higher risk of the maintainer being the only one who's ever debugged an obscure issue. Not recommended given the vendor-conservative constraint (favor "well-established, widely-adopted... avoid bleeding-edge"). `[LOW]` |
| GoatCounter (hosted) | **Plausible** (hosted SaaS, ~$9/mo `[LOW — web search]`) | If budget for a paid tool is acceptable and a more polished dashboard/UI is valued over saving the small recurring cost — Plausible is the more "established brand" of the two and also cookieless/GDPR-friendly. Reasonable alternative; picked GoatCounter first only because it's free at this traffic scale and equally well-regarded. |
| GoatCounter (hosted) | **Umami** (self-hosted, MIT) | Only if the project already plans to run its own server/VPS for some other reason — Umami's free tier requires self-hosting, which adds infrastructure this otherwise-static-hosted project doesn't need. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Jekyll's **built-in GitHub Pages processor** (push `.md`, GitHub auto-builds via the `github-pages` gem) | The `github-pages` gem pins an old Jekyll/Ruby version and lags current Jekyll releases; GitHub's own current guidance is to deploy via a custom GitHub Actions workflow instead of relying on this legacy auto-build path, even for Jekyll itself. Using the legacy path locks the site to whatever Jekyll version GitHub's gem happens to support, with no control over upgrade timing. `[LOW — web search, single round; directionally consistent with GitHub's own docs.github.com guidance surfaced in search]` | If Jekyll is chosen at all, deploy it via `actions/starter-workflows/pages/jekyll-gh-pages.yml` (Actions-based), not the auto-build path. But given the vendor-conservative + low-maintenance goals, Astro is still the better pick overall — Jekyll's ecosystem/plugin story is comparatively less actively maintained in 2026 than Astro's. |
| Gatsby / Next.js (static export) as the SSG | Both are React-application frameworks retrofitted for static output — far more build complexity, dependency surface, and upgrade churn than a purpose-built content SSG needs for a Markdown-archive-plus-a-few-pages site. Directly works against the "must never become the long pole" constraint for a maintainer whose main project is a C++ engine, not a web app. `[LOW — web search, general industry consensus]` | Astro (recommended) or Eleventy. |
| Self-hosted Plausible Community Edition / Matomo | Requires standing up and maintaining a ClickHouse+Elixir (Plausible CE) or PHP+MySQL (Matomo) stack on a VPS — real ongoing ops burden for a project whose entire point of choosing GitHub Pages was zero infrastructure. `[LOW — web search]` | GoatCounter hosted (free tier) or Plausible hosted SaaS — both zero-ops. |
| Google Analytics (any version) | Explicitly disqualified by the project's own "no cookies, no invasive tracking" constraint (PROJECT.md) — GA is cookie-based and not GDPR-friendly without a consent banner, which contradicts the "quiet, content-first" site philosophy. `[HIGH — directly contradicts stated project constraint, PROJECT.md:80-81]` | GoatCounter or Plausible (both cookieless). |

## Stack Patterns by Variant

**If the maintainer wants zero Node/npm toolchain long-term (strong Go/binary preference):**
- Use Hugo instead of Astro
- Because Hugo ships as a single compiled binary with no `node_modules`/dependency-upgrade treadmill — trades Astro's nicer Markdown/schema DX for a smaller long-term maintenance surface in a different dimension (no JS ecosystem churn at all).

**If post volume stays small (dozens, not hundreds, of posts) and a component model is unwanted:**
- Eleventy is a legitimate equal-weight alternative to Astro
- Because at low post-count, Astro's Content Collections/schema-validation benefit is smaller, and Eleventy's near-zero abstraction may be even less to maintain long-term.

**If GoatCounter's non-commercial free-tier terms become a concern (e.g., the studio starts monetizing and wants to be safe rather than rely on the honor system):**
- Switch to Plausible hosted (paid) or pay GoatCounter's $15/mo commercial tier
- Because both remain zero-ops; the only change is budget, not architecture.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|------------------|-------|
| astro@7.0.9 | @astrojs/rss@4.0.19 | Both are current majors published under the same Astro release line as of this session; install together via `npm install astro @astrojs/rss` and npm will resolve compatible ranges. `[MEDIUM]` |
| astro@7.0.9 | Node.js 24.x (user's fnm default) | Satisfies Astro's minimum Node engine requirement comfortably (Astro requires Node ≥18.20.8, well below 24.x). `[ASSUMED — Astro's Node engine floor from training data, not re-verified this session]` |
| withastro/action | actions/deploy-pages | The official Astro GitHub Action wraps GitHub's own `actions/deploy-pages` (currently v5.0.0) — no manual pinning needed if using the official Astro workflow template from docs.astro.build. `[MEDIUM]` |

## Sources

- `docs.astro.build/en/guides/deploy/github/` — fetched this session (WebFetch), official Astro GitHub Pages deploy guide — MEDIUM confidence
- `docs.astro.build/en/guides/rss/` — fetched this session (WebFetch), official Astro RSS guide — MEDIUM confidence
- `docs.astro.build/en/guides/content-collections/` — fetched this session (WebFetch), official Astro Content Collections guide — MEDIUM confidence
- `npm view astro version`, `npm view @astrojs/rss version`, `npm view @11ty/eleventy version`, `npm view @11ty/eleventy-plugin-rss version` — run this session, npm registry — HIGH confidence (version facts)
- `api.github.com/repos/gohugoio/hugo/releases/latest`, `api.github.com/repos/getzola/zola/releases/latest`, `api.github.com/repos/actions/deploy-pages/releases/latest` — run this session, GitHub Releases API — HIGH confidence (version facts)
- `rubygems.org/api/v1/gems/jekyll.json` — run this session, RubyGems API — HIGH confidence (version fact)
- WebSearch: "Astro vs Hugo vs Eleventy... 2026", "Jekyll GitHub Pages 2026 maintenance status", "GitHub Pages deploy Actions starter workflows", "GoatCounter vs Plausible vs Umami... 2026", "GoatCounter free hosted service pricing" — LOW confidence per classify-confidence (unverified web source), used only for comparative/qualitative claims, cross-checked across 2-3 independent results per query where stated above
- Repo files read directly this session: `/home/spoods/Projects/spoods-studios/interstellar-website/devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md`, `/home/spoods/Projects/spoods-studios/studio/vault/devlog/_TEMPLATE.md`, `/home/spoods/Projects/spoods-studios/interstellar-website/.planning/PROJECT.md` — HIGH confidence (direct observation)

---
*Stack research for: content-first static devblog/marketing site, GitHub Pages, solo dev, no-cookie analytics*
*Researched: 2026-07-13*

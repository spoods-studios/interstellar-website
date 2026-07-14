# Feature Research

**Domain:** Indie game-engine devblog / marketing website (static, content-first)
**Researched:** 2026-07-13
**Confidence:** MEDIUM (cross-verified against two live official engine-blog sites — Factorio and Godot — plus general technical-blog/SSG conventions; all web-sourced, no curated docs available for this ecosystem)

## Feature Landscape

### Table Stakes (Users Expect These)

Features readers assume exist on any blog/devlog site in 2026. Missing these makes the site feel broken or unfinished, not just "basic."

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| RSS/Atom feed | Every devblog reference site checked (Factorio, Godot) has one; devblog readers are a self-selecting technical audience that still uses feed readers | LOW | Already in v1 scope. Most SSGs (Astro, Hugo, 11ty) generate this from a plugin/config, near-zero extra work |
| OpenGraph + Twitter Card meta tags | Discord link unfurls, Twitter/X/Bluesky shares, and Reddit posts all depend on OG tags — without them, links posted in Discord #devlog (the primary distribution channel per PROJECT.md D-F) render as bare text/URL, which directly undercuts the "Discord-first audience building" strategy | LOW | **Flag: missing from v1 scope as written.** Needs a per-post `og:title`/`og:description`/`og:image` (or a generated fallback banner) and `twitter:card=summary_large_image`. This is the single highest-leverage gap given the Discord CTA is core to distribution |
| Mobile-responsive layout | Baseline in 2026; a meaningful share of devblog traffic arrives via Discord links opened on phones | LOW–MEDIUM | Any competent SSG theme handles this by default; still needs explicit verification pass, not just "the framework probably does it" |
| Readable typography / long-form reading layout | This is a "written video essay" register (VOICE.md) — line length, font size, paragraph spacing directly affect whether people finish a 2000-word post | LOW | Constrain content column width (~65-75ch), decent line-height; standard blog-theme concern |
| Code/syntax-highlighted blocks | Engine devblog will reference code, shaders, config snippets, terminal output as the content matures past M1.1 (physics/Vulkan deep-dives per D-H roadmap) | LOW | Shiki/Prism/highlight.js, both light+dark variants if dark mode ships. Not urgent for the manifesto + M0.x archive but will be needed the moment a rendering-deep-dive post lands (D-H mentions a "rendering deep-dive series") |
| Math rendering (KaTeX/MathJax) | Aerospace/physics-engine content will eventually need orbital mechanics or numerics notation; engine is built on real physics (per ecosystem context) | LOW–MEDIUM | Not needed for the manifesto/M0.x posts on file today, but should be verified as "supported by the chosen SSG" during stack research so it isn't a later rewrite. Flag as **table-stakes-in-waiting**, not urgent for M1.1 launch itself |
| Fast load / no heavy JS framework overhead | Content-first, no-hype philosophy (PRD §21.1) implies the site itself should not feel like a bloated SPA; also affects mobile/Discord-click bounce | LOW (if static-first tooling is chosen) | Directly informs STACK.md — favors an SSG that ships near-zero JS by default over a full SPA framework |
| 404 / broken-link handling | GitHub Pages default 404 is ugly and off-brand; any renamed/removed devlog draft will 404 | LOW | Trivial with any SSG; still needs an explicit custom 404 page, easy to forget |
| Canonical URLs per post | SEO baseline, avoids duplicate-content penalties if the same devblog content is ever mirrored (Discord excerpt + full post) | LOW | Free with most SSGs |
| Sitemap.xml | SEO/discoverability baseline; near-zero cost with any SSG | LOW | Bundled with RSS-plugin-equivalent tooling in most SSGs |
| Favicon / basic brand identity in browser chrome | Baseline polish; absence reads as "unfinished project" | LOW | Trivial, easy to overlook amid content work |
| Accessible color contrast / semantic HTML | Table stakes for any professional site in 2026, and the dev's own UX-philosophy directive (design-conscious, quality spacing/transitions) raises the bar further | LOW–MEDIUM | Verify at build, not bolt-on later |

### Differentiators (Competitive Advantage)

Features that set this site apart from a generic devblog. Align with the "quiet, content-first, no fake hype" philosophy (PRD §21.1) and the AI-transparency obligation (D-G).

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| "How It's Made" AI-transparency page | Almost no indie devblog does this proactively — most either hide AI tool use or over-hype it. A dedicated, honest disclosure page is a genuine trust differentiator in a market increasingly skeptical of AI-assisted creative work | LOW (content is already drafted per PROJECT.md) | Already in v1 scope. This is the site's actual differentiator — lean into it being findable (nav-level link, not buried in a footer) |
| Locked, distinctive editorial voice (Scott Manley / Everyday Astronaut register) | Most engine devblogs (Factorio FFF, Godot progress reports) are functional-terse; a "written video essay" voice with narrative pull is unusual for engine-dev content and matches the aerospace-sim niche audience | LOW (voice is content, not a site feature) | Site's job is to not get in the way of it — no CMS templating that forces headline/teaser formats incompatible with long narrative prose |
| Roadmap page mirroring Discord #roadmap pinned overview | Gives non-Discord visitors (search traffic, shared links) the same "here's what's coming" transparency Discord regulars already get — most indie engines only show this in a Trello/Discord silo invisible to outsiders | LOW–MEDIUM | Already in v1 scope. Needs a lightweight sync story so it doesn't silently drift from the Discord pin (even a manual "last synced" note is enough for v1) |
| Devblog archive as permanent, linkable canonical home | Explicitly named as Core Value in PROJECT.md — most small studios treat Discord as the archive (which is unsearchable, unlinkable, and vanishes into scroll history). Making every post a stable URL is the actual product-market differentiator here, not a checkbox feature | LOW–MEDIUM | Already in v1 scope; this *is* the reason the site exists per PROJECT.md's Core Value statement |
| Privacy-respecting, cookieless analytics | Most competitor devblogs (Factorio, Godot) run Google Analytics or nothing; explicitly avoiding cookies/tracking is a quiet trust signal consistent with the "no fake hype, real work" philosophy | LOW | Already in v1 scope (Plausible/GoatCounter class) |
| Engine-capture / real-render imagery only (no generative AI art) | D-G policy explicitly bans generative imagery; visuals sourced from actual engine captures + NASA/USGS data. This reads as more credible than the stock-AI-art many small studio sites now lean on | N/A (policy, not a build feature) | Constrains the differentiator above — image pipeline should be "screenshot/render export," not "AI banner generator" |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but would work against the stated philosophy, timeline, or gate tier (T3, no multi-vendor grid, static-only).

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Comments section | "Let readers discuss posts" feels natural for a blog | PROJECT.md explicitly rules this out — "no backend, static site; Discord is the conversation venue." Comments also require moderation overhead a solo/small studio can't sustain, and fragment discussion away from Discord (undermining D-F's Discord-first growth strategy) | Link back to the Discord #devlog thread for that post; CTA already in v1 scope |
| User accounts / newsletter signup with login | Feels like "growing the audience" | Explicitly out of scope (no backend, no accounts); adds a data-collection/privacy surface that conflicts with the cookieless-analytics, no-invasive-tracking constraint | RSS feed (already in scope) is the account-free subscribe mechanism; Discord invite is the community mechanism |
| Press kit / media assets page | Looks like standard indie-studio-website boilerplate | Explicitly deferred to Phase 2 (EA launch era) per PRD §21.2 — building it now is scope creep against a hard M1.1 clock where "site work must not become the long pole" | Defer; note the URL slot so it can be added later without restructuring nav |
| Steam wishlist funnel / storefront widgets | "Every indie game site has a Steam button" | Explicitly deferred to Phase 2; the game (Setare Aerospace) doesn't even activate its own repo until M1.1 — premature to funnel toward a storefront that doesn't exist yet | Discord CTA is the only funnel for v1; Steam page becomes real work once setare-game is active |
| Patreon / monetization integration | Common on established devblogs (many use Patreon badges/tiers) | PROJECT.md pins Patreon launch to M1.6 (D-F decision), not M1.1 — building the integration now is scope creep and adds a third-party embed to a site whose whole ethos is "quiet, content-first" | Defer entirely until M1.6; don't even stub the nav slot yet (unlike press kit/Steam, this has a firm later milestone, not just "later") |
| Full CMS / admin dashboard (Wordpress-style) | Feels like it'll make future editing easier | Directly conflicts with the constraint that devblog `.md` files remain source of truth via the existing studio promote-pipeline (`draft-devblog` skill → `devlog/` dir); a CMS would fork content ownership away from that pipeline and add a server/database this static-site project explicitly avoids | Render existing `.md` files at build time; content authoring stays in the studio vault's locked pipeline |
| Custom domain purchase/setup now | Feels like "doing it right the first time" | Explicitly deferred — PROJECT.md: "GitHub Pages URL is fine for launch, domain attaches later without rework." Chasing this now risks becoming the timeline's long pole for zero M1.1 value | Ship on the default GitHub Pages subdomain; keep the SSG config domain-agnostic so attaching a custom domain later is a DNS + config change, not a rebuild |
| Generative-AI banner/hero imagery | Fast, cheap way to get "polished" visuals for post headers | D-G policy explicitly bans generative-AI imagery/branding assets — using it would directly contradict the AI-transparency page's own credibility | Use actual engine render captures, screenshots, or NASA/USGS source imagery; if no capture exists yet for a post, ship without a hero image rather than generate one |
| Tag/category filtering system, related-posts widget | Godot's blog has category filters; feels like "parity with bigger engines" | At M1.1 launch the entire corpus is ~9 posts (manifesto + M0.1–M0.8) — a filtering/taxonomy system is complexity with zero payoff at this volume, and risks becoming premature architecture that constrains the content model before enough real posts exist to know what taxonomy is even needed | Simple reverse-chronological archive list for v1 (already the implied shape); revisit tagging once the archive is large enough that browsing by topic has real value (v1.x+) |
| Real-time / live features (live chat widget, live viewer counts, etc.) | "Feels more alive/active" | Static site with no backend; any real-time feature requires infrastructure this project is explicitly avoiding, and it's antithetical to a "quiet, no fake hype" devblog that isn't trying to manufacture activity signals | Discord itself is the live/real-time venue; site stays static |

## Feature Dependencies

```
Devblog archive (rendering .md → pages)
    └──requires──> Static-site tooling decision (STACK.md)
                       └──requires──> Content pipeline compat w/ existing devlog/ dir + VOICE.md preservation

RSS feed
    └──requires──> Devblog archive (needs post metadata: title, date, slug)

OpenGraph/social-embed metadata
    └──enhances──> Discord CTA (link unfurls become rich previews instead of bare URLs)
    └──requires──> Per-post title/description/(optional hero image) in front matter

Roadmap page
    └──requires──> Manual or scripted sync source from Discord #roadmap pinned overview

AI-transparency page
    └──independent──> no dependency on archive/roadmap; can ship standalone from how-its-made.md draft

Code/syntax highlighting, Math (KaTeX)
    └──enhances──> Devblog archive (needed once rendering-deep-dive posts land, per D-H roadmap)
    └──conflicts (partially)──> "near-zero JS" performance goal if implemented client-side; prefer build-time/SSG-side highlighting (Shiki-at-build) over client JS libraries

Dark mode
    └──enhances──> Code blocks (needs light+dark syntax theme pair if both ship together)

Custom domain
    └──requires──> GitHub Pages deployment already live (v1 scope) — purely additive, no rework per PROJECT.md
```

### Dependency Notes

- **RSS requires the archive:** the feed is generated from the same post metadata (title/date/slug/excerpt) the archive page needs, so they should be built from one content model, not two.
- **OpenGraph enhances the Discord CTA:** this is the strongest cross-feature argument for adding OG tags to v1 rather than deferring — the CTA's entire value depends on links looking good when pasted into Discord/social.
- **Code/math rendering enhances the archive, doesn't block it:** the manifesto and early M0.x posts are narrative prose, not code-heavy, so this can land in v1.x once the first rendering-deep-dive post is drafted, per the D-H "rendering deep-dive series" plan — but the SSG chosen in STACK.md should be verified now to support it without a retheme later.
- **Dark mode and code highlighting are coupled:** if dark mode ships, syntax themes need a light+dark pair or dark-mode code blocks will look broken. If code highlighting ships before dark mode, use a single theme that reads fine on both (many do); don't build dark-mode-aware highlighting until dark mode itself is confirmed for v1.
- **Custom domain conflicts with nothing:** explicitly designed as a zero-rework later add per PROJECT.md, confirmed here as consistent with all other v1 features.

## MVP Definition

### Launch With (v1) — already pinned in PROJECT.md, validated by this research

- [ ] Devblog archive (manifesto + M0.1–M0.8) — Core Value; the entire reason the site exists
- [ ] "How It's Made" AI-transparency page — obligation `ai-transparency-post`, differentiator
- [ ] Roadmap page — obligation-adjacent, transparency differentiator
- [ ] M1.1 launch post — required content
- [ ] Discord CTA — primary distribution/growth mechanism (D-F)
- [ ] RSS feed — table stakes for this audience, near-zero cost
- [ ] Privacy-respecting analytics — table stakes given no-tracking constraint, differentiator vs typical GA-tracked sites
- [ ] **OpenGraph/social-embed metadata** — **research flags this as a gap in v1 scope as written; recommend adding.** Directly amplifies the Discord CTA's value at near-zero cost; without it, every Discord-shared link looks broken/unpolished
- [ ] Mobile-responsive layout, custom 404, favicon, canonical URLs, sitemap.xml — baseline polish table stakes, near-zero cost with any competent SSG, should be treated as "done by default" checklist items during build rather than separately negotiated scope

### Add After Validation (v1.x)

- [ ] Code syntax highlighting (light+dark) — trigger: first rendering-deep-dive post is drafted
- [ ] Math rendering (KaTeX) — trigger: first post needs orbital-mechanics/numerics notation
- [ ] Dark mode toggle — trigger: reader feedback or simply "worth doing once core content ships"; verify SSG supports without retheme before v1 ships so this stays cheap
- [ ] Custom domain — trigger: whenever domain is purchased; explicitly zero-rework per PROJECT.md

### Future Consideration (v2+)

- [ ] Press kit — deferred to Phase 2 / EA launch era per PRD §21.2
- [ ] Steam page / wishlist funnel — deferred to Phase 2
- [ ] Patreon integration — pinned to M1.6 per D-F, not before
- [ ] Tag/category archive filtering, related-posts — defer until post volume actually warrants browsing by topic (not at ~9 posts)
- [ ] Comments — anti-feature, likely never (Discord is the designated venue)

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Devblog archive | HIGH | MEDIUM | P1 |
| AI-transparency page | HIGH | LOW | P1 |
| Roadmap page | MEDIUM | LOW–MEDIUM | P1 |
| Launch post | HIGH | LOW (content exists) | P1 |
| Discord CTA | HIGH | LOW | P1 |
| RSS feed | MEDIUM | LOW | P1 |
| Privacy analytics | MEDIUM | LOW | P1 |
| OpenGraph metadata | HIGH | LOW | **P1 (recommend promoting into v1 scope)** |
| Mobile responsive | HIGH | LOW (default w/ good SSG) | P1 |
| Dark mode | MEDIUM | LOW–MEDIUM | P2 |
| Code syntax highlighting | MEDIUM | LOW | P2 |
| Math rendering | LOW (not yet) | LOW–MEDIUM | P2 |
| Custom domain | LOW (URL works fine) | LOW | P2 |
| Press kit | LOW (not yet) | MEDIUM | P3 |
| Steam funnel | LOW (not yet) | MEDIUM | P3 |
| Patreon integration | LOW (not yet) | MEDIUM | P3 |
| Tag/category system | LOW (too few posts) | MEDIUM | P3 |
| Comments | NEGATIVE (conflicts w/ Discord-first) | MEDIUM | Never |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Factorio (FFF/blog) | Godot Engine (official blog) | Our Approach |
|---------|--------------------|-------------------------------|--------------|
| Archive format | Paginated, chronological, thumbnails + excerpt | Paginated, chronological, category-filterable | Chronological list; skip category filter at v1 (too few posts) |
| RSS | Yes (footer link) | Yes | Yes (already scoped) |
| Search | Yes (search box on blog) | Yes (search icon) | Skip at v1 — ~9 posts don't need search; revisit at volume |
| Dark mode | No visible toggle | Yes (dark-aware logo/theme) | Defer to v1.x; verify SSG support during stack pick so it's cheap later |
| Comments | No | No (uses external community channels) | No — confirms our Discord-only approach matches established practice, not an outlier choice |
| Social links / cross-posting | Minimal (RSS only) | Extensive (GitHub, Discord, Mastodon, Bluesky, Reddit) | Discord CTA is primary per D-F; keep footer light, avoid diluting focus with a social-icon wall |
| Tags/categories | No | Yes (News/Progress/Events/Release/Showcase) | Skip at v1; if added later, keep it to 2-3 categories max (e.g., Devlog / Announcements), not Godot's 6 |
| Author byline | Yes | Yes, with avatar | Optional for v1 — single-author/small-team devblog makes this lower priority than for a larger org |
| OpenGraph/social embeds | Not directly observed, but Discord-first distribution makes this more load-bearing here than for either competitor | Not directly observed | **Higher priority for this project than for either reference site**, because Discord-link-sharing is the explicit primary growth channel (D-F) — this is the one area where the reference sites don't set the bar high enough |

## Sources

- [Blog | Factorio](https://factorio.com/blog/search/Friday%20Facts) — live fetch of factorio.com/blog, MEDIUM confidence (direct primary-source observation, cross-checked against a second official engine blog)
- [Seven Years of Factorio Friday Facts · William Spies](https://spieswl.github.io/blog/2020/seven-years-of-factorio-friday-facts) — LOW confidence, secondary commentary
- [Friday Facts #391 - 2023 recap | Factorio](https://www.factorio.com/blog/post/fff-391)
- [Godot Engine - Blog](https://godotengine.org/blog/) — live fetch, MEDIUM confidence (direct primary-source observation)
- [KSP Community · GitHub](https://github.com/kspcommunity) — LOW confidence, general web search
- [Kerbal Space Program Wiki](https://wiki.kerbalspaceprogram.com/wiki/Main_Page)
- General SSG/technical-blog convention search (OpenGraph, RSS, dark mode, syntax highlighting) — LOW confidence, general web search, corroborated by direct observation of Factorio/Godot
- Project context: `/home/spoods/Projects/spoods-studios/interstellar-website/.planning/PROJECT.md` — v1 scope, constraints, D-F/D-G/D-H decisions referenced throughout

---
*Feature research for: indie game-engine devblog / marketing website*
*Researched: 2026-07-13*

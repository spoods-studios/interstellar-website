# Pitfalls Research

**Domain:** Indie-game devblog/marketing website, static site on GitHub Pages
**Researched:** 2026-07-13
**Confidence:** MEDIUM (web-cross-checked community + vendor-discussion sources; no HIGH-tier curated docs consulted this session)

## Critical Pitfalls

### Pitfall 1: The site becomes a second project competing with the engine

**What goes wrong:**
Theming, custom layouts, "just one more component," and hand-rolled build tooling eat the same calendar the engine milestone needs. The site was scoped to ship inside one engine-milestone window (M1.1) with near-zero maintenance after — but static-site work has no natural stopping point; every SSG invites endless polish.

**Why it happens:**
Marketing/site work draws on the same time budget as the actual game and has no external deadline pressure of its own once the launch obligation is nominally met, so it silently expands. Community sources confirm this is a common indie-dev failure mode: unplanned marketing/site effort causes schedule chaos and competes directly with dev time [MEDIUM confidence, web-cross-checked].

**How to avoid:**
- Pick the SSG with the smallest ongoing surface area for this project's actual needs (a handful of Markdown posts + 2 static pages), not the most "capable" one. Fewer plugins, fewer config knobs, no custom theme build step.
- Treat "renders existing locked `.md` content, does not restyle it" (already a PROJECT.md constraint) as a hard scope fence, not just a content rule — apply it to layout/CSS ambition too.
- Define "done" as a checklist (archive renders, RSS validates, OG validates, analytics live, deploy green) before starting, not as an open-ended polish target.

**Warning signs:**
- Custom CSS framework, component library, or JS bundler is being introduced for a devblog with < 15 posts.
- Time spent on site work in a session exceeds time spent on any single devblog post it's meant to host.

**Phase to address:**
Stack-selection / scaffolding phase — the SSG choice itself is the single highest-leverage decision for keeping this contained.

---

### Pitfall 2: Broken RSS/OpenGraph previews at launch (silent, high-visibility failure)

**What goes wrong:**
The devblog ships, Discord #devlog links to a post, and the link unfurls with no image, the wrong title, or no preview at all. RSS feed either doesn't validate, uses relative URLs that break in readers, or omits required fields (missing `<link>`/`<guid>`/absolute URLs).

**Why it happens:**
Missing `og:image` is the single most common cause of broken social previews — without it, platforms show no image or grab a random one from the page [MEDIUM confidence, web-cross-checked]. Relative image URLs in OG tags (`/images/og.jpg` instead of a full `https://...` URL) are silently ignored by every consuming platform [MEDIUM confidence, web-cross-checked]. Missing `twitter:card` suppresses the X/Twitter preview entirely even when OG tags are otherwise correct [MEDIUM confidence]. A shared layout that hardcodes homepage OG values means every post shared to Discord/social shows the same generic preview instead of the post's own title/image [MEDIUM confidence].

**How to avoid:**
- Every page template must emit per-page `og:title`, `og:description`, `og:image` (absolute URL, not relative), `og:url`, and `twitter:card` — generated from post frontmatter, never hardcoded once in a base layout.
- RSS feed: absolute URLs throughout, valid `<link>`/`<guid>` per item, and validate against the W3C Feed Validator (or `xmllint`) before every launch-critical merge, not just once at setup.
- Test social unfurl before the launch post goes out: paste the actual post URL into Discord's own embed preview (paste in a private channel, check the card) and a Twitter/X card validator equivalent, not just "looks right in browser."

**Warning signs:**
- OG tags present in the base `<head>` template only, not per-page/per-post.
- No RSS validator run in CI or pre-launch checklist.
- Discord embed of a real post URL was never manually checked before the launch announcement.

**Phase to address:**
Site scaffolding/templating phase (build the per-post template with OG+RSS baked in) and again as a launch-gate checklist item before the M1.1 launch post goes out.

---

### Pitfall 3: GitHub Pages baseurl/custom-domain rework at migration time

**What goes wrong:**
Site is built and working at `<org>.github.io/<repo>` (or `<user>.github.io`), then a custom domain is attached later per the roadmap ("custom domain attachable later without rework" is an explicit PROJECT.md requirement) — and every internal link, asset path, canonical URL, and OG `og:url` breaks or double-prefixes because the SSG's baseurl/path config was hardcoded to the GitHub Pages subpath.

**Why it happens:**
Static site generators bake the configured base URL into generated HTML (absolute canonical links, asset paths, sitemap, RSS `<link>`s) at build time. If the config's `url`/`baseURL` value is the temporary `github.io` path rather than root-relative or a variable swapped at deploy time, every generated absolute URL needs re-templating when the domain changes. Hugo specifically needs `canonifyURLs`/baseURL correctness or images/links break; Jekyll needs both `url` and `baseurl` keys set correctly and a `CNAME` file for custom domains [MEDIUM confidence, cross-checked across Hugo/Jekyll community discussions].

**How to avoid:**
- Use root-relative paths (`/posts/foo/`) everywhere in templates, never assume a repo-subpath prefix. If deploying to `<user>.github.io` (org/user root site, no repo-name subpath), `baseurl` can stay empty from day one — avoids the whole migration problem. Confirm which GitHub Pages mode this repo will use before scaffolding.
- Keep the SSG's `url`/`baseURL` config as a single source of truth referenced everywhere (canonical tags, RSS, sitemap, OG `og:url`) — never hardcode the github.io domain string in multiple templates.
- When the custom domain attaches later: update the one config value, add the `CNAME` file to the site root, and rebuild — this should be a < 5 minute change if the above is followed. Budget a smoke-test pass (internal links, RSS, OG) immediately after, not just "DNS resolves."

**Warning signs:**
- Any template or partial has the literal `github.io` string typed into it.
- Asset `<img src>` or nav links use the repo-name subpath explicitly instead of a config variable.

**Phase to address:**
Stack-selection/scaffolding phase (choose Pages mode + config structure correctly up front) — this is cheap to get right early and expensive to fix after content exists.

---

### Pitfall 4: HTTPS/DNS provisioning stalls block a hard launch date

**What goes wrong:**
If a custom domain (or even re-attaching Pages settings) is touched close to the M1.1 launch date, GitHub's TLS certificate provisioning can hang — "stuck at TLS certificate is being provisioned" is a recurring, unresolved-feeling state — and DNS A-record propagation can take up to a day. If this is on the launch-day critical path, it can block the entire release.

**Why it happens:**
GitHub Pages only issues a cert for the exact domain configured (root vs `www` are provisioned separately); Cloudflare-proxied DNS records break GitHub's ACME challenge (must be DNS-only, not proxied); and re-provisioning after any settings change restarts a 15–90 minute wait, sometimes longer if it gets stuck and requires a remove/re-add cycle [MEDIUM confidence, cross-checked across multiple GitHub Community discussions + official docs.github.com HTTPS guide].

**How to avoid:**
- PROJECT.md already defers custom-domain purchase past M1.1 launch — keep it that way. Do not attach a custom domain in the same window as the launch date; do it in a later, non-critical-path change.
- If a custom domain is ever attached, do it with days of buffer before any hard deadline, and turn off any CDN/proxy (Cloudflare orange-cloud) on the DNS records during provisioning.

**Warning signs:**
- A custom domain purchase/attachment task appears on the M1.1 launch checklist itself.

**Phase to address:**
Explicitly out of scope for the launch phase per PROJECT.md — flag this pitfall so a future phase (post-M1.1 domain attach) doesn't get scheduled adjacent to another hard deadline.

---

### Pitfall 5: Silent build/deploy failures serve a stale site

**What goes wrong:**
A GitHub Actions Pages deploy reports green/success, but the live site still serves an old build — new posts, fixed links, or the launch post itself don't actually go live even though CI looks fine. Because the external promote pipeline (`draft-devblog` → `devlog/`) keeps landing new `.md` files into this repo on its own schedule, a broken build here can go unnoticed for a while since nobody is watching the site daily.

**Why it happens:**
Reported failure modes include deploys that "succeed" in the Actions log but the Pages origin never promotes the new artifact (stale content served), Pages settings pointing at the wrong branch/folder after repo changes, and hard limits (individual files > 100MB or repo > 1GB) silently blocking a build [MEDIUM confidence, cross-checked across GitHub Community discussions]. This project's specific risk: the promote pipeline writes Markdown into `devlog/` from an external flow (studio vault), so a malformed frontmatter field or unexpected filename in a future post can break the build without anyone editing this repo directly.

**How to avoid:**
- Build must fail loudly, not degrade gracefully: configure the SSG so malformed frontmatter/broken Markdown throws a non-zero exit in CI rather than being skipped or silently rendering blank.
- Add a minimal post-deploy check (e.g., a GitHub Actions step that curls the live URL and greps for the latest post's slug, or checks the deployed `<meta generator>`/build timestamp) so a "successful" deploy that actually served stale content is caught the same run.
- Since maintenance must stay near-zero after launch, prefer a single GitHub Actions workflow with minimal moving parts (checkout → build → `actions/deploy-pages`) over a custom multi-job pipeline — fewer places for silent breakage.

**Warning signs:**
- No post-deploy verification step exists; "green checkmark" is the only signal trusted.
- A new devblog post has landed in `devlog/` via the promote pipeline but nobody manually confirmed it rendered on the live site.

**Phase to address:**
Deployment/CI phase — build the fail-loud + post-deploy-check pattern in from the start, since this is exactly the kind of issue that surfaces only after the team has stopped actively watching the site (which is the intended near-zero-maintenance steady state).

---

### Pitfall 6: Dead links from Discord announcements after slug/URL changes

**What goes wrong:**
A devblog post's slug gets tweaked after Discord has already announced it (typo fix, renamed for consistency, category reorganization) — the pinned Discord message and #devlog history now 404. Because Discord carries the "opening + link" per PROJECT.md's launch flow, every post has exactly one durable external pointer, and that pointer breaks silently (nobody re-checks old Discord links).

**Why it happens:**
Static sites have no automatic redirect layer like WordPress does — GitHub Pages serves files as-is with no server-side redirect capability, so a renamed file is just a 404 for the old path unless something explicit handles it. The general best practice (301 redirect old → new) applies but needs a static-site-specific implementation, since GitHub Pages can't do server redirects [MEDIUM confidence, generalized from redirect-strategy sources + known GitHub Pages static-hosting constraint].

**How to avoid:**
- Treat post slugs as permanent once a post is promoted/published — bake this into the promote pipeline norms (studio-side), not just the website repo.
- If a slug must change, generate a static redirect stub at the old path: a minimal HTML file with `<meta http-equiv="refresh">` + a `rel=canonical` to the new URL (works with zero server config on GitHub Pages), or use the SSG's redirect plugin if one exists for the chosen generator (e.g., `jekyll-redirect-from`) rather than just deleting the old file.
- Custom `404.html` should still be useful (links back to the archive/home) as a fallback for any link that does break, since it can't be prevented 100%.

**Warning signs:**
- A post is renamed/moved in the repo and the old path is simply deleted with no stub left behind.
- No `404.html` exists, or it's the GitHub-default blank 404.

**Phase to address:**
Content/templating phase — decide the slug-immutability norm and build the redirect-stub mechanism before the first post beyond the manifesto goes live, so it's a non-event when (not if) a future rename happens.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|-----------------|
| Hand-copy devblog `.md` into the site repo instead of wiring the promote pipeline output directly | Faster to ship first archive | Drift between studio vault source-of-truth and rendered site; double-maintenance | Never past initial scaffolding — PROJECT.md already treats `devlog/` promote pipeline as the ongoing content path |
| Skip RSS/OG validation, "it renders fine in browser" | Saves 15-30 min before launch | Silent broken previews discovered only when someone reports Discord unfurl looking wrong, post-launch | Never — it's a 10-minute pre-launch checklist item, not a deferred task |
| No post-deploy smoke check, trust the green CI checkmark | Simpler workflow file | Stale-content deploys go unnoticed for however long nobody manually checks the live site (matches this project's low-attention steady state) | Only if a human is committed to manually spot-checking every deploy — not compatible with the "near-zero maintenance" goal here |
| Ship without a custom `404.html` | One less file at launch | Broken links (renames, external references) dead-end with a generic GitHub 404, no path back to the archive | Acceptable for the very first launch commit only if added within the same phase before announcing broadly |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|-------------------|
| GitHub Pages (deploy) | Pointing Pages settings at the wrong branch/folder after switching from the classic "deploy from branch" to Actions-based deploy, or vice-versa | Pick one deploy mode (GitHub Actions `actions/deploy-pages` is the modern default) and don't leave stale legacy Pages settings pointing elsewhere |
| Custom domain (future) | Attaching domain + enabling HTTPS in the same window as a hard deadline; leaving Cloudflare proxy ("orange cloud") on during provisioning | Attach with days of buffer, DNS-only during provisioning, verify both root and `www` get certs if both are used |
| RSS readers | Relative URLs in feed items; missing `guid`/stable `id` per item (causes duplicate entries in readers on any content change) | Absolute URLs throughout; stable, content-independent `guid` per post (e.g., derived from slug, not title text) |
| Discord unfurl | Assuming OG tags "will just work" without ever testing an actual Discord embed of a real deployed URL | Manually paste the real post URL into a Discord message (private test channel) before the first public announcement |
| Analytics (GoatCounter/Plausible) | Self-hosting Plausible for a project explicitly meant to need near-zero ongoing ops | Prefer GoatCounter (hosted free tier works directly on `*.github.io` domains with a single script tag, no server to maintain) over self-hosted Plausible for this project's zero-ops constraint [MEDIUM confidence] |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Unoptimized devblog images (engine capture screenshots, cinematics stills) served at full resolution | Slow page loads, especially on the archive/index page rendering many post thumbnails | Resize/compress images at content-ingest time (before or during build), not manually per-post | Noticeable once more than ~10-15 posts have full-res hero images on one archive page |
| Full-text search or client-side JS framework added "for later" before it's needed | Slower initial load, more JS to maintain for a ~10-post site | Skip search entirely until archive size actually warrants it (SSG's own tag/category pages are enough at this scale) | Not a concern at this project's scale (single-digit to low-double-digit post count through M1.1 era) |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Analytics script sourced from a third-party CDN without SRI/pinning | Supply-chain risk if the analytics vendor's script is compromised | Self-host the analytics snippet file in the repo (GoatCounter supports this) rather than pointing at a live third-party script URL where feasible |
| Embedding raw user-controlled content (e.g., future comments/Discord embeds) without sanitization | XSS if any future feature ever accepts external input | Not applicable at launch — PROJECT.md explicitly excludes comments/accounts/backend; flag if that scope ever changes |
| GitHub Actions workflow with overly broad `permissions` (default `write-all` inherited) | A compromised action/dependency in the build step gets broad repo write access | Scope the Pages deploy workflow to minimal permissions (`contents: read`, `pages: write`, `id-token: write` only) |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Devblog archive with no visible chronological/milestone ordering | Reader can't tell what order M0.1→M0.8 posts go, loses the "watch it get built" narrative arc | Archive index sorted newest-first (standard) but with clear milestone labels so the progression is legible at a glance |
| Discord CTA buried below the fold or styled as a footer link | Misses the Discord-first audience-building goal (D-F) — PROJECT.md calls this out as a "prominent" requirement | Persistent, visually prominent CTA (header or sticky element), not a footnote |
| RSS feed exists but isn't discoverable (no `<link rel="alternate">` autodiscovery, no visible RSS icon) | Readers who want RSS can't find it without viewing source | Standard `<link rel="alternate" type="application/rss+xml">` in every page's `<head>` plus a visible link somewhere on the site |

## "Looks Done But Isn't" Checklist

- [ ] **RSS feed:** Often missing absolute URLs and a stable per-item `guid` — verify by validating the feed URL against a feed validator, not just "it loads in browser."
- [ ] **OpenGraph tags:** Often only set on the homepage/base layout, not per-post — verify by checking the rendered `<head>` of an actual post page (not the index) for post-specific `og:title`/`og:image`.
- [ ] **Custom domain readiness:** Often assumes the config just needs a domain string swapped — verify no template hardcodes `github.io` and that root-relative paths are used throughout.
- [ ] **Deploy pipeline:** Often "green checkmark = done" — verify a post-deploy check actually confirms the live site content changed, not just that the build step exited 0.
- [ ] **404 handling:** Often skipped entirely (GitHub default blank 404) — verify a custom `404.html` exists and links back to the archive.
- [ ] **Discord unfurl:** Often untested until the real launch announcement — verify by pasting an actual post URL into a private Discord test message before the public launch post.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|-----------------|
| Broken RSS/OG at launch | LOW | Fix the template, redeploy, manually re-paste the launch link in Discord if the original embed was already broken and cached |
| Baseurl hardcoded, custom domain migration breaks links | MEDIUM | Grep templates for hardcoded `github.io` strings, replace with config variable, rebuild, spot-check internal links + RSS + OG `og:url` |
| Stuck TLS certificate provisioning | LOW (time cost, not effort) | Remove and re-add the custom domain in Pages settings to force a fresh cert request; ensure DNS is not proxied |
| Silent stale deploy | LOW–MEDIUM | Re-push a trivial commit to force a fresh Actions run; check Pages settings still point at the correct branch/action; add the missing post-deploy check going forward |
| Dead link from a renamed slug | LOW | Add a static redirect-stub HTML file at the old path pointing to the new one; update the custom 404 page if not already helpful |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|---------------|
| Site becomes a time sink | Stack-selection/scaffolding | SSG choice minimizes config surface; "done" checklist defined before build starts |
| Broken RSS/OG at launch | Templating phase + launch gate | Feed validator run; real Discord embed test before public announcement |
| Baseurl/custom-domain rework | Stack-selection/scaffolding | No hardcoded `github.io` strings in templates; single config source for URL |
| HTTPS/DNS provisioning stalls | Explicitly deferred past launch (PROJECT.md) | Custom domain attach scheduled with buffer, never adjacent to a hard deadline |
| Silent stale deploy | Deployment/CI phase | Post-deploy check step exists and is part of the workflow, not manual-only |
| Dead links from slug changes | Content/templating phase | Redirect-stub mechanism exists and custom 404 page is functional before first post beyond the manifesto ships |

## Sources

- [Trying to add a custom domain in GitHub Pages but it doesn't work — Hugo Discourse](https://discourse.gohugo.io/t/trying-to-add-a-custom-domain-in-github-pages-but-it-doesnt-work/46642)
- [Setting up custom domain for a GitHub Pages with Jekyll site — Medium](https://zilhaz.medium.com/setting-up-custom-domain-for-a-github-pages-with-jekyll-site-in-the-right-way-ca2e9db83981)
- [Deploying to GitHub, then Custom Domain; what baseurl? — Hugo Discourse](https://discourse.gohugo.io/t/deploying-to-github-then-custom-domain-what-baseurl/9638)
- [Open Graph Meta Tags: What They Are, Why They Matter, How to Set Them Up — Rich Dev Tools](https://richdevtools.com/articles/web/open-graph-meta-tags-guide)
- [Open Graph Meta Tags on Hugo and WordPress Blogs — Burgeon Lab](https://burgeonlab.com/blog/hugo-and-wordpress-open-graph-meta-tags/)
- [Astro vs Eleventy vs Hugo vs Jekyll vs Gatsby in 2026](https://gautamkhorana.com/blog/static-site-generators-2026-astro-eleventy-hugo-jekyll-gatsby/)
- [Best Static Site Generators 2026: Astro, Next.js, Hugo & More](https://thesoftwarescout.com/best-static-site-generators-2026-astro-next-js-hugo-more/)
- [Why I Chose GoatCounter Analytics for my GitHub Pages Site — DEV Community](https://dev.to/iam_pbk/why-i-chose-goatcounter-for-my-github-pages-site-7k8)
- [GoatCounter GitHub repository](https://github.com/arp242/goatcounter)
- [Plausible Analytics GitHub repository](https://github.com/plausible/analytics)
- [Securing your GitHub Pages site with HTTPS — GitHub Docs (official)](https://docs.github.com/en/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https)
- [TLS certificate is being provisioned (stuck) — GitHub Community Discussion #140606](https://github.com/orgs/community/discussions/140606)
- [Custom domain HTTPS not available on GitHub Pages even after DNS check successful — GitHub Community Discussion #184514](https://github.com/orgs/community/discussions/184514)
- [GitHub Pages deployment created successfully but immediately fails — GitHub Community Discussion #200884](https://github.com/orgs/community/discussions/200884)
- [Github deployment fails silently — Simply-Static Issue #65](https://github.com/Simply-Static/simply-static/issues/65)
- [How To Change Post URL of Already Published Post Without Losing Traffic — ShoutMeLoud](https://www.shoutmeloud.com/change-post-url-already-published-post.html)
- [5 Time Management Tips for Indie Developers — Medium](https://medium.com/@atnoforgamedev/5-time-management-tips-for-indie-developers-%EF%B8%8F-468d3e0f6789)

---
*Pitfalls research for: indie-game devblog/marketing static website (GitHub Pages)*
*Researched: 2026-07-13*

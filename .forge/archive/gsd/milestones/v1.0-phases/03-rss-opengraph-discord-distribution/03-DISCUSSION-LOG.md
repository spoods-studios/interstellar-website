# Phase 3: RSS, OpenGraph & Discord Distribution - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-22
**Phase:** 3-RSS, OpenGraph & Discord Distribution
**Areas discussed:** RSS feed scope & depth, OpenGraph image strategy, Embed description source, Discord CTA + invite URL

---

## RSS feed scope & depth

### Feed scope

| Option | Description | Selected |
|--------|-------------|----------|
| Announcements only | One feed at `/rss.xml` from the same 9-post devlog query as the homepage archive; matches DIST-01's wording literally, D-31's separate collections make drift structurally impossible | ✓ |
| Two feeds | `/rss.xml` for announcements + `/technical/rss.xml` for the 55 deep-dives; serves the engineering audience, but the retroactive backfill would land all at once dated Jul 2026 | |
| One combined feed | All 64 documents in a single feed; contradicts D-13's reasoning and merges two collections Phase 2 deliberately kept apart | |

**User's choice:** Announcements only
**Notes:** → D-45. Technical feed captured as a deferred idea for M1.1+, when deep-dives land incrementally with real dates.

### Feed item depth

| Option | Description | Selected |
|--------|-------------|----------|
| Full rendered HTML | Whole post body in `<content:encoded>`, sanitized per Astro's RSS docs; readers get the full long-form essay offline | ✓ |
| Excerpt + link | First paragraph then "read the rest on the site"; drives clicks but makes the feed a teaser | |
| Title + date + link only | Minimal notification feed, zero sanitization surface, thinnest reader experience | |

**User's choice:** Full rendered HTML
**Notes:** → D-46. Surfaced during write-up: M0.7/M0.8 bodies carry relative image paths (`../assets/…`) that break in feed readers — absolute-URL rewriting recorded as a required behavior, not discretion.

### Feed discoverability

| Option | Description | Selected |
|--------|-------------|----------|
| Head autodiscovery + footer link | `<link rel="alternate">` in BaseLayout head + the visible footer RSS link D-18 reserved | ✓ |
| Head autodiscovery only | Detected by readers, invisible to humans browsing the site | |
| Head + footer + archive callout | Adds a "Subscribe by RSS" line on the homepage; most discoverable, louder than the content-first philosophy | |

**User's choice:** Head autodiscovery + footer link
**Notes:** → D-47.

---

## OpenGraph image strategy

Flagged in STATE.md as Phase 3's open blocker ("static per-post asset vs. build-time banner, within the D-G no-generative-imagery constraint").

### Image source

| Option | Description | Selected |
|--------|-------------|----------|
| Per-post hero + site default | M0.7/M0.8 use their real engine-output PNGs; everything else falls back to one hand-made card; D-K-clean, no new dependency, future heroes picked up automatically | ✓ |
| One static image everywhere | Single site-wide card on all pages; simplest, but every Discord paste looks identical | |
| Build-time generated banner | Distinct text card per post; needs satori/resvg/sharp — a rendering dependency against a no-dependency, no-client-JS project | |
| No OG image | Title + description only; contradicts DIST-02's "title, description, and image" criterion | |

**User's choice:** Per-post hero + site default
**Notes:** → D-48. Discovered during scouting: `hero_visual` is unreliable as the detection source — M0.5/M0.6 carry prose descriptions with no file behind them, M0.7/M0.8 carry `path — description`. Detection mechanism left to Claude's discretion with a mandatory loud-fail on unresolvable paths.

### Default card content

| Option | Description | Selected |
|--------|-------------|----------|
| Hand-authored wordmark card | "Interstellar Engine" in the site's own type on its near-white background + favicon glyph; authored as SVG in-repo, D-G-clean, produced in-phase | ✓ |
| Reuse an existing engine capture | `assets/m0.8-hero-precession.png` as the site default; zero new assets, but a milestone plot standing in for the whole site reads oddly | |
| Fresh engine screenshot from the developer | Strongest brand image, most honest to D-K; blocks the phase and puts site work on the engine milestone clock | |

**User's choice:** Hand-authored wordmark card
**Notes:** → D-49.

### OG scope

| Option | Description | Selected |
|--------|-------------|----------|
| Every page | All ~75 generated pages including the 55 deep-dives; DIST-02 says "every post and page", and deep-dive links are what get pasted in #technical-devlog | ✓ |
| Announcements + standalone pages only | Full OG on 11 pages, title-only defaults elsewhere; less markup, weaker embeds where engineering conversation happens | |

**User's choice:** Every page
**Notes:** → D-50.

---

## Embed description source

Constraint surfaced before the question: `devlog/`, `technical/`, `roadmap/`, and `pages/` are read-only promote drop targets (CLAUDE.md), so adding a `description:` frontmatter field to posts was never an available option.

### Announcement descriptions

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-extract first paragraph | First real prose paragraph, skipping H1 and hero image, truncated; derived so it cannot rot, needs no edits to read-only trees | ✓ |
| Site-side description map | Hand-written slug→description table in `src/lib/`; full control, but a second source of truth that goes stale silently for new posts | |
| Site tagline everywhere | Same one-line project description on every page; zero drift, but defeats most of the embed's value | |

**User's choice:** Auto-extract first paragraph
**Notes:** → D-51. One extracted value feeds `<meta name="description">`, OG/Twitter description, and the RSS item description.

### Technical deep-dive descriptions

| Option | Description | Selected |
|--------|-------------|----------|
| First paragraph after the blockquote | Skip the boilerplate `> Retroactive technical devlog…` preamble common to all 55, use the first real paragraph | ✓ |
| Derived structural line | Synthesize from the path ("M0.1 Phase 1 — Window + Surface · technical deep-dive"); never wrong, says nothing the title doesn't | |
| Use the blockquote as-is | One extraction rule for all four trees, but all 55 embeds carry identical text | |

**User's choice:** First paragraph after the blockquote
**Notes:** → D-51.

### Truncation

| Option | Description | Selected |
|--------|-------------|----------|
| ~160 chars, sentence boundary | Fits what Discord and search engines display without visible clipping; reads as a finished thought | ✓ |
| ~300 chars, word boundary | Richer preview in Discord, clipped in search results and some clients | |
| Whole first paragraph, no cap | Never truncates mid-thought, but the client clips it at an arbitrary point instead | |

**User's choice:** ~160 chars, sentence boundary
**Notes:** → D-52.

---

## Discord CTA + invite URL

### CTA placement

| Option | Description | Selected |
|--------|-------------|----------|
| Header slot + footer | The D-17 reserved nav slot plus a footer line beside RSS; satisfies "prominent on every page" with one shared layout change | ✓ |
| Header slot only | Quietest, but reads as just another nav item | |
| Header + end-of-post block | Catches readers when they finish, but adds chrome below every post next to D-15's prev/next nav | |
| Footer only | Least intrusive, weakest against DIST-03's "prominent" | |

**User's choice:** Header slot + footer
**Notes:** → D-53. End-of-post block captured as a deferred idea, revisitable once Phase 4 analytics exist.

### CTA form

| Option | Description | Selected |
|--------|-------------|----------|
| Plain text link, accent-colored | No new visual language, no icon asset, consistent with D-21/D-22/D-23 and PRD §21.1's quiet register | ✓ |
| Small styled pill/button | Unmistakably an action, but would be the site's first button styling | |
| Short sentence with link | Warmest and most in-voice, but too long for the header — forces footer/end-of-post placement | |

**User's choice:** Plain text link, accent-colored
**Notes:** → D-53. Button styling deferred to a future visual-polish milestone.

### Invite URL handling

Context given: `studio/vault/community/Discord Architecture.md:9` still reads `**Invite link:** (add when created)` — the permanent invite is recorded nowhere on disk and is an open Phase 0 Launch Checklist item.

| Option | Description | Selected |
|--------|-------------|----------|
| Placeholder that fails the build | One config constant; build hard-fails naming it while unset, same loud-fail culture as D-10/D-33/D-39; no possibility of shipping a dead CTA | ✓ |
| Developer pastes the link now | Baked in immediately, execution never blocks | |
| Omit CTA when unset | Never blocks a build, but fails silently — the exact failure mode this project designs against | |

**User's choice:** Placeholder that fails the build
**Notes:** → D-54.

### Vault sync

| Option | Description | Selected |
|--------|-------------|----------|
| Update the studio vault too | Fill in `Discord Architecture.md` and `Handles Secured.md`, closing an open Phase 0 Launch Checklist item; cross-repo precedent in D-25 | ✓ |
| Website repo only | Vault stays stale, checklist item stays open | |

**User's choice:** Update the studio vault too
**Notes:** → D-56.

---

## Follow-up: invite URL sequencing

Raised after the area closed: a build that hard-fails on an unset invite URL means Phase 3 cannot execute to green until a real link exists.

| Option | Description | Selected |
|--------|-------------|----------|
| Checkpoint task during execution | Plan carries a task that stops and asks for the URL before anything depends on it | |
| Developer pastes it now | Locked into CONTEXT.md immediately | |
| Front-load an invite-creation task | Plan specifies exactly what to create (permanent, no expiry, unlimited uses) before dependent work | |

**User's choice:** *Other* — "use playwright to create it then bake it in."
**Notes:** → D-55. Attempted in-session via the headed Playwright browser; `https://discord.com/channels/@me` redirected to the login screen. Discord login is a user-only interactive step (credentials + 2FA), so the URL remains the single open slot in CONTEXT.md. Planner instructed to front-load a `checkpoint:decision` task if the URL is still absent at planning time.

---

## Claude's Discretion

- `@astrojs/rss` vs. hand-rolled XML endpoint; `sanitize-html` configuration
- Hero-image detection mechanism (body's first image vs. parsing `hero_visual`'s leading path), subject to the mandatory loud-fail
- OG card composition and pixel dimensions beyond ≥1200×630; `twitter:card` type; whether to emit `og:type`, `article:published_time`, `og:site_name`
- Where the invite constant lives and how its loud-fail is wired (config-load-time vs. layout-level throw)
- Whether the 404 page carries feed/CTA/OG treatment
- Feed item cap, and feed channel `<title>`/`<description>`/`<language>` wording

## Deferred Ideas

- Second feed for the technical series (`/technical/rss.xml`) — revisit at M1.1+
- End-of-post "discuss this on Discord" block
- Styled CTA button/pill — future visual-polish milestone
- Hand-written per-page descriptions (rejected as a second source of truth)
- `hero_visual` prose descriptions on M0.5/M0.6 — no image file was ever produced
- CONT-06 slug-immutability / redirect stubs across three URL trees — Phase 4
- Analytics on outbound Discord CTA clicks — poor fit with cookieless ANLT-01

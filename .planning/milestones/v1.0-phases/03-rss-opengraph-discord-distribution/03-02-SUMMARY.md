---
phase: 03-rss-opengraph-discord-distribution
plan: 02
subsystem: ui
tags: [astro, rss, feed, container-api, sanitize-html, discovery]

requires:
  - phase: 03-rss-opengraph-discord-distribution
    plan: 01
    provides: "site.mjs feed copy constants (FEED_TITLE/FEED_DESCRIPTION/FEED_LANGUAGE), describeBody, sortEntriesNewestFirst, @astrojs/rss + sanitize-html at exact pins, BaseLayout <head> block and footer separator structure"
  - phase: 02-content-rendering
    provides: "content-guards (assertNonEmpty/isVisible), devlog-meta (entryDate/entryTitle), the 86-page build and the tests/*.smoke.sh harness"
provides:
  - "src/pages/rss.xml.ts — build-time APIRoute exporting GET, building to dist/rss.xml as RSS 2.0 with full site-identical post HTML in content:encoded"
  - "Container-API feed-content pattern (AstroContainer.create() + render(entry) + renderToString) — the only rendering path that carries this repo's mdast plugins and resolved image URLs into the feed"
  - "absolutize() — sanitize + D-46 absolute-URL rewrite + loud-fail, colocated in the endpoint"
  - "Feed autodiscovery (<link rel=alternate application/rss+xml>) on all 86 built pages"
  - "Visible footer RSS link, ordered copyright · RSS · Join the Discord"
affects: [03-05 distribution smoke tests, 03-06 studio vault sync]

tech-stack:
  added: []
  patterns:
    - "Build-time endpoint reuses the archive's collection query by importing the shared guard (isVisible) and the shared comparator (sortEntriesNewestFirst) rather than restating either — DIST-01's anti-drift core"
    - "Container API (experimental_AstroContainer from astro/container, bundled in astro@7.0.9) as the feed's rendering path — never a second Markdown parser, never the entry's pre-rendered HTML field"
    - "sanitize-html transformTags does double duty: sanitization allow-list AND the D-46 absolute-URL rewrite AND the loud-fail, in one pass"
    - "Channel `site` passed WITH the base so item links stay short relatives and the channel <link> is base-inclusive — no host or base literal under src/"

key-files:
  created:
    - src/pages/rss.xml.ts
  modified:
    - src/layouts/BaseLayout.astro

key-decisions:
  - "@astrojs/rss@4.0.19 serializes item `content` as XML-escaped markup (`&lt;img src=&quot;…&quot;&gt;`), not the CDATA block 03-RESEARCH's sample output showed. Semantically equivalent for consumers and xmllint-clean; every acceptance grep written with `[^\"]*` still matched because the escaped form contains no literal quote. Plan 03-05 must write its permanent feed assertions against the escaped form (`src=&quot;https://…`), not against CDATA."
  - "The `a`/`href` branch of absolutize() is present and correct but unexercised by the current corpus: all 9 devlog bodies contain zero anchors (`&lt;a ` count in dist/rss.xml is 0). Every link on an announcement page — deep-dive list, prev/next, breadcrumbs — is route chrome emitted by [slug].astro, not body content. The branch is defence for the first body-authored link, not dead code."
  - "No sitemap assertion was added for /rss.xml. @astrojs/sitemap excludes endpoint routes by design, so sitemap URLs stayed at 85 against 85 non-404 pages and tests/site.smoke.sh's count assertion passed untouched. This is correct behaviour, not a gap."

requirements-completed: [DIST-01]

coverage:
  - id: D1
    description: "/rss.xml builds to a well-formed RSS 2.0 document"
    requirement: DIST-01
    verification:
      - kind: integration
        ref: "npm run build exits 0; dist/rss.xml exists (60,156 bytes); xmllint --noout dist/rss.xml exits 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "The feed cannot drift from the homepage archive — same query, same visibility guard, same comparator"
    requirement: DIST-01
    verification:
      - kind: integration
        ref: "9 <item> elements == 9 devlog hrefs in dist/index.html; endpoint imports isVisible from content-guards and sortEntriesNewestFirst from devlog-meta, restating neither"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every guid is unique and every link/guid is prefixed by the config-derived site+base, never a literal"
    requirement: DIST-01
    verification:
      - kind: integration
        ref: "9 <guid> == 9 distinct values == 9 <item>; zero <link> and zero <guid> values fail the site+base prefix derived from astro.config.mjs; `! grep -rIn -e 'github\\.io' -e '/interstellar-website' src/` still green in tests/technical.smoke.sh and tests/post.smoke.sh"
        status: pass
    human_judgment: false
  - id: D4
    description: "Feed content is site-identical HTML with absolute image URLs — no second parser, no unresolved placeholder, no wikilink literal"
    requirement: DIST-01
    verification:
      - kind: integration
        ref: "2 _astro/*.webp URLs in dist/rss.xml, both absolute (src=&quot;https://spoods-studios.github.io/interstellar-website/_astro/…); grep -cF '__ASTRO_IMAGE_' = 0; grep -cF '[[' = 0; grep -c 'markdown-it' package.json = 0; no `.rendered` property access in the endpoint; zero srcset attributes"
        status: pass
    human_judgment: false
  - id: D5
    description: "Publication dates are RFC-822 and the channel carries language plus a self-referencing atom link (D-57)"
    requirement: DIST-01
    verification:
      - kind: integration
        ref: "0 of 9 <pubDate> values fail ^[A-Z][a-z]{2}, [0-9]{2} [A-Z][a-z]{2} [0-9]{4}; <atom:link href=…/rss.xml rel=\"self\" type=\"application/rss+xml\"/> present; <language>en</language> present; xmlns:content declared exactly once (added automatically by the package)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Feed discovery is present on every page in both the machine-readable and the visible slot"
    requirement: DIST-01
    verification:
      - kind: integration
        ref: "86 of 86 built pages carry type=\"application/rss+xml\", exactly one each (per-file loop, zero BAD lines); dist/index.html has exactly 2 rss.xml references; footer order is copyright → RSS → discord.gg; git diff --exit-code src/styles/global.css succeeds"
        status: pass
    human_judgment: false
  - id: D7
    description: "A feed-content URL that cannot be absolutized fails the build naming the entry"
    requirement: DIST-01
    verification:
      - kind: unit
        ref: "absolutize()'s else-branch throws `${entryId}: feed content ${attr}=\"${value}\" could not be rewritten to an absolute URL` — code path read and reviewed, not fixture-exercised (no corpus entry produces an unrewritable URL)"
        status: partial
    human_judgment: false
  - id: D8
    description: "The feed renders correctly in a real feed reader"
    requirement: DIST-01
    verification: []
    human_judgment: true
    rationale: "xmllint proves well-formedness, not RSS 2.0 semantics or reader rendering. 03-RESEARCH Open Question 1 is explicit that no viable offline semantics validator exists; the W3C validator needs the deployed URL. Owned by Plan 03-06's post-deploy checks."

duration: 13min
completed: 2026-07-22
status: complete
---

# Phase 3 Plan 02: RSS Feed and Feed Discovery Summary

**`/rss.xml` now carries all 9 visible devblog announcements with their full, byte-identical post HTML rendered through the site's own pipeline via the Container API, and all 86 pages autodiscover it.**

## Performance

- **Duration:** ~13 min
- **Tasks:** 2/2 (both `type="auto"`, no checkpoints)
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- **The feed structurally cannot drift from the archive.** The endpoint imports `isVisible` from `content-guards` and `sortEntriesNewestFirst` from `devlog-meta` rather than restating either predicate — the exact DIST-01 requirement. Item count (9) equals the homepage's devlog link count (9), and that equality is now a per-task gate.
- **All four documented traps were avoided and each is asserted, not assumed.** No `markdown-it` in `package.json`; no `.rendered` property access in the endpoint; zero `__ASTRO_IMAGE_` placeholders and zero `[[` wikilink literals in `dist/rss.xml`. Each of these would have exited 0 while shipping broken output.
- **Both hero images survive into the feed as absolute URLs** — `https://spoods-studios.github.io/interstellar-website/_astro/*.webp`, rewritten by `transformTags`. No root-relative `src` and no `srcset` attribute escaped.
- **Zero host or base literals under `src/`.** The pre-existing `! grep -rIn -e 'github\.io' -e '/interstellar-website' src/` guard (T-02-07) stays green with the endpoint in place; every URL composes from `context.site` and `import.meta.env.BASE_URL`.
- **D-57 pre-empted.** `<atom:link rel="self">` and `<language>en</language>` ship from the start — the one recommendation the W3C validator predictably raises.
- **86 of 86 pages carry exactly one autodiscovery link**, and the footer reads `© 2026 Spoods Studios · RSS · Join the Discord` with both U+00B7 separators intact as valid UTF-8. Zero new CSS.
- **`npm test` green** with `ALL CHECKS PASSED`, including the unchanged 86-page and 85-URL sitemap assertions, the zero-client-JS sweep, and the dead-link sweep — which now resolves the new footer href against `dist/rss.xml` and passes.

## Task Commits

1. **Task 1: The /rss.xml build-time endpoint** — `91f9a2e` (feat)
2. **Task 2: Feed discovery in the shared head and the footer** — `127f688` (feat)

## TDD Gate Compliance

Not applicable to this plan. Neither task carries `tdd="true"` or a `<behavior>` block, so the MVP+TDD behaviour-adding predicate returns false for both and the gate does not fire. This is deliberate on the plan's part: its § Artifacts section states *"New test files: none in this plan; the permanent feed assertions land in `tests/distribution.smoke.sh` (Plan 03-05). The acceptance criteria above are the per-task gate."* Every acceptance criterion was executed against the real build before each commit. No test framework was introduced.

## Files Created/Modified

**Created**
- `src/pages/rss.xml.ts` (99 lines) — `GET: APIRoute`. Query → Container render → `absolutize()` (sanitize + rewrite + loud-fail) → `getRssString()`. WHY-comments name D-45, D-46, D-57 and the two rejected rendering paths.

**Modified**
- `src/layouts/BaseLayout.astro` (+9/−4) — imports `FEED_TITLE`; adds the `rel="alternate"` link between the canonical and icon links; replaces the Plan 03-01 placeholder comment with the three-part footer line.

## Decisions Made

The plan's locked decisions were followed as written. Three implementation facts worth carrying forward are recorded in `key-decisions` above: the escaped-markup (not CDATA) serialization of `content:encoded`, the unexercised `a`/`href` transformer branch, and the deliberate absence of a sitemap assertion for the endpoint route.

## Deviations from Plan

None — both tasks executed exactly as written. No deviation rule fired.

### Notes recorded, not acted on

- **Two acceptance-criterion expressions are written in a form this machine's `grep -P` cannot evaluate**, though the underlying facts hold:
  - `grep -qP '<footer>.*\xc2\xb7.*\xc2\xb7.*</footer>'` returns no match because GNU `grep -P` interprets `\xc2` as **codepoint** U+00C2 in UTF-8 mode, not as a raw byte, and `LC_ALL=C` does not change this. The substance was verified three independent ways: `hexdump -C` of the built footer shows `c2 b7` twice (and `c2 a9` for the copyright sign), `grep -o '·' | wc -l` returns 2, and `grep -cP '<footer>.*\x{b7}.*\x{b7}.*</footer>'` returns 1. **Plan 03-05 should write this assertion with `\x{b7}` or a literal `·`, not `\xc2\xb7`**, or it will fail spuriously.
  - `grep -c 'Â' dist/index.html` returns 0 as required (no mojibake), and `file dist/index.html` reports `UTF-8 text` — both criteria pass as written.
- **The `content:encoded` serialization is escaped markup, not CDATA** (see `key-decisions`). Every acceptance grep in this plan passed regardless, because they were written with `[^"]*` classes that the escaped form satisfies. Plan 03-05's permanent assertions need the escaped form to avoid encoding a serializer detail that already differs from the research sample.

**Total deviations:** 0. **Impact on plan:** none.

## Issues Encountered

None. The pre-existing `astro` advisory (GHSA-4g3v-8h47-v7g6) logged by Plan 03-01 to `deferred-items.md` is unchanged by this plan and remains out of scope.

## Known Stubs

None. `absolutize()`'s `a`/`href` branch is unexercised by the current corpus but is real, reviewed code with a real throw — coverage absence, not a stub. It is recorded in `key-decisions` and in `coverage` D7 as `partial` so Plan 03-05 can decide whether a trap-and-restore fixture is warranted.

## Threat Flags

None. Every security-relevant surface this plan introduced is carried by the plan's own `<threat_model>`:

- **T-03-02** (feed-content XSS): allow-list is `sanitizeHtml.defaults.allowedTags.concat(['img'])` and nothing else. No `style`, `script`, `iframe`, `object`, `embed` or event-handler attribute was added.
- **T-03-04** (URL-rewrite spoofing): only `/`-prefixed values are rebased against `context.site`; `http(s):` and bare fragments pass through; everything else throws naming the entry.
- **T-03-06** (`customData` interpolation): the only interpolated values are `FEED_LANGUAGE` (a git-tracked constant) and `feedUrl` (composed by `new URL` from the config's own site and base). No content-derived value reaches `customData`.
- **T-03-07** (draft leak into the feed): the endpoint calls the shared `isVisible` guard, so a drafted post leaves the feed and the archive together. The permanent fixture is owned by Plan 03-05.

No new endpoint beyond the planned one, no auth path, no file-access pattern, no trust-boundary schema change.

## User Setup Required

None.

## Follow-up for Later Plans

- **03-05** — write the permanent feed assertions in `tests/distribution.smoke.sh` against the **escaped** `content:encoded` form (`src=&quot;https://…`), not CDATA; use `\x{b7}` or a literal `·` for the middot assertion; and do **not** add a sitemap assertion for `/rss.xml` (endpoint routes are correctly excluded, and the existing 85-URL count assertion must stay untouched). Optionally add a trap-and-restore fixture for `absolutize()`'s throw path, which no corpus entry currently reaches.
- **03-06** — RSS semantics beyond well-formedness need the deployed URL: run the W3C Feed Validator against `https://spoods-studios.github.io/interstellar-website/rss.xml` after deploy, and subscribe in one real reader to confirm the hero images load.

## Self-Check: PASSED

- `src/pages/rss.xml.ts` present on disk (99 lines); `src/layouts/BaseLayout.astro` modified (+9/−4).
- Both task commits verified in `git log`: `91f9a2e`, `127f688`.
- `npm run build` exits 0; `dist/rss.xml` exists; `xmllint --noout dist/rss.xml` exits 0.
- `npm test` exits 0 with `ALL CHECKS PASSED` as its final line.
- `git status --short` clean after the full test run; `git diff --exit-code src/styles/global.css` succeeds; no promote drop target (`devlog/`, `technical/`, `roadmap/`, `pages/`) was touched.
- `STATE.md` and `ROADMAP.md` untouched — the orchestrator owns those after the wave merges.

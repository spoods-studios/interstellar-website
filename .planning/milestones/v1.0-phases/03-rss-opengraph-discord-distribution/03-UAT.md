---
status: complete
phase: 03-rss-opengraph-discord-distribution
source: [03-01-SUMMARY.md, 03-02-SUMMARY.md, 03-03-SUMMARY.md, 03-04-SUMMARY.md, 03-05-SUMMARY.md]
started: 2026-08-09T12:32:29Z
updated: 2026-08-11T14:08:57Z
---

## Current Test

[testing complete]

## Tests

### 1. Full smoke suite green locally
expected: Run `npm test` in the repo root. It exits 0 and ends with `ALL CHECKS PASSED`, with `== running tests/distribution.smoke.sh ==` in the output.
result: pass

### 2. Default OG card looks right
expected: Open `public/og-default.png`. Typography renders in the site's sans-serif stack (no serif fallback), and the wordmark, glyph, accent rule and both tagline lines all sit inside the 96px safe inset — nothing clipped or crowding the edges.
result: pass

### 3. Discord rich embed on a devblog post
expected: Paste a deployed devblog post URL (one not pasted before — Discord won't re-scrape known URLs) into a Discord channel. A rich embed renders with the post title, a body-derived description, and a large image.
result: pass

### 4. Feed renders in a real feed reader
expected: Subscribe to the deployed `/rss.xml` in a real feed reader (e.g. Feedly, NetNewsWire, Thunderbird). All 9 posts appear newest-first with correct titles, dates, and full-content HTML including images.
result: pass

### 5. W3C feed validation on deployed rss.xml
expected: Submit the deployed `rss.xml` URL to validator.w3.org/feed. The feed validates as RSS 2.0 (warnings acceptable, errors are not).
result: pass

### 6. Technical pages share with their own description
expected: Paste a technical deep-dive URL into Discord (or inspect its og:description via view-source). The description is that page's own first real prose paragraph — not the site tagline, and not the shared "Retroactive technical devlog…" blockquote.
result: pass

### 7. Accept decided coverage gap — unabsolutizable feed URL loud-fail
expected: 03-02 coverage D7 is `partial` by decision — absolutize()'s a/href throw branch is code-reviewed but not fixture-exercised (no devlog body contains an anchor yet). 03-05 recorded the decision (no fixture; live negative gate in the smoke script arms itself the moment a post gains its first link). Confirm you accept this as decided, or report if you want it exercised now.
result: pass

### 8. [03-01 D1] npm deps at exact pins behind passed legitimacy gate
expected: Two new npm dependencies installed at exact pins behind a passed human package-legitimacy gate
result: pass
source: automated
coverage_id: D1

### 9. [03-01 D2] assertInviteConfigured() loud-fails on empty/placeholder invite
expected: assertInviteConfigured() fails the build at config-load time naming DISCORD_INVITE_URL when the invite is empty, whitespace-only, or the placeholder sentinel
result: pass
source: automated
coverage_id: D2

### 10. [03-01 D3] og-default.png committed 1200x630 alpha-free under 200 KB
expected: public/og-default.png is a committed 1200x630 alpha-free PNG under 200 KB with its editable SVG master
result: pass
source: automated
coverage_id: D3

### 11. [03-01 D5] describeBody extracts body-derived description, throws on no prose
expected: describeBody extracts a body-derived description (D-51 chrome-skipping, D-52 strict truncation, surrogate-safe) and throws naming the entry when a body yields no prose
result: pass
source: automated
coverage_id: D5

### 12. [03-01 D6] compareNewestFirst deterministic newest-first ordering
expected: compareNewestFirst orders newest-first with a deterministic id tie-break independent of input order
result: pass
source: automated
coverage_id: D6

### 13. [03-01 D7] Announcement route emits full OG/Twitter/theme-color block
expected: The announcement route emits the full OG/Twitter/theme-color block with absolute config-derived og:url and og:image, exactly one of each tag
result: pass
source: automated
coverage_id: D7

### 14. [03-01 D8] Discord CTA on all 86 pages, header nav + footer
expected: Every one of the 86 built pages carries the Discord CTA in header nav and footer, with rel=noopener noreferrer on both, and zero new CSS
result: pass
source: automated
coverage_id: D8

### 15. [03-02 D1] /rss.xml builds to well-formed RSS 2.0
expected: /rss.xml builds to a well-formed RSS 2.0 document
result: pass
source: automated
coverage_id: D1

### 16. [03-02 D2] Feed cannot drift from homepage archive
expected: The feed cannot drift from the homepage archive — same query, same visibility guard, same comparator
result: pass
source: automated
coverage_id: D2

### 17. [03-02 D3] Guids unique, links/guids config-derived site+base prefixed
expected: Every guid is unique and every link/guid is prefixed by the config-derived site+base, never a literal
result: pass
source: automated
coverage_id: D3

### 18. [03-02 D4] Feed content site-identical HTML, absolute image URLs
expected: Feed content is site-identical HTML with absolute image URLs — no second parser, no unresolved placeholder, no wikilink literal
result: pass
source: automated
coverage_id: D4

### 19. [03-02 D5] RFC-822 pubDates, language + atom self link
expected: Publication dates are RFC-822 and the channel carries language plus a self-referencing atom link (D-57)
result: pass
source: automated
coverage_id: D5

### 20. [03-02 D6] Feed discovery on every page, machine-readable + visible
expected: Feed discovery is present on every page in both the machine-readable and the visible slot
result: pass
source: automated
coverage_id: D6

### 21. [03-03 D1] heroBasename resolves final path segment
expected: heroBasename returns the final path segment for a ../assets/ reference, an assets/ reference, and a bare basename
result: pass
source: automated
coverage_id: D1

### 22. [03-03 D2] lookupHero null on absent, mapped record on hit
expected: lookupHero returns null on an absent reference (no body image -> default card) and the mapped record identically on a hit
result: pass
source: automated
coverage_id: D2

### 23. [03-03 D3] D-48 unresolvable body reference throws, never downgraded
expected: An unresolvable body reference throws naming both the post id and the offending path, and is never downgraded to no-image
result: pass
source: automated
coverage_id: D3

### 24. [03-03 D4] Vite-only glob confined to supplier module
expected: The Vite-only glob is confined to the supplier; the pure module has no import statement and no glob call site
result: pass
source: automated
coverage_id: D4

### 25. [03-03 D5] Hero announcements emit their own og:image with dimensions
expected: The two hero announcements emit exactly one og:image each, a PNG carrying their own plot, with dimensions from the same lookup
result: pass
source: automated
coverage_id: D5

### 26. [03-03 D6] Exactly three distinct og:image URLs site-wide, all resolving
expected: Exactly three distinct og:image URLs site-wide, every one absolute under site+base and resolving to a real file in dist/
result: pass
source: automated
coverage_id: D6

### 27. [03-03 D7] og:image:alt equals page title on hero posts
expected: og:image:alt on a hero post equals the page's own <title> text
result: pass
source: automated
coverage_id: D7

### 28. [03-03 D8] No regression — 86 pages, suite green, drop targets untouched
expected: No regression: 86 pages, full suite green, no promote drop target edited
result: pass
source: automated
coverage_id: D8

## Summary

total: 28
passed: 28
issues: 0
pending: 0
skipped: 0

## Notes

- 03-02-SUMMARY.md coverage block has a malformed entry: D7 `verification[0].status: partial` is
  not a valid status (pass/fail/unknown). Treated fail-safe as human checkpoint (Test 7).
  SUMMARY should be fixed to a valid status.
- 03-04 deviation (logged for phase review, not a test): `dist/technical/index.html` og:title
  ends with the site name — authored page-title literal at `src/pages/technical/index.astro:63`,
  not site-layer doubling.

## Gaps

[none yet]

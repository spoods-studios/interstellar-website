---
name: Interstellar Engine / Setare Aerospace
description: The game presented as the astrodynamics textbook it teaches.
colors:
  vellum: "#dfe6e1"
  vellum-deep: "#d3dcd6"
  ink: "#14233b"
  ink-soft: "#3b4d63"
  rule: "rgba(20,35,59,.18)"
  grid: "rgba(20,35,59,.07)"
  verm: "#d9481f"
  verm-ink: "#a8340f"
  verm-ink-hover: "#8f2b0b"
  plate: "#0d1626"
typography:
  display:
    fontFamily: "Archivo, sans-serif"
    fontSize: "clamp(2.6rem,6.2vw,5.6rem)"
    fontWeight: 850
    lineHeight: 0.92
    letterSpacing: "-.02em"
    fontVariation: "'wdth' 72"
  label:
    fontFamily: "Archivo, sans-serif"
    fontSize: "1.0625rem"
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: ".06em"
    fontVariation: "'wdth' 88"
  body:
    fontFamily: "'Source Serif 4', Georgia, serif"
    fontSize: "1.0625rem"
    fontWeight: 400
    lineHeight: 1.6
  equation:
    fontFamily: "'Source Serif 4', Georgia, serif"
    fontSize: "1.0625rem"
    fontWeight: 400
    lineHeight: 1.5
rounded:
  cta: "2px"
spacing:
  cell: "24px"
  column-gap: "24px"
  gut: "clamp(16px,4vw,56px)"
components:
  button-primary:
    backgroundColor: "{colors.verm-ink}"
    textColor: "#ffffff"
    typography: "{typography.label}"
    rounded: "{rounded.cta}"
    padding: "10px 18px"
  button-primary-hover:
    backgroundColor: "{colors.verm-ink-hover}"
  plate:
    backgroundColor: "{colors.plate}"
    padding: "10px"
  diagram:
    backgroundColor: "rgba(255,255,255,.35)"
    textColor: "{colors.ink}"
    padding: "16px"
  ghost:
    textColor: "{colors.ink-soft}"
    padding: "20px"
---

# Design System: Interstellar Engine / Setare Aerospace

Recorded from the built site as it shipped in phase 329 (showcase page),
measured against `dist/` on 2026-10-30. The tokens live in
`src/styles/global.css`; the showcase layout, motion hooks and media rules live
in `src/pages/index.astro`, `src/components/ShowcaseClip.astro`,
`src/scripts/showcase-motion.ts` and `src/scripts/clip-play.ts`.

## Overview

**Creative North Star: "The Astrodynamics Plate"**

The site presents the game as the textbook it teaches. Each feature is a
numbered figure plate set on a vellum page ruled with a quadrille. One inked
vermilion trajectory runs down the page through the side gutters. Captions,
margin notes and equations sit on the same grid as the plates, the way a
technical plate book lays them out. Every image and clip is a frame from the
current build, labelled with its capture date. Planned work is drawn as dashed
ghost outlines and marked as planned.

Density is low and the page reads top to bottom: a hero, four feature chapters,
the planned milestones and a Discord close. Ranking comes from weight, width
and case, not from extra type sizes. The palette is vellum and ink.
Vermilion is kept for the trajectory, the call to action and the few marks
that point at an action or a burn.

**Key Characteristics:**
- Two type sizes in total (`--s`, `--l`). Rank comes from weight, width and case.
- A 12-column grid laid over a 24 px quadrille drawn on the body.
- Figure plates with a dark matte, a 1 px ink frame and a numbered caption.
- One vermilion trajectory that draws with scroll. It is drawn in full and static under reduced motion and without JS.
- Engine captures only. Every still and clip caption carries its capture date.

## Colors

A cool, low-chroma vellum-and-ink palette with one hot accent. Ink at two
strengths does most of the work.

### Primary
- **Trajectory Vermilion** (`verm`): the trajectory stroke and its craft marker, the text-selection highlight, the 2 px focus outline, the burn arrow in the orbit diagram and the underline on the current nav item.
- **Inked Vermilion** (`verm-ink`): a darker vermilion that carries white text. It fills the CTA and colours the chapter numbers, the "In preparation" tags and the Δv label. It darkens to `verm-ink-hover` when the CTA is hovered.

### Neutral
- **Vellum** (`vellum`): the page background. It is also the `theme-color` meta, and the running head uses it at 92% over a 6 px backdrop blur.
- **Deep Vellum** (`vellum-deep`): code-block fill and the scrollbar track.
- **Navy Ink** (`ink`): body text, headings, plate and diagram frames, the 2 px rule on margin notes and the footer's top rule.
- **Soft Ink** (`ink-soft`): captions, margin-note prose, the ghost outlines, the brand suffix in the running head and the scrollbar thumb.
- **Rule** (`rule`): hairlines under the running head and the chapter headers, and between roadmap rows.
- **Grid** (`grid`): the quadrille lines on the body.
- **Plate Black** (`plate`): the matte behind every still and clip. The clip badge uses the same colour at 70% alpha.

### Named Rules
**The One Accent Rule.** Vermilion marks only the trajectory, the call to action and the marks that point at an action or a burn. It is never used as a fill for decoration.

## Typography

**Display and label font:** Archivo (variable, width 72–125%, weight 400–900), with sans-serif as the fallback.
**Body font:** Source Serif 4 (variable, optical size and weight 400–700, plus an italic 400 face), with Georgia and serif as the fallbacks.
**Code font:** the system monospace stack (`ui-monospace`, SFMono-Regular, Consolas, Liberation Mono, Menlo) at .9em.

All three faces are self-hosted latin woff2 subsets under
`src/assets/fonts/`, declared with `font-display: swap`. They are the largest
part of the eager bytes on `/`.

**Character:** a condensed, heavy grotesk set in capitals for structure, over
a book serif for prose. The pairing reads like a technical text with plate
labels.

### Hierarchy
Only two sizes exist: `--s` (1.0625rem) and `--l` (`clamp(2.6rem, 6.2vw, 5.6rem)`).
- **Display** (`--l`, weight 850, width 72%, line-height .92, -.02em, uppercase, balanced wrap): the H1 and the chapter and close H2s on `/`.
- **Mark** (`--s`, weight 800, width 110%, .04em, uppercase): the wordmark in the running head. Its "/ Setare Aerospace" suffix drops to weight 400 in soft ink.
- **Label** (`--s`, weight 700, width 88%, line-height 1.3, .06em, uppercase): H2s outside `/`, `.label` tags, chapter numbers, figure numbers in captions, breadcrumbs and meta lines. H3 and H4 use the same style at weight 600.
- **CTA** (`--s`, weight 700, width 92%, .05em, uppercase).
- **Lede** (`--s`, Source Serif 4 at weight 600): the hero lede on `/`.
- **Body** (`--s`, weight 400, line-height 1.6): prose. Paragraphs cap at 62ch and showcase paragraphs use `text-wrap: pretty`.
- **Equation** (`--s`, Source Serif 4 italic 400, line-height 1.5, no wrap): the margin-note equations.

### Named Rules
**The Two Sizes Rule.** No third font size. To rank a piece of text, change its weight, width or case. The one exception is text inside an SVG diagram (Archivo 600 at 13 px, uppercase, .05em). It is set in viewBox units and scales with the diagram.

## Layout

- **Page grid:** `main.page` is 12 equal columns with a 24 px column gap and padding of 56 px top, `--gut` sides and 120 px bottom. Each showcase section spans all 12 columns as a subgrid, so plates, captions and margin notes in every section share one set of columns.
- **Quadrille:** the body draws 1 px lines in the `grid` colour every 24 px (`--cell`) in both directions.
- **Hero:** the H1 spans columns 1–9 and the lede 1–7. The action row (CTA plus a Roadmap link, 28 px gap) spans all 12 columns. Fig. 1 spans 1–9, with the vis-viva margin note in 10–12, both 48 px below the action row.
- **Chapters:** 140 px top padding (180 px for the Discord close). The chapter header is a subgrid row with the number in columns 1–2 and the H2 in 3–12, over a hairline. The body copy spans 3–8. Content rows start 40 px below it with a 24 px gap: four up for the buildup row and the ghosts, two up for the launch-site clips, and a 7fr/5fr split for still plus diagram or diagram plus margin note.
- **Breakpoint 860 px:** below it every column span collapses to 1–12. Four-up rows become two-up, and the two-up launch-site row and the splits become one column. The roadmap's sticky era headings become static.
- **Running head:** sticky at top, z-index 5, 14 px by `--gut` padding. The wordmark sits left; Roadmap and the CTA sit right.

## Elevation & Depth

The page is flat paper. Depth comes from ink frames and the dark matte of the
plates, not from shadows. Two exceptions exist: the CTA's small lift shadow,
and the running head's translucent vellum over a 6 px backdrop blur.

### Shadow Vocabulary
- **CTA lift** (`box-shadow: 0 2px 6px rgba(20,35,59,.18)`): the only shadow on the site. On hover the CTA also moves up 1 px.

## Shapes

Square corners throughout. The CTA's 2 px radius is the only rounding. Lines
mark structure: 1 px ink frames on plates and diagrams, a 2 px ink rule above
margin notes, a 1 px ink rule above the footer and hairline `rule` dividers.
Planned work uses 1.5 px dashed soft-ink borders, and its icons use 4/4 dashed
strokes.

## Components

### Running head
The site name on the left, then Roadmap and the CTA on the right. It is
sticky with a hairline under it. Nav links are underlined on hover. The
current page carries a 2 px vermilion underline and `aria-current`. It comes
from `BaseLayout.astro` and is the same on every page.

### Call to action (Join the Discord)
- **Shape:** 2 px radius, 10 px by 18 px padding, with an 18 px arrow icon and a 10 px gap before the text.
- **Primary:** inked vermilion with white CTA type and the CTA lift shadow.
- **Hover / Focus:** the colour darkens and the button lifts 1 px, with a .2s `--ease` transition. Focus shows a 2 px vermilion outline at a 3 px offset. Under `prefers-reduced-motion: reduce` there is no transition and no lift.
- **Placement:** `/` has four invite links: the running head, the hero, the Discord close and the footer. Each opens in a new tab with `rel="noopener noreferrer"`.

### Plate
The frame for every still and clip: a plate-black matte with 10 px padding
and a 1 px ink border. Media fill the width at 16:9 with `object-fit: cover`.
A clip plate adds a "Clip" badge in the top right corner (20 px inset): a
label with a play glyph, white on plate black at 70% alpha.

### Figure caption
Placed 12 px below the plate, in soft ink. It starts with the figure number
in label type and ink (`Fig. 1`, `2.1` to `4.2`) with an 8 px space after it.
Then comes one sentence on what the capture shows, then `Captured
YYYY-MM-DD.` from `src/assets/showcase/captures.json`. Captions say only what
the frame shows.

### Margin note
Sits in the right margin columns, or in the split's right column. It has a
2 px ink rule on top with 12 px padding, a label, a single-line italic
equation and a short soft-ink paragraph. The equations used are vis-viva
`v² = μ (2/r − 1/a)` and Kepler's equation `M = E − e sin E`.

### Chapter header
The chapter number ("Chapter 2" to "Chapter 5", or "Planned") in inked
vermilion label type sits on columns 1–2. The display H2 sits on 3–12. The
two align at the bottom over a hairline with 18 px padding below. The six H2s
on `/` are exactly Layer buildup, Launch-site terrain, Lighting, Orbital
mechanics, Next milestones and Discord.

### Diagram
An inline SVG inside a 1 px ink frame with 16 px padding and a 35% white wash
over the vellum. It has `role="img"` and an `aria-label` that states what it
shows. Strokes use `currentColor` (ink). Vermilion marks only the burn arrow
and the Δv label. Two diagrams ship: 4.2, the five sun elevations (noon 90°,
raking 8°, terminator 0°, sunrise limb −2°, night −25°), and the Chapter 5
orbit, which marks the focus, periapsis, apoapsis and a prograde burn.

### Ghost
A planned item: a 1.5 px dashed soft-ink border, 20 px padding and a minimum
height of 240 px. A 96 px dashed line icon sits at the top. At the bottom
come an "In preparation" tag in inked vermilion, the item name in ink label
type and one line of soft-ink text. The four ghosts are The Moon and Mars,
Flight plans, Gas giants and Living ground, followed by a Roadmap link to
`${BASE_URL}roadmap/`.

### Footer
A 1 px ink rule on top, on its own 12-column grid with 28 px by `--gut`
padding. It holds one meta line: © 2026 Spoods Studios and a Join the Discord
link.

### Trajectory
See Motion. The static version is one `.traj` SVG per section. The hero draws
a vertical line at the right edge. Each chapter draws a 100 px cubic bend
across to the other gutter followed by a vertical line, and every other
section is mirrored with `scaleX(-1)` so the path alternates gutters. The
close ends the line with a 5 px craft dot. All of it is a 2 px vermilion
stroke with `vector-effect: non-scaling-stroke`, `aria-hidden`, behind the
content (z-index 0).

## Motion

Motion runs only on `/`. Two modules are bundled into the one processed
`<script>` in `src/pages/index.astro`. `setupClipPlay` runs first, then
`initShowcaseMotion`, so an error in the motion module cannot stop clip
playback. `BaseLayout.astro` imports neither, so `/roadmap/` and `/404` ship
no script besides GoatCounter. The site has no client router and the module
initialises once on load.

**Libraries:** `motion@14.9.0` and `lenis@1.3.27`, both pinned exactly in
`package.json` and the lockfile, and no gsap. `showcase-motion.ts` imports
`{ scroll, inView, frame, cancelFrame }` from `motion` (from the allowed set
`animate, scroll, inView, frame, cancelFrame`), Lenis, and
`lenis/dist/lenis.css`.

**Reduced-motion and no-JS gate (SSC-06):**
- Hidden starting states exist only in CSS. They sit inside `@media (prefers-reduced-motion: no-preference)` and apply only under the `.js` class on `<html>`. Without JS, or under reduce, nothing is hidden. The static trajectory shows in full and every section is in its final state, with no JS work.
- The module starts with `const mq = matchMedia('(prefers-reduced-motion: reduce)'); if (mq.matches) return;`. Only after that check does it add `.js` or construct Lenis, `scroll()` and `inView()`. It throws loudly if `main.page` has no `.traj-live` path and craft marker.
- Lenis is created with `autoRaf: false` and keeps the default `respectReducedMotion: true` as a second guard. Motion's frame loop drives it through `frame.setup(update, true)`, which lets scroll-linked work see the current scroll position within the same frame.
- If the visitor switches to reduce mid-session, a `change` listener tears everything down once. It removes itself, calls the cancel functions that `scroll()` and `inView()` returned, calls `cancelFrame(update)` and `lenis.destroy()`, disconnects the ResizeObserver and removes `.js`, which shows the static final state. It does not start again if the visitor switches back.

**Trajectory draw:**
- With `.js` and no-preference set, the per-section static SVGs are hidden. One full-page `.traj-live` SVG is shown instead: a `pathLength="1"` path with `stroke-dasharray: 1 1` and a starting offset of 1, plus a 5 px vermilion craft circle.
- The path is built from the section tops. It starts in the right gutter (x = width − half the side padding) and runs straight down to each section's top, then makes a 100 px cubic bend into the opposite gutter. It ends at the bottom of the last section. A ResizeObserver on `main` rebuilds it whenever the layout changes. The path is sampled every 16 px of length to map a page y to a length.
- The drawn length is the larger of two values: the path length at the point 60% down the viewport, and Motion `scroll()` progress times the total length. That value sets the dash offset (`1 − at/length`) and places the craft marker on the path at that length.

**Section entry:**
- Each `.enter` element starts hidden: opacity 0, `translate(calc(var(--dir) * -28px), -18px) rotate(calc(var(--dir) * -1.2deg))` and `blur(4px)`. `--dir` is 1 on odd sections and −1 on even sections, so each section enters from the side the trajectory comes from.
- `inView()`, with a `0px 0px -10% 0px` margin, adds `.in` once. CSS transitions then reveal the element: opacity and filter over .9s and transform over 1.1s, all with `--ease` (`cubic-bezier(.16,1,.3,1)`). Each element gets a 0/70/140/210 ms delay depending on its position in each group of four.
- The entries use CSS transitions rather than `animate()`, which keeps the bundle inside the 20 kB budget. `animate()` is not imported.

**Clip playback (`src/scripts/clip-play.ts`):**
- The module does not depend on the animation library. `setupClipPlay(videos, { IntersectionObserver, matchMedia, saveData })` receives the browser objects as arguments.
- One IntersectionObserver with a `200px` rootMargin keeps the set of clips near the viewport. A clip near the viewport plays, and a clip that leaves pauses. At most two play at once, and a waiting near clip takes a freed slot. A rejected `play()` frees its slot if the clip is still paused.
- It never calls `play()` while `prefers-reduced-motion: reduce` matches, and it pauses every playing clip on a switch to reduce. Clips near the viewport resume, up to two, if the visitor switches back. Under reduce the poster is the final state and the clip bytes are never fetched.
- If `navigator.connection.saveData` is true it never plays. It never reads or writes `currentTime`, so nothing scrubs and nothing is pinned to a scroll timeline.

## Media

**Stills** (`astro:assets` `<Picture>`):
- Settings: formats `['avif', 'webp']`, `fallbackFormat: 'jpg'`, `layout: 'constrained'`, width 1280, height 720, `widths: [640, 1280, 1920]` and `quality: 'mid'`. The sources are 1280×720 PNGs and Astro does not upscale, so only the 640w and 1280w candidates are emitted.
- Fig. 1 (terminator) uses `priority` (eager, `fetchpriority="high"`) and is the LCP. Every other still is lazy and async. Each still has a `sizes` value matching its column span.
- Caps: AVIF and WebP at 1280w are at most 150,000 bytes each, and the JPEG fallback at most 250,000. The largest shipped 1280w files are 10,130 B AVIF, 17,872 B WebP and 28,373 B JPEG, all from buildup-l0.
- `/` carries 5 `<picture>` elements, against a cap of 12.

**Clips** (`ShowcaseClip.astro`):
- Markup: `<video muted loop playsinline preload="none" poster="…" width="1280" height="720" disableremoteplayback>` with a webm `<source>` first and an mp4 second, both at `${BASE_URL}showcase/<name>` from `public/showcase/`. There is no `autoplay` (it overrides `preload`) and no `controls`.
- The build fails loudly when a clip has no `-poster.png` or no `captured` date in `captures.json`.
- `/` carries 3 clips, against a cap of 8: buildup-l4, spot-ksc and spot-starbase.
- Encodes come from `tools/showcase-encode.sh`. Captures must be 1280×720 and clips 4–8 s long.

**Posters:** each is built from `<name>-poster.png` with `getImage({ format: 'webp', width: 1280, quality: 'mid' })`. The cap is 80,000 bytes each. The shipped posters are 5,186 to 9,272 B.

**OG image:** the terminator still via `getImage` as a 1280×720 jpg, passed to `BaseLayout`'s `ogImage`. It is used on `/` only. Every other page keeps the default card.

## Budgets

These are byte counts against a clean `npm run build`, never wall-clock.
`tests/showcase.smoke.sh` enforces them. The values below were measured on
2026-10-30. All are raw file bytes, before the transfer compression that
GitHub Pages applies.

| Budget | Cap | Measured |
|---|---|---|
| Animation JS: gzip of the module `/` loads plus every `_astro` chunk it imports | ≤ 20,000 B | 9,987 B (one 30,266 B module, no chunks) |
| Eager bytes on `/` (`bash tools/perf-log.sh`, metric `home_eager_bytes`) | ≤ 500,000 B | 205,115 B |
| Worst-case full scroll (eager + each lazy still's largest candidate + posters + each clip's larger encode) | ≤ 8,000,000 B | 718,464 B |
| Clips on the page | ≤ 8 | 3 |
| Stills on the page | ≤ 12 | 5 |
| Clips playing at once | ≤ 2 | 2 (clip-play cap) |

The eager total breaks down as follows:
- HTML: 22,033 B. This includes the inlined page styles and `lenis.css`.
- Linked stylesheet: 5,147 B.
- Three woff2 fonts: 145,288 B.
- The JS module: 30,266 B.
- The hero's largest AVIF candidate: 2,381 B.

The worst case adds lazy stills (71,472 B), posters (19,784 B) and clips
(422,093 B). `tools/perf-log.sh` fails loudly, naming the path, when
`dist/index.html` is missing.

There are no cookies. GoatCounter is the only analytics and the only
third-party script. No built JS references `document.cookie` or any other
third-party origin.

## Do's and Don'ts

### Do:
- **Do** rank text by weight, width and case within the two sizes `--s` and `--l`.
- **Do** put every figure in a plate with a numbered caption that ends with its capture date from `captures.json`.
- **Do** put any new hidden starting state under both `@media (prefers-reduced-motion: no-preference)` and `.js`, so the page without JS is the final page.
- **Do** compose media URLs from `import.meta.env.BASE_URL`. The site is served under `/interstellar-website`.
- **Do** keep clips `preload="none"`, muted and played only by `clip-play.ts`.
- **Do** rerun `tools/perf-log.sh` and `tests/showcase.smoke.sh` after adding media or JS to `/`, and update the measured numbers here.

### Don't:
- **Don't** add a third font size, or a corner radius anywhere other than the CTA.
- **Don't** use vermilion as a decorative fill. It marks only the trajectory, the call to action and burns.
- **Don't** show mocked or generated imagery, or invented claims, dates, player counts or press. Show planned work only as ghosts marked "In preparation".
- **Don't** add `autoplay` or `controls` to a clip, scrub `currentTime`, or pin a clip in a scroll timeline.
- **Don't** import animation code from `BaseLayout.astro`, or use `is:inline` for the showcase script.
- **Don't** construct Lenis, `scroll()` or `inView()` before the reduce gate.

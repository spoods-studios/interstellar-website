# Concerns

<!-- known problems, one line each: C-NN — area — files — severity — focus — `path:line` evidence — status -->

## Concerns

- C-01 — content-collections — src/content.config.ts, src/lib/content-guards.ts, src/pages/roadmap/index.astro, src/pages/roadmap/[milestone].astro, roadmap/M1.3.md — medium — — — `src/content.config.ts:54`, `src/lib/content-guards.ts:15`, `src/pages/roadmap/index.astro:30`, `src/pages/roadmap/[milestone].astro:17`, `roadmap/M1.3.md:3` — open
- C-02 — description-extraction — src/lib/describe-entry.ts — low — — — `src/lib/describe-entry.ts:6` — open
- C-03 — hero-images — src/lib/hero-assets.ts — medium — — — `src/lib/hero-assets.ts:24`, `src/lib/hero-image.ts:27` — open
- C-04 — rss-feed — src/pages/rss.xml.ts — low — — — `src/pages/rss.xml.ts:49` — open
- C-05 — build-tooling — package.json — low — — — `package.json:9` — open
- C-06 — rss-feed — src/pages/rss.xml.ts, tests/distribution.smoke.sh — medium — — — `src/pages/rss.xml.ts:33`, `tests/distribution.smoke.sh:323` — open
- C-07 — assets — src/assets/og-default.svg, src/lib/site.mjs — low — — — `src/lib/site.mjs:41` — open
- C-08 — testing — tests/build.smoke.sh, tests/collections.smoke.sh, tests/post.smoke.sh, tests/roadmap.smoke.sh, .forge/TESTING.md — medium — — — `.forge/TESTING.md:21` — open
- C-09 — deploy-probe — tests/live-probe.sh, .github/workflows/deploy.yml — medium — — — `tests/live-probe.sh:67`, `tests/live-probe.sh:82`, `tests/live-probe.sh:88`, `.github/workflows/deploy.yml:39` — open
- C-10 — analytics — src/layouts/BaseLayout.astro — low — — — `src/layouts/BaseLayout.astro:90` — open
- C-11 — analytics — src/lib/site.mjs — low — — — `src/lib/site.mjs:78` — open
- C-12 — deploy-workflow — .github/workflows/deploy.yml — low — — — `.github/workflows/deploy.yml:39` — open
- C-13 — title-extraction — src/lib/title-from-h1.ts — low — — — `src/lib/title-from-h1.ts:4` — open
- C-14 — testing — tests/build.smoke.sh, devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md, .forge/TESTING.md — medium — — — `tests/build.smoke.sh:13`, `devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md:1`, `.forge/TESTING.md:25` — open

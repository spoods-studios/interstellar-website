# interstellar-website — conventions

> **Stub (D-10).** This repo is a scaffold; real conventions (build, review, flow,
> naming, commit style) land at **activation**. Until then this file exists only so
> the vault skeleton is uniform across the ecosystem and recall has a stable slot.

## Slug immutability (D-66)

Once a devlog, technical, or roadmap page has deployed, its URL is permanent.
Discord embeds, RSS guids, and studio-vault references all pin these URLs — a
rename without a stub breaks links already published to readers, and unlike a
broken build nothing tells you it happened; the only trace is the analytics
dashboard counting the 404 page at the dead URL's own path.

If a promoted file must be renamed anyway, the old path gets an entry in the
`SLUG_REDIRECTS` map in `astro.config.mjs` **in the same commit as the rename**:
base-free key, destination composed from `NORMALIZED_BASE` (Astro emits string
destinations verbatim into the stub's refresh URL, so a base-less destination
redirects readers to a path that does not exist — the smoke harness pins this).

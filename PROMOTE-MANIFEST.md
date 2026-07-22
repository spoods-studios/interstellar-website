# Promote Manifest

Audit record for the manual, in-repo promote of every piece of locked studio
content for closed milestones M0.1–M0.8 (Phase 2, Plan 01 — D-25, D-43). This
repo hosts no promote automation; that remains a studio-side concern per
`.planning/REQUIREMENTS.md` ("Out of Scope"). This file is the record of what
was copied, from where, and why anything named here was excluded.

## devlog/ — milestone announcements

| Source (`../studio/vault/devlog/drafts/`) | Destination (`devlog/`) |
|---|---|
| `m0.1-vulkan-bootstrap.md` | `2026-04-13-before-the-galaxy-a-triangle.md` |
| `m0.2-coordinate-system.md` | `2026-04-25-a-coordinate-system-that-doesnt-lie.md` |
| `m0.3-basic-orbit.md` | `2026-06-05-a-moon-that-actually-orbits.md` |
| `m0.4-multi-body.md` | `2026-06-14-from-one-world-to-many.md` |
| `m0.5-gravity-performance.md` | `2026-06-19-teaching-the-engine-to-fast-forward.md` |
| `m0.6-wh-shipped.md` | `2026-06-25-shipping-the-warp-lever-with-a-bouncer-on-the-door.md` |
| `m0.7-nested-wisdom-holman.md` | `2026-07-10-warping-without-losing-the-moon.md` |
| `m0.8-perturbations.md` | `2026-07-13-making-mercury-precess.md` |

Plus two hero assets from `../studio/vault/devlog/assets/`, referenced by the
M0.7/M0.8 bodies as `../assets/<file>.png` (D-28):

| Source | Destination |
|---|---|
| `m0.7-hero-contrast.png` | `assets/m0.7-hero-contrast.png` |
| `m0.8-hero-precession.png` | `assets/m0.8-hero-precession.png` |

`manifesto.md` is not listed above — it was already promoted in Phase 1
(`devlog/2026-04-07-why-im-building-a-hyperrealistic-space-sim.md`).

Copies are byte-for-byte, no frontmatter or body edits (D-14, D-25;
VOICE.md is locked studio-side).

## technical/ — per-phase deep-dives

`../studio/vault/devlog/technical/` copied wholesale into repo-root
`technical/`, milestone subdirectory structure preserved:

| Milestone | File count |
|---|---|
| `technical/m0.1/` | 6 |
| `technical/m0.2/` | 6 |
| `technical/m0.3/` | 8 |
| `technical/m0.4/` | 8 |
| `technical/m0.5/` | 8 |
| `technical/m0.6/` | 6 |
| `technical/m0.7/` | 8 |
| `technical/m0.8/` | 5 |
| `technical/_how-to-read.md` | 1 |
| **Total** | **56** |

Byte-for-byte copy, no frontmatter added, no heading normalisation, no
wikilink rewriting (D-33).

## roadmap/ — per-milestone detail docs

`../studio/vault/project/roadmap-detail/M0.1.md` … `M0.8.md` copied
byte-for-byte into repo-root `roadmap/`, filenames unchanged (D-38).

## pages/ — standalone pages

| Source | Destination | Note |
|---|---|---|
| `../studio/vault/devlog/drafts/how-its-made.md` | `pages/how-its-made.md` | Body byte-identical. One frontmatter field mutated: `status: draft` → `status: published` — the only content mutation permitted anywhere in this plan. Rationale: D-30 makes a `draft`-status entry non-rendering; CONT-03 requires this page live at M1.1 close; the file's own (now-removed) staging comment already said it publishes to this site at M1.1 close. The act of promoting IS the publication. `updated:`, `title`, and every body line are untouched. |
| `../studio/vault/devlog/discord/roadmap-overview.pinned.md` | `pages/roadmap.md` | **Authored, not copied** (D-37). Transcribed into site voice: dropped the "How this channel works" Discord-mechanics paragraph, rewrote the "confused by tags" pointer to name the How to Read page in this site's Technical section instead of a pinned Discord post, dropped the closing "follow the milestone threads below" line (site-generated chrome supersedes it), kept the era arc and the Era 0 milestone list with per-milestone summaries and phase counts in order, kept M1.1 listed as in-progress with no detail-page link (its detail doc lands in Phase 4, D-44). |

## Excluded and why

| Source | Reason |
|---|---|
| `../studio/vault/devlog/drafts/how-this-gets-built.md` | `status: skeleton` — unreleased, scheduled after M1.1 close |
| `../studio/vault/devlog/drafts/m0.8-perturbations.discord.txt` | Not a post — a Discord-format sidecar of `m0.8-perturbations.md` |
| `../studio/vault/devlog/technical/m1.1/` (5 deep-dives) | Phase 4 content, riding with the M1.1 launch post (D-44) |
| `../studio/vault/project/roadmap-detail/M1.1.md` | Phase 4 content (D-44) — M1.1 appears on `pages/roadmap.md` as in-progress with no detail page until then |

## Scope note

This manifest covers Phase 2 Plan 01 only: everything for closed milestones
M0.1–M0.8 (D-43). M1.1's announcement, 5 deep-dives, and `roadmap/M1.1.md`
land together in Phase 4 when that milestone actually closes (D-44).

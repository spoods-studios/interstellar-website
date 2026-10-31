# Promote Manifest

Audit record for the manual, in-repo promote of every piece of locked studio
content for closed milestones M0.1–M0.8 (Phase 2, Plan 01 — D-25, D-43). This
repo hosts no promote automation; that remains a studio-side concern per
`.forge/archive/gsd/REQUIREMENTS.md` ("Out of Scope"). This file is the record of what
was copied, from where, and why anything named here was excluded.

## technical/ — per-phase deep-dives

`../vault/devlog/technical/` copied wholesale into repo-root
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

`../.forge/docs/roadmap-detail/M0.1.md` … `M0.8.md` copied
byte-for-byte into repo-root `roadmap/`, filenames unchanged (D-38).

## pages/ — standalone pages

| Source | Destination | Note |
|---|---|---|
| `../vault/devlog/discord/roadmap-overview.pinned.md` | `pages/roadmap.md` | **Authored, not copied** (D-37). Transcribed into site voice: dropped the "How this channel works" Discord-mechanics paragraph, rewrote the "confused by tags" pointer to name the How to Read page in this site's Technical section instead of a pinned Discord post, dropped the closing "follow the milestone threads below" line (site-generated chrome supersedes it), kept the era arc and the Era 0 milestone list with per-milestone summaries and phase counts in order, kept M1.1 listed as in-progress with no detail-page link (its detail doc lands in Phase 4, D-44). |

## Excluded and why

| Source | Reason |
|---|---|
| `../vault/devlog/drafts/how-this-gets-built.md` | `status: skeleton` — unreleased, scheduled after M1.1 close |
| `../vault/devlog/drafts/m0.8-perturbations.discord.txt` | Not a post — a Discord-format sidecar of `m0.8-perturbations.md` |
| `../vault/devlog/technical/m1.1/` (5 deep-dives) | Phase 4 content, riding with the M1.1 launch post (D-44) |
| `../.forge/docs/roadmap-detail/M1.1.md` | Phase 4 content (D-44) — M1.1 appears on `pages/roadmap.md` as in-progress with no detail page until then |

## Scope note

This manifest covers Phase 2 Plan 01 only: everything for closed milestones
M0.1–M0.8 (D-43). M1.1's announcement, 5 deep-dives, and `roadmap/M1.1.md`
land together in Phase 4 when that milestone actually closes (D-44).

## M1.2 promote (2026-08-11, engine milestone close)

Promoted at the engine M1.2 `/complete-milestone` close, same rules as above
(byte-for-byte, D-33; no frontmatter or body edits):

| Source | Destination | Files |
|---|---|---|
| `../vault/devlog/technical/m1.2/` | `technical/m1.2/` | 10 (phases 55, 55.1, 55.2, 56, 57, 57.1, 58, 59, 60, 61) |

Still pending promote: `roadmap/M1.2.md` — its source
(`../.forge/docs/roadmap-detail/M1.2.md`) is a studio close-side
artifact not yet written at the time of this entry.

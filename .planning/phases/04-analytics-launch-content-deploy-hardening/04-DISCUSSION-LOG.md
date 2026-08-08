# Phase 4: Analytics, Launch Content & Deploy Hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-08
**Phase:** 4-Analytics, Launch Content & Deploy Hardening
**Areas discussed:** Analytics setup & wiring, Launch post timing & scope, Redirect stubs & slug norm, Post-deploy smoke check

---

## Analytics setup & wiring

| Option | Description | Selected |
|--------|-------------|----------|
| GoatCounter hosted | Stack-research pick; free non-commercial tier, cookieless, single script | ✓ |
| Plausible hosted | ~$9/mo, more polished dashboard, equally cookieless | |
| Defer analytics entirely | Ship v1 without; ANLT-01 moves to v2 | |

**User's choice:** GoatCounter hosted

| Option | Description | Selected |
|--------|-------------|----------|
| Create account now | Resolve during discuss like D-55 (Discord invite) | ✓ (attempted) |
| Constant + loud-fail, set later | D-54 pattern; build red until real code set | |
| Optional — absent if unset | Script renders only when set; deploys stay green | ✓ (fallback) |

**User's choice:** "Create account now", but goatcounter.com failed to load — user deferred signup to after the phase. Fallback recorded as D-61: optional-if-unset with loud build warning; hard-fail on malformed value once set.

| Option | Description | Selected |
|--------|-------------|----------|
| Count 404s | Dead-link radar feeding CONT-06 | ✓ |
| Exclude 404 | Cleaner stats, loses signal | |
| You decide | Claude discretion | |

**User's choice:** Count 404s

---

## Launch post timing & scope

| Option | Description | Selected |
|--------|-------------|----------|
| Full M1.1 tree | Announcement + hero + 10 deep-dives + roadmap/M1.1.md | ✓ |
| Announcement only | CONT-05 literal minimum; leaves cross-links dangling | |

**User's choice:** Full M1.1 tree
**Notes:** M1.1 confirmed shipped studio-side (published 2026-07-30, Discord post ID present). `how-this-gets-built.md` excluded — status: skeleton.

| Option | Description | Selected |
|--------|-------------|----------|
| Refresh in-phase | Re-transcribe overview from updated pin, promote with tree | ✓ |
| Leave stale, refresh later | Overview contradicts archive at launch | |

**User's choice:** Refresh in-phase

---

## Redirect stubs & slug norm

| Option | Description | Selected |
|--------|-------------|----------|
| Astro `redirects` config | Build-time meta-refresh stubs, zero deps | ✓ |
| Hand-authored stub pages | More control, more manual work per rename | |
| You decide | Claude discretion | |

**User's choice:** Astro `redirects` config

| Option | Description | Selected |
|--------|-------------|----------|
| Repo CLAUDE.md + vault conventions | Both places agents/promote flow read | ✓ |
| Vault conventions only | Lighter; CLAUDE.md readers miss it | |
| You decide | Claude discretion | |

**User's choice:** Repo CLAUDE.md + vault conventions

---

## Post-deploy smoke check

| Option | Description | Selected |
|--------|-------------|----------|
| CI job after deploy | Appended to deploy.yml; red workflow on failure | ✓ |
| Manual script only | Hand-run; silent-failure window returns | |

**User's choice:** CI job after deploy

| Option | Description | Selected |
|--------|-------------|----------|
| Commit SHA in page markup | Build stamps GITHUB_SHA; probe greps live HTML | ✓ |
| build-info.json endpoint | Separate route carrying SHA + timestamp | |
| You decide | Claude discretion | |

**User's choice:** Commit SHA in page markup

---

## Claude's Discretion

- GoatCounter script attributes, localhost/dev suppression, bot handling
- Smoke-check URL set, retry/backoff, harness style
- SITE-03 audit of existing loud-fail coverage
- Redirects map seeded vs empty; stub markup details
- Slug norm wording; SHA stamp placement
- M1.1 promote sequencing across plans

## Deferred Ideas

- GoatCounter signup + site-code constant set — after phase (site unreachable during discuss)
- Phase 3 deferred human verification — `/gsd-verify-work 3` only
- `how-this-gets-built.md` — publishes post-VOICE-pass via normal promote flow
- Outbound CTA click analytics — likely never (privacy posture)

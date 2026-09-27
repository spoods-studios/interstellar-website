# Phase 4: Analytics, Launch Content & Deploy Hardening - Pattern Map

**Mapped:** 2026-08-08
**Files analyzed:** 11 new/modified surfaces (+ promoted content tree)
**Analogs found:** 10 / 11 (smoke CI job has a partial analog only)

Note: 04-RESEARCH.md already carries verified inline patterns (Patterns 1–5) for
the *new* code. This map complements it with the *repo-side* analogs each change
must mirror — imports, WHY-comment idiom, guard shape, fixture idiom.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `src/lib/site.mjs` (+GOATCOUNTER constant + assert/warn fn) | config | build-time validation | itself — `DISCORD_INVITE_URL` + `assertInviteConfigured()` (`src/lib/site.mjs:14-55`) | exact |
| `src/layouts/BaseLayout.astro` (+analytics script, +SHA stamp) | layout/component | request-response (static render) | itself — existing `<head>` OG block (`src/layouts/BaseLayout.astro:33-66`) | exact |
| `astro.config.mjs` (+`redirects` map, +GoatCounter assert call) | config | build-time validation | itself — `validateContentLoudFail()` + `assertInviteConfigured()` call sites (`astro.config.mjs:100-116`) | exact |
| `.github/workflows/deploy.yml` (+`outputs:`, +smoke job) | CI config | request-response (live probes) | itself — existing build→deploy chain (`.github/workflows/deploy.yml:7-27`); smoke job is new mechanism (RESEARCH Pattern 4) | partial |
| `tests/hardening.smoke.sh` (NEW) | test | batch (grep dist/) | `tests/distribution.smoke.sh` | exact |
| `tests/{post,roadmap,markdown,build,technical,site,collections}.smoke.sh` (count/zero-JS updates) | test | batch | themselves — RESEARCH Pitfalls 2 & 3 enumerate exact lines | exact |
| `CLAUDE.md` (repo root, slug norm) | docs | — | its own `## Content` section (`CLAUDE.md:16-19`) | exact |
| `vault/conventions.md` (slug norm) | docs | — | stub file (`vault/conventions.md:1-5`) — first real convention lands here | role-match |
| `devlog/2026-07-30-*.md` + `assets/m1.1-hero-first-burn.png` | content (promote) | file-I/O copy | `devlog/2026-07-13-making-mercury-precess.md` + M0.7/M0.8 hero pattern | exact |
| `technical/m1.1/phase-*.md` (10 files) | content (promote) | file-I/O copy | `technical/m0.2/phase-07-core-vector-types.md` (incl. `[[nodiscard]]` precedent) | exact |
| `roadmap/M1.1.md`, `pages/roadmap.md` (refreshed) | content (promote) | file-I/O copy | `roadmap/M0.8.md` (D-38 H1/Era shape), existing `pages/roadmap.md` | exact |

## Pattern Assignments

### `src/lib/site.mjs` — GoatCounter constant (config, build-time validation)

**Analog:** the `DISCORD_INVITE_URL` triple in the same file — constant + placeholder sentinel + assert function.

**Constant + sentinel pattern** (`src/lib/site.mjs:14-18`):
```js
export const DISCORD_INVITE_URL = 'https://discord.gg/yeyyh6ycfw';

// The sentinel a scaffolded-but-unconfigured checkout would carry. Rejected
// by assertInviteConfigured() so a near-miss value can never reach a page.
export const INVITE_PLACEHOLDER = 'https://discord.gg/REPLACE_ME';
```

**Assert pattern** (`src/lib/site.mjs:45-55`):
```js
// D-54: an unset or placeholder invite must fail the build loudly rather than
// render a CTA with an empty href. Called bare at astro.config.mjs top level.
export function assertInviteConfigured() {
  const trimmed = typeof DISCORD_INVITE_URL === 'string' ? DISCORD_INVITE_URL.trim() : '';
  if (trimmed === '' || trimmed === INVITE_PLACEHOLDER) {
    throw new Error(
      'DISCORD_INVITE_URL: the Discord invite is unset, blank, or still the placeholder — set it to the permanent D-55 invite in src/lib/site.mjs'
    );
  }
  return trimmed;
}
```

**Deliberate deviation (D-61):** unset ⇒ `console.warn` naming the constant and return `null` (build proceeds); set-but-placeholder/malformed ⇒ throw. RESEARCH Pattern 1 has the full drafted function. Error message style: name the constant, state the failure, say where to fix it — copy the sentence shape above.

**File-header idiom** (`src/lib/site.mjs:1-8`): plain ESM, no Astro imports (config-load evaluability), decision IDs cited in a top comment block — extend that decision list with D-60/D-61 rather than adding a second header.

---

### `src/layouts/BaseLayout.astro` — analytics script + SHA stamp (layout)

**Analog:** its own `<head>` block, filled by Phase 3's D-50 work.

**Imports/frontmatter pattern** (`src/layouts/BaseLayout.astro:1-31`):
```astro
---
import '../styles/global.css';
import { DISCORD_INVITE_URL, SITE_NAME, SITE_TAGLINE, OG_DEFAULT, FEED_TITLE } from '../lib/site.mjs';
// ...props destructure...
const rawBase = import.meta.env.BASE_URL;
const base = rawBase.endsWith('/') ? rawBase : `${rawBase}/`;
---
```
Import the new constant/guard from `../lib/site.mjs` alongside the existing names. SHA read (`const buildSha = process.env.GITHUB_SHA ?? 'local';`) goes in this frontmatter — build-time server context (RESEARCH Pattern 2).

**Conditional-render pattern** (`src/layouts/BaseLayout.astro:58`):
```astro
{publishedTime && <meta property="article:published_time" content={publishedTime} />}
```
The gated GoatCounter `<script>` uses this same `{value && (...)}` idiom (RESEARCH Pattern 1's snippet; mark the script `is:inline`). `<meta name="build-sha">` sits unconditionally beside the OG metas (`BaseLayout.astro:49-61`).

**Comment idiom** (`BaseLayout.astro:22-23, 39-48`): multi-line WHY-comments as `{/* ... */}` inside markup, citing decision IDs — new additions cite D-60/D-61/D-62/D-68 the same way.

---

### `astro.config.mjs` — redirects map + assert call (config)

**Analog:** its own top-level validation section.

**Config-load assert-call pattern** (`astro.config.mjs:111-116`):
```js
validateContentLoudFail();

// D-54: same reasoning as validateContentLoudFail() above -- config evaluation
// is the layer nothing downstream swallows, so an unset invite crashes the
// build here rather than shipping a CTA with an empty href.
assertInviteConfigured();
```
`assertGoatcounterConfigured()` is called bare here, immediately after, with a matching WHY-comment. Import joins line 11's `import { assertInviteConfigured } from './src/lib/site.mjs';`.

**Base composition** (`astro.config.mjs:13-14`) — the redirects map's destinations MUST compose from this existing constant (RESEARCH Pitfall 1):
```js
const BASE = '/interstellar-website';
const NORMALIZED_BASE = BASE.endsWith('/') ? BASE : `${BASE}/`;
```
Redirects config shape: RESEARCH Pattern 3 (keys base-free, destinations `${NORMALIZED_BASE}...`, `redirects:` key added to the `defineConfig` object at `astro.config.mjs:118-132`).

---

### `.github/workflows/deploy.yml` — outputs + smoke job (CI)

**Analog:** the existing two-job chain — mirror its minimal-permissions, `needs:` style.

**Existing deploy job** (`.github/workflows/deploy.yml:16-27`):
```yaml
  deploy:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v5
```
Delta: add job-level `outputs: page_url: ${{ steps.deployment.outputs.page_url }}` to `deploy`, append `smoke:` with `needs: deploy` and no permissions block. Full smoke-job YAML including the bounded 12×15s retry loop, cache-buster, 404-under-base check, and redirect-stub probe: RESEARCH Pattern 4 (copy it near-verbatim). Comment style: terse `# D-08: ...` decision-ID comments as at `deploy.yml:4`.

---

### `tests/hardening.smoke.sh` (NEW) — build-time assertions (test)

**Analog:** `tests/distribution.smoke.sh` — the phase-3 harness this file mirrors structurally.

**Header + config-derivation pattern** (`tests/distribution.smoke.sh:1-29`):
```bash
#!/usr/bin/env bash
# Distribution smoke harness for Phase 3 ... [prose stating which requirements
# and loud-fail paths this file proves, and which checks are deliberately human]
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Clean build =="
rm -rf dist
npm run build

# --- Derive the expected absolute-URL prefix from astro.config.mjs itself
# (SITE-02: the site/base live in one config location, never a literal
# repeated here). ---
SITE=$(grep -oP "site:\s*'\K[^']+" astro.config.mjs)
BASE=$(grep -oP "^const BASE = '\K[^']+" astro.config.mjs)
NORMALIZED_BASE="${BASE%/}/"
```
Never hardcode the base in assertions — derive it as above (so the RESEARCH Code Examples' literal `/interstellar-website/` greps should be rewritten against `$NORMALIZED_BASE`).

**Trap-and-restore fixture pattern** (`tests/distribution.smoke.sh:382-392`) — the D-61 hard-fail proof copies this exactly, swapping in the GoatCounter constant:
```bash
trap 'cp "$SITE_LIB_BACKUP" "$SITE_LIB" 2>/dev/null || true; rm -f "$SITE_LIB_BACKUP" "$HERO_BACKUP"' EXIT
# A near-miss value must be rejected too -- the requirement is that no page can
# ever ship a CTA with a blank or scaffold href, not merely that an empty
# constant breaks something.
for BAD_INVITE in "" "   " "$INVITE_PLACEHOLDER"; do
  sed "s|^export const DISCORD_INVITE_URL = '.*';|export const DISCORD_INVITE_URL = '${BAD_INVITE}';|" \
    "$SITE_LIB_BACKUP" > "$SITE_LIB"
```
(D-61 twist: unset expects a *green build with the warning on stderr*; placeholder/malformed expects non-zero exit naming the constant.)

**Fixture teardown + tree-clean guard** (`tests/distribution.smoke.sh:438-444`):
```bash
trap - EXIT
rm -f "$HERO_BACKUP" "$SITE_LIB_BACKUP" "$DRAFT_BACKUP"

echo "== Final clean rebuild after all fixtures restored =="
npm run build
if git status --porcelain devlog/ technical/ roadmap/ pages/ src/ | grep -q .; then
  echo "FAIL: trees not clean after the full fixture run"
```

**Auto-discovery:** `tests/run-all.sh:11-14` globs `tests/*.smoke.sh` — new file needs zero harness edits (this is the stated design at `run-all.sh:2-5`).

---

### Existing test updates (Pitfalls 2 & 3 line map)

Zero-`<script>` assertions to make state-aware: `tests/post.smoke.sh:55`, `tests/roadmap.smoke.sh:43,75,76`, `tests/markdown.smoke.sh:28` (verify `$RENDERED` scope first), `tests/build.smoke.sh:45`, `tests/technical.smoke.sh:39,40,97`, `tests/site.smoke.sh:75`.

Corpus counts / `m0`-anchored patterns: `tests/collections.smoke.sh:28` (9/56/8→10/66/9), `tests/build.smoke.sh:27` (9→10), `tests/technical.smoke.sh:13,62` (broaden `m0.*`→`m*`, 55→65), `tests/roadmap.smoke.sh:51` (8→9). Review sweep: `grep -rn 'm0' tests/`.

---

### `CLAUDE.md` + `vault/conventions.md` — slug-immutability norm (docs)

**Analog:** the existing untouchability rule the norm sits beside (`CLAUDE.md:16-19`):
```markdown
## Content
`devlog/`, `technical/`, `roadmap/`, and `pages/` are drop targets for studio's
`draft-devblog` → promote pipeline — never move, rename, or restyle their
`.md` files; the site layer renders them as-is (VOICE.md is locked, studio-side).
```
Match this register: imperative, one dense paragraph, names the mechanism (redirects map in `astro.config.mjs`) and the why (Discord embeds/RSS/vault pin URLs). `vault/conventions.md` is still the D-10 stub — this is the first real convention; keep the stub blockquote, add the section below it.

---

### Content promote (D-63/D-64) — no code patterns, file-copy fidelity

**Analogs:** `devlog/2026-07-13-making-mercury-precess.md` (filename convention: date + title-derived slug), M0.7/M0.8 hero posts (body ref `../assets/<file>.png`; pickup is automatic via `src/lib/hero-assets.ts:18` glob + `assetImports` detection at `hero-assets.ts:24-26`), `technical/m0.2/phase-07-core-vector-types.md:62-63` (`[[nodiscard]]`-in-code-block precedent — promote verbatim, no escaping), `roadmap/M0.8.md` (H1 + `**Era:**` line shape).

Rules: copy byte-for-byte (do NOT strip the launch post's `tags` key — non-strict schema drops it, RESEARCH Pitfall 5); one atomic commit for the whole tree (Pitfall 4); post-promote acceptance grep `grep -rc technical-devlog dist/` = 0 (Phase 2 idiom).

## Shared Patterns

### Config-load-time loud-fail
**Source:** `astro.config.mjs:100-116` + `src/lib/site.mjs:47-55`
**Apply to:** GoatCounter guard, redirects-destination smoke assertion. Config evaluation is "the one layer nothing downstream swallows" — any new validation throws there, never in a layout.

### WHY-comments citing decision IDs
**Source:** every file above (`// D-54: ...`, `{/* D-50: ... */}`, `# D-08: ...`)
**Apply to:** all new code. No WHAT-comments; each non-obvious choice cites its D-number.

### Single-source URL composition (SITE-02)
**Source:** `astro.config.mjs:13-14` (`BASE`/`NORMALIZED_BASE`), `BaseLayout.astro:19-20`, `tests/distribution.smoke.sh:25-28` (grep-derivation)
**Apply to:** redirects destinations, smoke-job URLs (`needs.deploy.outputs.page_url`, never a hardcoded Pages URL), test assertions.

### Trap-and-restore fixtures
**Source:** `tests/distribution.smoke.sh:342,382,414,438` (commit `3f6b3dc`)
**Apply to:** D-61 hard-fail proof, `status: skeleton` schema-violation proof (SITE-03 audit fixture).

## No Analog Found

| File/Piece | Role | Data Flow | Reason |
|------|------|-----------|--------|
| smoke CI job body (`deploy.yml`) | CI | live HTTP probes | First live-probe job in the repo; use RESEARCH Pattern 4's verified YAML directly. Job scaffolding (needs/permissions style) does follow the existing deploy job. |

## Metadata

**Analog search scope:** `src/lib/`, `src/layouts/`, `astro.config.mjs`, `.github/workflows/`, `tests/`, `CLAUDE.md`, `vault/`, content trees
**Files scanned:** 8 read in full/part this session; test-line map inherited from 04-RESEARCH.md (verified there against disk)
**Pattern extraction date:** 2026-08-08

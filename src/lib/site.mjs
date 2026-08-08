// Site-wide constants shared by astro.config.mjs, the layouts and the feed.
// Plain ESM with no Astro imports on purpose: astro.config.mjs evaluates this
// at config-load time (D-54), which is the one layer nothing downstream
// swallows -- see the validateContentLoudFail() comment in astro.config.mjs
// for why a layout-level guard would not hold.
//
// Decisions: D-49 (default OG card), D-53 (plain-text Discord CTA),
// D-54 (build-time invite guard), D-55 (the permanent invite), D-16 (tagline),
// D-60 (GoatCounter hosted), D-61 (optional-if-unset site code), D-62 (script
// in the shared layout so the 404 page counts too).

// D-55: permanent invite, created with Expire After: Never and no use limit.
// Locked -- regenerating it dead-links every URL already shared, and Plan
// 03-06 writes this same literal into the studio vault, so it must match
// byte-for-byte.
export const DISCORD_INVITE_URL = 'https://discord.gg/yeyyh6ycfw';

// The sentinel a scaffolded-but-unconfigured checkout would carry. Rejected
// by assertInviteConfigured() so a near-miss value can never reach a page.
export const INVITE_PLACEHOLDER = 'https://discord.gg/REPLACE_ME';

export const SITE_NAME = 'Interstellar Engine';

// D-16, developer-approved verbatim including the terminal period.
export const SITE_TAGLINE = 'A space engine built from scratch on real n-body physics.';

export const FEED_TITLE = 'Interstellar Engine — Devblog';

// Deliberately a literal, not composed from SITE_TAGLINE: both are
// developer-approved copy with different capitalization, and deriving one
// from the other would silently rewrite approved wording on the next edit.
export const FEED_DESCRIPTION =
  'Milestone announcements from Interstellar Engine — a space engine built from scratch on real n-body physics.';

export const FEED_LANGUAGE = 'en';

// D-49. Carries the bare filename only -- the base path and host are composed
// by the consumer from import.meta.env.BASE_URL and Astro.site, so no module
// under src/ ever hardcodes the host (SITE-02, D-50).
export const OG_DEFAULT = {
  file: 'og-default.png',
  width: 1200,
  height: 630,
  alt: 'Interstellar Engine — a space engine built from scratch on real n-body physics.',
};

// D-60: the GoatCounter site code, unset until the developer signs up
// (post-phase). Set it to the account's code (lowercase letters, digits and
// hyphens) after creating the account.
export const GOATCOUNTER_CODE = '';

// The sentinel a scaffolded-but-unconfigured checkout would carry. Rejected
// by assertGoatcounterConfigured() so a near-miss value can never ship.
export const GOATCOUNTER_PLACEHOLDER = 'REPLACE_ME';

// D-61: deliberately asymmetric with assertInviteConfigured() below -- an
// UNSET code warns and returns null rather than throwing, because unset is
// the expected pre-signup state and D-08 means every push deploys: a hard
// block here would freeze the pipeline until an account exists. A placeholder
// or malformed code still throws, so the two adjacent states never collapse.
// Called bare at astro.config.mjs top level and from BaseLayout.astro.
// The warn is memoized per process: BaseLayout calls this once per rendered
// page, and an unmemoized warn repeats ~100x and interleaves with Astro's
// page listing — burying the one line D-61 wants seen.
let warnedGoatcounterUnset = false;
export function assertGoatcounterConfigured() {
  const code = typeof GOATCOUNTER_CODE === 'string' ? GOATCOUNTER_CODE.trim() : '';
  if (code === '') {
    if (!warnedGoatcounterUnset) {
      warnedGoatcounterUnset = true;
      console.warn(
        'GOATCOUNTER_CODE is unset — the site builds and deploys WITHOUT analytics. ' +
          'Set it in src/lib/site.mjs after creating the GoatCounter account (ANLT-01).'
      );
    }
    return null;
  }
  if (code === GOATCOUNTER_PLACEHOLDER || !/^[a-z0-9-]+$/.test(code)) {
    throw new Error(
      `GOATCOUNTER_CODE: "${code}" is the placeholder or not a valid GoatCounter site code — set the real code in src/lib/site.mjs`
    );
  }
  return code;
}

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

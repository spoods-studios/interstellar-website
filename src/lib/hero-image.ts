// D-48: a post's own hero image beats the default card, and a body reference
// that does not resolve stops the build naming the post and the path -- never a
// silent fall-through, which would hide a bad promote behind a plausible embed.
// D-59: the resolved record is the emitted PNG, not the Markdown pipeline's WebP
// variant, because Twitter Card WebP support is unreliable.
//
// This module is deliberately import-free and takes its map as a parameter: the
// eager Vite glob that builds that map in production cannot be evaluated by
// tests/lib.smoke.mjs under bare Node, so it lives in hero-assets.ts instead.
// Keeping the lookup and its failure path here keeps both under unit coverage.

export interface HeroRecord {
  src: string;
  width: number;
  height: number;
}

export function heroBasename(ref: string): string {
  return ref.split('/').pop()!;
}

export function lookupHero(
  byName: Map<string, HeroRecord>,
  ref: string | undefined,
  entryId: string
): HeroRecord | null {
  if (!ref) return null;
  const record = byName.get(heroBasename(ref));
  if (!record) {
    throw new Error(
      `${entryId}: hero image "${ref}" is referenced in the body but did not resolve to a built asset — check that the file exists in assets/ and is a .png`
    );
  }
  return record;
}

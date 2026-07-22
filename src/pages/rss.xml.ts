// D-45/D-46: the one feed, built from the SAME collection query and the SAME
// visibility guard the homepage archive runs, so the archive and the feed
// structurally cannot drift on the first drafted post.
//
// Content comes from the Container API rather than a second Markdown parse or
// the entry's pre-rendered HTML field. Both alternatives exit 0 while shipping
// broken output: a fresh markdown-it never sees this repo's wikilink and
// deep-dive mdast plugins (literal `[[...]]` in the feed), and the pre-rendered
// field carries unresolved `__ASTRO_IMAGE_` placeholders that the sanitizer
// silently reduces to bare <img> tags. renderToString() returns byte-identical
// HTML to what the page routes emit.
import type { APIRoute } from 'astro';
import { getCollection, render } from 'astro:content';
import { experimental_AstroContainer as AstroContainer } from 'astro/container';
import { getRssString } from '@astrojs/rss';
import sanitizeHtml from 'sanitize-html';
import { assertNonEmpty, isVisible } from '../lib/content-guards';
import { entryTitle, entryDate, sortEntriesNewestFirst } from '../lib/devlog-meta';
import { describeBody } from '../lib/describe-entry';
import { FEED_TITLE, FEED_DESCRIPTION, FEED_LANGUAGE } from '../lib/site.mjs';

// D-46: a relative URL is broken in every feed reader, so feed-content src/href
// values are rebased against the configured site. Built image sources arrive
// root-relative with the base already applied (`/<base>/_astro/*.webp`) -- not
// in the `../assets/...` form the Markdown source shows -- so the `/` branch is
// the one that actually fires for images.
function absolutize(html: string, site: URL, entryId: string): string {
  const toAbsolute =
    (attr: 'src' | 'href') => (tagName: string, attribs: Record<string, string>) => {
      const value = attribs[attr];
      if (value && value.startsWith('/')) {
        attribs[attr] = new URL(value, site).href;
      } else if (value && !/^https?:/i.test(value) && !value.startsWith('#')) {
        // Loud-fail rather than ship a URL that silently 404s in a reader.
        throw new Error(
          `${entryId}: feed content ${attr}="${value}" could not be rewritten to an absolute URL`
        );
      }
      return { tagName, attribs };
    };

  return sanitizeHtml(html, {
    // The defaults omit img entirely, which would silently delete both hero
    // pictures. Nothing else is added: style/script/iframe/object/embed and
    // event-handler attributes stay out of the allow-list (T-03-02) -- a
    // monochrome code block in a reader is graceful degradation, an injection
    // surface is not.
    allowedTags: sanitizeHtml.defaults.allowedTags.concat(['img']),
    transformTags: { img: toAbsolute('src'), a: toAbsolute('href') },
  });
}

export const GET: APIRoute = async (context) => {
  const site = context.site!; // set in astro.config.mjs (SITE-02)
  const rawBase = import.meta.env.BASE_URL;
  const base = rawBase.endsWith('/') ? rawBase : `${rawBase}/`;

  // D-45: the archive's expression, imported rather than restated. The other
  // three content trees are excluded structurally by being separate
  // collections, so no exclusion filter is written.
  const entries = assertNonEmpty(await getCollection('devlog'), 'devlog').filter(isVisible);
  const sorted = sortEntriesNewestFirst(entries);

  const container = await AstroContainer.create();
  const items = [];
  for (const entry of sorted) {
    const { Content } = await render(entry);
    items.push({
      title: entryTitle(entry),
      pubDate: entryDate(entry),
      // Short relative, resolved against the base-inclusive channel `site`
      // below. The package derives <guid isPermaLink="true"> from it, and the
      // collection id carries both date and slug, so guids stay unique even
      // for two posts sharing a title or a date.
      link: `devlog/${entry.id}/`,
      description: describeBody(entry.body, entry.id),
      content: absolutize(await container.renderToString(Content), site, entry.id),
    });
  }

  const feedUrl = new URL(`${base}rss.xml`, site).href;
  const xml = await getRssString({
    title: FEED_TITLE,
    description: FEED_DESCRIPTION,
    // Passing site WITH the base makes the channel <link> base-inclusive and
    // lets the item links above stay short relatives.
    site: new URL(base, site).href,
    items,
    // xmlns:content is added automatically whenever an item carries `content`;
    // declaring it here too would emit a duplicate attribute.
    xmlns: { atom: 'http://www.w3.org/2005/Atom' },
    // D-57: the self-referencing atom link is the one recommendation the W3C
    // feed validator predictably raises, emitted from the start.
    customData: `<language>${FEED_LANGUAGE}</language><atom:link href="${feedUrl}" rel="self" type="application/rss+xml"/>`,
    trailingSlash: true,
  });

  return new Response(xml, { headers: { 'Content-Type': 'application/xml' } });
};

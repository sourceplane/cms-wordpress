/**
 * The sample site a deploy with no WordPress behind it renders.
 *
 * A fresh deploy has no WordPress site connected — its URL is the owner's to
 * add — and it must still serve a site, not a page of empty lists. So until
 * the build is given a WORDPRESS_URL (lib/wordpress.ts), every request the
 * WordPress client would send to the REST API is answered from this file
 * instead, in the shapes the API returns (lib/wordpress.d.ts), and the layout
 * shows a notice that the site is not connected yet. The first post says how
 * to connect it. Once WORDPRESS_URL is set, nothing here is read.
 */
import type { Author, Category, Page, Post, Tag } from "./wordpress.d";

type Query = Record<string, string | number | boolean | undefined>;

export interface SampleAnswer {
  data: unknown;
  total: number;
  totalPages: number;
}

const ORIGIN = "https://example.com";

function entity(id: number, slug: string, date: string, kind: string) {
  return {
    id,
    date,
    date_gmt: date,
    modified: date,
    modified_gmt: date,
    slug,
    status: "publish" as const,
    link: `${ORIGIN}/${kind}/${slug}`,
    guid: { rendered: `${ORIGIN}/?p=${id}` },
  };
}

const author: Author = {
  id: 1,
  name: "The editor",
  url: "",
  description: "Writes the sample posts until a WordPress site is connected.",
  link: `${ORIGIN}/author/editor`,
  slug: "editor",
  avatar_urls: {},
  meta: {},
};

function category(id: number, name: string, slug: string, count: number): Category {
  return { id, count, description: "", link: `${ORIGIN}/category/${slug}`, name, slug, meta: {}, taxonomy: "category", parent: 0 };
}
function tag(id: number, name: string, slug: string, count: number): Tag {
  return { id, count, description: "", link: `${ORIGIN}/tag/${slug}`, name, slug, meta: {}, taxonomy: "post_tag" };
}

const categories: Category[] = [
  category(1, "Getting started", "getting-started", 2),
  category(2, "Guides", "guides", 1),
];
const tags: Tag[] = [
  tag(1, "WordPress", "wordpress", 3),
  tag(2, "Next.js", "nextjs", 2),
  tag(3, "Cloudflare", "cloudflare", 2),
];

function post(
  id: number,
  slug: string,
  title: string,
  date: string,
  excerpt: string,
  content: string,
  cats: number[],
  tagIds: number[],
): Post {
  return {
    ...entity(id, slug, date, "posts"),
    title: { rendered: title },
    content: { rendered: content, protected: false },
    excerpt: { rendered: `<p>${excerpt}</p>`, protected: false },
    author: author.id,
    featured_media: 0,
    comment_status: "closed",
    ping_status: "closed",
    sticky: false,
    template: "",
    format: "standard",
    categories: cats,
    tags: tagIds,
    meta: {},
    _embedded: {
      author: [{ id: author.id, name: author.name, slug: author.slug, avatar_urls: {} }],
      "wp:term": [
        cats.map((c) => categories.find((x) => x.id === c)!).map(({ id, name, slug }) => ({ id, name, slug })),
        tagIds.map((t) => tags.find((x) => x.id === t)!).map(({ id, name, slug }) => ({ id, name, slug })),
      ],
    },
  };
}

const posts: Post[] = [
  post(
    3,
    "connect-your-wordpress-site",
    "Connect your WordPress site",
    "2026-10-28T09:00:00",
    "These are sample posts. Point the site at your WordPress and its posts, pages, categories, tags and authors replace them.",
    [
      "<p>This site is a headless front end for WordPress: it reads posts, pages, categories, tags and authors from a WordPress site's REST API and renders them. None is connected yet, so it is showing these sample posts.</p>",
      "<h2>Connect it</h2>",
      "<ol>",
      "<li>Have a WordPress site whose REST API answers at <code>https://your-site/wp-json/wp/v2/posts</code> (any self-hosted or managed WordPress).</li>",
      "<li>Store its URL as the <code>WORDPRESS_URL</code> secret of each environment: <code>orun secrets set WORDPRESS_URL --env stage</code>, which prompts for the value, and again with <code>--env prod</code>.</li>",
      "<li>Redeploy the site (Orunbase's Deploy button on the web component, or a merge to <code>main</code> that changes it). The build reads the URL, and every page then renders from your WordPress.</li>",
      "</ol>",
      "<p>Optional: install the template's <em>next-revalidate</em> plugin in WordPress and give it and the Worker one shared <code>WORDPRESS_WEBHOOK_SECRET</code>, so WordPress can call <code>/api/revalidate</code> when content changes. The site's README says how.</p>",
    ].join(""),
    [1],
    [1, 3],
  ),
  post(
    2,
    "how-the-site-reads-wordpress",
    "How the site reads WordPress",
    "2026-10-27T09:00:00",
    "Every page asks the REST API for what it shows, through one typed client in lib/wordpress.ts.",
    "<p>The pages call one client, <code>lib/wordpress.ts</code>, which requests <code>/wp-json/wp/v2/…</code> with the post's embedded author, featured image and terms. Filters on the posts page — author, category, tag and search — are the REST API's own query parameters.</p><p>Pages render on every request, so a change in WordPress shows on the next visit.</p>",
    [2],
    [1, 2],
  ),
  post(
    1,
    "hello-world",
    "Hello world!",
    "2026-10-26T09:00:00",
    "The post every WordPress site starts with, so the archive has something to page through.",
    "<p>Welcome to WordPress. This is the post every new WordPress site starts with. Edit or delete it, then start writing.</p>",
    [1],
    [1, 2, 3],
  ),
];

const pages: Page[] = [
  {
    ...entity(10, "about", "2026-10-26T09:00:00", "pages"),
    title: { rendered: "About" },
    content: {
      rendered:
        "<p>A sample page. Pages you publish in WordPress are listed under Pages and rendered at <code>/pages/&lt;slug&gt;</code>.</p>",
      protected: false,
    },
    excerpt: { rendered: "<p>A sample page.</p>", protected: false },
    author: author.id,
    featured_media: 0,
    parent: 0,
    menu_order: 0,
    comment_status: "closed",
    ping_status: "closed",
    template: "",
    meta: {},
  },
];

function list<T>(items: T[], query: Query = {}): SampleAnswer {
  const perPage = Number(query.per_page ?? 10);
  const page = Number(query.page ?? 1);
  const start = (page - 1) * perPage;
  return {
    data: items.slice(start, start + perPage),
    total: items.length,
    totalPages: Math.max(1, Math.ceil(items.length / perPage)),
  };
}

function matches(text: string, search: unknown): boolean {
  return !search || text.toLowerCase().includes(String(search).toLowerCase());
}

function ids(value: unknown): number[] {
  return value === undefined ? [] : String(value).split(",").map(Number);
}

/**
 * What the REST API would answer for `path` with `query`, from the sample
 * site; `null` where it would answer 404.
 */
export function sampleWordPress(path: string, query: Query = {}): SampleAnswer | null {
  const route = path.replace(/^\/wp-json\/wp\/v2\//, "").replace(/\/$/, "");
  const [kind, id] = route.split("/");
  const one = <T extends { id: number }>(items: T[]) => {
    const found = items.find((i) => i.id === Number(id));
    return found ? { data: found, total: 1, totalPages: 1 } : null;
  };
  switch (kind) {
    case "posts": {
      if (id) return one(posts);
      const authors = ids(query.author);
      const cats = ids(query.categories);
      const tagIds = ids(query.tags);
      const found = posts.filter(
        (p) =>
          (!query.slug || p.slug === query.slug) &&
          (authors.length === 0 || authors.includes(p.author)) &&
          (cats.length === 0 || p.categories.some((c) => cats.includes(c))) &&
          (tagIds.length === 0 || p.tags.some((t) => tagIds.includes(t))) &&
          matches(`${p.title.rendered} ${p.content.rendered}`, query.search),
      );
      return list(found, query);
    }
    case "pages":
      if (id) return one(pages);
      return list(pages.filter((p) => !query.slug || p.slug === query.slug), query);
    case "categories":
      if (id) return one(categories);
      return list(categories.filter((c) => (!query.slug || c.slug === query.slug) && matches(c.name, query.search)), query);
    case "tags": {
      if (id) return one(tags);
      const of = query.post === undefined ? null : posts.find((p) => p.id === Number(query.post));
      return list(
        tags.filter((t) => (!query.slug || t.slug === query.slug) && matches(t.name, query.search) && (!of || of.tags.includes(t.id))),
        query,
      );
    }
    case "users":
      if (id) return one([author]);
      return list([author].filter((a) => (!query.slug || a.slug === query.slug) && matches(a.name, query.search)), query);
    default:
      // Media and anything else: the sample site has none.
      return null;
  }
}

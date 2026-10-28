# apps/web — the site

A Next.js front end for a WordPress site used as a headless CMS, from 9d8's
[next-wp](https://github.com/9d8dev/next-wp) (MIT), running on Cloudflare
Workers + Static Assets:

- Posts, pages, categories, tags and authors read from the WordPress REST API
  (`/wp-json/wp/v2`) through one typed client, `lib/wordpress.ts`
- `/posts` with search, author, category and tag filters and pagination;
  `/posts/[slug]`, `/pages`, `/pages/[slug]`, and the category, tag and
  author lists
- The sitemap, Open Graph images (`/api/og`, next/og) and the revalidation
  webhook for the next-revalidate plugin (`/api/revalidate`)
- Every page rendered on request against WordPress, shadcn/ui, Tailwind 4,
  light and dark themes, Cloudflare Web Analytics (set
  `NEXT_PUBLIC_CF_BEACON_TOKEN`)

With no `WORDPRESS_URL` at build time the site is **unconnected**: it renders
the sample content in `lib/sample.ts` under a notice. The site's name is
`SITE_NAME` in `site.config.ts`.

```bash
pnpm dev        # next dev on http://localhost:3000
pnpm build      # next build + opennextjs-cloudflare build → .open-next/
pnpm preview    # wrangler dev over the built Worker
```

How it is connected to a WordPress site and deployed — per environment, on
merge to `main` — is the repository's README and `component.yaml` beside
this file.

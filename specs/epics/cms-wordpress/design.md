# cms-wordpress — design

## The template

[9d8dev/next-wp](https://github.com/9d8dev/next-wp) (Next.js 16.3 App
Router, React 19, Tailwind CSS 4, shadcn/ui), the template Vercel lists as
its Next.js Starter for WordPress Headless CMS, is a front end for a
WordPress site: one typed client (`lib/wordpress.ts`) reads the REST API
(`/wp-json/wp/v2`) — posts with their embedded author, featured image and
terms, pages, categories, tags and users — and the App Router renders the
home page, `/posts` (search, author/category/tag filters, pagination),
`/posts/[slug]`, `/pages`, `/pages/[slug]`, the category, tag and author
lists, a sitemap, Open Graph images (`/api/og`, next/og) and
`/api/revalidate`, the webhook its WordPress plugin (`next-revalidate`)
calls on a change to invalidate cache tags. The fetches carry tags and a
one-hour revalidate; posts and pages are pre-rendered from
`generateStaticParams`. Its options are `site.config.ts` and
`menu.config.ts`; it ships vitest tests for the client, the webhook and its
helpers, and a Railway template (WordPress, MySQL and the site in Docker).

## How it maps to Cloudflare

| Vercel | Here | Why |
|---|---|---|
| Next.js hosting | One Worker built by `@opennextjs/cloudflare` (`output: 'standalone'`) with the static-assets incremental cache | The OpenNext path every Next.js baseline here shares |
| ISR: `generateStaticParams`, the data cache with tags and `revalidate: 3600`, `revalidateTag` from the webhook | Every page that reads WordPress is `force-dynamic` and fetches `no-store`; the webhook is kept, secret-checked, with nothing to clear | The static-assets cache is read-only: a page or fetch cached at build could never refresh, and every write logs an error. The R2 cache plus a tag cache would make ISR work — a bucket, a Durable Object or D1 and their wiring, for a site that renders in tens of milliseconds |
| `runtime = "edge"` on `/api/og` | The Node.js runtime under `nodejs_compat` | OpenNext runs no edge functions; next/og renders the same PNG there |
| Image Optimization | Off: `images.unoptimized` | The Worker has no optimiser; media is served from WordPress as uploaded |
| `@vercel/analytics` | The Cloudflare Web Analytics beacon, rendered only with a token | The Cloudflare equivalent; nothing to install |
| `WORDPRESS_URL` in the project's env | Inlined by `next build` from an optional Orun secret per environment | The client reads it at module load; each environment builds anyway |
| `WORDPRESS_WEBHOOK_SECRET` | A Worker secret | Read at request time by the webhook only |
| `site_domain: https://next-wp.com` | `NEXT_PUBLIC_SITE_URL` per environment | Absolute links need the origin each environment is served on |

## Unconnected: the sample site

A bootstrap cannot know its owner's WordPress, so the site must deploy and
pass its smoke without one — cms-sanity's idea. Upstream, an unset
`WORDPRESS_URL` makes every list empty; here the client answers every
request it would send from `lib/sample.ts` instead: three posts, a page, two
categories, three tags and an author, in the REST API's own shapes
(`lib/wordpress.d.ts`), with the API's own filtering (author, categories,
tags, search, slug, pagination) and its 404 for an id it does not have. The
pages render them unchanged, and the layout shows a notice — "no WordPress
site is connected yet" — linking the first post, which says how to connect
one. The sample sits behind the fetch layer, so no page knows the
difference, and once a URL is set nothing in the file is read.

## The repository

cms-sanity's shape: `apps/web` (type `cloudflare-workers-assets-turbo`,
lane `isolated`, the WordPress URL an `optionalSecretEnv`) and `tests/web`
(type `turbo-package`, a vitest suite run on the `dev` rung, holding the
template's own tests unchanged plus the sample mode and the name seam). No
infrastructure: WordPress is the owner's own site. The site's name is one
seam, `SITE_NAME` in `site.config.ts`, which the nav, footer, mobile menu
and the root title read (upstream's title, "WordPress & Next.js Starter by
9d8", now reads it too). The home page's credit to next-wp is content and
stays.

## The build

`next build` (Turbopack), `opennextjs-cloudflare build --skipBuild`, then
`populateCache local` (the pre-rendered home page and 404 into the assets).
`repo-blueprint.yaml` is cms-sanity's: one landing (`01-product`) places,
brands and lands the whole tree, one convergence builds and deploys stage
and prod side by side, and `02-docs` records what went live, probing `/`,
`/posts` (sample or connected) and the webhook. The smoke checks `/posts`
renders its count and `/api/revalidate` refuses a webhook without the
secret.

## Out of scope

- The Railway template (`wordpress/`, `Dockerfile`, `railway.json`) and the
  plugin's PHP source (`plugin/`): WordPress runs wherever its owner runs it;
  the plugin is upstream's release download.
- Draft previews and authenticated REST reads: upstream has none.

## The alternative rejected

**ISR on the R2 incremental cache with a D1 or Durable Object tag cache**,
so the webhook's `revalidateTag` would refresh cached pages as it does on
Vercel. It is the faithful port of the caching, and it costs a bucket and a
tag store per environment, their Terraform roots and wiring, and a cache that
can serve a stale page when a webhook is missed — for pages that render in
tens of milliseconds against a REST API. Rendering per request is always
fresh, needs nothing provisioned, and leaves the webhook a no-op that the
plugin can keep calling; the R2 cache stays the upgrade if a site's
WordPress is too slow to call on every visit.

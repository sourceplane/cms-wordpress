# cms-wordpress

A Next.js front end for a [WordPress](https://wordpress.org) site, used as a
headless CMS: posts, pages, categories, tags and authors are read from the
site's REST API (`/wp-json/wp/v2`), with search, filters, pagination, a
sitemap, Open Graph images and a revalidation webhook for WordPress — running
on **Cloudflare Workers + Static Assets** through
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare). It is
Vercel's [Next.js Starter for WordPress Headless CMS](https://github.com/9d8dev/next-wp)
(9d8's `next-wp`), ported to Workers.

## Live deployment

<!-- 02-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace and the secrets the site uses into
[ai/context/deployment.md](ai/context/deployment.md); how the site deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 02-docs:end -->

## Connecting WordPress

The site deploys and serves before it has a WordPress behind it: until its
build is given a WordPress URL it shows a few **sample posts**, a sample page
and their categories, tags and author, bundled with it, under a notice that
says so. To make it read your content:

1. **Have a WordPress site whose REST API answers**: `https://<your-site>/wp-json/wp/v2/posts`
   returns JSON. Any self-hosted or managed WordPress does by default; the
   site reads only published content, so it needs no credentials.
2. **Give the build its URL**, once per deployed environment. `next build`
   bakes it in, so it is stored as this repository's Orun secret
   `WORDPRESS_URL`, and stage and prod can each name their own (a staging
   WordPress for stage, say):

   ```bash
   orun secrets set WORDPRESS_URL --env stage   # prompts for the value: https://<your-site>
   orun secrets set WORDPRESS_URL --env prod
   ```

   Then **redeploy the site**: a secret is read when the site builds, and
   setting one builds nothing. Press **Deploy** on the `web` component in
   Orunbase (or see "Deploy by hand" below); the sample content and the
   notice are gone from that deploy on, and `/admin` redirects to your
   site's `wp-admin`.
3. **Images** need nothing: featured images are served as uploaded, from
   wherever your WordPress's media URLs point (`images.unoptimized` — the
   Worker has no image optimiser, so next/image passes them through).
4. **The revalidation webhook** (optional). Every page renders on every
   request, so a change you publish shows on the next visit with nothing
   else set up. The template's `next-revalidate` plugin
   ([download](https://github.com/9d8dev/next-wp/releases/latest/download/next-revalidate.zip))
   calls `/api/revalidate` when content changes; to accept it, give the
   plugin (WordPress → Settings → Next.js Revalidation: this site's URL and
   the secret) and each Worker one shared secret, a Cloudflare Worker secret
   that deploys leave alone:

   ```bash
   pnpm --filter @app/web exec wrangler secret put WORDPRESS_WEBHOOK_SECRET --name cms-wordpress-web-stage
   pnpm --filter @app/web exec wrangler secret put WORDPRESS_WEBHOOK_SECRET --name cms-wordpress-web-prod
   ```

   Without it every webhook is refused with 401, and nothing else changes.

## What is here

| Surface | Where |
|---|---|
| Home, `/posts` (search, filters, pagination), `/posts/[slug]`, `/pages`, `/pages/[slug]`, the category, tag and author lists | `apps/web/app` |
| The WordPress REST client, its types | `apps/web/lib/wordpress.ts`, `apps/web/lib/wordpress.d.ts` |
| The sample content an unconnected site shows, and its notice | `apps/web/lib/sample.ts`, `apps/web/components/unconnected-notice.tsx` |
| The revalidation webhook, the Open Graph image, the sitemap | `apps/web/app/api/revalidate`, `apps/web/app/api/og`, `apps/web/app/sitemap.ts` |
| The site's name, description and origin; the menus | `apps/web/site.config.ts`, `apps/web/menu.config.ts` |
| Components (craft, shadcn/ui), the theme toggle | `apps/web/components` |
| Workers build and deploy contract | `apps/web/next.config.ts`, `open-next.config.ts`, `wrangler.jsonc`, `component.yaml` |
| Tests | `tests/web` (vitest) |

## Getting started

```bash
pnpm install
pnpm typecheck
pnpm lint
pnpm test
pnpm build            # next build + opennextjs-cloudflare build → apps/web/.open-next
```

That needs no WordPress, and is what to run before you push: a pull request
builds the site but does not lint or run its tests. With a WordPress:

```bash
cd apps/web
cp .env.example .env.local        # WORDPRESS_URL=https://<your-site>
cd ../..
pnpm --filter @app/web dev        # http://localhost:3000
```

For the Worker locally, the URL is read at build time and the webhook secret
is a Worker secret:

```bash
cd apps/web
cp .dev.vars.example .dev.vars    # WORDPRESS_WEBHOOK_SECRET=<a shared secret>
WORDPRESS_URL=https://<your-site> pnpm build
pnpm preview                      # wrangler dev over the built Worker
```

| Variable | Read | What it does |
|---|---|---|
| `WORDPRESS_URL` | build time | The WordPress site. Deployed builds take it from the `WORDPRESS_URL` secret of their environment. Unset, the site is unconnected: sample content and a notice. |
| `WORDPRESS_HOSTNAME` | build time | The template's next/image allow-list for media; the URL's own when unset. Inert while images are unoptimised. |
| `NEXT_PUBLIC_SITE_URL` | build time | The site's origin for absolute links (the sitemap, canonical and Open Graph links). The deploy sets it per environment. |
| `WORDPRESS_WEBHOOK_SECRET` | request time, in the Worker | The secret `/api/revalidate` checks. Optional. |
| `NEXT_PUBLIC_CF_BEACON_TOKEN` | build time | Optional Cloudflare Web Analytics token. Unset, no script is rendered. |

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. The site builds once per
environment, with that environment's WordPress URL and origin, and deploys —
to `stage`, then to `prod` once stage has converged on the same commit;
`dev` only verifies. The Worker is `cms-wordpress-web-<env>` on your account's
workers.dev subdomain, and every deploy is smoke-tested over HTTP: the posts
page must render its count and the revalidation webhook must refuse a
request without the secret. A pull request runs the same pipeline's verify
lanes: the site built and dry-deployed for each environment, with nothing
deployed. They do not lint or run the tests, so run `pnpm typecheck`,
`pnpm lint` and `pnpm test` before you push. (A push to `main` builds,
deploys and smoke-tests.)

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare token and account id are brokered per run from the workspace's
Cloudflare connection; nothing provider-shaped is stored in the repository
or in GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick, and each one deploys
exactly as a merge would deploy it. Leave the component blank to redeploy
every component in that environment, with nothing changed: after setting
`WORDPRESS_URL`, say. A component with nothing to run in that environment (a
test suite in `prod`) is left out with a notice.

## Custom domain

The site answers on workers.dev from its first deploy. To serve it on your
own domain:

1. Add the domain to the Cloudflare account the site deploys into, and attach
   it to the Worker (dashboard → Workers & Pages →
   `cms-wordpress-web-prod` → Settings → Domains & Routes → Add →
   Custom domain).
2. Set the environment's public origin in `intent.yaml`, so the next deploy
   builds the site's absolute links for it — the sitemap, canonical and Open
   Graph links (until then they use the workers.dev URL):

   ```yaml
   environments:
     prod:
       env:
         SITE_URL: https://cms-wordpress.example.com
   ```

   The site was born with the reserved placeholder
   `cms-wordpress.example.com` where its domain goes: that example, and
   `BASE_DOMAIN` under each environment in `intent.yaml`. Replace it with
   your domain in the same change, and land it with a change under
   `apps/web` so the merge rebuilds the site. Then point the
   `next-revalidate` plugin at the new origin, if you use it.

## Credits

The site is 9d8's [next-wp](https://github.com/9d8dev/next-wp) (MIT —
`apps/web/LICENSE`), the template Vercel lists as its Next.js Starter for
WordPress Headless CMS.

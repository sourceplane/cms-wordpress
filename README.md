# cms-wordpress

Vercel's [Next.js Starter for WordPress Headless CMS](https://github.com/9d8dev/next-wp)
(9d8's `next-wp`) — posts, pages, categories, tags and authors read from a
WordPress site's REST API through one typed client, with search, filters and
pagination, a sitemap, Open Graph images, shadcn/ui and light and dark
themes, and a revalidation webhook for WordPress's next-revalidate plugin —
running on **Cloudflare Workers + Static Assets** through
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare), and
packaged as an **Orun baseline**: one command takes a new site from nothing
to live on stage and prod, in its own repository, under its own name — in
ONE landing.

The template's code is the code and WordPress stays the owner's own site.
What the port adds is the Workers build, the monorepo wrapper, a test
package and the deploy contract; what it changes is what Workers force:
every page renders on request and reads WordPress afresh instead of ISR on a
read-only cache, the Open Graph image runs on the Node.js runtime instead of
the edge, images are served unoptimised, and Vercel Analytics becomes the
Cloudflare Web Analytics beacon — and what makes it deployable before its
owner has connected a WordPress: an unconnected build renders bundled sample
posts under a visible notice instead of empty lists. What the baseline adds
is everything needed to make a copy of it somebody else's — built the way
[cirrus-baseline](https://github.com/sourceplane/cirrus-baseline) is. See
[`specs/epics/cms-wordpress`](specs/epics/cms-wordpress/README.md) for the
design, the milestones and the as-built status.

## Instantiating a site

```bash
git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/cms-wordpress
cd cms-wordpress
orun new --blueprint repo-blueprint.yaml --out ~/sites/acme-notes --run-hooks --resume \
  --set reponame=acme-notes --set productname="Acme Notes" \
  --set githuborg=acme-inc --set subdomain=<workers-dev-subdomain>
```

Or, once the platform's registry lists it, from the Orun console (Baselines →
`cms-wordpress` → Build). Two phases — `01-product` (the repository, its CI
and the whole site in one pull request, deployed to stage and prod by one
convergence, smoke-tested) and `02-docs` (the live deployment recorded) —
each landing one pull request in the new repository.
**[BOOTSTRAP.md](BOOTSTRAP.md)** is the operator guide;
[docs/phases/](docs/phases/README.md) has a page per phase.

The new repository receives the **site only** — the app, its tests, its CI,
its tooling, a README of its own and its operating contract — renamed
throughout to the site's name, repository and Cloudflare Worker. None of
this repository's machinery ships, and nothing that ships names it.

The only provider the bootstrap asks for is Cloudflare. **WordPress is not a
provider the platform brokers**, so the site is built without it and its
owner connects one afterwards: one optional Orun secret (`WORDPRESS_URL`)
and a redeploy, and — for the revalidation webhook only — a Worker secret
`WORDPRESS_WEBHOOK_SECRET`. The site's README, "Connecting WordPress"
(`.baseline/product/README.md` here), has the steps.

| What makes it a baseline | Where |
|---|---|
| The console card (inputs, secrets, programme) | `blueprint.yaml` |
| The build document (modules, phases, hooks) | `repo-blueprint.yaml` |
| This tree's identity, and the bootstrap's task contracts | `.baseline/` |
| The rename engine | `tooling/rebrand/rebrand.mjs` |
| The bootstrap's helpers (deferrals, redeploy marker, work-tree strip) | `tooling/bootstrap/` |
| The deployment-record renderer | `hooks/render-deployment-docs.sh` |
| The site's README and context pack | `.baseline/product/README.md`, `ai/context/` |
| The baseline's tests: contract, leak, offline bootstrap, end to end | `testing/`, `.github/workflows/baseline.yml` |
| Cutting a `baseline-vN` tag | `.github/workflows/tag.yml` |

## What is here (the site)

| Surface | Where |
|---|---|
| Home, `/posts` (search, filters, pagination), `/posts/[slug]`, `/pages`, `/pages/[slug]`, the category, tag and author lists | `apps/web/app` |
| The WordPress REST client and its types | `apps/web/lib/wordpress.ts`, `apps/web/lib/wordpress.d.ts` |
| The sample content an unconnected site renders, and its notice | `apps/web/lib/sample.ts`, `apps/web/components/unconnected-notice.tsx` |
| The revalidation webhook, the Open Graph image, the sitemap | `apps/web/app/api/revalidate`, `apps/web/app/api/og`, `apps/web/app/sitemap.ts` |
| The site's name (the rename's seam), description and origin | `apps/web/site.config.ts` |
| Workers build and deploy contract | `apps/web/next.config.ts`, `open-next.config.ts`, `wrangler.jsonc`, `component.yaml` |
| Tests (the template's own, plus the sample mode and the name seam) | `tests/web` (vitest) |

## Getting started

```bash
pnpm install
pnpm typecheck
pnpm lint
pnpm test
pnpm build            # next build + opennextjs-cloudflare build → apps/web/.open-next
pnpm --filter @app/web preview   # wrangler dev over the built Worker: the sample site, unconnected
```

That much needs no WordPress, and it is what to run before a push: a pull
request builds and dry-deploys the site, and does not lint or run the tests.
To see your own content:

```bash
cd apps/web
cp .env.example .env.local        # WORDPRESS_URL=https://<your-site>
cd ../..
pnpm --filter @app/web dev        # http://localhost:3000
```

| Variable | Where it is read | What it does |
|---|---|---|
| `WORDPRESS_URL` | build time (`next build` inlines it into the server bundle) | The WordPress site. A deployed build takes it from its environment's `WORDPRESS_URL` secret, best-effort. Unset, the site is unconnected: the sample content under a notice. |
| `WORDPRESS_HOSTNAME` | build time | The template's next/image allow-list for media; the URL's own when unset. Inert while images are unoptimised. |
| `NEXT_PUBLIC_SITE_URL` | build time | The origin of the sitemap, canonical and Open Graph links; the deploy sets it per environment (`SITE_URL`, else the workers.dev URL). |
| `WORDPRESS_WEBHOOK_SECRET` | request time, in the Worker | The secret `/api/revalidate` checks. A Worker secret in stage/prod, `.dev.vars` locally. Optional: without it every webhook is refused with 401. |
| `NEXT_PUBLIC_CF_BEACON_TOKEN` | build time | Optional. Cloudflare Web Analytics token. Unset, no script is rendered. |

## How it maps to Vercel

| Vercel | Here |
|---|---|
| Next.js hosting (posts and pages pre-rendered by `generateStaticParams`, a data cache with tags and a one-hour revalidate, route handlers) | One Cloudflare Worker (`.open-next/worker.js`) + Static Assets; every page that reads WordPress renders on request (`force-dynamic`, fetches `no-store`), the home page and the 404 are pre-rendered and served from the static-assets cache |
| On-demand revalidation (`/api/revalidate` → `revalidateTag`, called by the next-revalidate plugin) | The route is kept and checks its secret as before; there is no cache for it to clear, because nothing is cached — a published change shows on the next visit |
| `export const runtime = "edge"` on `/api/og` | The Node.js runtime under `nodejs_compat` (OpenNext runs no edge functions); next/og renders the same PNG |
| Image Optimization (`next/image`, WordPress's host allowed) | Off (`images.unoptimized`): the Worker has no optimiser, media is served from WordPress as uploaded |
| `@vercel/analytics` | Cloudflare Web Analytics beacon (`components/analytics.tsx`) |
| Project env vars in the dashboard (`WORDPRESS_URL`, `WORDPRESS_HOSTNAME`, `WORDPRESS_WEBHOOK_SECRET`) | Build time: the URL from an optional Orun secret per environment, inlined by `next build`. Run time: the webhook secret as a Worker secret |
| No `WORDPRESS_URL`: empty lists | An unconnected site: sample posts, a page, terms and an author, under a notice — deployable before a WordPress is connected |
| `site_domain: "https://next-wp.com"` | `NEXT_PUBLIC_SITE_URL`, set per environment by the deploy: its `SITE_URL`, else its workers.dev URL |
| The Railway template (WordPress, MySQL and the site in Docker) | Not carried: WordPress is the owner's own, wherever it runs; the plugin is upstream's release download |
| Deploy on push | Orun deploys `<repo>-web-{stage,prod}` on merge to `main` and smoke-tests it (`apps/web/component.yaml`) |
| "Deploy with Vercel" (clone the template) | `orun new --blueprint repo-blueprint.yaml` — a new repository, branded, deployed |

## CI

| Workflow | What it runs | Ships to a site |
|---|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow a site carries: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (the site built and dry-deployed per environment; they do not lint or run the tests), except the bootstrap's own landings (`orun/BASE-*`), where `plan` alone is the check; a merge deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the environment and components it names under the push-to-main trigger, so they deploy as a merge deploys them | yes |
| `baseline.yml` | the baseline's own tiers: contract tests and the component docs' drift check, the blueprint read by the pinned orun, the leak gate, the offline bootstrap, each landing installed, its fixture rendered, type-checked, linted, tested and built, then the site built in a staged job tree, dry-deployed and served with no WordPress behind it | no |
| `tag.yml` | cuts a `baseline-vN` tag (manual) | no |

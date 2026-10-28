# cms-wordpress — implementation status

| Milestone | State | Landed |
|---|---|---|
| WP0 — the spec | ✅ | the repository's first commit |
| WP1 — the site on Workers | ✅ | WP-2 |
| WP2 — a baseline | planned | WP-3 |

## Departures from the upstream template

Everything not listed here is the template as it is upstream at `4a2caeb`.

| # | What | Why |
|---|---|---|
| 1 | The app lives in `apps/web` of a pnpm workspace; the Railway template (`wordpress/`, `Dockerfile`, `.dockerignore`, `railway.json`), the plugin's PHP source (`plugin/`), `vercel.json`, upstream's workflows and agent notes, the legacy `.eslintrc.json` and its lockfile are not carried | WordPress is the owner's own; the plugin is upstream's release download; the workspace has one lockfile |
| 2 | `package.json`: Next 16.3.0 → 16.3.8 (and `eslint-config-next` with it); `@opennextjs/cloudflare` and `wrangler` added; `@vercel/analytics` removed; vitest moved to `tests/web`; `build` adds `opennextjs-cloudflare build --skipBuild` and `populateCache local`; `preview` and `typecheck` added; `packageManager` and `engines` dropped | The workspace's toolchain (pnpm 10.12.1, Node 22) and its `typecheck` / `lint` / `test` / `build` contract; 16.3.8 is the 16.3 patch OpenNext 1.20.13 builds |
| 3 | `next.config.ts`: `output: 'standalone'` always, `outputFileTracingRoot` at the workspace root, `images.unoptimized`, `WORDPRESS_URL` inlined through `env`, the image host derived from the URL when `WORDPRESS_HOSTNAME` is unset | OpenNext builds from the standalone output; the Worker has no image optimiser; the URL is a build-time value here |
| 4 | Every page that reads WordPress, and the sitemap, is `force-dynamic`; `generateStaticParams` is gone from `posts/[slug]` and `pages/[slug]` | The static-assets incremental cache is read-only: nothing pre-rendered from WordPress could refresh |
| 5 | `lib/wordpress.ts`: fetches are `cache: "no-store"` (the tags kept); with no `WORDPRESS_URL` every request is answered from `lib/sample.ts` instead of an empty list; `isWordPressConfigured` exported | The data cache would look up and fail to write a read-only cache on every request; an unconnected site must render |
| 6 | `lib/sample.ts` and `components/unconnected-notice.tsx` (new); the layout renders the notice | The sample site and its notice |
| 7 | `app/api/og/route.tsx`: `runtime = "edge"` removed | OpenNext runs no edge functions; next/og renders under `nodejs_compat` |
| 8 | `app/layout.tsx`: `@vercel/analytics` → `components/analytics.tsx` (the Cloudflare Web Analytics beacon); the title is `siteConfig.site_name` (was "WordPress & Next.js Starter by 9d8") | The Cloudflare equivalent; one rename seam |
| 9 | `site.config.ts`: `SITE_NAME` is `site_name`; `site_domain` is `NEXT_PUBLIC_SITE_URL` | One rename seam; the origin per environment |
| 10 | `tsconfig.json` and `eslint.config.mjs` ignore `.open-next` and `.wrangler` (and the missing `wp.config.ts` leaves the include list); `types/images.d.ts` declares `*.svg` | Build output is not source; a fresh tree has no `next-env.d.ts` before its first build |
| 11 | `.env.example` says which variables are build-time and which are Worker secrets; `.dev.vars.example` (new) | Workers read runtime secrets from the Worker, not the build |
| 12 | `open-next.config.ts`, `wrangler.jsonc`, `component.yaml` (new) | The Workers build and the deploy contract |
| 13 | The template's `__tests__` run from `tests/web/src`, unchanged; `site.test.ts` and `unconnected.test.ts` added | The workspace's test package; the seam and the sample mode are this port's |

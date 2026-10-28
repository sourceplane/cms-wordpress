# cms-wordpress — operating contract (for humans and agents)

This is the standing guide to how this site is deployed and operated.
Instance facts (live URLs, workspace, the secrets it uses) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `02-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the site without any
other source.

## What this system is

A Next.js front end for a WordPress site used as a headless CMS, served from
Cloudflare, expressed as an Orun component-native desired-state repo.

- **`apps/web`** — Next.js built by `@opennextjs/cloudflare` into one Worker
  plus Static Assets. Every page that shows WordPress content — `/posts`
  (search, filters, pagination), `/posts/<slug>`, `/pages`, `/pages/<slug>`,
  the category, tag and author lists, `/sitemap.xml` — renders per request
  and reads the WordPress REST API afresh (`no-store`); the home page and the
  404 are pre-rendered static assets. `/api/og` renders Open Graph images;
  `/api/revalidate` is the webhook WordPress's next-revalidate plugin calls.
- **`tests/web`** — vitest over the WordPress client (a stubbed REST API and
  the sample site), the revalidation webhook, metadata, utilities and the
  site's name. No lane lints or runs the tests: a pull request builds and
  dry-deploys the site, so run `pnpm typecheck && pnpm lint && pnpm test`
  before you push.
- **`tooling/*`** — shared TypeScript and ESLint configuration, and the
  wrangler renderer for a deployable that comes to take wiring.

There is no infrastructure component: WordPress is the owner's site, read
over HTTPS, not something this repository provisions.

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — lanes build and dry-deploy, nothing deploys.

## WordPress: connected, or sample content

The site reads ONE WordPress, fixed at build time (`next build` inlines
`WORDPRESS_URL`). Until a build has a URL it is **unconnected**: every page
renders the sample posts, page, categories, tags and author bundled in
`apps/web/lib/sample.ts`, answered in the REST API's own shapes, under a "no
WordPress site is connected" notice. Nothing fails: an unconnected site
deploys, passes its smoke test and serves.

To connect it, per deployed environment:

```bash
# 1. the WordPress URL (the next build reads it)
orun secrets set WORDPRESS_URL --env stage    # prompts for the value: https://<the-wordpress>
# …and the same with --env prod

# 2. redeploy apps/web: the URL is read when it BUILDS, and setting a secret
#    builds nothing. Orunbase's Deploy button on `web`, or
gh workflow run ci.yml --ref main -f environment=stage -f component=web

# 3. the revalidation webhook (optional): one shared secret, in the
#    next-revalidate plugin's settings and as a Worker secret (Cloudflare's,
#    not Orun's — the deploy never touches it, so it survives deploys)
pnpm --filter @app/web exec wrangler secret put WORDPRESS_WEBHOOK_SECRET --name cms-wordpress-web-stage
```

The URL is read best-effort (`optionalSecretEnv` in
`apps/web/component.yaml`): a key nobody has stored is skipped, never a
failed lane. A wrong URL is not caught at build: the lists then render empty
("0 posts found") and a post's page 404s, so probe `/posts` after
connecting. Once connected, `/admin` redirects to the WordPress's
`wp-admin`.

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. `apps/web` checks its committed `wrangler.jsonc` is there, builds once per
   environment with that environment's WordPress URL (if any) and origin
   (`NEXT_PUBLIC_SITE_URL`: the environment's `SITE_URL`, else its
   workers.dev URL), `wrangler deploy` ships `cms-wordpress-web-<env>`, and a
   smoke test fetches `/posts` and requires its count ("N posts found"),
   then requires `/api/revalidate` to refuse a webhook without the secret
   (401) — proof the Worker's server code answers.
4. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
5. **The convergence run is the deployment.** A green run means every
   planned lane passed. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

On a pull request nothing deploys: the site builds and dry-deploys.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "site
  converged"; probe the URLs instead.
- Published content needs no deploy: the site reads WordPress on every
  request, so a published post shows on the next visit. Nothing is cached in
  the Worker, so `/api/revalidate` has nothing to clear; it is kept for the
  plugin and answers 200 once its secret matches.
- A change to `intent.yaml`'s `environments`, or to an Orun secret, maps to
  no component and redeploys nothing on its own. Land it with a change under
  `apps/web`.

## Secrets model

- **Brokered provider secrets**: `CLOUDFLARE_API_TOKEN` (the
  `workers-deploy` scope) and `CLOUDFLARE_ACCOUNT_ID` — pointers minted per
  run from the workspace's Cloudflare connection. No long-lived values at
  rest; nothing to rotate by hand.
- **The WordPress URL**: `WORDPRESS_URL` on `stage` and `prod`, stored by
  the owner, read by the build. Not a credential (the site reads published
  content only), kept as a secret so each environment can name its own.
- **The webhook secret**: `WORDPRESS_WEBHOOK_SECRET`, a Worker secret per
  environment, read at request time by `/api/revalidate` only.
- Inspect by NAME only: `orun secrets list --org <ws> --env stage|prod`. No
  tooling in this repository prints a secret value, and no document in
  `ai/context/` may contain one.

## Verifying the system

```bash
# the site on each environment (also recorded, probed, in deployment.md);
# an unconnected site carries data-wordpress="unconnected"
curl -s https://cms-wordpress-web-stage.your-workers-subdomain.workers.dev/posts | grep -Eo 'data-wordpress="[a-z]*"|[0-9]+(<!-- -->)? (<!-- -->)?posts?(<!-- -->)? found'
curl -s -o /dev/null -w '%{http_code}\n' -X POST -d '{}' https://cms-wordpress-web-prod.your-workers-subdomain.workers.dev/api/revalidate   # 401

# workspace readiness
orun secrets list --org <ws> --env stage && orun secrets list --org <ws> --env prod
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| connect a WordPress | "WordPress: connected, or sample content" above |
| write, edit, publish | in WordPress (`/admin` redirects there once connected); no deploy needed |
| change the site's code | edit `apps/web` (its name: `SITE_NAME` in `apps/web/site.config.ts`; its menus: `apps/web/menu.config.ts`), merge |
| read more of WordPress (a custom post type, a field) | a function in `apps/web/lib/wordpress.ts` and its type in `wordpress.d.ts`, and an answer for it in `apps/web/lib/sample.ts` so an unconnected build still renders |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| deploy by hand | Orunbase's Deploy button, or `gh workflow run ci.yml --ref main -f environment=<env> [-f component=<a,b>]` — the named components (blank: every one) run in that environment as a merge runs them; started off `main` it is refused |
| redeploy without a change | edit the last line of `apps/web/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| serve a custom domain | attach it to the Worker in Cloudflare and set `SITE_URL` for the environment in `intent.yaml` — the next deploy builds the site's links for it (README, "Custom domain") — then replace the placeholder `cms-wordpress.example.com` in `intent.yaml`'s `BASE_DOMAIN` with it |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `02-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 02-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

Structural changes follow the same contract that deployed the site: add a
component under `apps/`, `infra/` or `packages/` with a `component.yaml`,
land it as a pull request, and the convergence run deploys it. A component
under `infra/` whose wiring the Worker reads is declared in `apps/web`'s
`dependsOn` (enforced on `main`), so it is applied first.

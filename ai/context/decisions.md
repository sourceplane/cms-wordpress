# cms-wordpress — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | Next.js on Workers + Static Assets through `@opennextjs/cloudflare`, with the static-assets incremental cache | The OpenNext path every Next.js baseline here shares; the cache serves the pre-rendered home page and 404 with no binding | `specs/epics/cms-wordpress/design.md` |
| 2 | Next 16.3.8, the template's 16.3 line | OpenNext 1.20.13 builds it; 16.4 is avoided | IMPLEMENTATION-STATUS (departures) |
| 3 | Every page that reads WordPress is `force-dynamic`, its fetches `no-store`; no ISR, no tag cache | The static-assets cache is read-only; the R2 cache plus a tag cache is provisioning for pages that render in milliseconds | design, "The alternative rejected"; risk WP-D |
| 4 | `/api/revalidate` is kept, secret-checked, with nothing to clear | The plugin keeps calling it, and an ISR upgrade would need it as is | risk WP-E |
| 5 | Unconnected, the client answers from `lib/sample.ts` in the REST API's shapes, under a notice | A bootstrap knows no WordPress; the site must deploy, pass its smoke and show what it is | design, "Unconnected: the sample site" |
| 6 | `WORDPRESS_URL` is an optional Orun secret per environment, inlined at build | The client reads it at module load; a key nobody stored is skipped, never a failed lane | `apps/web/component.yaml` |
| 7 | The webhook secret is a Worker secret set by hand; nothing for WordPress is brokered | Read at request time; no platform connection knows the owner's WordPress | operations.md |
| 8 | `/api/og` on the Node.js runtime | OpenNext runs no edge functions | risk WP-G |
| 9 | Images unoptimised (`images.unoptimized`) | The Worker has no image optimiser | risk WP-F |
| 10 | The site's name is one seam, `SITE_NAME` in `apps/web/site.config.ts`, which the root title reads too | The rename rewrites one literal | IMPLEMENTATION-STATUS (departures) |
| 11 | `site_domain` is `NEXT_PUBLIC_SITE_URL`, set per environment by the deploy (its `SITE_URL`, else its workers.dev URL) | The sitemap, canonical and Open Graph links are absolute | `apps/web/component.yaml` |
| 12 | The Railway template and the plugin's source are not carried | WordPress runs wherever its owner runs it; the plugin is upstream's download | IMPLEMENTATION-STATUS (departures) |
| 13 | No custom-domain phase: a domain is the owner's step, and `SITE_URL` points the build at it | The brokered `workers-deploy` token has no zone scope | README, "Custom domain" |
| 14 | One landing (`01-product`) then the record (`02-docs`), each checked in the build box | A landing has a fixed cost; the convergence on main builds, deploys and smoke-tests the site for real | `docs/phases/README.md` |
| 15 | `ci.yml` plans nothing while `intent.yaml` names `ws_CHANGE_ME`; no Checks workflow | A bootstrap cannot set a repository variable; a push to main must start `ci.yml` alone | `.github/workflows/ci.yml` |
| 16 | stack-tectonic 0.19.0, not 0.20.0 | 0.20.0's lane-shared install links `node_modules` out of the job's tree | risk WP-I |
| 17 | Component docs are generated from the manifests and checked in CI | A hand-written copy drifts silently | `tooling/catalog/gen-component-docs.py` |
| 18 | `subdomain` is read from the Cloudflare connection, never asked; the console asks for no domain | Both belong to the account or the owner, not to the build | `blueprint.yaml` |

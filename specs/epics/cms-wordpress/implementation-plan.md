# cms-wordpress — implementation plan

Three milestones, each one reviewed pull request (WP0 is the repository's
first commit), each green before it merges.

## WP0 — the spec (WP-1)

The repository is born: `intent.yaml` with the placeholder workspace
`ws_CHANGE_ME`, `ci.yml` (byte for byte turso-starter's, which plans nothing
until the workspace is set), the shared TypeScript and ESLint configuration,
the spec index, this doc set and the task contracts.

## WP1 — the site on Workers (WP-2)

- The template's `app/`, `components/`, `lib/`, `public/` and configuration
  in `apps/web`; its dependencies, with `@opennextjs/cloudflare` and
  `wrangler`, without `@vercel/analytics`; Next 16.3.8.
- `next.config.ts`: `output: 'standalone'`, the workspace root for the
  trace, images unoptimised, `WORDPRESS_URL` inlined. `open-next.config.ts`
  with the static-assets incremental cache; `wrangler.jsonc`.
- Every page that reads WordPress `force-dynamic`, the client's fetches
  `no-store`, `/api/og` on the Node.js runtime.
- The sample site (`lib/sample.ts`) behind the client, and the notice.
- `SITE_NAME` in `site.config.ts`, `site_domain` from
  `NEXT_PUBLIC_SITE_URL`; the Cloudflare Web Analytics beacon.
- `component.yaml`: the deploy contract (the origin per environment, the
  optional `WORDPRESS_URL`) and its smoke. `tests/web`: the template's own
  tests, the sample mode, the name and the origin.
- The README's "How it maps to Vercel" and "Connecting WordPress".

## WP2 — a baseline (WP-3)

cms-sanity's machinery, renamed: `blueprint.yaml`, `repo-blueprint.yaml`,
`.baseline/` (identity, the product's README with "Connecting WordPress" and
"Deploy by hand", task contracts), `tooling/rebrand`, `tooling/bootstrap`,
`hooks/render-deployment-docs.sh` (probing `/`, `/posts` and the webhook),
`docs/phases/`, the context pack, `testing/` (the leak and placement gates
on this tree's files; the e2e tier reading every route the site promises,
unconnected) and `baseline.yml` / `tag.yml`.

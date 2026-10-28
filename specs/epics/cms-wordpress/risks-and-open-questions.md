# cms-wordpress — risks and open questions

| ID | Risk | State | Notes |
|---|---|---|---|
| WP-A | `baseline-v1` is not yet proven live | OPEN | Proven offline in Baseline CI: the offline bootstrap with the blueprint's own hooks, the stage lane's own steps in a staged job tree, the site served by `wrangler dev` and smoke-tested with the component's own command, unconnected. A console bootstrap closes it |
| WP-B | Worker size | WATCH | About 10 MiB raw and 2.8 MiB gzipped, against Workers Free's 3 MiB — most of it next/og's WebAssembly (resvg, yoga) for `/api/og`. A dependency that grows it past 3 MiB needs Workers Paid (or `/api/og` dropped). Every pull request's dry run prints it |
| WP-C | Connected to a real WordPress | OPEN | The client is the template's, tested against a stubbed REST API by the template's own tests, and the sample mode answers in the API's shapes; no build has yet read a live WordPress. Connecting one (the README's steps) closes it |
| WP-D | Every page reads WordPress on every request | ACCEPTED | No ISR (design, "The alternative rejected"). Each page view costs a few REST calls to WordPress — a slow or rate-limited WordPress makes a slow site. The R2 incremental cache plus a tag cache is the upgrade, and the webhook already calls `revalidateTag` |
| WP-E | `/api/revalidate` clears nothing | ACCEPTED | Kept for the plugin, secret-checked as upstream; there is no cache for it to clear |
| WP-F | Images are not optimised | ACCEPTED | `images.unoptimized`; WordPress already serves sized variants. Cloudflare Images through OpenNext's `IMAGES` binding is the upgrade |
| WP-G | `/api/og` on the Node.js runtime instead of the edge | ACCEPTED | OpenNext runs no edge functions; the PNG is the same, checked by the e2e tier |
| WP-H | A wrong `WORDPRESS_URL` is not caught at build | ACCEPTED | The client degrades as upstream: lists render empty, a post 404s. The deployment record and the README say to probe `/posts` after connecting |
| WP-I | stack-tectonic 0.19.0, not 0.20.0 | ACCEPTED | 0.20.0's lane-shared install links each job's `node_modules` out of its tree, which Turbopack refuses |

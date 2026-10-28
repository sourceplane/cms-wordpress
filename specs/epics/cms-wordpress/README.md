# cms-wordpress — Vercel's Next.js Starter for WordPress Headless CMS on Cloudflare Workers

**9d8's next-wp — a Next.js front end that reads a WordPress site's REST
API — built by OpenNext into one Cloudflare Worker with Static Assets, every
page rendered on request against WordPress, deployed by Orun to stage and
prod on every merge, serving sample content until a WordPress is connected —
and the baseline that makes a copy of it somebody else's site in one
landing.**

| | |
|---|---|
| Status | ✅ Shipped (`baseline-v1`) — proven offline in Baseline CI; not yet live (risk WP-A) |
| Upstream | [9d8dev/next-wp](https://github.com/9d8dev/next-wp) (MIT), at `4a2caeb` (2026-08-06) — Vercel's Next.js Starter for WordPress Headless CMS |
| Reference | [cms-sanity](https://github.com/sourceplane/cms-sanity) — the same scaffolding, tests and bootstrap, and the unconnected sample mode; [portfolio-starter-kit](https://github.com/sourceplane/portfolio-starter-kit) — the origin per environment |
| Key | `WP` |

## Read in this order

1. [design.md](design.md) — the template, how each Vercel piece maps to
   Cloudflare, the unconnected sample mode, the repository and the build,
   and the alternative rejected.
2. [implementation-plan.md](implementation-plan.md) — the milestones and
   what each one lands.
3. [risks-and-open-questions.md](risks-and-open-questions.md) — what is not
   proven, and what was accepted.
4. [IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md) — what shipped, and
   every departure from the upstream template.

## Milestones

| Milestone | What it lands | Task |
|---|---|---|
| WP0 — the spec | the repository, its intent, CI, tooling and spec index; this doc set | WP-1 |
| WP1 — the site on Workers | the template in `apps/web`, built by OpenNext into one Worker, its sample mode; `tests/web` | WP-2 |
| WP2 — a baseline | the console card, the build document, the context pack and the baseline's tests | WP-3 |

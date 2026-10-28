# cms-wordpress — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a site built from it; the
two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

Vercel's Next.js Starter for WordPress Headless CMS (9d8dev/next-wp) — a
Next.js front end that reads a WordPress site's REST API: posts, pages,
categories, tags and authors, with search, filters, pagination, a sitemap,
Open Graph images and a revalidation webhook — built by OpenNext into one
Cloudflare Worker with Static Assets, packaged as an Orun baseline:
`orun new --blueprint repo-blueprint.yaml` builds a new site in its own
repository and takes it to live on stage and prod in one landing
(`01-product`), then records what went live (`02-docs`). It deploys before
its owner has connected a WordPress: unconnected, the site serves bundled
sample content under a "no WordPress site is connected" notice. There is no
infra component; WordPress stays the owner's.

## Release

| | |
|---|---|
| Latest tag | `baseline-v2` — WP3: the console card reads with the platform's own reader (an inline list item no longer carries an apostrophe and a comma) |
| Before it | `baseline-v1` — WP0 to WP2: the repository, the site on Workers with its sample mode, and the baseline (blueprint, phases, tests); its card is refused by the platform's reader |
| Proven live | Not yet: proven offline in Baseline CI only, unconnected (risk WP-A); no build has read a live WordPress yet (risk WP-C) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/cms-wordpress/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/cms-wordpress/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/cms-wordpress/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What the components are | `apps/web/docs/`, `tests/web/docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one site from `baseline-v1` from the console and record its
   timings against the 12-minute estimate (closes WP-A); then the registry
   row goes public with the measured minutes.
2. Connect a WordPress to it, see the samples give way, and post through
   the next-revalidate plugin once (closes WP-C).

# Epics

Orun-style work programs. Each epic is a folder carrying `epic.yaml` (the
declaration the platform reads: slug, key prefix, milestones with exit
criteria and task keys) beside its doc set. The pull request that adds the
folder is the adoption; the merge creates the epic in the workspace.

| Epic | Cluster | Status | What it is |
|------|---------|--------|------------|
| [`cms-wordpress/`](./cms-wordpress/) | **WP** | In progress (WP1: the site on Workers) | Vercel's Next.js Starter for WordPress Headless CMS — 9d8's next-wp, posts, pages and terms from a WordPress REST API — on Cloudflare Workers + Static Assets through OpenNext, serving sample content until a WordPress is connected, and an Orun baseline that instantiates it (WP2) |

As-built ≠ intent: what shipped lives in each epic's `IMPLEMENTATION-STATUS.md`.

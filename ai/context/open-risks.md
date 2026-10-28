# cms-wordpress — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted and resolved ones, is
`specs/epics/cms-wordpress/risks-and-open-questions.md`; this page lists
only what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| WP-A | `baseline-v1` is not yet proven live; it is proven offline in Baseline CI (the offline bootstrap, the stage lane's own steps, the site served and smoke-tested, unconnected) | OPEN | One console bootstrap from `baseline-v1` |
| WP-B | The Worker is about 2.8 MiB gzipped (most of it next/og's WebAssembly), against Workers Free's 3 MiB | WATCH | Holds while dependencies stay as they are; every pull request's dry run prints the size |
| WP-C | No build has read a live WordPress; the client is tested against a stubbed REST API | OPEN | Connect a WordPress to a bootstrapped site |

Accepted, and worth knowing before you change them: WP-D (every page reads
WordPress on every request), WP-E (the webhook clears nothing), WP-F
(images are not optimised), WP-G (`/api/og` on the Node.js runtime), WP-H
(a wrong URL is not caught at build), WP-I (stack-tectonic 0.19.0).

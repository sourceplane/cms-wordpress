import type { NextConfig } from "next";
import path from "node:path";

// The WordPress site the pages read: its URL, stored per environment as the
// product's WORDPRESS_URL secret and handed to the build (component.yaml's
// optionalSecretEnv). Unset, the site is not connected yet and renders the
// bundled sample content (lib/sample.ts). The hostname, for next/image, is
// WORDPRESS_HOSTNAME when given, else the URL's own.
const wordpressUrl = process.env.WORDPRESS_URL || "";
const wordpressHostname =
  process.env.WORDPRESS_HOSTNAME || (wordpressUrl ? new URL(wordpressUrl).hostname : "");

const nextConfig: NextConfig = {
  // Inlined into the server bundle at build time: the Worker reads no
  // environment for it at request time.
  env: {
    WORDPRESS_URL: wordpressUrl,
  },
  // Required by @opennextjs/cloudflare, which bundles `.next/standalone/**`
  // into the Worker. Trace from the monorepo root so workspace dependencies
  // resolve from the root node_modules.
  output: "standalone",
  outputFileTracingRoot: path.join(__dirname, "../.."),
  // Dev server only (`next build` ignores it): orun.work's live Preview tab
  // loads `next dev` from the preview's own host, and Next.js refuses the
  // hot reload and other /_next/* dev requests from an origin it is not told
  // about. These are the preview's hosts, prod's and stage's.
  allowedDevOrigins: ["*.orun-preview.app", "preview-gateway-stage.oruncloud.workers.dev"],
  experimental: {
    // Dev server only: behind orun.work's live Preview the browser's Origin
    // is the preview's host while `next dev` sees a local Host, and Next.js
    // refuses a Server Action from an origin it is not told about. `next
    // build` runs with NODE_ENV=production, so production keeps its
    // same-origin check.
    ...(process.env.NODE_ENV === "development"
      ? { serverActions: { allowedOrigins: ["*.orun-preview.app", "preview-gateway-stage.oruncloud.workers.dev"] } }
      : {}),
  },
  images: {
    // The Worker has no image optimiser: WordPress media is served as
    // uploaded, from the WordPress site.
    unoptimized: true,
    remotePatterns: wordpressHostname
      ? [
          {
            protocol: "https",
            hostname: wordpressHostname,
            port: "",
            pathname: "/**",
          },
        ]
      : [],
  },
  async redirects() {
    if (!wordpressUrl) {
      return [];
    }
    return [
      {
        source: "/admin",
        destination: `${wordpressUrl}/wp-admin`,
        permanent: true,
      },
    ];
  },
};

export default nextConfig;

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

import Link from "next/link";

import { isWordPressConfigured } from "@/lib/wordpress";

// Shown on every page while no WordPress site is connected (WORDPRESS_URL was
// not set when the site was built): the posts, pages and terms are the
// bundled samples (lib/sample.ts), and this says how to connect a real site.
export function UnconnectedNotice() {
  if (isWordPressConfigured) return null;
  return (
    <div
      role="status"
      data-wordpress="unconnected"
      className="border-b bg-accent/50 px-4 py-2 text-center text-sm"
    >
      Showing sample content: no WordPress site is connected yet.{" "}
      <Link className="underline" href="/posts/connect-your-wordpress-site">
        Connect your WordPress site
      </Link>
      .
    </div>
  );
}

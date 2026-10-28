// OpenNext Cloudflare adapter config.
//
// Nothing here is incrementally regenerated: every page that reads WordPress
// renders per request (`dynamic = "force-dynamic"`), so a change in WordPress
// shows on the next visit and /api/revalidate has no cached page to refresh.
// The static-assets incremental cache serves what the build pre-rendered (the
// home page, the 404) straight from the Worker's static assets — read only,
// nothing to provision. Pages that revalidate (ISR, `revalidateTag`) would swap
// this for the R2 incremental cache plus a tag cache.
import { defineCloudflareConfig } from "@opennextjs/cloudflare/config";
import staticAssetsIncrementalCache from "@opennextjs/cloudflare/overrides/incremental-cache/static-assets-incremental-cache";

export default defineCloudflareConfig({
  incrementalCache: staticAssetsIncrementalCache,
});

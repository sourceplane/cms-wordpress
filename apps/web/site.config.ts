type SiteConfig = {
  site_domain: string;
  site_name: string;
  site_description: string;
};

// The site's name, written once: the nav, the footer, the mobile menu and the
// pages' titles read it. Creating a site from this template rewrites it to
// that site's name, so keep it literal, double-quoted and on one line.
export const SITE_NAME = "next-wp";

export const siteConfig: SiteConfig = {
  site_name: SITE_NAME,
  site_description: "Starter template for Headless WordPress with Next.js",
  // The site's public origin (the sitemap, canonical, Open Graph and OG-image
  // links are absolute): the deploy sets NEXT_PUBLIC_SITE_URL to the
  // environment's SITE_URL or its workers.dev URL (apps/web/component.yaml).
  site_domain: process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000",
};

import { afterEach, describe, expect, it, vi } from "vitest";

afterEach(() => {
  vi.unstubAllEnvs();
  vi.resetModules();
});

describe("site identity (apps/web/site.config.ts)", () => {
  it("names the site once: the nav, the footer and the title read SITE_NAME", async () => {
    const { SITE_NAME, siteConfig } = await import("@/site.config");
    expect(SITE_NAME.trim()).not.toBe("");
    expect(siteConfig.site_name).toBe(SITE_NAME);
  });

  it("builds absolute links for the origin the deploy names, else localhost", async () => {
    vi.stubEnv("NEXT_PUBLIC_SITE_URL", "https://acme-web-stage.acme.workers.dev");
    expect((await import("@/site.config")).siteConfig.site_domain).toBe("https://acme-web-stage.acme.workers.dev");
    vi.unstubAllEnvs();
    vi.resetModules();
    vi.stubEnv("NEXT_PUBLIC_SITE_URL", "");
    expect((await import("@/site.config")).siteConfig.site_domain).toBe("http://localhost:3000");
  });
});

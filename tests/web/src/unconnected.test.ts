import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// A site built with no WordPress URL — what every fresh deploy is until its
// owner connects one — must render its sample site, never reach the network,
// and answer a missing slug as WordPress would (nothing), not with an error.

const mockFetch = vi.fn();
vi.stubGlobal("fetch", mockFetch);

beforeEach(() => {
  vi.stubEnv("WORDPRESS_URL", "");
  mockFetch.mockReset();
  vi.resetModules();
});
afterEach(() => {
  vi.unstubAllEnvs();
});

describe("the WordPress client with no WORDPRESS_URL (apps/web/lib/wordpress.ts)", () => {
  it("is unconnected, and says so", async () => {
    const wp = await import("@/lib/wordpress");
    expect(wp.isWordPressConfigured).toBe(false);
  });

  it("lists the sample posts, paginated, with their embedded author and terms", async () => {
    const wp = await import("@/lib/wordpress");
    const { data, headers } = await wp.getPostsPaginated(1, 2);
    expect(headers).toEqual({ total: 3, totalPages: 2 });
    expect(data).toHaveLength(2);
    expect(data[0]!.slug).toBe("connect-your-wordpress-site");
    expect(data[0]!._embedded?.author?.[0]?.name).toBeTruthy();
    expect(data[0]!._embedded?.["wp:term"]?.[0]?.[0]?.name).toBe("Getting started");
    expect(mockFetch).not.toHaveBeenCalled();
  });

  it("filters as the REST API does: by category, tag, author and search", async () => {
    const wp = await import("@/lib/wordpress");
    expect((await wp.getPostsPaginated(1, 9, { category: "2" })).data.map((p) => p.slug)).toEqual([
      "how-the-site-reads-wordpress",
    ]);
    expect((await wp.getPostsPaginated(1, 9, { tag: "3" })).headers.total).toBe(2);
    expect((await wp.getPostsPaginated(1, 9, { author: "1" })).headers.total).toBe(3);
    expect((await wp.getPostsPaginated(1, 9, { search: "hello" })).data.map((p) => p.slug)).toEqual(["hello-world"]);
  });

  it("finds a post and a page by slug, and nothing for a slug it does not have", async () => {
    const wp = await import("@/lib/wordpress");
    expect((await wp.getPostBySlug("hello-world"))?.title.rendered).toBe("Hello world!");
    expect(await wp.getPostBySlug("no-such-post")).toBeUndefined();
    expect((await wp.getPageBySlug("about"))?.title.rendered).toBe("About");
    expect(await wp.getPageBySlug("nope")).toBeUndefined();
  });

  it("answers by id as the API does, a 404 included", async () => {
    const wp = await import("@/lib/wordpress");
    expect((await wp.getCategoryById(1)).slug).toBe("getting-started");
    await expect(wp.getCategoryById(999)).rejects.toMatchObject({ status: 404 });
    await expect(wp.getFeaturedMediaById(1)).rejects.toMatchObject({ status: 404 });
  });

  it("lists the terms, the authors, the pages and the sitemap's posts", async () => {
    const wp = await import("@/lib/wordpress");
    expect((await wp.getAllCategories()).map((c) => c.slug)).toEqual(["getting-started", "guides"]);
    expect(await wp.getAllTags()).toHaveLength(3);
    expect((await wp.getAllAuthors()).map((a) => a.slug)).toEqual(["editor"]);
    expect((await wp.getAllPages()).map((p) => p.slug)).toEqual(["about"]);
    expect((await wp.getAllPostsForSitemap()).map((p) => p.slug)).toHaveLength(3);
    expect(mockFetch).not.toHaveBeenCalled();
  });

  it("tells the reader how to connect WordPress, in the first post", async () => {
    const wp = await import("@/lib/wordpress");
    const post = await wp.getPostBySlug("connect-your-wordpress-site");
    expect(post?.content.rendered).toContain("WORDPRESS_URL");
  });
});

describe("the WordPress client with a WORDPRESS_URL", () => {
  it("reads the REST API on every request, past Next's data cache", async () => {
    vi.stubEnv("WORDPRESS_URL", "https://wp.example.com");
    mockFetch.mockResolvedValue({
      ok: true,
      status: 200,
      statusText: "OK",
      json: () => Promise.resolve([]),
      headers: { get: (name: string) => ({ "X-WP-Total": "0", "X-WP-TotalPages": "0" })[name] ?? null },
    });
    const wp = await import("@/lib/wordpress");
    expect(wp.isWordPressConfigured).toBe(true);
    await wp.getAllCategories();
    await wp.getPostsPaginated(1, 9);
    expect(mockFetch).toHaveBeenCalledTimes(2);
    for (const [url, init] of mockFetch.mock.calls) {
      expect(String(url)).toMatch(/^https:\/\/wp\.example\.com\/wp-json\/wp\/v2\//);
      expect(init).toMatchObject({ cache: "no-store" });
      expect(init.next?.revalidate).toBeUndefined();
    }
  });
});

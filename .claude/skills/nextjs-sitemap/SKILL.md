---
name: nextjs-sitemap
description: "Use when adding, changing or checking a sitemap (sitemap.xml) or robots.txt in a Next.js component of this repo (e.g. src/frontend): which URLs go in, the absolute base URL from the Terraform-injected <NAME>_URL env var, app/sitemap.ts and app/robots.ts, dynamic routes, splitting large sitemaps with generateSitemaps, localized alternates, images and videos. Next.js 16 App Router."
license: MIT
metadata:
  version: "1.0.0"
  next: "16"
---

# Sitemap for a Next.js component

Generate the sitemap in code with `app/sitemap.ts` and reference it from `app/robots.ts`. Follow `nextjs-best-practices` for everything not covered here. API reference: https://nextjs.org/docs/app/api-reference/file-conventions/metadata/sitemap

## 1. Base URL

Every `<loc>` must be an absolute URL on the public custom domain.

- Terraform injects each service's public URL as `<NAME>_URL`, where `<NAME>` is the `src/<name>` folder name in upper case with `-` changed to `_` (`.config/terraform/services.tf`). The `frontend` service is served at the bare domain (`https://<repo>.<domain>`); any other service gets `https://<name>.<repo>.<domain>`.
- Read it in one helper, with a local fallback:

```ts
// src/<name>/lib/site-url.ts
export function siteUrl(): string {
  return (process.env.FRONTEND_URL ?? "http://localhost:3000").replace(/\/$/, "");
}
```

  Use the env var matching the component's own folder name (`FRONTEND_URL` for `src/frontend`, `WEB_URL` for `src/web`).
- Never use the `*.run.app` URL, `request.url` or the `Host` header as the base. The service is reachable on both domains, and only the custom domain should be indexed.
- Never hard-code the domain: each project created from the template gets its own.

## 2. Build time vs request time

`sitemap.ts` and `robots.ts` are Route Handlers that are **prerendered at build time by default**. During `docker build` (`npm run build`), `FRONTEND_URL` is not set: it exists only at runtime on Cloud Run. A build-time sitemap would contain `http://localhost:3000`.

Make both files run per request:

```ts
import { connection } from "next/server";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  await connection();
  // ...
}
```

Do not use `export const dynamic = "force-dynamic"`: it is not allowed when `cacheComponents` is enabled. If the URL list is expensive (database, CMS), cache the data function with `"use cache"` + `cacheLife("hours")` and keep the base URL lookup outside it.

After the first deploy, check `curl -s https://<custom-domain>/sitemap.xml | head` shows the custom domain.

## 3. Which URLs go in

Include only canonical, indexable pages that return 200:

- static pages under `app/` (`page.tsx` files, excluding route groups' `(name)` segments from the path),
- every instance of dynamic routes (`app/blog/[slug]/page.tsx` -> one entry per slug, taken from the same data source the page uses, ideally the same function as `generateStaticParams`).

Exclude:

- Route Handlers (`app/**/route.ts`), `/api/*`, Server Action endpoints,
- pages with `robots: { index: false }` in their metadata, auth/account/admin/checkout pages, search result and filter URLs (`?q=`, `?sort=`), drafts, previews,
- redirects, `not-found` pages, error pages,
- URLs whose canonical (`alternates.canonical`) points elsewhere.

Rules for each entry:

- one URL form only: no trailing slash (except the root `https://domain/`), lower-case, no query strings or fragments, URL-encoded path segments (`encodeURIComponent(slug)`),
- `lastModified`: the real content change date from the data (`post.updatedAt`). Never `new Date()` for every entry: it tells crawlers everything changed on every request. Omit it for static pages without a known date.
- `changeFrequency` and `priority` are ignored by Google; add them only if the user asks.
- no duplicates: build entries into a `Map` keyed by URL if they come from several sources.

## 4. Structure

```ts
// src/<name>/app/sitemap.ts
import type { MetadataRoute } from "next";
import { connection } from "next/server";
import { siteUrl } from "@/lib/site-url";
import { getPosts } from "@/lib/posts";

const STATIC_PATHS = ["/", "/about", "/blog"];

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  await connection();
  const base = siteUrl();
  const posts = await getPosts();

  return [
    ...STATIC_PATHS.map((path) => ({ url: path === "/" ? `${base}/` : `${base}${path}` })),
    ...posts.map((post) => ({
      url: `${base}/blog/${encodeURIComponent(post.slug)}`,
      lastModified: post.updatedAt,
    })),
  ];
}
```

Adjust the `@/` import alias to the component's `tsconfig.json` (use relative imports if no alias is configured).

## 5. robots.txt

Generate it with `app/robots.ts` and point it at the sitemap. **Delete `public/robots.txt`** (the Next template ships one): when both exist, the build passes without a warning and the static `public/robots.txt` silently wins, so the `Sitemap:` line never appears.

```ts
// src/<name>/app/robots.ts
import type { MetadataRoute } from "next";
import { connection } from "next/server";
import { siteUrl } from "@/lib/site-url";

export default async function robots(): Promise<MetadataRoute.Robots> {
  await connection();
  const base = siteUrl();
  return {
    rules: { userAgent: "*", allow: "/", disallow: ["/api/"] },
    sitemap: `${base}/sitemap.xml`,
  };
}
```

`robots.txt` `disallow` only stops crawling; it does not remove a page from the index. To keep a page out of search results use `robots: { index: false }` in its metadata and leave it out of the sitemap.

## 6. Large sites

- Limits per sitemap file: 50,000 URLs and 50 MB uncompressed. Split before reaching them.
- Split by section with nested files (`app/blog/sitemap.ts` -> `/blog/sitemap.xml`), or by page with `generateSitemaps`. In Next 16 `id` is a `Promise<string>`:

```ts
export async function generateSitemaps() {
  const count = await countProducts();
  return Array.from({ length: Math.ceil(count / 50000) }, (_, id) => ({ id }));
}

export default async function sitemap(props: { id: Promise<string> }): Promise<MetadataRoute.Sitemap> {
  const id = Number(await props.id);
  const products = await getProducts({ offset: id * 50000, limit: 50000 });
  return products.map((p) => ({ url: `${siteUrl()}/product/${p.id}`, lastModified: p.updatedAt }));
}
```

  Files are served at `/product/sitemap/<id>.xml`. Next does not generate an index file for them: list every split sitemap in `robots.ts` (`sitemap` accepts an array).

## 7. Languages, images, videos

- Localized pages: add `alternates.languages` (`{ en: ..., pl: ... }`) with absolute URLs, include every language version as its own entry, and make the alternates symmetric (each version lists all the others).
- `images: [absoluteUrl]` for important page images (product photos, article hero). Skip icons and decoration.
- `videos: [{ title, thumbnail_loc, description }]` only for pages whose main content is the video.

## 8. Verify

1. `cd src/<name> && npx --no-install eslint --max-warnings=0 . && npx --no-install tsc --noEmit`
2. Run the app (`mise run dev`) and open `http://localhost:3000/sitemap.xml` and `/robots.txt`:
   - valid XML, every `<loc>` absolute,
   - every listed URL returns 200: `curl -s localhost:3000/sitemap.xml | grep -o '<loc>[^<]*' | sed 's/<loc>//; s|https\?://[^/]*|http://localhost:3000|' | xargs -n1 curl -s -o /dev/null -w '%{http_code} %{url_effective}\n'`
   - no excluded routes (`/api`, admin, `noindex` pages) and no duplicates.
3. `npm run build` passes, and the build output lists `/sitemap.xml` and `/robots.txt` as dynamic, not static.

---
name: feature-sliced-design
description: "Use when creating, moving or reviewing code in a frontend component that uses Tailwind CSS (e.g. src/frontend with tailwindcss in package.json): where a file goes, how to name layers, slices and segments, which imports are allowed, public APIs (index.ts), and how Tailwind styles, tokens and the cn() helper fit in. Feature-Sliced Design v2.1 on Next.js App Router. Also use when the user mentions FSD, layers, slices, widgets, features or entities."
license: MIT
metadata:
  version: "1.0.0"
  fsd: "2.1"
---

# Feature-Sliced Design (with Next.js and Tailwind)

Frontend components that use Tailwind are structured with Feature-Sliced Design (FSD) v2.1. Reference: https://feature-sliced.design/docs (Next.js guide: `/docs/guides/tech/with-nextjs`). Follow `nextjs-best-practices` for Next itself; this skill decides **where code lives and what may import what**.

All paths below are relative to the component root (`src/<name>/`).

## 1. Layout

Next.js routing stays in the root `app/`; all FSD code lives in `src/`.

```
src/<name>/
  app/                      Next.js routing only: page.tsx, layout.tsx, route.ts, sitemap.ts ...
  proxy.ts                  Next.js request proxy (root, next to app/)
  src/
    _app/                   FSD "app" layer: providers, global styles, route handler logic
      styles/globals.css
      providers/
      api-routes/
    _pages/                 FSD "pages" layer: one slice per page
    widgets/
    features/
    entities/
    shared/
      ui/  api/  lib/  config/  routes/  i18n/
```

- The FSD `app` and `pages` layers are named **`_app` and `_pages`**, so Next never mistakes them for router folders.
- `tsconfig.json`: `"paths": { "@/*": ["./src/*"] }`. Imports look like `@/entities/user`, `@/shared/ui/button`.
- Files in `app/` contain no logic. They re-export from FSD:

```tsx
// app/products/[slug]/page.tsx
export { ProductPage as default, generateMetadata } from "@/_pages/product";

// app/api/orders/route.ts
export { createOrder as POST } from "@/_app/api-routes";

// app/layout.tsx
export { RootLayout as default, metadata } from "@/_app/layout";
```

- Other root Next files (`proxy.ts`, `instrumentation.ts`) stay in the component root and also only re-export or call into `src/`.
- Where other skills suggest a path, map it into FSD: the sitemap's `siteUrl()` helper goes to `src/shared/config/site-url.ts`; `app/sitemap.ts` and `app/robots.ts` stay in `app/` and import from `@/shared/config`.

## 2. Layers

From top (most specific) to bottom (most reusable):

| Layer | Holds | Slices? |
|---|---|---|
| `_app` | providers, global styles, root layout, route handler logic (`api-routes` segment) | no, segments only |
| `_pages` | one slice per page or route: composes widgets/features for that screen | yes |
| `widgets` | large self-contained UI blocks used on several pages (header, product grid) | yes |
| `features` | user interactions that deliver value: `add-to-cart`, `auth-by-email`, `search-products` | yes |
| `entities` | business concepts: `user`, `product`, `order` (their data, types, display cards) | yes |
| `shared` | business-agnostic code: UI kit, API client, config, routes, generic libs | no, segments only |

- `processes` is deprecated: never create it; put the logic in `features` or `_app`.
- Never add other layers.
- Start simple: most code begins in `_pages`. Move it down to `widgets`/`features`/`entities` only when a second page needs it.

## 3. Import rules

- A slice imports **only from layers strictly below** it: `features` -> `entities`, `shared`; never `features` -> `features` or `entities` -> `features`.
- Slices on the same layer never import each other. Compose them one layer up instead (two features meet in a widget or page).
- Exception for entities only: an entity exposes a cross-import API in `entities/<a>/@x/<b>.ts`, and entity `<b>` imports `@/entities/<a>/@x/<b>`. Prefer type-only imports there.
- `_app` and `shared` have no slices; their segments may import each other freely within the layer.
- Within a slice use relative imports (`../model/cart`); across slices use the alias (`@/entities/product`).
- From outside a slice import **only its public API** (`@/entities/product`), never inner files (`@/entities/product/ui/card`).

## 4. Slices and segments

- Slice names: kebab-case, named by business meaning (`product`, `add-to-cart`), not by type (`modals`, `forms`).
- Segments (by purpose, not by file type):

| Segment | Holds |
|---|---|
| `ui` | components, their Tailwind classes, formatters used only for display |
| `api` | requests, server actions, DTO types, mappers |
| `model` | schemas, state, business logic, domain types |
| `lib` | code used inside this slice only |
| `config` | constants, feature flags |

- Do not create `components`, `hooks`, `types`, `utils` or `helpers` segments. A hook goes where its purpose is (`model` for state, `api` for data). A type goes next to what it describes.
- `shared/lib` is not a dump: one folder per topic (`shared/lib/css`, `shared/lib/dates`), each with its own `index.ts`.
- `shared/db` (custom segment) for database queries if the frontend talks to a database directly. Route handler and server-only code: `index.server.ts` as a separate public API, so client components cannot import it by accident. Add `import "server-only"` in it.

## 5. Public API

- Every slice has `index.ts` at its root, and only that file is imported from outside.
- Export names explicitly. No `export * from ...`.

```ts
// src/entities/product/index.ts
export { ProductCard } from "./ui/product-card";
export { getProduct, getProducts } from "./api/product";
export type { Product } from "./model/product";
```

- No `index.ts` inside segments of sliced layers (`entities/product/ui/index.ts` is redundant).
- `shared` has one public API **per segment and component**, so importing one button does not pull the whole UI kit: `@/shared/ui/button`, `@/shared/lib/css`.

## 6. Where Tailwind code lives in FSD

How to write the classes themselves is in `tailwind-best-practices`. This section only places them in the layers:

| What | Where |
|---|---|
| Tailwind entry CSS (`@import "tailwindcss"`, `@theme` tokens, `@custom-variant`, `@utility`) | `src/_app/styles/globals.css`, imported once from the root layout |
| `cn()` helper | `src/shared/lib/css/`, imported as `@/shared/lib/css` |
| Business-agnostic UI kit with variants (`button`, `input`, `dialog`) | `src/shared/ui/<component>/` |
| A slice's classes | the `ui` segment of the slice that renders them |
| Variant choice driven by business state | `model` returns the state (`status: "overdue"`); `ui` maps it to classes |

- A slice never defines its own tokens or global CSS: new tokens go to `_app/styles`.
- A lower layer never styles a higher one: an entity card takes `className` for placement only; a widget or page does not reach into it to restyle it, it asks for a variant.

## 7. Lint the structure (Steiger)

Steiger is the official FSD architecture linter (beta).

```sh
cd src/<name>
npm i -D steiger @feature-sliced/steiger-plugin
```

```ts
// src/<name>/steiger.config.ts
import { defineConfig } from "steiger";
import fsd from "@feature-sliced/steiger-plugin";

export default defineConfig([...fsd.configs.recommended]);
```

Run `npx steiger ./src`. Disable a rule for specific paths with `{ files: [...], rules: { "fsd/<rule>": "off" } }`, and skip files with `{ ignores: [...] }`. To enforce it on commit, add a job to `src/<name>/lefthook.yml` next to ESLint:

```yaml
    - name: <name>-steiger
      root: src/<name>/
      glob: "src/**/*"
      run: npx --no-install steiger ./src
```

## 8. When writing or reviewing code

1. Decide the layer first (section 2), then the slice, then the segment. If unsure, put it in the page slice.
2. Check every new import against section 3. A same-layer or upward import means the code is in the wrong place: move it, do not work around it.
3. Update the slice's `index.ts` when something is used from outside.
4. Run `npx --no-install eslint --max-warnings=0 .`, `npx --no-install tsc --noEmit` and `npx --no-install steiger ./src` (if installed) in `src/<name>`.

# Next.js Review Checklist

Load this reference when `next.config.*` is detected in the project root. Use it to catch Next.js-specific issues during code review.

## Table of Contents

1. [Server / Client Component Boundary](#server--client-component-boundary)
2. [Server Actions](#server-actions)
3. [Data Fetching and Caching](#data-fetching-and-caching)
4. [Route Handlers](#route-handlers)
5. [Security](#security)
6. [Performance](#performance)
7. [Common Bugs](#common-bugs)

---

## Server / Client Component Boundary

These are the most frequent source of bugs in Next.js PRs.

### Flag these:

- **`"use client"` too high in the tree** — if a layout or wrapper component has `"use client"`, everything it imports becomes client-side, bloating the JS bundle. Push the directive to the lowest leaf that needs interactivity.

- **Server-only code in Client Components** — database queries, API keys, or `fs` usage in a `"use client"` file will either fail at runtime or leak secrets to the browser. Flag immediately as a security issue.

- **Importing a Server Component into a Client Component** — this silently converts the Server Component into a Client Component. The correct pattern is passing server content as `children` props.

- **Missing `"use client"` on components using hooks** — `useState`, `useEffect`, `useRef`, event handlers like `onClick` require the client directive. Without it, the component fails at runtime.

- **`error.tsx` without `"use client"`** — error boundary files must be Client Components. Missing the directive causes the error boundary itself to fail.

---

## Server Actions

### Flag these:

- **Missing input validation** — Server Actions are public HTTP endpoints. Any user can call them with arbitrary data. Flag actions that trust `formData.get()` values without validation, type checking, or sanitization.

```tsx
// BAD — trusts user input
export async function updateUser(formData: FormData) {
  const role = formData.get('role') as string  // user could set role to "admin"
  await db.update('users', { role })
}
```

- **Missing authorization checks** — verify the action checks that the current user is allowed to perform the mutation. An action without auth is equivalent to an unprotected API endpoint.

- **Missing `revalidatePath` / `revalidateTag` after mutations** — data will appear stale after the action completes. Every action that writes data should revalidate the affected paths or tags.

- **Missing error handling** — unhandled errors in Server Actions return a generic 500 to the client. Actions should catch errors and return structured error state, especially when used with `useActionState`.

- **Redirect after mutation without try/catch awareness** — `redirect()` throws internally. If it's inside a try/catch, the redirect gets swallowed. Place `redirect()` outside the try/catch block.

---

## Data Fetching and Caching

### Flag these:

- **`useEffect` + `fetch` when a Server Component would work** — if the component doesn't need interactivity, fetch data on the server. Client-side fetching adds loading spinners, layout shift, and extra round trips.

- **Unbounded data fetching in Server Components** — queries without `LIMIT`, pagination, or reasonable bounds can return huge datasets. On the server this blocks rendering; the response can also be enormous.

- **Missing `<Suspense>` around slow server fetches** — without Suspense, one slow data source blocks the entire page from streaming. Wrap independent data-loading sections in `<Suspense>` with a fallback.

- **Fetching the same data in multiple Server Components** — Next.js deduplicates `fetch()` calls with the same URL, but custom database queries or SDK calls are NOT deduplicated. Use `React.cache()` to memoize across components in the same request.

---

## Route Handlers

### Flag these:

- **`route.ts` coexisting with `page.tsx` in the same folder** — this is not allowed in the App Router. The route handler takes precedence and the page silently disappears.

- **Not awaiting `params` in Next.js 15+** — `params` and `searchParams` are Promises. Using them without `await` returns a Promise object instead of the actual values. This applies to pages, layouts, and route handlers.

```tsx
// BUG — params is a Promise in Next.js 15+
export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  const id = params.id  // This is a Promise, not a string
}

// CORRECT
export async function GET(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
}
```

- **Missing response status codes** — POST handlers returning 200 instead of 201, error paths returning 200 instead of 4xx/5xx.

- **Not handling `request.json()` failure** — if the body isn't valid JSON, this throws. Wrap in try/catch or validate content-type first.

---

## Security

### Flag these:

- **Secrets in Client Components** — any `process.env.SECRET_*` or API key in a `"use client"` file is exposed to the browser. Only `NEXT_PUBLIC_*` env vars should appear in client code.

- **Unvalidated redirect targets** — `redirect(userInput)` or `NextResponse.redirect(userInput)` can be exploited for open redirects. Validate the target URL against an allowlist or ensure it's a relative path.

- **Missing CSRF protection on Server Actions** — Next.js has built-in CSRF protection for Server Actions via the `Origin` header check, but custom API route handlers (`route.ts`) do NOT have this. Flag mutations in route handlers without CSRF tokens.

- **SQL injection via string interpolation** — even with D1's prepared statements available, developers sometimes concatenate user input into SQL strings. Flag any SQL query built with template literals or string concatenation.

- **Exposing internal error details** — error responses that include stack traces, database errors, or internal paths leak information to attackers.

---

## Performance

### Flag these:

- **Large dependencies in Server Components without dynamic import** — packages like `moment`, `lodash` (full), or heavy charting libraries loaded synchronously increase cold start time. Use `next/dynamic` or `import()` for heavy client-side deps.

- **Missing `loading.tsx` for data-heavy routes** — without a loading state, navigations appear frozen until the server finishes rendering.

- **Images without `next/image`** — raw `<img>` tags skip automatic optimization (resizing, WebP, lazy loading). Use the `Image` component from `next/image`.

- **Layouts fetching data that child pages also fetch** — if both layout and page need the same data, the layout fetch blocks the page. Consider parallel fetching or moving the fetch to where it's actually rendered.

- **Middleware doing heavy computation** — middleware runs on every matched request. Database queries, external API calls, or heavy computation in middleware adds latency to every request. Keep middleware thin (auth checks, redirects, header manipulation).

---

## Common Bugs

### Watch for these patterns:

- **`useRouter()` from `next/navigation` vs `next/router`** — App Router uses `next/navigation`. Importing from `next/router` fails silently or crashes.

- **Calling `cookies()` or `headers()` in a cached context** — these functions opt the route into dynamic rendering. Using them in a layout that wraps cached pages forces the entire subtree to be dynamic.

- **`generateStaticParams` returning wrong shape** — each item must be an object matching the dynamic segments. A common mistake is returning `[id]` instead of `[{ id }]`.

- **Client Component trying to be async** — Client Components cannot be `async`. If you see `async function MyClientComponent()` with `"use client"`, it will fail at runtime.

- **`notFound()` called in a segment without `not-found.tsx`** — the error bubbles up to the nearest `not-found.tsx` or the root one. If none exists, users see the default 404 page with no context.

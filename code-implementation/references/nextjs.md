# Next.js Reference

Load this reference when `next.config.*` is detected in the project root.

## Table of Contents

1. [App Router File Conventions](#app-router-file-conventions)
2. [Server vs Client Components](#server-vs-client-components)
3. [Server Actions](#server-actions)
4. [Route Handlers](#route-handlers)
5. [Middleware](#middleware)
6. [Common Pitfalls](#common-pitfalls)

---

## App Router File Conventions

The App Router uses a file-system based router where folders define routes. Each folder can contain these special files:

| File | Purpose |
|------|---------|
| `layout.tsx` | Shared UI for a segment and its children. Persists across navigations — does not remount. |
| `page.tsx` | The unique UI for a route. Makes the route publicly accessible. |
| `loading.tsx` | Instant loading UI (wraps the page in `<Suspense>`). |
| `error.tsx` | Error boundary for a segment. Must be a Client Component (`"use client"`). |
| `not-found.tsx` | UI for `notFound()` calls or unmatched routes. |
| `template.tsx` | Like layout but remounts on every navigation. Rare — prefer layout. |
| `default.tsx` | Fallback for parallel routes when no match exists. |

### Route Groups and Dynamic Segments

```
app/
├── (marketing)/        ← route group: no URL segment, shares layout
│   ├── about/page.tsx  ← /about
│   └── layout.tsx
├── [slug]/page.tsx     ← dynamic: /anything
├── [...slug]/page.tsx  ← catch-all: /a/b/c
└── [[...slug]]/page.tsx ← optional catch-all: / or /a/b/c
```

### Parallel Routes and Intercepting Routes

```
app/
├── @modal/            ← parallel route slot
│   └── (..)photo/[id]/page.tsx  ← intercepts /photo/[id] from this level
├── layout.tsx         ← receives { children, modal } props
└── page.tsx
```

Use parallel routes for modals, side panels, or conditional content that renders alongside the main page.

---

## Server vs Client Components

**Default: Server Components.** Every component in the App Router is a Server Component unless you add `"use client"` at the top of the file. This keeps the JS bundle small — server-only code never ships to the browser.

### When to use each

| Server Component | Client Component (`"use client"`) |
|---|---|
| Fetch data | Event handlers (onClick, onChange, etc.) |
| Access backend resources directly | useState, useEffect, useRef |
| Keep secrets on server (API keys, tokens) | Browser APIs (localStorage, window) |
| Reduce client JS bundle | Interactive UI (forms, dropdowns, modals) |

### Composition pattern

Server Components can import Client Components, but not the reverse. To pass server data to interactive UI:

```tsx
// ServerWrapper.tsx (Server Component — no directive)
import { ClientForm } from './ClientForm'

export default async function ServerWrapper() {
  const data = await db.query(...)
  return <ClientForm initialData={data} />
}
```

```tsx
// ClientForm.tsx
"use client"
import { useState } from 'react'

export function ClientForm({ initialData }) {
  const [value, setValue] = useState(initialData)
  return <input value={value} onChange={e => setValue(e.target.value)} />
}
```

### Children pattern for avoiding unnecessary "use client" spread

```tsx
// InteractiveWrapper.tsx
"use client"
export function InteractiveWrapper({ children }) {
  const [open, setOpen] = useState(false)
  return <div onClick={() => setOpen(!open)}>{open && children}</div>
}

// Page.tsx (Server Component)
import { InteractiveWrapper } from './InteractiveWrapper'
import { HeavyServerContent } from './HeavyServerContent'

export default function Page() {
  return (
    <InteractiveWrapper>
      <HeavyServerContent />  {/* stays server-rendered */}
    </InteractiveWrapper>
  )
}
```

---

## Server Actions

Server Actions are async functions that run on the server. Define them with `"use server"` at the top of the file or inline within a function body.

### Defining actions

**Dedicated file (recommended for reusable actions):**

```tsx
// app/actions/user.ts
"use server"

import { revalidatePath } from 'next/cache'

export async function updateUser(formData: FormData) {
  const name = formData.get('name') as string
  await db.update('users', { name })
  revalidatePath('/profile')
}
```

**Inline (for one-off actions):**

```tsx
export default function Page() {
  async function handleSubmit(formData: FormData) {
    "use server"
    // ...
  }
  return <form action={handleSubmit}>...</form>
}
```

### Using with forms

```tsx
import { updateUser } from '@/app/actions/user'

export default function ProfileForm() {
  return (
    <form action={updateUser}>
      <input name="name" />
      <button type="submit">Save</button>
    </form>
  )
}
```

### Using with useActionState (for loading/error states)

```tsx
"use client"
import { useActionState } from 'react'
import { updateUser } from '@/app/actions/user'

export function ProfileForm() {
  const [state, action, isPending] = useActionState(updateUser, null)
  return (
    <form action={action}>
      <input name="name" />
      <button disabled={isPending}>
        {isPending ? 'Saving...' : 'Save'}
      </button>
      {state?.error && <p>{state.error}</p>}
    </form>
  )
}
```

### Cache revalidation after mutations

Always revalidate after mutating data:

```tsx
import { revalidatePath } from 'next/cache'
import { revalidateTag } from 'next/cache'

// Revalidate a specific path
revalidatePath('/dashboard')

// Revalidate all data associated with a cache tag
revalidateTag('posts')

// Redirect after mutation
import { redirect } from 'next/navigation'
redirect('/success')
```

---

## Route Handlers

API routes in the App Router live in `app/**/route.ts` files. They cannot coexist with `page.tsx` in the same folder.

```tsx
// app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  const users = await db.query('SELECT * FROM users')
  return NextResponse.json(users)
}

export async function POST(request: NextRequest) {
  const body = await request.json()
  const user = await db.insert('users', body)
  return NextResponse.json(user, { status: 201 })
}
```

### Dynamic route handlers

```tsx
// app/api/users/[id]/route.ts
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const user = await db.query('SELECT * FROM users WHERE id = ?', [id])
  return NextResponse.json(user)
}
```

---

## Middleware

Middleware runs before every request. Define in `middleware.ts` at the project root (not inside `app/`).

```tsx
// middleware.ts
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  // Redirect example
  if (request.nextUrl.pathname === '/old') {
    return NextResponse.redirect(new URL('/new', request.url))
  }

  // Add headers
  const response = NextResponse.next()
  response.headers.set('x-custom', 'value')
  return response
}

export const config = {
  matcher: [
    // Match all paths except static files and _next
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
}
```

---

## Common Pitfalls

### Hydration mismatches

Server and client HTML must match on first render. Common causes:
- Using `Date.now()` or `Math.random()` in shared components
- Accessing `window` or `localStorage` during render
- Browser extensions modifying DOM

**Fix:** Use `useEffect` for browser-only values, or `suppressHydrationWarning` for intentional mismatches (e.g., timestamps).

### Accidentally making large subtrees client-side

Adding `"use client"` to a high-level component makes everything it imports client-side too. Push `"use client"` as far down the tree as possible — only the leaf components that need interactivity.

### Forgetting to revalidate after mutations

Server Actions that modify data without calling `revalidatePath` or `revalidateTag` will leave stale data in the cache. Always revalidate after mutations.

### Fetching in Client Components when Server Components suffice

If a component doesn't need interactivity, fetch data in a Server Component and pass it as props. Avoid `useEffect` + `fetch` patterns when a Server Component can do the same work at build/request time.

### Dynamic params are now async

In Next.js 15+, `params` and `searchParams` are Promises. Always `await` them:

```tsx
// Correct
export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
}
```

# Cloudflare Review Checklist

Load this reference when `wrangler.toml`, `wrangler.jsonc`, or `wrangler.json` is detected in the project. Use it to catch Cloudflare-specific issues during code review.

## Table of Contents

1. [Workers Runtime Violations](#workers-runtime-violations)
2. [D1 Database Issues](#d1-database-issues)
3. [R2 Storage Issues](#r2-storage-issues)
4. [KV Misuse](#kv-misuse)
5. [Queue Issues](#queue-issues)
6. [Next.js on Cloudflare Workers](#nextjs-on-cloudflare-workers)
7. [Security](#security)

---

## Workers Runtime Violations

Workers run on V8 isolates, not Node.js. These are hard failures in production that may work in local dev.

### Flag these:

- **Node.js `fs` / `path` usage** — filesystem APIs don't exist in Workers. Code using `fs.readFile`, `path.join`, etc. will crash at deploy. Use R2 for file storage, KV for key-value data.

- **Missing `nodejs_compat` flag** — if code uses `Buffer`, `crypto`, `stream`, or other Node.js APIs, verify `wrangler.toml` has `compatibility_flags = ["nodejs_compat"]`. Without it, these APIs are unavailable.

- **Exceeding CPU time limits** — Workers have 30s CPU time (paid) / 10ms (free). Heavy computation (image processing, large JSON parsing, crypto operations) can hit these limits. Flag synchronous loops over large datasets without chunking.

- **Exceeding subrequest limits** — Workers allow 1000 `fetch()` calls per invocation (50 on free). Flag code that makes fetch calls inside loops without bounds, especially when iterating over user-supplied data.

- **Using `process.env` for bindings** — Cloudflare bindings (D1, R2, KV, Queue) are accessed through the `env` parameter, not `process.env`. `process.env` only works for plain string environment variables.

- **Global mutable state** — Workers share isolates across requests. Mutable variables at module scope can leak data between requests. Flag any module-level `let`/`var` that stores request-specific data.

```ts
// BUG — shared across requests
let currentUser: User | null = null

export default {
  async fetch(request: Request, env: Env) {
    currentUser = await getUser(request)  // leaks to other requests
  }
}
```

---

## D1 Database Issues

### Flag these:

- **SQL injection via string interpolation** — D1 has prepared statements (`env.DB.prepare().bind()`). Any SQL built with template literals or concatenation is a vulnerability, even if the input "looks safe."

```ts
// VULNERABILITY
const result = await env.DB.prepare(`SELECT * FROM users WHERE name = '${name}'`).all()

// CORRECT
const result = await env.DB.prepare('SELECT * FROM users WHERE name = ?').bind(name).all()
```

- **Using `.all()` when `.first()` is expected** — if the query should return one row, `.all()` wastes memory and the caller might access `results[0]` without checking if it exists. Use `.first()` for single-row queries.

- **Using `.all()` when `.run()` is appropriate** — INSERT/UPDATE/DELETE statements that don't need returned rows should use `.run()` (more efficient).

- **Missing `.bind()` on prepared statements** — `env.DB.prepare('SELECT * FROM users WHERE id = ?').all()` executes with `?` as a literal. The query won't fail but returns wrong results silently.

- **Unbounded queries** — `SELECT * FROM table` without `LIMIT` or `WHERE` can return the entire table. In Workers' 128MB memory limit, this can crash the isolate.

- **Multiple independent queries that should be batched** — sequential `await env.DB.prepare(...).run()` calls each make a network round trip. Use `env.DB.batch([...])` to send them in a single call. Batch is also atomic — if any statement fails, all roll back.

- **Not handling `.first()` returning `null`** — `.first()` returns `null` when no row matches. Code that accesses properties without null checking will crash.

---

## R2 Storage Issues

### Flag these:

- **Not handling `null` from `.get()`** — `env.BUCKET.get(key)` returns `null` if the object doesn't exist. Code that accesses `.body` or `.httpMetadata` without checking for null will crash.

- **Missing `Content-Type` on `.put()`** — uploaded objects without `httpMetadata.contentType` default to `application/octet-stream`. When served directly, browsers won't handle them correctly (images won't display, etc.).

- **Not paginating `.list()` results** — `.list()` returns max 1000 objects. If `listed.truncated` is true, there are more results. Code that doesn't check `truncated` and use the cursor will silently miss objects.

- **Large file uploads without multipart** — single `.put()` calls should be used for files up to ~100MB. For larger files, use `createMultipartUpload()`. Flag direct puts with unbounded user-supplied data.

- **Not cleaning up failed multipart uploads** — if `.complete()` is never called (e.g., due to an error), the incomplete upload leaks storage. Use try/catch with `.abort()` on failure.

---

## KV Misuse

### Flag these:

- **Using KV for write-heavy workloads** — KV is eventually consistent and optimized for reads. Writes propagate globally in ~60 seconds. If code does frequent writes and reads back immediately, it will see stale data. Use D1 for consistent read-after-write.

- **Storing large values without checking size** — KV values max out at 25 MB. Flag code that stores user-uploaded content or serialized datasets without size validation.

- **Not handling `null` from `.get()`** — `.get()` returns `null` for missing keys. Code that parses the result without checking (`JSON.parse(await env.KV.get(key))`) will throw on `null`.

- **Missing TTL on session/cache data** — temporary data (sessions, tokens, cached responses) should use `expirationTtl` to auto-expire. Without it, KV fills up with stale entries.

- **Using KV when D1 is more appropriate** — if the code is building query patterns on top of KV (scanning prefixes, filtering results), it's reimplementing a database poorly. Suggest D1 instead.

- **Not paginating `.list()` results** — `.list()` returns max 1000 keys. Same truncation issue as R2 — check `list_complete` and use cursor for full results.

---

## Queue Issues

### Flag these:

- **Not acknowledging messages** — if a consumer processes a message but doesn't call `message.ack()`, the message will be redelivered. This causes duplicate processing.

- **Not handling at-least-once semantics** — Queues guarantee at-least-once delivery, meaning duplicates are possible. Flag consumer code that isn't idempotent (e.g., inserting without checking for existing records, sending notifications without dedup).

- **Missing error handling in consumers** — if processing throws without `message.retry()`, the message is silently lost. Always wrap processing in try/catch with `message.retry()` on failure.

- **Unbounded message bodies** — Queue messages have size limits. Flag code that sends large payloads (full file contents, large JSON blobs) as message bodies. Store the data in R2/KV and send a reference (key/path) in the message.

- **Missing dead-letter queue** — after `max_retries` (default 3), messages are dropped. If losing messages is unacceptable, flag the missing `dead_letter_queue` in wrangler.toml.

---

## Next.js on Cloudflare Workers

When the project uses `@opennextjs/cloudflare`, watch for these additional issues.

### Flag these:

- **Using `@cloudflare/next-on-pages` instead of `@opennextjs/cloudflare`** — the old package only supports Edge runtime. The OpenNext adapter supports the full Node.js runtime with `nodejs_compat`. Flag if the project is still on the old adapter.

- **Accessing bindings via `process.env` instead of `getCloudflareContext`** — Cloudflare bindings (D1, R2, KV) are NOT available on `process.env`. The correct import:

```tsx
import { getCloudflareContext } from '@opennextjs/cloudflare'
const { env } = await getCloudflareContext()
```

- **Using `getCloudflareContext` in Client Components** — bindings are only available server-side (Server Components, Server Actions, Route Handlers, Middleware). Using them in a `"use client"` component will fail at runtime.

- **Missing type safety for bindings** — if the project has a `wrangler.toml` but no `worker-configuration.d.ts`, bindings are untyped and prone to typos. Suggest running `wrangler types --env-interface CloudflareEnv`.

- **Using Node.js `fs` for file operations** — Next.js Server Components normally support `fs`, but on Cloudflare Workers they don't. Flag `fs.readFile`, `fs.writeFile`, etc. — use R2 instead.

- **Compatibility date too old** — `@opennextjs/cloudflare` requires `compatibility_date` of `2024-09-23` or later. Check `wrangler.toml` for an older date.

---

## Security

### Flag these across all Cloudflare services:

- **Hardcoded secrets in code** — API keys, tokens, database credentials should be in `wrangler.toml` secrets (`[vars]` for non-sensitive, `wrangler secret put` for sensitive). Flag any hardcoded credentials.

- **Missing authentication on Workers** — Workers are publicly accessible by default. If the Worker handles sensitive data, verify there's auth middleware (API keys, JWTs, Cloudflare Access).

- **CORS misconfiguration** — `Access-Control-Allow-Origin: *` on Workers that handle authenticated requests allows any site to make requests. Flag overly permissive CORS on sensitive endpoints.

- **Exposing binding names or internal structure** — error responses that leak binding names, table schemas, or internal paths help attackers understand the infrastructure. Return generic error messages to clients.

- **Not validating request method** — Workers receive all HTTP methods. If a handler only expects GET but doesn't check `request.method`, a POST with malicious body might be processed unexpectedly.

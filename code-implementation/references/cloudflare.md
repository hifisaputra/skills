# Cloudflare Reference

Load this reference when `wrangler.toml`, `wrangler.jsonc`, or `wrangler.json` is detected in the project.

## Table of Contents

1. [Workers Runtime Constraints](#workers-runtime-constraints)
2. [Bindings and Configuration](#bindings-and-configuration)
3. [D1 Database](#d1-database)
4. [R2 Storage](#r2-storage)
5. [KV](#kv)
6. [Queues](#queues)
7. [Next.js on Cloudflare Workers](#nextjs-on-cloudflare-workers)

---

## Workers Runtime Constraints

Workers run on the V8 isolate model, not a full Node.js process. Key differences:

- **No filesystem access** — `fs`, `path` are unavailable (use R2/KV for storage)
- **CPU time limits** — 30s for paid plans, 10ms for free (wall-clock time is more generous)
- **Memory** — 128 MB per Worker
- **Request size** — 100 MB max
- **Subrequest limit** — 1000 fetch calls per invocation (50 on free plan)
- **`nodejs_compat`** — enables Node.js API polyfills (Buffer, crypto, streams, etc.). Add to `wrangler.toml`:

```toml
compatibility_flags = ["nodejs_compat"]
```

Bindings to KV, R2, D1, and Queues are direct in-process references with no network hop and no auth overhead — always prefer them over REST APIs.

---

## Bindings and Configuration

All Cloudflare services are accessed through bindings in the `env` object. Define them in `wrangler.toml`:

```toml
name = "my-worker"
compatibility_date = "2024-09-23"
compatibility_flags = ["nodejs_compat"]

[[d1_databases]]
binding = "DB"
database_name = "my-db"
database_id = "xxx"

[[r2_buckets]]
binding = "BUCKET"
bucket_name = "my-bucket"

[[kv_namespaces]]
binding = "KV"
id = "xxx"

[[queues.producers]]
binding = "MY_QUEUE"
queue = "my-queue"

[[queues.consumers]]
queue = "my-queue"
max_batch_size = 10
max_batch_timeout = 30
```

Access in Worker code:

```ts
export default {
  async fetch(request: Request, env: Env) {
    const result = await env.DB.prepare('SELECT * FROM users').all()
    return Response.json(result.results)
  }
}
```

---

## D1 Database

D1 is a SQLite-based SQL database. All queries use prepared statements to prevent SQL injection.

### Basic queries

```ts
// Single row
const user = await env.DB.prepare('SELECT * FROM users WHERE id = ?')
  .bind(userId)
  .first()

// All rows
const { results } = await env.DB.prepare('SELECT * FROM users WHERE active = ?')
  .bind(1)
  .all()

// Insert / update / delete (use .run() — no rows returned)
await env.DB.prepare('INSERT INTO users (name, email) VALUES (?, ?)')
  .bind(name, email)
  .run()

// Raw value
const count = await env.DB.prepare('SELECT COUNT(*) as count FROM users')
  .first('count')
```

### Batch operations

Batch sends multiple statements in a single round trip. Statements execute sequentially and are atomic — if any fails, the entire batch rolls back.

```ts
const results = await env.DB.batch([
  env.DB.prepare('INSERT INTO users (name) VALUES (?)').bind('Alice'),
  env.DB.prepare('INSERT INTO users (name) VALUES (?)').bind('Bob'),
  env.DB.prepare('SELECT * FROM users'),
])
// results[2].results contains all users
```

### Return object shape

```ts
{
  results: T[],      // array of rows (empty for mutations)
  success: boolean,
  meta: {
    changes: number,  // rows affected
    last_row_id: number,
    duration: number,  // ms
  }
}
```

### Migrations

Store migrations in `migrations/` and run with:

```bash
wrangler d1 migrations apply my-db        # production
wrangler d1 migrations apply my-db --local # local dev
```

---

## R2 Storage

R2 is S3-compatible object storage with no egress fees.

### Core operations

```ts
// Upload
await env.BUCKET.put('images/photo.png', imageData, {
  httpMetadata: { contentType: 'image/png' },
  customMetadata: { uploadedBy: 'user-123' },
})

// Download
const object = await env.BUCKET.get('images/photo.png')
if (object === null) return new Response('Not found', { status: 404 })
return new Response(object.body, {
  headers: { 'Content-Type': object.httpMetadata?.contentType ?? '' },
})

// Check existence (metadata only, no body download)
const head = await env.BUCKET.head('images/photo.png')

// Delete
await env.BUCKET.delete('images/photo.png')

// Delete multiple
await env.BUCKET.delete(['file1.png', 'file2.png'])
```

### Listing objects

```ts
const listed = await env.BUCKET.list({
  prefix: 'images/',
  limit: 100,
  cursor: previousCursor, // for pagination
})

for (const object of listed.objects) {
  console.log(object.key, object.size)
}

if (listed.truncated) {
  // more results available — use listed.cursor for next page
}
```

### Multipart uploads (large files)

```ts
const multipart = await env.BUCKET.createMultipartUpload('large-file.zip')
const part1 = await multipart.uploadPart(1, chunk1)
const part2 = await multipart.uploadPart(2, chunk2)
await multipart.complete([part1, part2])
```

---

## KV

KV is a globally distributed key-value store. Optimized for read-heavy workloads. Eventually consistent — writes propagate globally within ~60 seconds.

### Core operations

```ts
// Write
await env.KV.put('user:123', JSON.stringify({ name: 'Alice' }))

// Write with expiration
await env.KV.put('session:abc', token, {
  expirationTtl: 3600, // seconds
})

// Write with metadata
await env.KV.put('file:doc.pdf', fileData, {
  metadata: { uploadedBy: 'user-123', size: 1024 },
})

// Read
const value = await env.KV.get('user:123')
const parsed = await env.KV.get('user:123', { type: 'json' })

// Read with metadata
const { value, metadata } = await env.KV.getWithMetadata('file:doc.pdf')

// Delete
await env.KV.delete('user:123')

// List keys
const { keys, list_complete, cursor } = await env.KV.list({
  prefix: 'user:',
  limit: 100,
})
```

### When to use KV vs D1

| KV | D1 |
|---|---|
| Simple key-value lookups | Relational data, JOINs, aggregations |
| Read-heavy, write-light | Balanced read/write |
| Global low-latency reads | Consistent writes |
| Config, sessions, feature flags | User data, transactions, structured queries |

---

## Queues

Queues decouple producers from consumers. Messages have at-least-once delivery.

### Producing messages

```ts
// Single message
await env.MY_QUEUE.send({ type: 'email', to: 'user@example.com' })

// With content type
await env.MY_QUEUE.send('plain text', { contentType: 'text' })

// Batch send
await env.MY_QUEUE.sendBatch([
  { body: { type: 'email', to: 'a@example.com' } },
  { body: { type: 'email', to: 'b@example.com' } },
])
```

### Consuming messages

```ts
export default {
  async queue(batch: MessageBatch<any>, env: Env) {
    for (const message of batch.messages) {
      try {
        await processMessage(message.body, env)
        message.ack()
      } catch (e) {
        message.retry()
      }
    }
  },
}
```

### Configuration options

```toml
[[queues.consumers]]
queue = "my-queue"
max_batch_size = 10       # messages per batch (default 10, max 100)
max_batch_timeout = 30    # seconds to wait for full batch (default 5)
max_retries = 3           # retry attempts before dead-letter (default 3)
dead_letter_queue = "my-dlq"  # optional
```

---

## Next.js on Cloudflare Workers

When deploying Next.js to Cloudflare Workers, use `@opennextjs/cloudflare` (the official adapter). This replaces the older `@cloudflare/next-on-pages` approach.

### Setup

```bash
npm install @opennextjs/cloudflare
```

Requires `nodejs_compat` and compatibility date `2024-09-23` or later in `wrangler.toml`.

### Accessing bindings in Next.js

Use `getCloudflareContext` from `@opennextjs/cloudflare` to access `env`:

```tsx
import { getCloudflareContext } from '@opennextjs/cloudflare'

export async function GET() {
  const { env } = await getCloudflareContext()
  const result = await env.DB.prepare('SELECT * FROM users').all()
  return Response.json(result.results)
}
```

Works in:
- Server Components
- Server Actions
- Route Handlers
- Middleware

### Type safety

Generate types from your wrangler config:

```bash
wrangler types --env-interface CloudflareEnv
```

This creates `worker-configuration.d.ts` with typed bindings. Then use in your code:

```tsx
const { env } = await getCloudflareContext<{ env: CloudflareEnv }>()
```

### Local development

`next dev` with `@opennextjs/cloudflare` simulates bindings locally using Miniflare. D1 uses a local SQLite file, KV/R2 use local storage. Run migrations locally first:

```bash
wrangler d1 migrations apply my-db --local
```

### Key differences from standard Next.js

- **No Node.js filesystem APIs** — use R2 for file storage, KV for key-value data
- **Edge runtime by default** — all routes run in the Workers runtime
- **Bindings instead of env vars** — access Cloudflare services through `getCloudflareContext().env`, not `process.env` (use `process.env` only for plain string config)
- **Cold starts** — Workers have minimal cold starts compared to serverless Node, but be mindful of large dependencies

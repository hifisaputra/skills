---
name: code-implementation
description: Implements a code task using a structured plan-first approach with TDD when tests exist, or direct implementation for docs/config changes. Use when user says "implement this", "build this feature", "fix this bug", or any request to write code for a well-defined task.
---

# Code Implementation

Structured approach to implementing a code task: understand, plan, implement, commit. Uses TDD when the project has test infrastructure, and direct implementation otherwise.

## Inputs

This skill expects a clear task — either an issue body, a user description, or a PR comment with requested changes. If the task is unclear, ask a specific clarifying question before proceeding.

## Step 1: Understand the task

Read the task description thoroughly. If it references other files, PRDs, or issues, read those too. Explore relevant parts of the codebase to understand the existing patterns and architecture.

### Load stack-specific references

Check the project root for framework config files and load the corresponding reference from `references/`:

- `next.config.*` detected → read `references/nextjs.md` (App Router patterns, Server/Client Components, Server Actions, common pitfalls)
- `wrangler.toml` / `wrangler.jsonc` / `wrangler.json` detected → read `references/cloudflare.md` (D1, R2, KV, Queues, Workers constraints, Next.js on Workers bindings)

Load both if both are present (Next.js on Cloudflare Workers). Skip if neither exists.

### Look up external docs

Before writing code that uses external libraries or APIs, look up the current documentation first (via context7 `resolve-library-id` + `query-docs`, or WebSearch). Do not rely on memory for method signatures or options. The bundled references cover common patterns but are not exhaustive — always verify against current docs for less common APIs.

If the task is ambiguous or missing critical information, stop and ask — never guess at requirements.

## Step 2: Estimate scope

Estimate how many lines of code this will likely require. If the estimate is >500 lines of changes, report the estimate and suggest breaking it into smaller pieces. If the caller (user or another skill) confirms to proceed anyway, continue — the threshold is a warning, not a hard stop.

## Step 3: Plan

Write a brief plan before touching any code:
- What files you'll change or create
- What behaviors you'll implement
- If using TDD: your red-green cycle order
- For bug fixes: which test will reproduce the bug

Post the plan where appropriate (as a comment on the issue, or communicate it to the user). Do NOT wait for approval — post and start.

## Step 4: Detect project tooling

### Test infrastructure

Check for test infrastructure in this order:
- `package.json` → `scripts.test` → `npm test` (or `bun test` if using Bun)
- `vitest.config.*` or `package.json` `scripts.test` containing `vitest` → `npx vitest run` (or `bunx vitest run`)
- `Makefile` / `Justfile` → `make test` / `just test`
- `pytest.ini`, `pyproject.toml` `[tool.pytest]`, or `tests/` dir → `pytest`
- `Cargo.toml` → `cargo test`
- `bun.lockb` without explicit test script → `bun test` (Bun's built-in test runner)
- `.github/workflows/*.yml` → look for the test step command

Detect the package manager from the lockfile: `bun.lockb` → bun, `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm. Use the matching runner for commands (e.g., `bunx` instead of `npx`).

If test infrastructure exists, verify the existing tests pass before writing any code:

```
<detected test command>
```

If tests are already failing, stop and report: "Existing tests are failing before any changes." Do not proceed until the suite is green.

If no test infrastructure is found, skip to Step 6.

### Linter / formatter

Also detect if the project has a linter or formatter:
- `package.json` → `scripts.lint` → `npm run lint` (use detected package manager)
- `next.config.*` → `next lint` (Next.js built-in linter, wraps ESLint)
- `.eslintrc*` / `eslint.config.*`, `biome.json` → `npx eslint` / `npx biome check`
- `pyproject.toml` `[tool.ruff]` or `ruff.toml` → `ruff check`
- `rustfmt.toml` or `Cargo.toml` → `cargo fmt --check`
- `.prettierrc*` → `npx prettier --check`

Prefer `scripts.lint` from `package.json` over individual tool detection — it reflects the project's intended lint configuration.

If found, run the linter after implementation (in both Step 5 and Step 6) to catch style issues before committing.

### shadcn/ui components

Check for `components.json` at the project root. If it exists, the project uses shadcn/ui. Read it to find:
- The UI component directory (from `aliases.ui`, e.g. `~/components/ui`)
- The package manager (from the lockfile, as detected above)

List the already-installed components:

```
ls <ui-directory>/
```

During implementation, when you need a shadcn component that isn't already installed, install it before writing code that imports it:

```
npx shadcn@latest add <component-name>
```

Use the detected package manager's runner (`bunx`, `pnpx`, `npx`). Common components: `button`, `card`, `dialog`, `dropdown-menu`, `input`, `select`, `table`, `tabs`, `toast`, `form`, `label`, `textarea`, `checkbox`, `radio-group`, `switch`, `sheet`, `popover`, `tooltip`, `alert`, `badge`, `separator`, `skeleton`, `avatar`, `accordion`, `command`, `calendar`, `slider`.

Do not manually create component files that shadcn can generate — the CLI handles styling, variants, and dependencies correctly.

### Build command

Detect the build command:
- `package.json` → `scripts.build` → `npm run build` (use detected package manager)
- `next.config.*` without explicit build script → `next build`
- `Cargo.toml` → `cargo build`
- `Makefile` / `Justfile` → `make build` / `just build`
- `pyproject.toml` with `[build-system]` → the configured build backend

If found, run the build after tests and lint pass (in both Step 5 and Step 6) to catch type errors, broken imports, and other compilation issues before pushing.

## Step 5: Implement with TDD

For **bug fixes**, start by writing a regression test that reproduces the bug — confirm it fails, then fix the code and confirm the test passes. This ensures the bug can't silently return.

For **new features**, install any missing shadcn/ui components first (if the project uses shadcn, as detected in Step 4), then implement each behavior in your plan:

```
RED:   Write one test that captures expected behavior → verify it fails
GREEN: Write minimal code to pass → verify it passes
```

Rules:
- One test at a time, vertical slices
- Tests verify behavior through public interfaces, not implementation details
- Only enough code to pass the current test
- Run tests after each step to confirm RED/GREEN state
- Never refactor while RED

After all tests pass, refactor if needed. Run tests again.

Commit after each meaningful unit of work (a completed red-green cycle, a refactor pass) rather than saving all commits for the end. This keeps commits atomic and makes review easier.

```
git add <specific-files>
git commit -m "<type>(#<ref>): <description>"
```

Run the full test suite one final time to make sure nothing else broke:

```
<detected test command>
```

If a linter was detected in Step 4, run it now and fix any issues before proceeding.

If a build command was detected in Step 4, run it now and fix any errors before proceeding. Build failures (type errors, missing imports, invalid config) must be resolved — do not push code that doesn't build.

If any pre-existing tests broke, fix them before proceeding.

Skip to Step 7.

## Step 6: Implement directly (no tests)

For documentation, configuration, or projects without test infrastructure — install any missing shadcn/ui components first (if applicable), then make the changes and verify them manually. Check that:
- Files are syntactically valid
- Changes match the task requirements
- Nothing unrelated was accidentally modified

If a linter was detected in Step 4, run it and fix any issues.

If a build command was detected in Step 4, run it and fix any errors before proceeding.

## Step 7: Push

Stage any remaining uncommitted changes explicitly rather than using `git add -A`, which can accidentally include secrets, build artifacts, or other untracked files.

```
git add <specific-files>
git commit -m "<type>(#<ref>): <description>"
git push -u origin HEAD
```

Commit types: `feat` for new features, `fix` for bug fixes, `docs` for documentation, `refactor` for restructuring.

If the push fails due to diverged history, rebase on main and retry:

```
git fetch origin main
git rebase origin/main
```

If the rebase produces conflicts, stop and report: "Merge conflict with main on `<file>`." Do not force push or silently discard changes.

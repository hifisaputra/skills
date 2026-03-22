---
name: code-review
description: Thorough code review of a PR — checks correctness, security, performance, style consistency, test coverage, and verifies the PR addresses its linked issue. Use when user says "review this PR", "check this PR", "look at this diff", or any request to review code changes.
---

# Code Review

Thorough review of a pull request. Checks for bugs, security issues, performance problems, style consistency, test coverage, and verifies the PR actually addresses its linked issue.

## Inputs

This skill expects either:
- A PR number or URL
- A diff piped in or referenced by the caller

If called by another skill (e.g., `process-reviews`), it receives the PR number and context. If called standalone, ask for the PR number.

## Step 1: Gather context

### Resolve repo info

```
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

### Read PR metadata

```
gh pr view <number> --json title,body,baseRefName,headRefName,files,additions,deletions
```

### Read the linked issue

Extract the issue number from the PR body (look for `Closes #N`, `Fixes #N`, `Resolves #N`). If found:

```
gh issue view <issue-number> --json title,body,labels
```

This is used later to verify the PR actually addresses the issue requirements.

### Load stack-specific review checklists

Check the project root for framework config files and load the corresponding review checklist:

- `next.config.*` detected → read `references/nextjs.md` (Server/Client boundary mistakes, Server Action vulnerabilities, caching bugs, async params)
- `wrangler.toml` / `wrangler.jsonc` / `wrangler.json` detected → read `references/cloudflare.md` (Workers runtime violations, D1/R2/KV misuse, queue idempotency, binding access patterns)

Load both if both are present (Next.js on Cloudflare Workers — the Cloudflare reference has a dedicated section for this combo). Use the checklists to catch stack-specific issues that a generic review would miss.

### Get the diff

```
gh pr diff <number>
```

For re-reviews (when the caller indicates previous feedback exists), also read previous review comments to check if feedback was addressed:

```
gh pr view <number> --comments
gh api repos/$REPO/pulls/<number>/comments
```

### Read surrounding source code

The diff alone is not enough. For each changed file, read the surrounding context to understand:
- Function/class scope around the changes
- Imports and dependencies
- How the changed code is used elsewhere

```
gh pr view <number> --json files --jq '.files[].path'
```

Read at least the full functions/classes where changes were made.

## Step 2: Analyze

Review the changes thoroughly across all of these dimensions:

### Correctness
- Logic errors, off-by-one, null/undefined risks
- Race conditions, deadlocks
- Error handling gaps (uncaught promises, missing try/catch)
- Edge cases not covered

### Security
- SQL injection, XSS, command injection
- Auth/authz issues (missing permission checks)
- Secret exposure (API keys, tokens in code)
- OWASP top 10 concerns
- Unsafe deserialization, path traversal

### Performance
- N+1 queries
- Unnecessary allocations or copies
- Missing database indexes for new queries
- Unbounded loops or result sets
- Large payloads without pagination

### Style and consistency
- Naming consistency with existing codebase patterns
- Code structure matching project conventions
- Duplicated logic that already exists elsewhere
- Overly complex code that could be simplified

### Test coverage
- Were tests added for new behavior?
- Do tests cover edge cases and error paths?
- Are tests testing behavior (not implementation details)?
- For bug fixes: is there a regression test?

### Issue alignment
If a linked issue was found, verify:
- Does the PR actually implement what the issue asked for?
- Are there requirements in the issue that the PR doesn't address?
- Did the PR add scope beyond what the issue requested?

Flag any gaps between the issue requirements and the PR implementation.

## Step 3: Categorize findings

Group each finding by severity:

- **Bug** — incorrect behavior, will cause issues in production
- **Security** — vulnerability that needs fixing before merge
- **Performance** — measurable performance impact
- **Suggestion** — improvement that would make the code better but isn't blocking
- **Nit** — minor style/preference issue
- **Question** — something unclear that the author should clarify

## Step 4: Post the review

### Format inline comments

For each finding, prepare an inline comment on the specific file and line:

```json
[
  {
    "path": "src/api/users.ts",
    "line": 42,
    "body": "**Bug**: This query doesn't handle the case where `userId` is undefined. `env.DB.prepare()` will bind `undefined` as a literal string.\n\n```suggestion\nif (!userId) return Response.json({ error: 'Missing userId' }, { status: 400 })\n```"
  }
]
```

### Post as a review

Use the GitHub review API to post all comments atomically as a single review:

```
gh api repos/$REPO/pulls/<number>/reviews \
  --method POST \
  -f event="COMMENT" \
  -f body="$(cat <<'EOF'
**[AI]** ## Code Review

### Summary
<1-2 sentence overview of the changes and overall quality>

### Findings
<count by severity — e.g., "1 bug, 2 suggestions, 1 nit">

### Issue Alignment
<whether the PR addresses the linked issue, any gaps>

---
*Automated review — a human reviewer should verify these findings before merging.*
EOF
)" \
  --jq '.id'
```

Post inline comments via the review. If the `gh api` call with inline comments is too complex, fall back to individual `gh pr comment` calls for each finding, clearly referencing the file and line.

### Review verdict

Return one of these verdicts to the caller:
- **approve** — no bugs or security issues found (suggestions/nits don't block)
- **request-changes** — bugs, security issues, or missing issue requirements found

Always use `COMMENT` event, never `REQUEST_CHANGES` or `APPROVE` — the AI signals its opinion through labels, but the human makes the final call on the PR.

## Re-review behavior

When reviewing a PR that was previously reviewed (indicated by the caller or by existing `**[AI]**` comments):

1. Read previous review comments to understand what was flagged
2. Check if each previous finding was addressed in the new commits
3. Flag any previous findings that were NOT addressed
4. Review new changes for fresh issues
5. Post a re-review summary noting what was resolved and any remaining/new issues

## Safety

- Never use `APPROVE` or `REQUEST_CHANGES` events — only `COMMENT`
- Never merge PRs
- Never push changes to the PR branch
- All comments must start with `**[AI]**`

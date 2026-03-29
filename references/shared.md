# Shared Workflow References

Common patterns used across all loop skills (process-issues, process-reviews, process-pr, supervisor). Each skill references this file instead of duplicating the logic.

## Worktree Setup

Each loop skill MUST run in its own git worktree to avoid conflicts with parallel Claude instances.

Before starting, check if already in a worktree:

```
git rev-parse --show-toplevel
```

If NOT already in a worktree for this skill, create one using the `EnterWorktree` tool (if available). If `EnterWorktree` is not available, create one manually:

```
WORKTREE=$(git rev-parse --show-toplevel)/../$(basename "$(git rev-parse --show-toplevel)")-<suffix>
git worktree add --detach "$WORKTREE" main 2>/dev/null || true
```

Use `--detach` because `main` is typically already checked out in the primary worktree — `git worktree add "$WORKTREE" main` will silently fail otherwise.

Prefix ALL subsequent commands with `cd $WORKTREE &&` (cd does not persist between Bash calls).

Install dependencies if needed:

```
cd $WORKTREE && [ ! -d "node_modules" ] && (bun install 2>/dev/null || npm install 2>/dev/null || true)
```

**Worktree suffixes by skill:**
- process-issues → `-issues`
- process-reviews → `-reviews`
- process-pr → `-merge`
- supervisor → `-supervisor`

## Pre-flight Checks

Run before every cycle. If any fail, stop and report.

```
git worktree prune
gh auth status
git status --porcelain
```

- If `git status --porcelain` produces output → stop: "Working tree is dirty. Commit or stash changes before running."
- If `gh auth status` fails → stop: "GitHub CLI is not authenticated. Run `gh auth login`."

### Label creation

Ensure all required labels exist (no-op if already present):

```
for label in ai-ready ai-in-progress ai-done ai-blocked ai-needs-input needs-ai-review ai-changes-requested ai-approved prd; do
  gh label create "$label" 2>/dev/null || true
done
```

### Pause check

The `ai-pause` label is the graceful stop signal. **Create** the label to pause, **delete** it (`gh label delete ai-pause -y`) to resume.

```
gh label list --search "ai-pause" --json name --jq '.[].name' | grep -qx "ai-pause"
```

`--search` is a fuzzy substring match (it returns labels like `ai-ready`, `ai-done` too), so `grep -qx` is needed for exact match. If `grep` matches → stop: "ai-pause label detected. Stopping gracefully. Delete the label (`gh label delete ai-pause -y`) to resume."

### Repo variable

```
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

## Comment Authorship

All comments posted by AI MUST start with `**[AI]**`. When reading comments:
- Starts with `**[AI]**` → AI (previous runs)
- Does NOT start with `**[AI]**` → human

## Rate Limit Handling

If a `gh` command fails with HTTP 403 or "rate limit exceeded", stop the current cycle and report: "GitHub API rate limit hit. Wait before retrying." Do not retry immediately.

## Safety Rails

- Never force push
- Never use `APPROVE` or `REQUEST_CHANGES` review events — only `COMMENT`
- Skip draft PRs even if labeled
- `ai-pause` label stops all work gracefully
- Never leave an issue `ai-in-progress` after failure — always move to `ai-blocked`

## `ai-needs-input` Transition

When scanning for eligible issues, also check `ai-needs-input` issues for human responses:

```
gh issue list --label "ai-needs-input" --state open --limit 100 --json number,title,body,labels
```

For each, read comments and check if a human has replied after the last AI comment. If a human comment exists:

```
gh issue edit <number> --remove-label "ai-needs-input" --add-label "ai-ready"
gh issue comment <number> --body "**[AI]** Human input received. Moving to ai-ready."
```

Then include these issues in the normal selection pool.

## Review-Cycle Limit

When addressing PR feedback, track how many review cycles a PR has been through by counting `**[AI]** Addressed review feedback` comments on the PR. If a PR has been through 3+ AI feedback cycles without being approved, escalate instead of continuing:

```
gh pr comment <number> --body "**[AI]** This PR has been through 3 review cycles without resolution. Escalating for human review."
gh pr edit <number> --remove-label "ai-changes-requested" --add-label "ai-needs-input"
```

Do not continue addressing feedback on this PR — a human needs to look at it.

## New-Commit Check for Approved PRs

Before merging an `ai-approved` PR, verify no new commits were pushed after the last AI review:

```
LAST_COMMIT=$(gh pr view <number> --json commits --jq '.commits[-1].committedDate')
LAST_REVIEW=$(gh pr view <number> --json comments --jq '[.comments[] | select(.body | startswith("**[AI]**")) | .createdAt] | sort | last // empty')
```

If `LAST_REVIEW` is empty (no AI review comment found) OR `LAST_COMMIT` is newer than `LAST_REVIEW`, the approval is stale:

```
gh pr edit <number> --remove-label "ai-approved" --add-label "needs-ai-review"
gh pr comment <number> --body "**[AI]** New commits detected since last review. Sending back for re-review."
```

Skip this PR (do not merge). It will be picked up by the review phase.

The `// empty` in the jq expression returns an empty string instead of `null` when no AI comments exist, preventing silent date-comparison failures.

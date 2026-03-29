---
name: process-pr
description: Autonomous loop that picks up ai-approved PRs, does a final verification (issue resolution + merge conflicts), and merges or sends back for rework. Use when user says "merge PRs", "process PRs", "finalize PRs", "check PRs for merge", or wants AI to autonomously merge ready PRs. Also triggers on "merge ready PRs", "land PRs", or "ship it".
---

# Process PR

Autonomous loop that picks up `ai-approved` PRs, performs a final verification pass, and either merges them or sends them back to `process-issues` for rework.

This is the last gate before code lands. The two checks are intentionally narrow — the heavy review already happened in `code-review`. This skill only verifies:

1. **Issue resolution** — does the PR actually address what the linked issue asked for?
2. **Merge readiness** — is the PR free of merge conflicts and has CI passed?

If both pass, merge. If either fails, send the PR back with a clear explanation so `process-issues` can fix it.

## Shared Setup

Read `references/shared.md` for:
- **Comment authorship** convention (`**[AI]**` prefix)
- **Worktree isolation** — use suffix `-merge`
- **Pre-flight checks** (Phase 0) — worktree prune, gh auth, clean tree, label creation, pause check, repo variable
- **Rate limit handling**
- **Safety rails**

---

## Phase 1: Find PRs to process

```
gh pr list --state open --label "ai-approved" --json number,title,url,isDraft,headRefName --limit 50
```

Filter out draft PRs. Process up to 5 PRs per cycle — if more remain, they'll be handled in the next cycle.

If no PRs are found, report "No ai-approved PRs to process" and stop (or loop back if running with `/loop`).

---

## Phase 2: Verify each PR

For each PR, run two checks. Both must pass for the PR to be merged.

### 2A. Check issue resolution

Extract the linked issue number from the PR body. Look for `Closes #N`, `Fixes #N`, or `Resolves #N`:

```
gh pr view <number> --json body --jq '.body'
```

If no linked issue is found, the PR cannot be verified — send it back:

```
gh pr comment <number> --body "$(cat <<'EOF'
**[AI]** Cannot verify this PR — no linked issue found in the PR body.

Please add `Closes #<issue-number>` to the PR description so I can verify the changes match the requirements.
EOF
)"
gh pr edit <number> --remove-label "ai-approved" --add-label "ai-changes-requested"
```

Skip to the next PR.

If a linked issue is found, read both the issue and the PR diff:

```
gh issue view <issue-number> --json title,body
gh pr diff <number>
```

Compare the issue requirements against the actual changes. This is a focused check — the full code review already happened. You're answering one question: **do these changes address what the issue asked for?**

Things that indicate the issue is NOT resolved:
- The issue asked for feature X, but the PR implements something different
- The issue lists multiple requirements and one or more are missing from the changes
- The PR only partially implements what was asked (e.g., backend done but frontend missing, when both were required)

Things that are fine and should NOT block merge:
- Minor implementation differences from the issue description (the issue describes the "what", not the "how")
- Additional improvements beyond what the issue asked for
- Style differences from what the issue suggested

If the changes don't resolve the issue, send the PR back with specifics about what's missing.

### 2B. Check merge readiness

Check the PR's merge status via the GitHub API:

```
gh pr view <number> --json mergeable,mergeStateStatus,statusCheckRollup
```

Interpret the results:

**Merge conflicts** (`mergeable` is `CONFLICTING`):
The PR has conflicts with the base branch. Send it back — process-issues will need to rebase or resolve conflicts.

**CI failing** (`mergeStateStatus` is `UNSTABLE` or check rollup shows failures):
Check the specific failures:

```
gh pr checks <number> --json name,state,bucket
```

If checks are failing, send the PR back — process-issues will need to fix the failures.

**Behind base branch** (`mergeStateStatus` is `BEHIND`):
This is not a blocker if there are no conflicts. GitHub will handle the merge. Proceed.

**No CI checks** (`statusCheckRollup` is empty `[]`):
The repo has no CI configured. This is not a blocker — proceed if `mergeable` is `MERGEABLE`.

**Clean** (`mergeStateStatus` is `CLEAN` and `mergeable` is `MERGEABLE`):
Ready to merge.

**Unknown** (`mergeable` is `UNKNOWN`):
GitHub hasn't computed the merge status yet. Wait a few seconds and retry once:

```
sleep 5
gh pr view <number> --json mergeable,mergeStateStatus
```

If still unknown after retry, skip this PR for now — it will be picked up in the next cycle.

### 2C. Check for stale approval

Before merging, verify the approval is still valid — no new commits since the last AI review (see `references/shared.md` → "New-Commit Check for Approved PRs"). If stale, relabel to `needs-ai-review` and skip this PR.

---

## Phase 3: Act

### If both checks pass → Merge

Use the `--repo` flag to avoid failures when the worktree is in detached HEAD state (which is the common case — `gh pr merge` without `--repo` fails with "not on any branch"):

```
gh pr merge <number> --squash --delete-branch --repo $REPO
```

If the merge command exits non-zero, check whether the PR was actually merged (GitHub may have completed the server-side merge before the local error):

```
gh pr view <number> --json state --jq '.state'
```

If the state is `MERGED`, the merge succeeded despite the error — proceed normally. If it's still `OPEN`, the merge truly failed — send the PR back with the error message.

The `Closes #N` in the PR body automatically closes the linked issue when the PR merges. Verify the issue closed:

```
gh issue view <issue-number> --json state --jq '.state'
```

If still open (rare — usually means `Closes #N` syntax was wrong), close it manually:

```
gh issue edit <issue-number> --remove-label "ai-done"
gh issue close <issue-number>
```

This is a fallback — normally GitHub handles it.

Update local state to stay current:

```
git fetch origin main
git reset --hard origin/main
```

### If either check fails → Send back

Remove `ai-approved` and add `ai-changes-requested` so `process-issues` picks it up in its Phase A:

```
gh pr edit <number> --remove-label "ai-approved" --add-label "ai-changes-requested"
```

Post a comment explaining exactly what failed. The comment should be actionable — process-issues will read it to understand what to fix:

**If issue not resolved:**

```
gh pr comment <number> --body "$(cat <<'EOF'
**[AI]** Final verification failed — PR does not fully resolve the linked issue.

**Issue:** #<issue-number> — <issue-title>

**What's missing:**
- <specific requirement from the issue that isn't addressed>

Sending back for rework.
EOF
)"
```

**If merge conflict:**

```
gh pr comment <number> --body "$(cat <<'EOF'
**[AI]** Final verification failed — merge conflict detected.

Please rebase onto main and resolve conflicts.

Sending back for rework.
EOF
)"
```

**If CI failing:**

```
gh pr comment <number> --body "$(cat <<'EOF'
**[AI]** Final verification failed — CI checks are failing.

**Failing checks:**
- <check name>: <failure summary>

Sending back for rework.
EOF
)"
```

Also update the linked issue label back to `ai-ready` so process-issues treats it as actionable (it won't pick up the PR feedback otherwise since the issue would still be labeled `ai-done`):

```
gh issue edit <issue-number> --remove-label "ai-done" --add-label "ai-ready"
gh issue comment <issue-number> --body "**[AI]** PR #<number> sent back for rework: <brief reason>. Resetting to ai-ready."
```

---

## Phase 4: Report

After processing all PRs in this cycle, report a summary:

```
Processed N PRs:
- #123 "Add user auth" → merged
- #456 "Fix pagination" → sent back (merge conflict)
- #789 "Update docs" → sent back (missing requirement: API docs not updated)
```

Then loop back to Phase 0 for the next cycle.

---

## Usage with /loop

```
/loop 10m /process-pr
```

## Safety Rails

- Only merge PRs that are labeled `ai-approved` — never merge PRs that haven't been through code review
- Always use `--squash` merge to keep history clean
- Always `--delete-branch` after merge to clean up
- If a `gh` command fails with HTTP 403 or "rate limit exceeded", stop the current cycle and report: "GitHub API rate limit hit. Wait before retrying." Do not retry immediately.
- Never force push
- If the merge command fails, check `gh pr view --json state` before giving up — the merge may have completed server-side despite the local error. Only send back if the PR is still `OPEN`
- Skip draft PRs even if labeled `ai-approved`

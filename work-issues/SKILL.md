---
name: work-issues
description: Autonomous loop that implements ai-ready GitHub issues, handles PR feedback, and asks clarifying questions when blocked. Use when user says "work issues", "start working", "process backlog", or wants AI to autonomously implement GitHub issues.
---

# Work Issues

Autonomous loop that picks up `ai-ready` issues, implements them, and handles feedback on open PRs.

## Worktree Isolation

This skill MUST run in its own git worktree to avoid conflicts with other parallel Claude instances.

Before starting, check if already in a worktree:

```
git rev-parse --show-toplevel
```

If NOT already in a worktree for this skill, create one and switch to it using the `EnterWorktree` tool (if available). If `EnterWorktree` is not available, create one manually and prefix ALL subsequent commands with `cd <worktree-path> &&`:

```
WORKTREE=$(git rev-parse --show-toplevel)/../$(basename "$(git rev-parse --show-toplevel)")-issues
git worktree add "$WORKTREE" main 2>/dev/null || true
```

Then for every command in this skill, prefix with:
```
cd $WORKTREE && <command>
```

This is necessary because `cd` does not persist between Bash calls.

## Loop Cycle

Each cycle runs through three phases in order:

0. **Pre-flight checks** — verify the environment is ready
1. **Handle feedback** on existing PRs
2. **Implement** the next available issue

---

## Phase 0: Pre-flight Checks

Run these before every cycle. If any fail, stop and report the problem.

```
# Check gh is authenticated
gh auth status

# Check working tree is clean (no uncommitted changes)
git status --porcelain
```

If `git status --porcelain` produces output, stop: "Working tree is dirty. Commit or stash changes before running."

If `gh auth status` fails, stop: "GitHub CLI is not authenticated. Run `gh auth login`."

Check for an `ai-pause` label on the repo — this is the graceful stop signal:

```
gh label list --search "ai-pause" --json name
```

If the `ai-pause` label exists, stop: "ai-pause label detected. Stopping gracefully. Remove the label to resume."

---

## Phase A: Handle PR Feedback

### A1. Find PRs needing attention

First, check for PRs labeled `ai-changes-requested` — this is the primary signal:

```
gh pr list --author "@me" --state open --label "ai-changes-requested" --json number,title,url
```

If no labeled PRs are found, fall back to comment-based detection for PRs that may not have labels (e.g. PRs created outside this workflow):

```
gh pr list --author "@me" --state open --json number,title,url,isDraft,labels
```

For each PR without an `ai-changes-requested`, `needs-ai-review`, or `ai-approved` label, check comments:

```
gh pr view <number> --comments
gh api repos/{owner}/{repo}/pulls/<number>/comments
```

A PR needs attention if:
- It has review comments or PR comments with no `<!-- feedback-addressed -->` after them
- It has review comments or PR comments posted AFTER the most recent `<!-- feedback-addressed -->` comment

If no PRs need attention, skip to Phase B.

### A2. Address feedback

For each PR needing attention:

```
gh pr checkout <number>
```

Read the review comments:

```
gh pr view <number> --comments
gh api repos/{owner}/{repo}/pulls/<number>/comments
```

Categorize each new comment:
- **Fix**: concrete change requested — make the change, run tests
- **Question**: reviewer wants clarification — reply with an answer; if it reveals a needed change, make it
- **Nit**: style/preference — apply if reasonable, group into one commit

Commit fixes:

```
git commit -m "fix(#<issue>): address review - <brief description>"
git push
```

Post a summary and update labels:

```
gh pr comment <number> --body "$(cat <<'EOF'
<!-- feedback-addressed -->
Addressed review feedback:
- <what was fixed>

Ready for another look.
EOF
)"
```

Update the PR label to request a new review:

```
gh pr edit <number> --remove-label "ai-changes-requested" --add-label "needs-ai-review"
```

Return to the issue branch or main before continuing.

---

## Phase B: Implement Next Issue

### B0. Recover stale issues

Check for issues stuck in `ai-in-progress` from a previous crashed run:

```
gh issue list --label "ai-in-progress" --state open --json number,title
```

For each one, check if there's an active branch or open PR:

```
git branch --list "issue-<number>-*"
gh pr list --head "issue-<number>-*" --json number,state
```

- If a draft PR exists, the work was partially done — skip it (it will be handled when someone reviews it or closes it)
- If no branch and no PR exist, the issue was claimed but never worked on — reset it:

```
gh issue edit <number> --remove-label "ai-in-progress" --add-label "ai-ready"
gh issue comment <number> --body "Resetting to ai-ready — previous work session was interrupted before any progress was made."
```

### B1. Find the next issue

```
gh issue list --label "ai-ready" --state open --json number,title,body,labels
```

Also check for previously blocked issues that now have answers:

```
gh issue list --label "ai-blocked" --state open --json number,title,body,labels
```

For `ai-blocked` issues, read the comments to see if a human has replied to the AI's question. If yes, treat it as eligible again.

Selection order:
1. Unblocked `ai-blocked` issues with answered questions (priority first, then oldest)
2. `ai-ready` issues not labeled `ai-in-progress` (priority first, then oldest)
3. Skip issues whose "Blocked by" references are still open

Priority: if an issue has a `priority:high` or `priority:critical` label, pick it before lower-priority or unlabeled issues.

If no issues are eligible, report "No issues to work on" and stop.

### B2. Claim the issue

```
gh issue edit <number> --remove-label "ai-ready" --add-label "ai-in-progress"
gh issue comment <number> --body "Starting work on this issue."
git checkout -b issue-<number>-<short-slug>
```

For previously `ai-blocked` issues:

```
gh issue edit <number> --remove-label "ai-blocked" --add-label "ai-in-progress"
gh issue comment <number> --body "Question answered. Resuming work."
```

### B3. Understand the issue

Read the issue body. If it references a parent PRD, read that too. Explore relevant parts of the codebase.

**If the issue is unclear or missing critical information:**

- Comment on the issue with a specific question:

```
gh issue comment <number> --body "$(cat <<'EOF'
<!-- ai-question -->
I have a question before I can proceed:

<specific question about what's unclear>

Labeling as `ai-blocked` — I'll pick this up again once answered.
EOF
)"
```

- Label it `ai-blocked`, remove `ai-in-progress`:

```
gh issue edit <number> --remove-label "ai-in-progress" --add-label "ai-blocked"
```

- **Move to the next issue** (go back to B1)

### B4. Estimate size

Before planning, estimate how many lines of code this will likely require. If the estimate is >500 lines of changes:

```
gh issue comment <number> --body "This issue looks too large for autonomous implementation (~<estimate> lines). Consider breaking it into smaller issues."
gh issue edit <number> --remove-label "ai-in-progress" --add-label "ai-blocked"
```

Move to the next issue.

### B5. Plan

Post a brief plan as a comment on the issue:
- What you'll change
- Which behaviors you'll test
- Your TDD cycle order (RED-GREEN pairs)

Do NOT wait for approval — post the plan and start.

### B6. Implement with TDD

Before writing code that uses external libraries or APIs, look up the current documentation first (via context7 `resolve-library-id` + `query-docs`, or WebSearch). Do not rely on memory for method signatures or options.

For each behavior in your plan:

```
RED:   Write one test that captures expected behavior -> verify it fails
GREEN: Write minimal code to pass -> verify it passes
```

Rules:
- One test at a time, vertical slices
- Tests verify behavior through public interfaces, not implementation details
- Only enough code to pass the current test
- Run tests after each step to confirm RED/GREEN state
- Never refactor while RED

After all tests pass, refactor if needed. Run tests again.

### B7. Commit and push

Make clean, atomic commits as you go.

```
git add -A
git commit -m "feat(#<number>): <description>"
git push -u origin issue-<number>-<short-slug>
```

### B8. Open a draft PR

```
gh pr create --draft --title "<issue title>" --body "$(cat <<'EOF'
Closes #<number>

## What was done

<brief summary of changes>

## Decisions made

<any non-obvious choices and why>

## Testing

<what tests were added and what they verify>
EOF
)"
```

### B9. Update the issue

```
gh issue edit <number> --remove-label "ai-in-progress" --add-label "ai-done"
gh issue comment <number> --body "PR opened: <pr-url>"
```

### B10. Wait for CI

Check if the repo has CI checks configured. If it does, wait for them to pass:

```
gh pr checks <pr-number> --watch --fail-level all
```

If checks fail:
- Read the failure logs: `gh pr checks <pr-number>`
- Fix the issue, commit, and push
- Wait for checks again
- If checks fail 3 times, leave the PR as draft, comment on the issue explaining the CI failure, and move to the next issue

### B11. Mark PR ready for review

Only mark ready after CI passes (or if the repo has no CI checks):

```
gh pr ready <pr-number>
gh pr edit <pr-number> --add-label "needs-ai-review"
```

### B12. Next issue

Report: "Finished #<number>. Moving to next cycle."

Go back to the top of the loop (Phase A).

---

## Usage with /loop

```
/loop 10m /work-issues
```

## Safety Rails

- Open PRs as drafts first, then mark ready for review — never merge
- If an issue seems too large (>500 lines of changes), stop and tell the user
- If tests in the repo are failing before you start, stop and tell the user
- If you encounter a conflict with another branch, stop and tell the user
- Never force push
- When blocked, always ask a specific question — never guess

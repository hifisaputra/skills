---
name: supervisor
description: Unified autonomous loop that runs the full AI pipeline in one cycle — merges approved PRs, reviews PRs, handles feedback, and implements the next issue. Replaces running process-issues, process-reviews, and process-pr as three separate loops. Use when user says "start working", "run supervisor", "run pipeline", "work on everything", or wants AI to autonomously handle the full issue-to-merge lifecycle in a single session.
---

# Supervisor

Single-loop orchestrator that runs the full AI pipeline each cycle. Instead of three separate `/loop` commands, this runs all phases sequentially in one session, saving API cost and context.

## Cycle Order

Each cycle clears the pipeline from the end first:

1. **Merge** — land `ai-approved` PRs (clears the way)
2. **Review** — review `needs-ai-review` PRs (produces `ai-approved`)
3. **Feedback** — address `ai-changes-requested` PRs (produces `needs-ai-review`)
4. **Implement** — pick up the next `ai-ready` issue (produces new PRs)

## Comment Authorship

Every comment posted by AI MUST start with `**[AI]**`. When reading comments:
- Starts with `**[AI]**` → AI (previous runs)
- Does NOT start with `**[AI]**` → human

## Worktree Isolation

This skill MUST run in its own git worktree.

```
git rev-parse --show-toplevel
```

If NOT already in a worktree for this skill, create one:

```
WORKTREE=$(git rev-parse --show-toplevel)/../$(basename "$(git rev-parse --show-toplevel)")-supervisor
git worktree add --detach "$WORKTREE" main 2>/dev/null || true
```

Prefix ALL subsequent commands with `cd $WORKTREE &&`. Install dependencies if needed:

```
cd $WORKTREE && [ ! -d "node_modules" ] && (bun install 2>/dev/null || npm install 2>/dev/null || true)
```

---

## Phase 0: Pre-flight

Run before every cycle. If any fail, stop and report.

```
git worktree prune
gh auth status
git status --porcelain
```

If dirty → stop. If not authenticated → stop.

Ensure labels exist:

```
for label in ai-ready ai-in-progress ai-done ai-blocked ai-needs-input needs-ai-review ai-changes-requested ai-approved prd; do
  gh label create "$label" 2>/dev/null || true
done
```

Check `ai-pause` (create label to pause, delete to resume):

```
gh label list --search "ai-pause" --json name --jq '.[].name' | grep -qx "ai-pause"
```

`--search` is fuzzy, so `grep -qx` is needed for exact match. If found → stop gracefully.

```
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

---

## Phase 1: Merge Approved PRs

Up to 5 PRs per cycle.

### 1.1 Find

```
gh pr list --state open --label "ai-approved" --json number,title,url,isDraft,headRefName --limit 50
```

Filter out drafts. If none → skip to Phase 2.

### 1.2 Verify each PR

**Issue resolution** — extract issue number from PR body (`Closes #N`, `Fixes #N`):

```
gh pr view <number> --json body --jq '.body'
gh issue view <issue-number> --json title,body
gh pr diff <number>
```

If no linked issue → send back asking to add `Closes #N`. Otherwise verify the diff addresses the issue requirements. Minor implementation differences are fine — check for missing requirements or wrong feature.

**Merge readiness:**

```
gh pr view <number> --json mergeable,mergeStateStatus,statusCheckRollup
```

- `CONFLICTING` → send back
- CI failing → check `gh pr checks <number>`, send back
- `UNKNOWN` → `sleep 5`, retry once, skip if still unknown
- `BEHIND` without conflicts → OK, proceed
- `CLEAN`/`MERGEABLE` → proceed

### 1.3 Act

**Both pass → Merge:**

```
gh pr merge <number> --squash --delete-branch --repo $REPO
```

If merge command fails, verify with `gh pr view <number> --json state --jq '.state'`. If `MERGED` → proceed. If `OPEN` → send back.

After merge:

```
git fetch origin main && git reset --hard origin/main
```

**Either fails → Send back:**

```
gh pr edit <number> --remove-label "ai-approved" --add-label "ai-changes-requested"
gh pr comment <number> --body "**[AI]** Final verification failed — <reason>. Sending back for rework."
gh issue edit <issue-number> --remove-label "ai-done" --add-label "ai-ready"
gh issue comment <issue-number> --body "**[AI]** PR #<number> sent back: <brief reason>. Resetting to ai-ready."
```

---

## Phase 2: Review PRs

Up to 5 PRs per cycle. Delegates to the `code-review` skill.

### 2.1 Find PRs from three sources

**Labeled `needs-ai-review`:**

```
gh pr list --state open --label "needs-ai-review" --json number,title,url,isDraft,author --limit 100
```

**Stale `ai-approved`** (new commits since last review):

```
gh pr list --state open --label "ai-approved" --json number,title,url,isDraft,author,updatedAt --limit 50
```

For each, compare dates:

```
gh pr view <number> --json commits --jq '.commits[-1].committedDate'
gh pr view <number> --json comments --jq '[.comments[] | select(.body | startswith("**[AI]**")) | .createdAt] | sort | last'
```

If last commit is newer → relabel to `needs-ai-review`.

**Unlabeled PRs** (up to 15, fallback):

```
gh pr list --state open --json number,title,url,isDraft,author,labels --limit 50
```

Filter to PRs without any AI workflow label. Check if they have `**[AI]**` review comments — if not, they need a first review.

Deduplicate all sources, take first 5, skip all drafts.

### 2.2 Review each PR

```
gh pr checkout <number> --detach
gh pr view <number> --json isDraft --jq '.isDraft'
```

If now draft → skip. Otherwise delegate to `code-review` skill with the PR number.

After review:

```
git checkout --detach origin/main
```

### 2.3 Update labels

Based on `code-review` verdict:
- **request-changes:** `--remove-label "needs-ai-review" --add-label "ai-changes-requested"`
- **approve:** `--remove-label "needs-ai-review" --remove-label "ai-changes-requested" --add-label "ai-approved"`

---

## Phase 3: Handle PR Feedback

Up to 3 PRs per cycle.

### 3.1 Find PRs

**Primary — labeled:**

```
gh pr list --author "@me" --state open --label "ai-changes-requested" --json number,title,url
```

**Unlabeled with feedback:**

```
gh pr list --author "@me" --state open --json number,title,url,isDraft,labels
```

For each without workflow labels, read comments and check for unaddressed human feedback.

**Rejected PRs** (closed without merge, reset linked issues):

```
gh pr list --author "@me" --state closed --limit 10 --json number,title,mergedAt,body,closedAt
```

For closed PRs where `mergedAt` is empty, extract issue number. If issue still has `ai-done` label and no human assignee, reset to `ai-ready`.

### 3.2 Address feedback

For each PR:

```
gh pr checkout <number>
gh pr view <number> --comments
gh api repos/$REPO/pulls/<number>/comments
```

Categorize comments:
- **Fix** — concrete change → use `code-implementation` skill
- **Question** — reply with answer, make changes if needed
- **Nit** — apply if reasonable, group into one commit

Commit, push, update:

```
git commit -m "fix(#<issue>): address review - <brief description>"
git push
gh pr comment <number> --body "**[AI]** Addressed review feedback:\n- <what was fixed>\n\nReady for another look."
gh pr edit <number> --remove-label "ai-changes-requested" --add-label "needs-ai-review"
```

Return to clean state:

```
git fetch origin main && git checkout --detach origin/main
```

---

## Phase 4: Implement Next Issue

### 4.0 Recover stale issues

```
gh issue list --label "ai-in-progress" --state open --limit 100 --json number,title
```

For each, check for active branch or open PR:

```
git branch --list "issue-<number>-*" | head -1
git ls-remote --heads origin "issue-<number>-*" 2>/dev/null | head -1
gh pr list --author "@me" --state open --json number,headRefName --jq ".[] | select(.headRefName | startswith(\"issue-<number>-\")) | .number"
```

- Open PR exists → skip (will be handled when reviewed/closed)
- Branch exists but no PR → skip (leave for manual inspection)
- No branch, no PR → reset to `ai-ready`

### 4.1 Find the next issue

```
gh issue list --label "ai-ready" --state open --limit 100 --json number,title,body,labels
gh issue list --label "ai-blocked" --state open --limit 100 --json number,title,body,labels
```

For `ai-blocked` issues, check if unblocked:
- **Dependency-blocked** — check if blocking issues are closed
- **Question-blocked** — check if human replied after last AI question
- **Failure-blocked** — only resume if human commented since failure

Selection: unblocked issues first, then `ai-ready`. Priority labels first (`priority:high`, `priority:critical`), then oldest.

**Persistent failure guard:** Skip issues attempted 2+ times without new human input.

If nothing eligible → report "No issues to work on" and end cycle.

### 4.2 Claim and implement

```
git fetch origin main && git reset --hard origin/main
gh issue edit <number> --remove-label "ai-ready" --add-label "ai-in-progress"
gh issue comment <number> --body "**[AI]** Starting work on this issue."
EXISTING=$(git branch --list "issue-<number>-*" | head -1 | xargs)
if [ -n "$EXISTING" ]; then git checkout "$EXISTING"; else git checkout -b issue-<number>-<short-slug>; fi
```

Read the issue body. If unclear → ask a question, label `ai-blocked`, move to next.

Use `code-implementation` skill to implement. On failure (too large, merge conflict, tests failing, build broken):

```
gh issue comment <number> --body "**[AI]** <failure description>"
gh issue edit <number> --remove-label "ai-in-progress" --add-label "ai-blocked"
git checkout --detach origin/main
```

**Never leave an issue `ai-in-progress` after a failure.**

### 4.3 Open draft PR

Check for existing PR first:

```
EXISTING_PR=$(gh pr list --author "@me" --state open --head "$(git branch --show-current)" --json number --jq '.[0].number')
```

If none:

```
gh pr create --draft --title "<issue title>" --body "Closes #<number>

## What was done
<summary>

## Decisions made
<choices>

## Testing
<tests>"
```

Update issue:

```
gh issue edit <number> --remove-label "ai-in-progress" --add-label "ai-done"
gh issue comment <number> --body "**[AI]** PR opened: <pr-url>"
```

### 4.4 CI check

Check CI (2 attempts max). If passes:

```
gh pr ready <pr-number>
gh pr edit <pr-number> --add-label "needs-ai-review"
```

If fails after 2 fix attempts, leave as draft.

### 4.5 Clean up

```
git checkout --detach origin/main
```

Report: "Finished #<number>. Cycle complete."

---

## Usage

```
/loop 10m /supervisor
```

## Safety Rails

- Open PRs as drafts, mark ready only after CI passes
- Never force push
- Merge with `--squash --delete-branch`
- Never use `APPROVE` or `REQUEST_CHANGES` review events — only `COMMENT`
- If issue seems too large (>500 lines), label `ai-blocked`
- If rate-limited (HTTP 403), stop the cycle
- Never leave an issue `ai-in-progress` after failure — always `ai-blocked`
- Skip draft PRs even if labeled
- `ai-pause` label stops all work gracefully

---
name: review-prs
description: Autonomous loop that reviews PRs ready for review and re-reviews PRs where feedback has been addressed. Use with /loop to continuously monitor repos. Use when user says "review PRs", "check for PRs", or "start reviewing".
---

# Review PRs

Autonomous loop that finds PRs ready for review and re-reviews PRs where feedback has been addressed.

## Worktree Isolation

This skill MUST run in its own git worktree to avoid conflicts with other parallel Claude instances.

Before starting, check if already in a worktree:

```
git rev-parse --show-toplevel
```

If NOT already in a worktree for this skill, create one and switch to it using the `EnterWorktree` tool (if available). If `EnterWorktree` is not available, create one manually and prefix ALL subsequent commands with `cd <worktree-path> &&`:

```
WORKTREE=$(git rev-parse --show-toplevel)/../$(basename "$(git rev-parse --show-toplevel)")-reviews
git worktree add "$WORKTREE" main 2>/dev/null || true
```

Then for every command in this skill, prefix with:
```
cd $WORKTREE && <command>
```

This is necessary because `cd` does not persist between Bash calls.

## Loop Cycle

Each cycle:

0. **Pre-flight checks** — verify the environment is ready
1. Find PRs needing **first review**
2. Find PRs needing **re-review** (feedback was addressed)
3. Review them all

---

### 0. Pre-flight Checks

Run these before every cycle. If any fail, stop and report the problem.

```
# Check gh is authenticated
gh auth status

# Check working tree is clean
git status --porcelain
```

If `git status --porcelain` produces output, stop: "Working tree is dirty. Commit or stash changes before running."

If `gh auth status` fails, stop: "GitHub CLI is not authenticated. Run `gh auth login`."

Check for an `ai-pause` label on the repo:

```
gh label list --search "ai-pause" --json name
```

If the `ai-pause` label exists, stop: "ai-pause label detected. Stopping gracefully. Remove the label to resume."

---

### 1. Find PRs needing review

```
gh pr list --state open --json number,title,url,isDraft,author,reviews --limit 20
```

For each non-draft PR, check its comment history:

```
gh pr view <number> --comments --json comments
```

Classify each PR into one of:

| Condition | Action |
|-----------|--------|
| No `<!-- ai-review -->` comment exists | **Needs first review** |
| `<!-- ai-review -->` exists, no `<!-- feedback-addressed -->` after it | **Already reviewed, skip** |
| `<!-- feedback-addressed -->` exists AFTER the last `<!-- ai-review -->` | **Needs re-review** |

Compare by comment order (later = more recent).

If no PRs need review, say "No PRs to review" and stop.

### 2. Review each PR

For each PR needing review (first review or re-review):

#### a. Get the diff

For first reviews:

```
gh pr diff <number>
```

For re-reviews, focus on what changed since the last review:

```
gh pr view <number> --json commits
```

Check commits after the last `<!-- ai-review -->` comment. Get the diff for just those changes if possible, otherwise review the full diff.

#### b. Get PR context

```
gh pr view <number> --json title,body,files
```

#### c. Read surrounding source code

The diff alone is not enough for a meaningful review. For each changed file, read the relevant sections to understand the context around the changes:

```
gh pr view <number> --json files --jq '.files[].path'
```

For each file, read at least the surrounding functions/classes where changes were made. This helps catch issues like:
- Missing null checks that depend on upstream code
- Duplicated logic that already exists elsewhere in the file
- Breaking changes to interfaces used by other parts of the codebase

#### d. Analyze the changes

Review for:
- **Bugs**: logic errors, off-by-one, null/undefined risks, race conditions
- **Security**: injection, auth issues, secret exposure, OWASP top 10
- **Performance**: N+1 queries, unnecessary allocations, missing indexes
- **Readability**: unclear naming, missing context, overly complex logic
- **Testing**: missing test coverage for new behavior, brittle tests

Do NOT nitpick style, formatting, or conventions — focus on substance.

For re-reviews, also verify:
- Previous feedback was actually addressed (not just claimed)
- New changes didn't introduce new issues

#### e. Post the review

If there are issues to flag:

```
gh api repos/{owner}/{repo}/pulls/<number>/reviews \
  --method POST \
  -f body="$(cat <<'EOF'
<!-- ai-review -->
## AI Code Review

<summary of findings>

---
*Automated review by Claude*
EOF
)" \
  -f event="COMMENT" \
  -f 'comments=[{"path":"<file>","line":<line>,"body":"<comment>"}]'
```

If changes look good with no significant issues:

```
gh pr comment <number> --body "$(cat <<'EOF'
<!-- ai-review -->
## AI Code Review

Changes look good. No significant issues found.

---
*Automated review by Claude*
EOF
)"
```

For re-reviews where all feedback was properly addressed:

```
gh pr comment <number> --body "$(cat <<'EOF'
<!-- ai-review -->
## AI Re-Review

All previous feedback has been addressed. Changes look good.

---
*Automated review by Claude*
EOF
)"
```

### 3. Report

List which PRs were reviewed and a one-line summary for each.

---

## Usage with /loop

```
/loop 10m /review-prs
```

## Safety Rails

- Never approve or merge PRs — only post review comments
- Never request changes (use COMMENT event, not REQUEST_CHANGES)
- Skip draft PRs
- Never force push

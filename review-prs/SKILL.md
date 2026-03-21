---
name: review-prs
description: Poll for open PRs ready for review and post AI code reviews. Use with /loop to continuously monitor repos. Use when user says "review PRs", "check for PRs", or "start reviewing".
---

# Review PRs

Find open PRs that are ready for review and post AI code reviews.

## Worktree Isolation

This skill MUST run in its own git worktree to avoid conflicts with other parallel Claude instances (e.g. work-issues, handle-pr-feedback).

Before starting, set up a worktree if not already in one:

```
# From the main repo clone
git worktree add ../$(basename "$PWD")-reviews main
cd ../$(basename "$PWD")-reviews
```

If already running inside a worktree, skip this step. Note: review-prs is read-only (no commits/pushes), so worktree isolation is less critical but still recommended for consistency.

## Process

### 1. Find PRs needing review

```
gh pr list --state open --json number,title,url,isDraft,author,reviewRequests,reviews --limit 20
```

Filter to PRs that are:
- NOT drafts
- Do NOT already have a review comment containing `<!-- ai-review -->`

To check for existing AI review, for each candidate PR:

```
gh pr view <number> --comments --json comments
```

Skip any PR where a comment body contains `<!-- ai-review -->`.

If no PRs need review, say "No PRs to review" and stop.

### 2. Review each PR

For each PR needing review:

#### a. Get the diff

```
gh pr diff <number>
```

#### b. Get PR context

```
gh pr view <number> --json title,body,files
```

#### c. Analyze the changes

Review the diff for:
- **Bugs**: logic errors, off-by-one, null/undefined risks, race conditions
- **Security**: injection, auth issues, secret exposure, OWASP top 10
- **Performance**: N+1 queries, unnecessary allocations, missing indexes
- **Readability**: unclear naming, missing context, overly complex logic
- **Testing**: missing test coverage for new behavior, brittle tests

Do NOT nitpick style, formatting, or conventions — focus on substance.

#### d. Post the review

If there are issues to flag, post a review with inline comments:

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

If the changes look good with no significant issues:

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

### 3. Report

List which PRs were reviewed and a one-line summary for each.

## Usage with /loop

To continuously monitor for PRs:

```
/loop 10m /review-prs
```

## Safety Rails

- Never approve or merge PRs — only post review comments
- Never request changes (use COMMENT event, not REQUEST_CHANGES)
- Skip PRs already reviewed (detected by `<!-- ai-review -->` marker)
- Only review non-draft PRs

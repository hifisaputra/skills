# Workflow Skills Complete Refactor

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 17 issues from the workflow audit — critical bugs, reliability gaps, duplication, and maintainability problems across all 7 skills.

**Architecture:** Extract shared boilerplate (worktree setup, label creation, pause check, comment convention, rate-limit handling) into `references/shared.md` that all loop skills reference. Fix supervisor to have full parity with the three individual loop skills. Add missing label transitions, review-cycle limits, and null-safety fixes.

**Tech Stack:** Markdown skill files, bash (GitHub CLI), no code compilation

---

### Task 1: Fix setup-labels.sh — add missing labels, fix descriptions

**Files:**
- Modify: `scripts/setup-labels.sh`

- [ ] **Step 1: Add `ai-pause` and `ai-needs-input` labels, fix `ai-blocked` description**

Replace the full `labels` array in `scripts/setup-labels.sh` with:

```bash
labels=(
  "prd|0E8A16|Product Requirements Document"
  "ai-ready|1D76DB|Ready for AI to pick up"
  "ai-in-progress|FBCA04|AI is currently working on this"
  "ai-done|0E8A16|AI opened a draft PR"
  "ai-blocked|D93F0B|Blocked by dependency, question, or failure"
  "ai-needs-input|FFA500|HITL issue waiting for human input"
  "ai-pause|BFDADC|Pause AI loops gracefully (create to pause, delete to resume)"
  "needs-ai-review|7057FF|PR is ready for AI review"
  "ai-changes-requested|D93F0B|AI reviewed PR and requested changes"
  "ai-approved|0E8A16|AI reviewed PR and approved"
  "priority:high|B60205|High priority issue"
  "priority:critical|E11D48|Critical priority issue"
)
```

Changes: `ai-blocked` description broadened from "AI asked a question, waiting for answer" to "Blocked by dependency, question, or failure". Added `ai-needs-input` (orange) and `ai-pause` (light pink) labels.

- [ ] **Step 2: Commit**

```bash
git add scripts/setup-labels.sh
git commit -m "fix: add missing labels and fix ai-blocked description in setup script"
```

---

### Task 2: Create shared references file

**Files:**
- Create: `references/shared.md`

- [ ] **Step 1: Create `references/shared.md` with extracted shared logic**

```markdown
# Shared Workflow References

Common patterns used across all loop skills (process-issues, process-reviews, process-pr, supervisor). Each skill references this file instead of duplicating the logic.

## Worktree Setup

Each loop skill MUST run in its own git worktree to avoid conflicts with parallel Claude instances.

Before starting, check if already in a worktree:

` ` `
git rev-parse --show-toplevel
` ` `

If NOT already in a worktree for this skill, create one using the `EnterWorktree` tool (if available). If `EnterWorktree` is not available, create one manually:

` ` `
WORKTREE=$(git rev-parse --show-toplevel)/../$(basename "$(git rev-parse --show-toplevel)")-<suffix>
git worktree add --detach "$WORKTREE" main 2>/dev/null || true
` ` `

Use `--detach` because `main` is typically already checked out in the primary worktree — `git worktree add "$WORKTREE" main` will silently fail otherwise.

Prefix ALL subsequent commands with `cd $WORKTREE &&` (cd does not persist between Bash calls).

Install dependencies if needed:

` ` `
cd $WORKTREE && [ ! -d "node_modules" ] && (bun install 2>/dev/null || npm install 2>/dev/null || true)
` ` `

**Worktree suffixes by skill:**
- process-issues → `-issues`
- process-reviews → `-reviews`
- process-pr → `-merge`
- supervisor → `-supervisor`

## Pre-flight Checks

Run before every cycle. If any fail, stop and report.

` ` `
git worktree prune
gh auth status
git status --porcelain
` ` `

- If `git status --porcelain` produces output → stop: "Working tree is dirty. Commit or stash changes before running."
- If `gh auth status` fails → stop: "GitHub CLI is not authenticated. Run `gh auth login`."

### Label creation

Ensure all required labels exist (no-op if already present):

` ` `
for label in ai-ready ai-in-progress ai-done ai-blocked ai-needs-input needs-ai-review ai-changes-requested ai-approved prd; do
  gh label create "$label" 2>/dev/null || true
done
` ` `

### Pause check

The `ai-pause` label is the graceful stop signal. **Create** the label to pause, **delete** it (`gh label delete ai-pause -y`) to resume.

` ` `
gh label list --search "ai-pause" --json name --jq '.[].name' | grep -qx "ai-pause"
` ` `

`--search` is a fuzzy substring match (it returns labels like `ai-ready`, `ai-done` too), so `grep -qx` is needed for exact match. If `grep` matches → stop: "ai-pause label detected. Stopping gracefully. Delete the label (`gh label delete ai-pause -y`) to resume."

### Repo variable

` ` `
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
` ` `

## Comment Authorship

All comments posted by AI MUST start with `**[AI]**`. When reading comments:
- Starts with `**[AI]**` → AI (previous runs)
- Does NOT start with `**[AI]**` → human

## Rate Limit Handling

If a `gh` command fails with HTTP 403 or "rate limit exceeded", stop the current cycle and report: "GitHub API rate limit hit. Wait before retrying." Do not retry immediately.

## Safety Rails (all loop skills)

- Never force push
- Never use `APPROVE` or `REQUEST_CHANGES` review events — only `COMMENT`
- Skip draft PRs even if labeled
- `ai-pause` label stops all work gracefully
- Never leave an issue `ai-in-progress` after failure — always move to `ai-blocked`

## `ai-needs-input` Transition

When scanning for eligible issues, also check `ai-needs-input` issues for human responses:

` ` `
gh issue list --label "ai-needs-input" --state open --limit 100 --json number,title,body,labels
` ` `

For each, read comments and check if a human has replied after the last AI comment. If a human comment exists:

` ` `
gh issue edit <number> --remove-label "ai-needs-input" --add-label "ai-ready"
gh issue comment <number> --body "**[AI]** Human input received. Moving to ai-ready."
` ` `

Then include these issues in the normal selection pool.

## Review-Cycle Limit

When addressing PR feedback, track how many review cycles a PR has been through by counting `**[AI]** Addressed review feedback` comments on the PR. If a PR has been through 3+ AI feedback cycles without being approved, escalate instead of continuing:

` ` `
gh pr comment <number> --body "**[AI]** This PR has been through 3 review cycles without resolution. Escalating for human review."
gh pr edit <number> --remove-label "ai-changes-requested" --add-label "ai-needs-input"
` ` `

Do not continue addressing feedback on this PR — a human needs to look at it.

## New-Commit Check for Approved PRs

Before merging an `ai-approved` PR, verify no new commits were pushed after the last AI review:

` ` `
LAST_COMMIT=$(gh pr view <number> --json commits --jq '.commits[-1].committedDate')
LAST_REVIEW=$(gh pr view <number> --json comments --jq '[.comments[] | select(.body | startswith("**[AI]**")) | .createdAt] | sort | last // empty')
` ` `

If `LAST_REVIEW` is empty (no AI review comment found) OR `LAST_COMMIT` is newer than `LAST_REVIEW`, the approval is stale:

` ` `
gh pr edit <number> --remove-label "ai-approved" --add-label "needs-ai-review"
gh pr comment <number> --body "**[AI]** New commits detected since last review. Sending back for re-review."
` ` `

Skip this PR (do not merge). It will be picked up by the review phase.

The `// empty` in the jq expression returns an empty string instead of `null` when no AI comments exist, preventing silent date-comparison failures.
```

Note: the triple-backtick code fences inside this file should be actual triple backticks (shown above as `` ` ` ` `` for escaping in the plan).

- [ ] **Step 2: Commit**

```bash
git add references/shared.md
git commit -m "feat: extract shared workflow logic into references/shared.md"
```

---

### Task 3: Refactor process-issues to use shared references and add missing features

**Files:**
- Modify: `process-issues/SKILL.md`

- [ ] **Step 1: Replace Comment Authorship, Worktree Isolation, and Phase 0 boilerplate with reference**

Replace lines 10–99 (from `## Comment Authorship` through end of Phase 0) with:

```markdown
## Shared Setup

Read `references/shared.md` for:
- **Comment authorship** convention (`**[AI]**` prefix)
- **Worktree isolation** — use suffix `-issues`
- **Pre-flight checks** (Phase 0) — worktree prune, gh auth, clean tree, label creation, pause check, repo variable
- **Rate limit handling**
- **Safety rails**

---
```

- [ ] **Step 2: Add `ai-needs-input` transition to Phase B1 (Find the next issue)**

After the existing `ai-blocked` issue scanning block (after the line `gh issue list --label "ai-blocked" --state open --limit 100 --json number,title,body,labels`), add:

```markdown
Also check for `ai-needs-input` issues that now have human responses (see `references/shared.md` → "ai-needs-input Transition"). Any issues transitioned to `ai-ready` become eligible in the current cycle.
```

Update the selection order to:

```markdown
Selection order:
1. Unblocked `ai-blocked` issues with answered questions (priority first, then oldest)
2. Newly-transitioned `ai-needs-input` issues (priority first, then oldest)
3. `ai-ready` issues not labeled `ai-in-progress` (priority first, then oldest)
4. Skip issues whose "Blocked by" references are still open
```

- [ ] **Step 3: Add review-cycle limit to Phase A2 (Address feedback)**

Before the existing "Categorize each new comment" block in Phase A2, add:

```markdown
**Review-cycle limit:** Before addressing feedback, check if this PR has hit the review-cycle limit (see `references/shared.md` → "Review-Cycle Limit"). If it has been through 3+ AI feedback cycles, escalate instead of continuing. Otherwise proceed with the feedback below.
```

- [ ] **Step 4: Commit**

```bash
git add process-issues/SKILL.md
git commit -m "refactor: process-issues uses shared refs, adds ai-needs-input + review-cycle limit"
```

---

### Task 4: Refactor process-reviews to use shared references and fix null-date bug

**Files:**
- Modify: `process-reviews/SKILL.md`

- [ ] **Step 1: Replace Comment Authorship, Worktree Isolation, and Phase 0 boilerplate with reference**

Replace lines 10–95 (from `## Comment Authorship` through end of Phase 0) with:

```markdown
## Shared Setup

Read `references/shared.md` for:
- **Comment authorship** convention (`**[AI]**` prefix)
- **Worktree isolation** — use suffix `-reviews`
- **Pre-flight checks** (Phase 0) — worktree prune, gh auth, clean tree, label creation, pause check, repo variable
- **Rate limit handling**
- **Safety rails**

---
```

- [ ] **Step 2: Fix null-date handling in stale `ai-approved` detection**

In Phase 1, "Stale `ai-approved` PRs" section, replace the jq query for last AI review comment date:

Old:
```
gh pr view <number> --json comments --jq '[.comments[] | select(.body | startswith("**[AI]**")) | .createdAt] | sort | last'
```

New:
```
gh pr view <number> --json comments --jq '[.comments[] | select(.body | startswith("**[AI]**")) | .createdAt] | sort | last // empty'
```

And add this clarification after the date comparison:

```markdown
The `// empty` returns an empty string instead of `null` when no AI comments exist. If the result is empty (no previous AI review), the PR always needs review — relabel to `needs-ai-review`.
```

Apply the same `// empty` fix to the unlabeled PRs fallback section (Phase 1, lines 158-160).

- [ ] **Step 3: Pass review type to code-review skill**

In Phase 2, "Delegate to code-review" section, replace:

```markdown
Pass to the `code-review` skill:
- The PR number
- Whether this is a first review or re-review
```

With:

```markdown
Pass to the `code-review` skill:
- The PR number
- Whether this is a **first review** or **re-review** (determined in Phase 1)
- For re-reviews: include a note like "This is a re-review. Previous feedback was posted on <date>. Check if previous findings were addressed." so `code-review` can prioritize checking previous issues.
```

- [ ] **Step 4: Commit**

```bash
git add process-reviews/SKILL.md
git commit -m "refactor: process-reviews uses shared refs, fixes null-date bug, passes review type"
```

---

### Task 5: Refactor process-pr to use shared references and fix redundant close

**Files:**
- Modify: `process-pr/SKILL.md`

- [ ] **Step 1: Replace Comment Authorship, Worktree Isolation, and Phase 0 boilerplate with reference**

Replace lines 16–103 (from `## Comment Authorship` through end of Phase 0) with:

```markdown
## Shared Setup

Read `references/shared.md` for:
- **Comment authorship** convention (`**[AI]**` prefix)
- **Worktree isolation** — use suffix `-merge`
- **Pre-flight checks** (Phase 0) — worktree prune, gh auth, clean tree, label creation, pause check, repo variable
- **Rate limit handling**
- **Safety rails**

---
```

- [ ] **Step 2: Add new-commit check before merging**

In Phase 2, after the merge-readiness check (2B) and before Phase 3 (Act), add:

```markdown
### 2C. Check for stale approval

Before merging, verify the approval is still valid — no new commits since the last AI review (see `references/shared.md` → "New-Commit Check for Approved PRs"). If stale, relabel to `needs-ai-review` and skip this PR.
```

- [ ] **Step 3: Simplify the post-merge issue handling**

Replace Phase 3 "If both checks pass → Merge" section's post-merge issue handling (lines 226-239):

Old:
```markdown
The `Closes #N` in the PR body will automatically close the linked issue when the PR is merged.

After merging, check the issue state:

` ` `
gh issue view <issue-number> --json state --jq '.state'
` ` `

If the issue was auto-closed by the merge, no label cleanup is needed. If it's still open for some reason, update it:

` ` `
gh issue edit <issue-number> --remove-label "ai-done"
gh issue close <issue-number>
` ` `
```

New:
```markdown
The `Closes #N` in the PR body automatically closes the linked issue when the PR merges. Verify the issue closed:

` ` `
gh issue view <issue-number> --json state --jq '.state'
` ` `

If still open (rare — usually means `Closes #N` syntax was wrong), close it manually:

` ` `
gh issue edit <issue-number> --remove-label "ai-done"
gh issue close <issue-number>
` ` `

This is a fallback — normally GitHub handles it.
```

- [ ] **Step 4: Commit**

```bash
git add process-pr/SKILL.md
git commit -m "refactor: process-pr uses shared refs, adds stale-approval check, clarifies issue close"
```

---

### Task 6: Refactor supervisor to use shared references and add all missing logic

This is the largest task — the supervisor had 4 critical bugs where it diverged from the individual loop skills.

**Files:**
- Modify: `supervisor/SKILL.md`

- [ ] **Step 1: Replace Comment Authorship, Worktree Isolation, and Phase 0 boilerplate with reference**

Replace lines 19–79 (from `## Comment Authorship` through end of Phase 0) with:

```markdown
## Shared Setup

Read `references/shared.md` for:
- **Comment authorship** convention (`**[AI]**` prefix)
- **Worktree isolation** — use suffix `-supervisor`
- **Pre-flight checks** (Phase 0) — worktree prune, gh auth, clean tree, label creation, pause check, repo variable
- **Rate limit handling**
- **Safety rails**

---
```

- [ ] **Step 2: Add new-commit check to Phase 1 (Merge) before merging**

In Phase 1, section 1.2 "Verify each PR", add a new check before the existing "Issue resolution" check:

```markdown
**Stale approval check** — verify no new commits since last AI review (see `references/shared.md` → "New-Commit Check for Approved PRs"). If stale, relabel to `needs-ai-review` and skip — this PR will be picked up in Phase 2.
```

This fixes Critical Issue #1.

- [ ] **Step 3: Add rejected-PR recovery to Phase 3 (Handle PR Feedback)**

In Phase 3, section 3.1 "Find PRs", add the rejected-PR recovery logic that was missing. After the "Unlabeled with feedback" block, add:

```markdown
**Rejected PRs** (closed without merge, reset linked issues):

```
gh pr list --author "@me" --state closed --limit 10 --json number,title,mergedAt,body,closedAt
```

For each closed PR where `mergedAt` is empty (not merged), extract the issue number from the body (`Closes #<number>`). Before resetting, verify the issue still has the `ai-done` label and hasn't been manually reassigned:

```
gh issue view <number> --json labels,assignees --jq '.labels[].name' | grep -q "ai-done"
```

Only if the issue is still labeled `ai-done` and has no human assignee:

```
gh issue edit <number> --remove-label "ai-done" --add-label "ai-ready"
gh issue comment <number> --body "**[AI]** PR #<pr-number> was closed without merging. Resetting to ai-ready for a fresh attempt."
```

Skip if the issue was already relabeled — that means someone handled it manually.
```

This fixes Critical Issue #2.

- [ ] **Step 4: Add review-cycle limit to Phase 3 (Handle PR Feedback)**

In Phase 3, section 3.2 "Address feedback", add before the comment categorization:

```markdown
**Review-cycle limit:** Before addressing feedback, check if this PR has hit the review-cycle limit (see `references/shared.md` → "Review-Cycle Limit"). If it has been through 3+ AI feedback cycles, escalate instead of continuing. Otherwise proceed with the feedback below.
```

This fixes High-Priority Issue #8.

- [ ] **Step 5: Fix stale `ai-in-progress` recovery in Phase 4**

Replace Phase 4.0 "Recover stale issues" section. The current version skips issues with branches but no PR — it should reset them like `process-issues` does.

Old behavior (lines 281-283):
```markdown
- Open PR exists → skip (will be handled when reviewed/closed)
- Branch exists but no PR → skip (leave for manual inspection)
- No branch, no PR → reset to `ai-ready`
```

New:
```markdown
- Open PR exists → skip (will be handled when reviewed/closed)
- Branch exists (local or remote) but no PR → the work started but wasn't finished. Reset to `ai-ready`:

```
gh issue edit <number> --remove-label "ai-in-progress" --add-label "ai-ready"
gh issue comment <number> --body "**[AI]** Resetting to ai-ready — previous work session was interrupted before a PR was opened."
```

- No branch, no PR → the issue was claimed but never worked on. Reset to `ai-ready`:

```
gh issue edit <number> --remove-label "ai-in-progress" --add-label "ai-ready"
gh issue comment <number> --body "**[AI]** Resetting to ai-ready — previous work session was interrupted before any progress was made."
```
```

This fixes Critical Issue #3.

- [ ] **Step 6: Add `ai-needs-input` transition to Phase 4.1 (Find the next issue)**

After the existing `ai-blocked` scanning, add:

```markdown
Also check for `ai-needs-input` issues that now have human responses (see `references/shared.md` → "ai-needs-input Transition"). Any issues transitioned to `ai-ready` become eligible in the current cycle.
```

Update the selection text to:

```markdown
Selection: unblocked issues first, then newly-transitioned `ai-needs-input` issues, then `ai-ready`. Priority labels first (`priority:high`, `priority:critical`), then oldest.
```

This fixes Critical Issue #4.

- [ ] **Step 7: Commit**

```bash
git add supervisor/SKILL.md
git commit -m "fix: supervisor gains rejected-PR recovery, stale-approval check, ai-needs-input, review-cycle limit, and proper ai-in-progress reset"
```

---

### Task 7: Update README to reflect changes

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add supervisor and process-pr to the Skills section**

After the `process-reviews` entry in the Skills section, add:

```markdown
- **process-pr** — Autonomous loop: picks up `ai-approved` PRs, verifies issue resolution and merge readiness, checks for stale approvals, merges or sends back.

  ```
  /loop 10m /process-pr
  ```

- **supervisor** — Unified loop that runs all phases (merge → review → feedback → implement) in one session. Alternative to running the three loops separately.

  ```
  /loop 10m /supervisor
  ```
```

- [ ] **Step 2: Update the workflow diagram**

Replace the existing workflow diagram:

```markdown
## The Workflow

```
You <-> AI (brainstorm) -> GitHub Issues
                              |
                    +---------+---------+---------+
                    |                   |         |
             [Loop 1: Execute]   [Loop 2: Review]  [Loop 3: Merge]
             /process-issues     /process-reviews   /process-pr

             ──── OR use the unified loop ────
             /supervisor (runs all 3 phases per cycle)
```
```

- [ ] **Step 3: Add `ai-needs-input` lifecycle detail and `process-pr` to label lifecycle**

In the Label Lifecycle section, update the Issues diagram to show the `ai-needs-input` → `ai-ready` transition:

```markdown
**Issues:**
```
brainstorm creates:
  AFK unblocked  ->  ai-ready
  AFK blocked    ->  ai-blocked (auto-unblocks when blockers close)
  HITL           ->  ai-needs-input (human comments → auto-transitions to ai-ready)

ai-ready  ->  ai-in-progress  ->  ai-done (draft PR opened)
   ^               |
   |               v
   +------- ai-blocked (dependency / question / failure)
   ^
   |
   +------- ai-needs-input (human provides input → auto-detected by loops)
```
```

- [ ] **Step 4: Add shared references note to Setup section**

After the GitHub Labels section, add:

```markdown
### Shared References

Loop skills (`process-issues`, `process-reviews`, `process-pr`, `supervisor`) share common setup logic via `references/shared.md`. This includes worktree isolation, pre-flight checks, comment conventions, and safety rails.
```

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: update README with supervisor, process-pr, shared references, and lifecycle fixes"
```

---

### Task 8: Update all label creation loops in skills to match setup-labels.sh

The label creation loops in each skill currently create 9 labels. They should match what `setup-labels.sh` creates (minus `ai-pause` which is user-created on demand, and `priority:*` which are optional).

**Files:**
- Modify: `references/shared.md`

- [ ] **Step 1: Verify the label list in `references/shared.md` is complete**

The label creation in `references/shared.md` currently lists:
```
ai-ready ai-in-progress ai-done ai-blocked ai-needs-input needs-ai-review ai-changes-requested ai-approved prd
```

This matches all workflow labels. `ai-pause` is deliberately NOT auto-created (it's user-created on demand as a pause signal). `priority:*` labels are optional and created by `setup-labels.sh` only.

No change needed — verify and move on.

- [ ] **Step 2: Commit (no-op if nothing changed)**

Skip if no changes.

---

### Task 9: Verify cross-references and consistency

**Files:**
- Read: all modified files

- [ ] **Step 1: Verify `references/shared.md` is referenced correctly by all 4 loop skills**

Read each modified SKILL.md and confirm:
- The "Shared Setup" section points to `references/shared.md`
- The worktree suffix matches the skill
- No stale boilerplate remains (no duplicate label creation, pause check, or comment authorship sections)

- [ ] **Step 2: Verify supervisor has parity with individual loops**

Check that supervisor now handles all these cases that were previously missing:
- [x] Stale approval check before merge (Phase 1)
- [x] Rejected-PR recovery (Phase 3)
- [x] Stale `ai-in-progress` reset (Phase 4.0)
- [x] `ai-needs-input` transition (Phase 4.1)
- [x] Review-cycle limit (Phase 3)

- [ ] **Step 3: Verify label names are consistent across all files**

Search all SKILL.md files for label references and confirm spelling matches:
- `ai-ready`, `ai-in-progress`, `ai-done`, `ai-blocked`, `ai-needs-input`
- `needs-ai-review`, `ai-changes-requested`, `ai-approved`
- `prd`, `priority:high`, `priority:critical`, `ai-pause`

- [ ] **Step 4: Run a final diff review**

```bash
git diff main --stat
git diff main
```

Verify all changes look correct, no accidental deletions, and the total scope is reasonable.

- [ ] **Step 5: Commit any fixups**

```bash
git add -A
git commit -m "fix: cross-reference consistency pass"
```

---

### Task 10: Add structured failure comments for persistent failure detection

Addresses audit issue #9 — persistent failure detection is fragile because it relies on pattern-matching free-text `**[AI]**` failure comments. This task adds a structured comment format so the failure guard can count attempts reliably.

**Files:**
- Modify: `references/shared.md`
- Modify: `process-issues/SKILL.md`
- Modify: `supervisor/SKILL.md`

- [ ] **Step 1: Add structured failure comment format to `references/shared.md`**

Add a new section after "Review-Cycle Limit":

```markdown
## Structured Failure Comments

When an implementation attempt fails, post a comment with this structured header so the persistent-failure guard can count attempts reliably:

` ` `
**[AI]** ❌ **Attempt failed** (attempt #N)

<failure description>
` ` `

To count previous attempts on an issue:

` ` `
gh issue view <number> --json comments --jq '[.comments[] | select(.body | test("^\\*\\*\\[AI\\]\\*\\* ❌ \\*\\*Attempt failed\\*\\*"))] | length'
` ` `

The persistent failure guard: if count ≥ 2, only resume if a human has commented since the last failure comment. To check:

` ` `
LAST_FAILURE=$(gh issue view <number> --json comments --jq '[.comments[] | select(.body | test("^\\*\\*\\[AI\\]\\*\\* ❌ \\*\\*Attempt failed\\*\\*")) | .createdAt] | sort | last // empty')
LAST_HUMAN=$(gh issue view <number> --json comments --jq '[.comments[] | select(.body | test("^\\*\\*\\[AI\\]\\*\\*") | not) | .createdAt] | sort | last // empty')
` ` `

If `LAST_HUMAN` is empty or older than `LAST_FAILURE`, skip the issue.
```

- [ ] **Step 2: Update `process-issues/SKILL.md` failure comment templates**

In Phase B4 "Implement", update all failure comment templates to use the structured format. For example, change:

```
gh issue comment <number> --body "**[AI]** This issue looks too large for autonomous implementation. Consider breaking it into smaller issues."
```

To:

```
ATTEMPTS=$(gh issue view <number> --json comments --jq '[.comments[] | select(.body | test("^\\*\\*\\[AI\\]\\*\\* ❌ \\*\\*Attempt failed\\*\\*"))] | length')
NEXT=$((ATTEMPTS + 1))
gh issue comment <number> --body "**[AI]** ❌ **Attempt failed** (attempt #$NEXT)

This issue looks too large for autonomous implementation. Consider breaking it into smaller issues."
```

Apply the same pattern to all failure paths in B4 (merge conflict, existing tests failing, existing build failing, any other failure).

Also update the persistent failure guard in B1 to use the structured count:

```
Before selecting an issue, count structured failure comments (see `references/shared.md` → "Structured Failure Comments"). If ≥ 2 attempts and no human comment since last failure, skip the issue.
```

- [ ] **Step 3: Apply same changes to `supervisor/SKILL.md` Phase 4**

Mirror the changes from Step 2 in supervisor's Phase 4.2 (Claim and implement) and Phase 4.1 (persistent failure guard).

- [ ] **Step 4: Commit**

```bash
git add references/shared.md process-issues/SKILL.md supervisor/SKILL.md
git commit -m "fix: structured failure comments for reliable persistent-failure detection"
```

---

### Task 11: Add branch cleanup for abandoned CI branches

Addresses audit issue #16 — if CI stalls and the skill moves on, the next cycle creates a new branch, orphaning the old one.

**Files:**
- Modify: `references/shared.md`
- Modify: `process-issues/SKILL.md`
- Modify: `supervisor/SKILL.md`

- [ ] **Step 1: Add branch cleanup to pre-flight in `references/shared.md`**

In the "Pre-flight Checks" section, after `git worktree prune`, add:

```markdown
### Stale branch cleanup

Clean up local branches that have no corresponding open PR and no remote tracking branch (leftover from crashed runs):

` ` `
for branch in $(git branch --list "issue-*" | sed 's/^[ *]*//'); do
  ISSUE_NUM=$(echo "$branch" | grep -oP 'issue-\K\d+')
  HAS_PR=$(gh pr list --author "@me" --state open --head "$branch" --json number --jq 'length')
  if [ "$HAS_PR" = "0" ]; then
    HAS_REMOTE=$(git ls-remote --heads origin "$branch" 2>/dev/null | wc -l)
    if [ "$HAS_REMOTE" = "0" ]; then
      git branch -D "$branch" 2>/dev/null || true
    fi
  fi
done
` ` `

This prevents branch accumulation from failed runs. Only deletes branches with no open PR and no remote counterpart.
```

- [ ] **Step 2: Commit**

```bash
git add references/shared.md
git commit -m "fix: add stale branch cleanup to pre-flight checks"
```

---

### Task 12: Mitigate race conditions between parallel loops

Addresses audit issue #5 — when `process-issues` and `process-reviews` run in parallel, both can find the same PR and apply conflicting labels. This adds a claim-before-work pattern.

**Files:**
- Modify: `references/shared.md`
- Modify: `process-issues/SKILL.md`
- Modify: `process-reviews/SKILL.md`

- [ ] **Step 1: Add claim pattern to `references/shared.md`**

Add a new section after "Stale branch cleanup":

```markdown
## Claiming Work Items

When multiple loops run in parallel, they can find the same PR or issue. To reduce conflicts, each skill should **claim before working** by updating the label immediately after selecting a work item, before doing any expensive analysis.

For PRs: change the label in the same step as selection (e.g., `process-reviews` removes `needs-ai-review` immediately and adds a transient claim).

For issues: the existing `ai-in-progress` label already serves as a claim. The key is to label `ai-in-progress` BEFORE starting any work, which the skills already do.

For PR feedback: `process-issues` should remove `ai-changes-requested` immediately when it picks up a PR, before analyzing comments. This prevents `process-reviews` from also picking it up.

This is a best-effort mitigation — GitHub label operations are not atomic. The supervisor skill avoids this entirely by running all phases sequentially.
```

- [ ] **Step 2: Update `process-issues/SKILL.md` Phase A2 to claim immediately**

In Phase A2 "Address feedback", move the label update to before the checkout. Change the order so the first thing done after selecting a PR is:

Add before `gh pr checkout <number>`:

```markdown
Claim the PR immediately to prevent parallel loops from picking it up:

` ` `
gh pr edit <number> --remove-label "ai-changes-requested"
` ` `

Then proceed with checkout and analysis. The `needs-ai-review` label is added after work is complete.
```

- [ ] **Step 3: Update `process-reviews/SKILL.md` Phase 2 to claim immediately**

In Phase 2 "Review each PR", add before checkout:

```markdown
Claim the PR by removing `needs-ai-review` immediately:

` ` `
gh pr edit <number> --remove-label "needs-ai-review"
` ` `

The correct label (`ai-approved` or `ai-changes-requested`) is applied after review completes. If the review fails or is skipped, re-add `needs-ai-review`.
```

- [ ] **Step 4: Commit**

```bash
git add references/shared.md process-issues/SKILL.md process-reviews/SKILL.md
git commit -m "fix: claim-before-work pattern to mitigate parallel loop race conditions"
```

---

### Task 13: Document hardcoded limits in shared references

Addresses audit issue #12 — limits are scattered across files with no central reference. This doesn't make them configurable (no config system exists) but documents them in one place for easy discovery and modification.

**Files:**
- Modify: `references/shared.md`

- [ ] **Step 1: Add configurable limits section to `references/shared.md`**

Add at the end of the file:

```markdown
## Default Limits

These values are used across multiple skills. To change them, update the relevant skill files:

| Limit | Default | Used in |
|-------|---------|---------|
| Max lines per issue | ~500 | brainstorm-to-issues, code-implementation, process-issues, supervisor |
| PRs per merge cycle | 5 | process-pr, supervisor Phase 1 |
| PRs per review cycle | 5 | process-reviews, supervisor Phase 2 |
| PRs per feedback cycle | 3 | process-issues Phase A, supervisor Phase 3 |
| CI check attempts | 2 | process-issues B7, supervisor Phase 4.4 |
| CI poll wait | 10-15 seconds | process-issues B7, supervisor Phase 4.4 |
| Review cycle limit | 3 | process-issues Phase A, supervisor Phase 3 |
| Failure attempt limit | 2 | process-issues B1, supervisor Phase 4.1 |
| Merge strategy | --squash --delete-branch | process-pr, supervisor Phase 1 |
| Rejected PR scan depth | 10 | process-issues Phase A, supervisor Phase 3 |
| Unlabeled PR scan limit | 15 | process-reviews Phase 1 |
```

- [ ] **Step 2: Commit**

```bash
git add references/shared.md
git commit -m "docs: centralize default limits in shared references"
```

---

### Task 14: Fix brainstorm backup file naming collision

Addresses audit issue #17 — simultaneous brainstorms with the same short name can overwrite each other's backup files.

**Files:**
- Modify: `brainstorm-to-issues/SKILL.md`

- [ ] **Step 1: Add timestamp to backup filename**

In step 6 "Create the issues", change the backup file naming:

Old:
```markdown
` ` `
<project-root>/brainstorm-<short-name>.json
` ` `
```

New:
```markdown
` ` `
<project-root>/brainstorm-<short-name>-<YYYYMMDD-HHMMSS>.json
` ` `

Use `date +%Y%m%d-%H%M%S` for the timestamp. This prevents collisions when multiple brainstorms run simultaneously.
```

- [ ] **Step 2: Commit**

```bash
git add brainstorm-to-issues/SKILL.md
git commit -m "fix: add timestamp to brainstorm backup filename to prevent collisions"
```

---

### Audit Coverage Map

| Audit # | Issue | Task |
|---------|-------|------|
| 1 | Supervisor merges unreviewed commits | Task 6.2, Task 5.2 |
| 2 | Supervisor doesn't recover rejected PRs | Task 6.3 |
| 3 | Supervisor doesn't reset stale ai-in-progress | Task 6.5 |
| 4 | ai-needs-input issues orphaned | Task 2 (shared.md), Task 3.2, Task 6.6 |
| 5 | Race conditions with parallel loops | Task 12 |
| 6 | setup-labels.sh missing labels | Task 1 |
| 7 | ai-blocked description wrong | Task 1 |
| 8 | No review-cycle limit | Task 2 (shared.md), Task 3.3, Task 6.4 |
| 9 | Persistent failure detection fragile | Task 10 |
| 10 | Stale approval null-date bug | Task 4.2, Task 2 (shared.md) |
| 11 | Massive duplication | Task 2, Task 3.1, Task 4.1, Task 5.1, Task 6.1 |
| 12 | Hardcoded limits scattered | Task 13 |
| 13 | Review type not passed | Task 4.3 |
| 14 | Redundant issue close | Task 5.3 |
| 15 | ai-blocked overloaded | Not addressed — low priority, would need sub-labels |
| 16 | Abandoned branches | Task 11 |
| 17 | Brainstorm backup naming | Task 14 |

# Workflow Audit — 2026-03-29

## Critical Issues (can cause incorrect behavior)

### 1. Supervisor can merge PRs with unreviewed new commits
**Files:** `supervisor/SKILL.md` Phase 1 vs Phase 2
Phase 1 merges `ai-approved` PRs before Phase 2 reviews anything. If new commits were pushed after approval, they get merged without review. Should check for new commits since last AI review before merging.

### 2. Supervisor doesn't recover rejected PRs
**Files:** `supervisor/SKILL.md` Phase 3 vs `process-issues/SKILL.md` Phase A
`process-issues` has logic to detect closed-without-merge PRs and reset the linked issue to `ai-ready`. Supervisor Phase 3 has no equivalent — issues get stuck on `ai-done` after PR rejection.

### 3. Supervisor doesn't reset stale `ai-in-progress` issues
**Files:** `supervisor/SKILL.md` Phase 4.0 vs `process-issues/SKILL.md` Phase B0
`process-issues` resets abandoned `ai-in-progress` issues (no branch/PR = interrupted). Supervisor skips them entirely — they stay `ai-in-progress` forever.

### 4. `ai-needs-input` issues are orphaned
**Files:** All loop skills + `brainstorm-to-issues/SKILL.md`
`brainstorm-to-issues` creates HITL issues with `ai-needs-input`, but no loop skill ever checks for answered `ai-needs-input` issues or transitions them to `ai-ready`. They require manual relabeling.

### 5. Race conditions with parallel loops
**Files:** All loop skills
If `process-issues` and `process-reviews` run in parallel, both can find the same unlabeled PR and apply conflicting labels simultaneously. No locking mechanism exists.

---

## High-Priority Issues (reliability & correctness)

### 6. setup-labels.sh missing 2 labels
**File:** `scripts/setup-labels.sh`
Missing: `ai-pause` and `ai-needs-input`. Both are referenced by skills and documented in README but not created by the setup script.

### 7. `ai-blocked` label description is wrong in setup script
**File:** `scripts/setup-labels.sh`
Script says "AI asked a question, waiting for answer" but the label is also used for dependency blocks and failures. Should be "Blocked by dependency, question, or failure".

### 8. No review-cycle limit for PRs
**Files:** `process-issues/SKILL.md`, `process-reviews/SKILL.md`
If AI misunderstands feedback, a PR can bounce between `ai-changes-requested` and `needs-ai-review` indefinitely. No max-iterations guard.

### 9. Persistent failure detection is fragile
**Files:** `process-issues/SKILL.md` line 281, `supervisor/SKILL.md` line 299
"Skip issues attempted 2+ times" relies on pattern-matching `**[AI]**` failure comments. No structured counter. ANY human comment resets the guard, even "I don't know" or an unrelated remark.

### 10. Stale `ai-approved` detection returns null for first reviews
**File:** `process-reviews/SKILL.md` lines 119-126
jq query for last AI comment date returns `null` if no AI comments exist. Date comparison with `null` silently fails, potentially missing stale approvals.

---

## Medium-Priority Issues (maintainability)

### 11. Massive duplication across skills
- Worktree setup (~25 lines) duplicated 4x with subtle differences
- Label creation loop duplicated 5x identically
- `ai-pause` check duplicated 4x identically
- Changes require updating all copies

### 12. Hardcoded limits scattered everywhere
- 500-line threshold: `brainstorm-to-issues`, `code-implementation`, `process-issues`
- Batch sizes: 5 PRs (merge/review), 3 PRs (feedback) in multiple files
- CI wait: "10-15 seconds" in `process-issues`
- Merge strategy: `--squash --delete-branch` in `supervisor` + `process-pr`

### 13. `process-reviews` determines review type but doesn't pass it
**Files:** `process-reviews/SKILL.md` Phase 1 vs Phase 2
Phase 1 determines "first review vs re-review" but Phase 2 just passes the PR number to `code-review`. The distinction is lost — `code-review` has to re-detect it by reading comments.

### 14. Redundant issue close in `process-pr`
**File:** `process-pr/SKILL.md` lines 226-239
Explicitly closes issue with `gh issue close` after merge, but `Closes #N` in PR body already auto-closes it. The explicit close is redundant.

---

## Low-Priority Issues (polish)

### 15. `ai-blocked` is overloaded
Used for dependency blocks, question blocks, failure blocks, size warnings, merge conflicts, and PR creation failures. No way to distinguish the reason without reading comments. Could benefit from sub-labels or a structured comment format.

### 16. Abandoned branches from stalled CI
**File:** `process-issues/SKILL.md` B7
If CI checks stall after 2 polls, the skill moves on. Next cycle creates a new branch, leaving the old one orphaned. No branch cleanup.

### 17. `brainstorm-to-issues` backup file naming
**File:** `brainstorm-to-issues/SKILL.md` lines 144-150
Saves `brainstorm-<short-name>.json` in project root. Simultaneous brainstorms could collide. No cleanup on failure.

---

## Recommended Priority

**Fix first (high impact, straightforward):**
1. Add missing labels to `setup-labels.sh` (#6, #7)
2. Add `ai-needs-input` → `ai-ready` transition to `process-issues` and `supervisor` (#4)
3. Add new-commit check before merge in supervisor Phase 1 (#1)
4. Add rejected-PR recovery to supervisor Phase 3 (#2)
5. Add stale `ai-in-progress` reset to supervisor Phase 4 (#3)

**Fix second (prevents stuck states):**
6. Add max review cycles (e.g., 3) before escalating to `ai-needs-input` (#8)
7. Fix null handling in stale-approval detection (#10)

**Fix later (maintainability):**
8. Extract shared logic (worktree, labels, pause) into reference files (#11)
9. Centralize configurable limits (#12)

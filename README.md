# AI Workflow Skills

A set of Claude Code skills that create an automated GitHub-integrated development workflow.

## The Workflow

```
You <-> AI (brainstorm) -> GitHub Issues
                              |
                    +---------+---------+
                    |                   |
             [Loop 1: Execute]   [Loop 2: Review]
             /loop /process-issues  /loop /process-reviews
```

### Phase 1: Brainstorm & Plan
Talk to AI about your idea. AI explores the codebase, challenges the idea, writes a PRD, and breaks it into GitHub issues with smart labeling — `ai-ready` for autonomous work, `ai-blocked` for dependency-blocked issues, `ai-needs-input` for issues requiring human input.

### Phase 2: AI Execute (Loop)
AI picks up `ai-ready` issues, implements them with TDD via the `code-implementation` skill, and opens draft PRs. Handles PR feedback from reviews. When blocked, asks questions and moves on. Automatically unblocks dependency-blocked issues when their blockers close.

### Phase 3: AI Review (Loop)
Separate loop that reviews PRs via the `code-review` skill — checks correctness, security, performance, style, tests, and issue alignment. Re-reviews when feedback is addressed. Detects stale approvals when new commits are pushed.

## Skills

- **brainstorm-to-issues** — Interactive brainstorming that produces a PRD and vertical-slice GitHub issues with scope estimation, priority labels, and dependency tracking.

- **process-issues** — Autonomous loop: picks up `ai-ready` issues, delegates to `code-implementation`, handles PR feedback, unblocks dependency-blocked issues, recovers from crashes.

  ```
  /loop 10m /process-issues
  ```

- **process-reviews** — Autonomous loop: finds PRs needing review, delegates to `code-review`, updates labels, detects stale approvals.

  ```
  /loop 10m /process-reviews
  ```

- **code-implementation** — Structured implementation: understand, plan, TDD (when tests exist), commit, push. Detects project tooling, loads stack-specific references for Next.js and Cloudflare Workers.

- **code-review** — Thorough PR review: correctness, security, performance, style, test coverage, issue alignment. Posts inline comments via GitHub review API.

## Setup

### Required
- [Claude Code](https://claude.com/claude-code) installed
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated
- Repository with issues enabled

### GitHub Labels

Labels are auto-created by the process skills on first run. No manual setup needed.

You can also create them manually:

```bash
for label in ai-ready ai-in-progress ai-done ai-blocked ai-needs-input needs-ai-review ai-changes-requested ai-approved prd; do
  gh label create "$label" 2>/dev/null || true
done
```

| Label | Description |
|-------|-------------|
| `prd` | Product Requirements Document |
| `ai-ready` | Ready for AI to pick up |
| `ai-in-progress` | AI is currently working on this |
| `ai-done` | AI opened a draft PR |
| `ai-blocked` | Blocked by dependency, question, or failure |
| `ai-needs-input` | HITL issue waiting for human input |
| `ai-pause` | Pause AI loops gracefully (create to pause, delete to resume) |
| `needs-ai-review` | PR is ready for AI review |
| `ai-changes-requested` | AI reviewed PR and requested changes |
| `ai-approved` | AI reviewed PR — no issues found |
| `priority:high` | High priority issue |
| `priority:critical` | Critical priority issue |

## Label Lifecycle

**Issues:**
```
brainstorm creates:
  AFK unblocked  ->  ai-ready
  AFK blocked    ->  ai-blocked (auto-unblocks when blockers close)
  HITL           ->  ai-needs-input (human comments + relabels to ai-ready)

ai-ready  ->  ai-in-progress  ->  ai-done (draft PR opened)
   ^               |
   |               v
   +------- ai-blocked (dependency / question / failure)
```

**PRs:**
```
needs-ai-review  ->  ai-changes-requested  ->  needs-ai-review (after fixes)
       |                                              |
       +---------------> ai-approved <----------------+
                              |
                    (new commits pushed -> needs-ai-review)
```

Labels are the primary signal for both loops. Unlabeled PRs are detected via comment analysis as a fallback.

Use `ai-pause` to gracefully stop all loops (create the label to pause, `gh label delete ai-pause -y` to resume). Use `priority:high` / `priority:critical` on issues to influence pickup order.

## License

MIT

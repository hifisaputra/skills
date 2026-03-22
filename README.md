# AI Workflow Skills

A set of Claude Code skills that create an automated GitHub-integrated development workflow.

## The Workflow

```
You <-> AI (brainstorm) -> GitHub Issues
                              |
                    +---------+---------+
                    |                   |
             [Loop 1: Execute]   [Loop 2: Review]
             /loop /work-issues  /loop /review-prs
```

### Phase 1: Brainstorm & Plan
Talk to AI about your idea. AI challenges it, writes a PRD, and breaks it into GitHub issues labeled `ai-ready`.

### Phase 2: AI Execute (Loop)
AI picks up `ai-ready` issues, implements them with TDD, and opens draft PRs. Also handles PR feedback from both AI reviews and your comments. When something is unclear, AI asks a question on the issue and moves on to the next one.

### Phase 3: AI Review (Loop)
Separate loop that reviews PRs ready for review and re-reviews PRs where feedback has been addressed.

## Skills

- **brainstorm-to-issues** - Interactive brainstorming that produces a PRD and vertical-slice GitHub issues.

- **work-issues** - Autonomous loop: implements `ai-ready` issues with TDD, handles PR feedback, asks questions on unclear issues and moves on.

  ```
  /loop 10m /work-issues
  ```

- **review-prs** - Autonomous loop: reviews PRs ready for review, re-reviews when feedback is addressed.

  ```
  /loop 10m /review-prs
  ```

## Setup

### Required
- [Claude Code](https://claude.com/claude-code) installed
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated
- Repository with issues enabled

### GitHub Labels

Run the setup script from inside your repo:

```bash
bash path/to/my-skills/scripts/setup-labels.sh
```

This creates all required labels:

| Label | Description |
|-------|-------------|
| `prd` | Product Requirements Document |
| `ai-ready` | Ready for AI to pick up |
| `ai-in-progress` | AI is currently working on this |
| `ai-done` | AI opened a draft PR |
| `ai-blocked` | AI asked a question, waiting for answer |
| `ai-pause` | Pause AI loops gracefully |
| `priority:high` | High priority issue |
| `priority:critical` | Critical priority issue |

## Label Lifecycle

```
ai-ready  ->  ai-in-progress  ->  ai-done (draft PR opened)
   ^               |
   |               v
   +------- ai-blocked (question asked, waiting for answer)
```

Use `ai-pause` on the repo to gracefully stop all loops at the end of their current cycle. Use `priority:high` / `priority:critical` on issues to influence pickup order.

## License

MIT

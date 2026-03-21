# AI Workflow Skills

A set of Claude Code skills that create an automated GitHub-integrated development workflow.

## The Workflow

```
You <-> AI (brainstorm) -> GitHub Issues -> AI (execute) -> Draft PRs -> You (review)
```

### Phase 1: Brainstorm & Plan
Talk to AI about your idea. AI challenges it, writes a PRD, and breaks it into GitHub issues labeled `ai-ready`.

### Phase 2: Auto-Execute
AI picks up `ai-ready` issues, implements them using TDD, and opens draft PRs.

### Phase 3: Review & Iterate
You review draft PRs. AI reads your feedback and pushes fixes.

## Skills

- **brainstorm-to-issues** - Interactive brainstorming that produces a PRD and vertical-slice GitHub issues.

  ```
  npx skills@latest add <your-username>/my-skills/brainstorm-to-issues
  ```

- **work-issues** - Autonomously picks up `ai-ready` issues, implements with TDD, opens draft PRs.

  ```
  npx skills@latest add <your-username>/my-skills/work-issues
  ```

- **handle-pr-feedback** - Reads PR review comments and pushes fixes.

  ```
  npx skills@latest add <your-username>/my-skills/handle-pr-feedback
  ```

## Setup

### Required
- [Claude Code](https://claude.com/claude-code) installed
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated
- Repository with issues enabled

### GitHub Labels
Create these labels in your repo:

| Label | Description |
|-------|-------------|
| `prd` | Product Requirements Document |
| `ai-ready` | Ready for AI to pick up |
| `ai-in-progress` | AI is currently working on this |
| `ai-done` | AI opened a draft PR |
| `ai-blocked` | AI couldn't proceed, needs human input |

```bash
gh label create prd --color "0E8A16" --description "Product Requirements Document"
gh label create ai-ready --color "1D76DB" --description "Ready for AI to pick up"
gh label create ai-in-progress --color "FBCA04" --description "AI is currently working on this"
gh label create ai-done --color "0E8A16" --description "AI opened a draft PR"
gh label create ai-blocked --color "D93F0B" --description "AI needs human input"
```

## Label Lifecycle

```
ai-ready  ->  ai-in-progress  ->  ai-done (draft PR opened)
                    |
                    v
              ai-blocked (if stuck)
```

## License

MIT

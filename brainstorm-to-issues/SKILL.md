---
name: brainstorm-to-issues
description: Interactive brainstorming session that refines an idea into a PRD and breaks it into GitHub issues labeled ai-ready. Use when user wants to brainstorm, plan a feature, has an idea to discuss, says "brainstorm", "let's plan", "I have an idea", or wants to break work into issues.
---

# Brainstorm to Issues

Turn a casual idea into structured, implementable GitHub issues through conversation.

## Pre-flight

Before starting the brainstorm, verify the environment so the user doesn't lose work at the end:

```
gh auth status
```

If this fails, stop immediately: "GitHub CLI isn't authenticated. Run `gh auth login` first, then let's brainstorm."

## Process

### 1. Capture the idea

Ask the user to describe their idea freely. Don't interrupt — let them get it all out. Then summarize what you heard back to them in 2-3 sentences to confirm understanding.

If the user references an existing PRD or issue (e.g., "I want to add more issues to #42" or "let's extend the auth PRD"), read it with `gh issue view <number>` and skip to step 4 — you're extending, not creating from scratch.

### 2. Explore the codebase

Before interviewing the user, proactively explore the codebase to understand the landscape. This makes your questions sharper and avoids asking things the code already answers:

- Project structure, frameworks, and patterns in use
- Existing modules related to the idea
- Database schemas, API routes, or config that would be affected
- Test infrastructure and conventions
- **File ownership boundaries** — which directories/files belong to which logical modules. This matters later when you need to split work into non-overlapping issues for parallel implementation.

This exploration informs both the interview and the eventual issue breakdown. Spend enough time here that you can have a technical conversation about the idea without constantly asking the user "where does X live?"

### 3. Grill the idea

Interview the user about every aspect. Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer informed by what you found in the codebase.

If a question can be answered by exploring the codebase, explore it instead of asking.

Cover at minimum:
- Who is this for? What problem does it solve?
- What does "done" look like?
- What are the edge cases?
- What's explicitly out of scope?
- Are there technical constraints or preferences?

Keep going until there are no open questions.

### 4. Write the PRD

Create a PRD as a GitHub issue using `gh issue create`:

<prd-template>
## Problem Statement

The problem from the user's perspective.

## Solution

The solution from the user's perspective.

## User Stories

Numbered list:
1. As a <actor>, I want <feature>, so that <benefit>

Be extensive — cover all aspects discussed.

## Implementation Decisions

Key technical decisions made during brainstorming:
- Modules to build/modify (reference by component/module name — e.g., "auth middleware", "users API", "dashboard page")
- Architectural choices
- Schema changes
- API contracts

Include enough technical direction that the implementing agent knows which areas of the codebase to work in, but avoid hardcoding specific file paths or line numbers that will go stale.

## Out of Scope

What was explicitly excluded.
</prd-template>

Add the label `prd` to the issue.

### 5. Break into vertical slices

Break the PRD into **tracer bullet** issues. Each issue is a thin vertical slice through ALL layers end-to-end, NOT a horizontal layer slice.

**Scope estimation:** For each slice, estimate the rough size (small: <100 lines, medium: 100-300 lines, large: 300-500 lines). If any slice looks like it would exceed ~500 lines of changes, split it further — the downstream implementation skill has a ~500 line threshold and will reject issues that are too large.

#### Minimize file conflicts for parallel work

AI agents pick up unblocked `ai-ready` issues in parallel. If two parallel issues modify the same files, their PRs will conflict and one will need to be rebased or redone. This is wasteful, so the issue breakdown should minimize file overlap between issues that can run at the same time.

**Keep every issue as a vertical slice.** Do not split work into horizontal layers (e.g., "all schema changes" then "all renderer changes" then "all UI changes") just to avoid file conflicts. Each issue should still touch all the layers it needs end-to-end. The way to avoid conflicts is through dependency chains, not by breaking vertical slices apart.

After defining the slices, do a file-overlap analysis:

1. **Map the file footprint** of each slice — list the files or directories it will likely touch. Be specific (e.g., "src/api/routes/widgets.ts, src/db/migrations/, src/components/WidgetList.tsx") rather than vague ("the API layer"). Use what you learned in step 2 about the codebase structure.

2. **Identify conflicts** — two slices conflict if their file footprints overlap. Common conflict hotspots:
   - Shared config files (routes index, DB schema, app entrypoint)
   - Barrel/index files that re-export modules
   - Shared types or interfaces files
   - CSS/style files used across components

3. **Resolve conflicts through dependency chains.** When two vertical slices touch the same files, chain them with a dependency so they run sequentially instead of in parallel. Pick the natural ordering — the slice that establishes shared groundwork (e.g., adds the DB table, creates the base component) goes first, and the slice that builds on it depends on it. If there's no natural ordering, just pick one. The key rule: **no two simultaneously-unblocked issues should share files.** Add as many dependency links as needed to enforce this — a longer chain is better than a merge conflict.

4. **Maximize parallel lanes.** Arrange the dependency graph so the maximum number of issues are unblocked at any given time, while respecting the constraint above. Think of it as coloring a graph: issues in the same "color" (parallel group) must not conflict on files. Spread unrelated slices across separate lanes that can run simultaneously.

If a shared file is unavoidable across many slices (e.g., a routes index where every feature adds a line), front-load those changes into the first slice in the chain so later slices only append to what the first one established.

#### Present the breakdown

Present the breakdown to the user as a numbered list showing:
- **Title**: short descriptive name
- **Type**: HITL (needs human input) / AFK (fully autonomous)
- **Priority**: critical / high / normal (if everything is normal, skip this column)
- **Blocked by**: dependencies on other slices
- **User stories covered**: which stories from the PRD
- **Estimated size**: small / medium / large
- **Files touched**: key files/directories this slice will modify

After the list, show a **parallel lanes** view — which issues can run simultaneously without conflicts:

```
Lane 1: #1 Setup DB schema → #3 Widget CRUD API → #5 Widget permissions
Lane 2: #2 Dashboard layout  → #4 Widget list component
```

This makes the conflict-avoidance strategy visible. Ask: Does the granularity feel right? Any slices to merge or split? Do the dependency chains make sense for avoiding conflicts?

Iterate until approved.

### 6. Create the issues

Before creating anything, save the full list of planned issues (titles, bodies, labels, dependencies) to a local file as a backup:

```
<project-root>/brainstorm-<short-name>-<YYYYMMDD-HHMMSS>.json
```

Use `date +%Y%m%d-%H%M%S` for the timestamp. This prevents collisions when multiple brainstorms run simultaneously.

This ensures nothing is lost if issue creation fails partway through. If a `gh issue create` call fails, stop, report which issues were created and which remain, and offer to retry the remaining ones.

For each approved slice, create a GitHub issue with `gh issue create`. Create in dependency order so you can reference real issue numbers.

<issue-template>
## Parent PRD

#<prd-issue-number>

## What to build

Concise description of this vertical slice. Describe end-to-end behavior, not layer-by-layer implementation.

## Acceptance criteria

Specific, testable criteria that an implementing agent can verify. Each criterion should describe observable behavior, not vague quality:

- [ ] `POST /api/widgets` returns 201 with the created widget JSON
- [ ] Widget appears in the dashboard list without page refresh
- [ ] Creating a widget with a duplicate name returns 409

Avoid criteria like "works correctly" or "handles edge cases" — be precise about what "correct" means.

## Blocked by

List of issue references this depends on, or omit this section entirely if unblocked.

- #<issue-number>

## Type

AFK / HITL

## Input Needed (HITL only)

What specific input the human must provide before this can be implemented. Be precise — not "design feedback" but "choose between tabbed layout or sidebar layout for the settings page and provide rough wireframe or description of which settings go where."
</issue-template>

**Labeling rules:**

- **AFK issues with no blockers** → label `ai-ready` (can be picked up immediately by the AI implementation loop)
- **AFK issues with blockers** → label `ai-blocked` (will be picked up automatically when blockers close)
- **HITL issues** → label `ai-needs-input` (waiting for human to provide input described in the "Input Needed" section). Once the human comments with their input and relabels to `ai-ready`, the AI implementation loop picks it up.

If the user assigned priorities, also add the corresponding label:
- `priority:critical` or `priority:high` (normal priority gets no label — it's the default)

### 7. Update the PRD with child links

After all issues are created, edit the PRD issue to add a tracking section at the bottom:

```
gh issue edit <prd-number> --body "$(current body)

## Implementation Issues

- [ ] #<issue-1> - <title>
- [ ] #<issue-2> - <title>
- [ ] #<issue-3> - <title>
"
```

This makes the PRD a single source of truth — you can see the full breakdown and track progress from one place.

### 8. Summary

Print a summary: PRD issue link, list of created issues with numbers and labels, dependency graph, and suggested starting order.

If any HITL issues were created, call them out explicitly:

```
Issues waiting for your input:
- #<number> "<title>" — needs: <what input is needed>
- #<number> "<title>" — needs: <what input is needed>

Comment on the issue with your input, then change the label from `ai-needs-input` to `ai-ready` to hand it off.
```

Clean up the local backup file if all issues were created successfully.

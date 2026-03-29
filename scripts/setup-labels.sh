#!/usr/bin/env bash
set -euo pipefail

# Creates all GitHub labels required by the AI workflow.
# Run from inside a repo: bash scripts/setup-labels.sh

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

for entry in "${labels[@]}"; do
  IFS='|' read -r name color description <<< "$entry"
  if gh label create "$name" --color "$color" --description "$description" 2>/dev/null; then
    echo "Created: $name"
  else
    echo "Exists:  $name"
  fi
done

echo "Done. All labels are set up."

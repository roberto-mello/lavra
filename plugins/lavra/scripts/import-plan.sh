#!/bin/bash
#
# Import a markdown plan into beads
#
# Usage:
#   ./import-plan.sh plan.md "Epic Title"
#
# Expected markdown format:
#   # Epic Title
#   Description here
#
#   ## Research / Background
#   Research findings...
#
#   ## Implementation Steps
#   ### Step 1: Database Schema
#   Details...
#
#   ### Step 2: API Endpoints
#   Details...
#
# This will create:
#   - Epic bead with full plan as description
#   - Child beads for each step (### headers under Implementation Steps)
#   - Knowledge comments for research/background sections
#

set -euo pipefail

PLAN_FILE="${1:-}"
EPIC_TITLE="${2:-}"

if [[ -z "$PLAN_FILE" || ! -f "$PLAN_FILE" ]]; then
  echo "Usage: $0 <plan.md> <epic-title>"
  echo ""
  echo "Example:"
  echo "  $0 auth-plan.md \"Add two-factor authentication\""
  exit 1
fi

if [[ -z "$EPIC_TITLE" ]]; then
  echo "Error: Epic title required"
  echo "Usage: $0 <plan.md> <epic-title>"
  exit 1
fi

echo "Importing plan from: $PLAN_FILE"
echo "Epic title: $EPIC_TITLE"
echo ""

# Read full plan
FULL_PLAN=$(cat "$PLAN_FILE")

# Create epic bead
echo "Creating epic bead..."
EPIC_OUTPUT=$(bd create "$EPIC_TITLE" -d "$FULL_PLAN" --type epic 2>&1)
EPIC_ID=$(echo "$EPIC_OUTPUT" | grep -oE '[A-Z]+-[0-9]+' | head -1)

if [[ -z "$EPIC_ID" ]]; then
  echo "Error: Failed to create epic bead"
  echo "$EPIC_OUTPUT"
  exit 1
fi

echo "Created epic: $EPIC_ID"
echo ""

# Extract research/background section and add as INVESTIGATION
RESEARCH=$(awk '/^## (Research|Background|Context)/{flag=1;next}/^## /{flag=0}flag' "$PLAN_FILE")

if [[ -n "$RESEARCH" ]]; then
  echo "Adding research findings as INVESTIGATION..."
  bd comments add "$EPIC_ID" "INVESTIGATION: Background and Research

$RESEARCH"
fi

# Extract decisions section and add as DECISION
DECISIONS=$(awk '/^## (Decisions|Choices|Approach)/{flag=1;next}/^## /{flag=0}flag' "$PLAN_FILE")

if [[ -n "$DECISIONS" ]]; then
  echo "Adding decisions..."
  bd comments add "$EPIC_ID" "DECISION: Architectural Decisions

$DECISIONS"
fi

# Extract implementation steps (### headers under Implementation/Tasks/Steps section)
echo ""
echo "Creating child beads for implementation steps..."

PREV_BEAD=""
STEP_NUM=0

# Find the Implementation Steps section and extract ### headers
awk '/^## (Implementation|Tasks|Steps|Work)/{flag=1;next}/^## /{flag=0}flag' "$PLAN_FILE" | \
  grep -E '^### ' | \
  while IFS= read -r line; do
    ((STEP_NUM++))

    # Extract step title (remove ###)
    STEP_TITLE=$(echo "$line" | sed 's/^### *//')

    # Extract step description (text between this ### and next ### or ##)
    STEP_DESC=$(awk -v title="$line" '
      $0 == title {flag=1; next}
      /^##/ {flag=0}
      flag && /^$/ {next}
      flag {print}
    ' "$PLAN_FILE" | head -20)

    # Create child bead
    if [[ -z "$PREV_BEAD" ]]; then
      # First step, no dependencies
      CHILD_OUTPUT=$(bd create "$STEP_TITLE" -d "$STEP_DESC" --parent "$EPIC_ID" 2>&1)
    else
      # Subsequent steps depend on previous
      CHILD_OUTPUT=$(bd create "$STEP_TITLE" -d "$STEP_DESC" --parent "$EPIC_ID" --deps "$PREV_BEAD" 2>&1)
    fi

    CHILD_ID=$(echo "$CHILD_OUTPUT" | grep -oE '[A-Z]+-[0-9.]+' | head -1)

    if [[ -n "$CHILD_ID" ]]; then
      echo "  Created: $CHILD_ID - $STEP_TITLE"
      PREV_BEAD="$CHILD_ID"
    else
      echo "  Warning: Failed to create bead for: $STEP_TITLE"
    fi
  done

echo ""
echo "Import complete!"
echo ""
echo "Epic: $EPIC_ID"
echo "View: bd show $EPIC_ID"
echo "List children: bd list --parent $EPIC_ID"
echo ""
echo "Next steps:"
echo "  1. Review the created beads: bd show $EPIC_ID"
echo "  2. Start work: /beads-work ${EPIC_ID}.1"
echo "  3. Or refine with research: /beads-plan $EPIC_ID"

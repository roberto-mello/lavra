#!/bin/bash
#
# SubagentStop: Auto-capture learnings before subagent exits
#
# This hook runs when any subagent completes. It prompts the subagent
# to log key learnings to the bead before finishing.
#

INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty')

# Only run for actual subagents (not the main agent)
[[ -z "$AGENT_ID" ]] && exit 0

# Check if there's a BEAD_ID in the agent's context
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  # Try to extract BEAD_ID from the transcript
  BEAD_ID=$(grep -oE 'BEAD_ID: [A-Za-z0-9._-]+' "$TRANSCRIPT_PATH" 2>/dev/null | head -1 | sed 's/BEAD_ID: //')

  if [[ -n "$BEAD_ID" ]]; then
    # Subagent is working on a bead - prompt it to log learnings
    cat << EOF
{
  "decision": "block",
  "reason": "Before completing, please log what you learned to the bead using one or more of these formats:

bd comments add $BEAD_ID \"LEARNED: [key technical insight you discovered]\"
bd comments add $BEAD_ID \"DECISION: [important choice you made and why]\"
bd comments add $BEAD_ID \"FACT: [constraint, gotcha, or important detail]\"
bd comments add $BEAD_ID \"PATTERN: [coding pattern or convention you followed]\"
bd comments add $BEAD_ID \"INVESTIGATION: [root cause or how something works]\"

After logging at least one insight, you may complete."
}
EOF
    exit 0
  fi
fi

# No BEAD_ID found or not working on a bead - allow completion
exit 0

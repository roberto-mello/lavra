#!/bin/bash
# teammate-idle-check.sh
# Prevents workers from going idle while ready beads remain.
# Uses JSON decision:block pattern (consistent with subagent-wrapup.sh).
#
# TeammateIdle hook -- fires when a teammate tries to go idle.

INPUT=$(cat)
TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // empty')

# Validate teammate_name against safe pattern
if [[ ! "$TEAMMATE" =~ ^[a-zA-Z0-9_-]{1,64}$ ]]; then
  TEAMMATE="unknown"
fi

READY=$(bd ready --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")

if [ "$READY" -gt 0 ]; then
  cat << EOF
{
  "decision": "block",
  "reason": "There are $READY beads ready to work on. Run 'bd ready' and pick one."
}
EOF
  exit 0
fi

# No ready beads -- allow idle (remaining beads may be blocked by dependencies)
exit 0

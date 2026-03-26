#!/usr/bin/env bash
# extract-bead-context.sh — Extract bead context for agent prompt injection
# Usage: extract-bead-context.sh <bead-id>

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: extract-bead-context.sh <bead-id>"
  exit 1
fi

BEAD_ID="$1"

# Fetch full bead output
RAW=$(bd show "$BEAD_ID" --long 2>&1)

# Extract title: first line is "✓ {id} · {title}   [...]"
# Use awk to split on '·' and take the second field (title), then trim trailing " [..."
TITLE=$(echo "$RAW" | head -1 | awk -F'·' '{print $2}' | sed 's/[[:space:]]*\[.*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

# Extract description block: between "DESCRIPTION" and next section header,
# stripping leading and trailing blank lines.
# LABELS may appear as "LABELS: value" (colon+value on same line).
DESCRIPTION=$(echo "$RAW" | awk '
  /^DESCRIPTION$/ { in_desc=1; next }
  in_desc && /^(LABELS(:|$)|PARENT$|BLOCKS$|RELATED$|COMMENTS$|EXTENDED DETAILS$)/ { in_desc=0 }
  in_desc { lines[++n]=$0 }
  END {
    # find first non-blank line
    first=1
    while (first<=n && lines[first] ~ /^[[:space:]]*$/) first++
    # find last non-blank line
    last=n
    while (last>=first && lines[last] ~ /^[[:space:]]*$/) last--
    for (i=first; i<=last; i++) print lines[i]
  }
')

# Extract knowledge-prefixed comments from COMMENTS section
FINDINGS=$(echo "$RAW" | awk '
  /^COMMENTS$/ { in_comments=1; next }
  in_comments && /^EXTENDED DETAILS/ { in_comments=0 }
  in_comments && /^[[:space:]]+(INVESTIGATION|FACT|PATTERN|DECISION|LEARNED|DEVIATION):/ {
    # strip leading whitespace
    sub(/^[[:space:]]+/, "")
    print
  }
')

# Output the structured block
echo "## Bead: ${BEAD_ID} — ${TITLE}"
echo ""
echo "${DESCRIPTION}"

if [[ -n "$FINDINGS" ]]; then
  echo ""
  echo "## Research Findings"
  echo ""
  echo "$FINDINGS"
fi

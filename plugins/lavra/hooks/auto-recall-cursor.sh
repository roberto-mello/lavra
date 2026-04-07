#!/usr/bin/env bash
#
# SessionStart: Cursor IDE adapter for auto-recall.sh
#
# Cursor's sessionStart hook sends workspace_roots[] instead of cwd.
# This wrapper extracts workspace_roots[0], rewrites it as cwd in the
# JSON payload, then delegates to auto-recall.sh.
#
# Input field difference:
#   Claude Code: {cwd: "/path/to/project", ...}
#   Cursor:      {workspace_roots: ["/path/to/project"], ...}
#
# Output field difference:
#   auto-recall.sh: {hookSpecificOutput: {systemMessage: "..."}}
#   Cursor expects: {additional_context: "..."}
#

set -euo pipefail

INPUT=$(cat)
WORKSPACE=$(echo "$INPUT" | jq -r '.workspace_roots[0] // .cwd // empty')
[[ -z "$WORKSPACE" ]] && exit 0

# Delegate to canonical hook with cwd injected into JSON,
# then map hookSpecificOutput.systemMessage → additional_context
echo "$INPUT" \
  | jq --arg cwd "$WORKSPACE" '. + {cwd: $cwd}' \
  | bash "$(dirname "$0")/auto-recall.sh" \
  | jq 'if .hookSpecificOutput.systemMessage then {additional_context: .hookSpecificOutput.systemMessage} else empty end'

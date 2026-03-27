#!/bin/bash
#
# Dispatch to a project-level hook script if it exists, otherwise exit cleanly.
#
# Cortex Code only supports global ~/.snowflake/cortex/hooks.json (no project-level
# hooks config). This dispatcher lives at a fixed absolute path in the global hooks
# directory and conditionally forwards to project-level scripts based on CWD.
#
# Usage: dispatch-hook.sh <hooks-dir> <script-name>
# Example: dispatch-hook.sh .cortex/hooks memory-capture.sh
#
# stdin is passed through to the target script via exec.
# Exits 0 silently if the target script does not exist (non-lavra project).
#

HOOKS_DIR="${1:?Usage: dispatch-hook.sh <hooks-dir> <script-name>}"
HOOK="${2:?Usage: dispatch-hook.sh <hooks-dir> <script-name>}"

test -f "$HOOKS_DIR/$HOOK" || exit 0
exec bash "$HOOKS_DIR/$HOOK"

#!/bin/bash
#
# SessionStart hook: auto-install memory features in beads projects
#
# Installed globally by ./install.sh (global install).
# Detects beads projects missing memory hooks and installs them automatically.
#

# Platform selection (default: claude for backward compatibility)
PLATFORM="${1:-claude}"

case "$PLATFORM" in
  claude)
    PROJECT_HOOKS_DIR=".claude/hooks"
    GLOBAL_HOOKS_DIR="$HOME/.claude/hooks"
    SETTINGS_FILE=".claude/settings.json"
    SOURCE_SENTINEL="$HOME/.claude/.beads-compound-source"
    HOOK_CMD_PREFIX="bash .claude/hooks"
    BASH_TOOL_NAME="Bash"
    PRODUCT_NAME="Claude Code"
    ;;
  cortex)
    PROJECT_HOOKS_DIR=".cortex/hooks"
    GLOBAL_HOOKS_DIR="$HOME/.snowflake/cortex/hooks"
    SETTINGS_FILE="$HOME/.snowflake/cortex/hooks.json"
    SOURCE_SENTINEL="$HOME/.snowflake/cortex/.beads-compound-source"
    HOOK_CMD_PREFIX="bash .cortex/hooks"
    BASH_TOOL_NAME="bash"
    PRODUCT_NAME="Cortex Code"
    ;;
  *)
    echo "Unknown platform: $PLATFORM" >&2
    exit 1
    ;;
esac

# Only relevant if this project has .beads/ initialized
if [ ! -d ".beads" ]; then
  exit 0
fi

# Already has memory hooks -- nothing to do
if [ -f "$PROJECT_HOOKS_DIR/memory-capture.sh" ]; then
  exit 0
fi

# Find where the hook scripts are installed
# Try multiple locations in order:
# 1. Global hooks directory (manual install)
# 2. Same directory as this script (marketplace/plugin install)
# 3. Plugin source path (legacy)

HOOKS_SOURCE_DIR=""

# Option 1: Global hooks directory
if [ -f "$GLOBAL_HOOKS_DIR/memory-capture.sh" ]; then
  HOOKS_SOURCE_DIR="$GLOBAL_HOOKS_DIR"
fi

# Option 2: Same directory as this script (for marketplace installs)
if [ -z "$HOOKS_SOURCE_DIR" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  if [ -f "$SCRIPT_DIR/memory-capture.sh" ]; then
    HOOKS_SOURCE_DIR="$SCRIPT_DIR"
  fi
fi

# Option 3: Legacy plugin source path (backward compatibility)
if [ -z "$HOOKS_SOURCE_DIR" ] && [ -f "$SOURCE_SENTINEL" ]; then
  PLUGIN_SOURCE=$(cat "$SOURCE_SENTINEL")
  PLUGIN_DIR="$PLUGIN_SOURCE/plugins/beads-compound"
  if [ -f "$PLUGIN_DIR/hooks/memory-capture.sh" ]; then
    HOOKS_SOURCE_DIR="$PLUGIN_DIR/hooks"
  fi
fi

# Verify we found the hooks
if [ -z "$HOOKS_SOURCE_DIR" ] || [ ! -f "$HOOKS_SOURCE_DIR/memory-capture.sh" ]; then
  cat <<'NOFIND'
{
  "systemMessage": "[beads-compound] Memory hook scripts not found. Install via: /plugin install beads-compound"
}
NOFIND
  exit 0
fi

# --- Auto-install memory features ---

# 1. Set up memory directory
PROVISION_SCRIPT="$HOOKS_SOURCE_DIR/provision-memory.sh"

if [ -f "$PROVISION_SCRIPT" ]; then
  source "$PROVISION_SCRIPT"
  provision_memory_dir "." "$HOOKS_SOURCE_DIR"
else
  # Fallback: minimal setup if provision script missing
  MEMORY_DIR=".beads/memory"
  mkdir -p "$MEMORY_DIR"
  [ ! -f "$MEMORY_DIR/knowledge.jsonl" ] && touch "$MEMORY_DIR/knowledge.jsonl"
fi

# 2. Install hook scripts from source directory
HOOKS_DIR="$PROJECT_HOOKS_DIR"
mkdir -p "$HOOKS_DIR"

for hook in memory-capture.sh auto-recall.sh subagent-wrapup.sh knowledge-db.sh provision-memory.sh recall.sh; do
  if [ -f "$HOOKS_SOURCE_DIR/$hook" ]; then
    cp "$HOOKS_SOURCE_DIR/$hook" "$HOOKS_DIR/$hook"
    chmod +x "$HOOKS_DIR/$hook"
  fi
done

# 3. Configure settings.json with hook definitions
SETTINGS="$SETTINGS_FILE"

if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  EXISTING=$(cat "$SETTINGS")

  RECALL_CMD="$HOOK_CMD_PREFIX/auto-recall.sh"
  CAPTURE_CMD="$HOOK_CMD_PREFIX/memory-capture.sh"
  WRAPUP_CMD="$HOOK_CMD_PREFIX/subagent-wrapup.sh"

  UPDATED=$(echo "$EXISTING" | jq --arg recall "$RECALL_CMD" --arg capture "$CAPTURE_CMD" --arg wrapup "$WRAPUP_CMD" --arg matcher "$BASH_TOOL_NAME" '
    .hooks.SessionStart = (
      [(.hooks.SessionStart // [])[] | select(.hooks[]?.command | contains("auto-recall") | not)] +
      [{"hooks":[{"type":"command","command":($recall),"async":true}]}]
    ) |
    .hooks.PostToolUse = (
      [(.hooks.PostToolUse // [])[] | select(.hooks[]?.command | contains("memory-capture") | not)] +
      [{"matcher":$matcher,"hooks":[{"type":"command","command":($capture),"async":true}]}]
    ) |
    .hooks.SubagentStop = (
      [(.hooks.SubagentStop // [])[] | select(.hooks[]?.command | contains("subagent-wrapup") | not)] +
      [{"hooks":[{"type":"command","command":($wrapup)}]}]
    ) |
    if .hooks.PreToolUse == null then del(.hooks.PreToolUse) else . end |
    if .hooks.SubagentStop == null then del(.hooks.SubagentStop) else . end
  ')
  echo "$UPDATED" > "$SETTINGS"
elif [ ! -f "$SETTINGS" ]; then
  mkdir -p "$(dirname "$SETTINGS")"
  cat > "$SETTINGS" << SETTINGS_EOF
{
  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "$HOOK_CMD_PREFIX/auto-recall.sh", "async": true}]}
    ],
    "PostToolUse": [
      {"matcher": "$BASH_TOOL_NAME", "hooks": [{"type": "command", "command": "$HOOK_CMD_PREFIX/memory-capture.sh", "async": true}]}
    ],
    "SubagentStop": [
      {"hooks": [{"type": "command", "command": "$HOOK_CMD_PREFIX/subagent-wrapup.sh"}]}
    ]
  }
}
SETTINGS_EOF
fi

# Report success
cat <<EOF
{
  "systemMessage": "[beads-compound] Auto-installed memory hooks. Restart $PRODUCT_NAME to activate auto-recall and knowledge capture.",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Memory hooks were just auto-installed for this project (auto-recall, knowledge capture, subagent wrapup). Tell the user to restart $PRODUCT_NAME to activate them."
  }
}
EOF

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
    SOURCE_SENTINEL="$HOME/.claude/.lavra-source"
    HOOK_CMD_PREFIX="bash .claude/hooks"
    BASH_TOOL_NAME="Bash"
    PRODUCT_NAME="Claude Code"
    ;;
  cortex)
    PROJECT_HOOKS_DIR=".cortex/hooks"
    GLOBAL_HOOKS_DIR="$HOME/.snowflake/cortex/hooks"
    SETTINGS_FILE="$HOME/.snowflake/cortex/hooks.json"
    SOURCE_SENTINEL="$HOME/.snowflake/cortex/.lavra-source"
    HOOK_CMD_PREFIX="bash ~/.snowflake/cortex/hooks/dispatch-hook.sh .cortex/hooks"
    BASH_TOOL_NAME="Bash"
    PRODUCT_NAME="Cortex Code"
    ;;
  codex)
    PROJECT_HOOKS_DIR=".codex/hooks"
    GLOBAL_HOOKS_DIR="$HOME/.codex/hooks"
    SETTINGS_FILE="$HOME/.codex/hooks.json"
    SOURCE_SENTINEL="$HOME/.codex/.lavra-source"
    HOOK_CMD_PREFIX="bash ~/.codex/hooks/dispatch-hook.sh .codex/hooks"
    BASH_TOOL_NAME="Bash"
    PRODUCT_NAME="Codex"
    ;;
  *)
    echo "Unknown platform: $PLATFORM" >&2
    exit 1
    ;;
esac

# Only relevant if this project has .beads/ or .lavra/ initialized
if [ ! -d ".beads" ] && [ ! -d ".lavra" ]; then
  exit 0
fi

# Compare versions and determine if update is needed
GLOBAL_VERSION=""
PROJECT_VERSION=""
NEED_UPDATE=false

if [ -f "$GLOBAL_HOOKS_DIR/.lavra-version" ]; then
  GLOBAL_VERSION=$(cat "$GLOBAL_HOOKS_DIR/.lavra-version")
fi
if [ -f "$PROJECT_HOOKS_DIR/.lavra-version" ]; then
  PROJECT_VERSION=$(cat "$PROJECT_HOOKS_DIR/.lavra-version")
fi

if [ -n "$GLOBAL_VERSION" ] && [ "$GLOBAL_VERSION" != "$PROJECT_VERSION" ]; then
  NEED_UPDATE=true
elif [ -f "$PROJECT_HOOKS_DIR/memory-capture.sh" ]; then
  # Hooks exist but no version mismatch (or no version markers yet) -- up to date
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
  PLUGIN_DIR="$PLUGIN_SOURCE/plugins/lavra"
  if [ -f "$PLUGIN_DIR/hooks/memory-capture.sh" ]; then
    HOOKS_SOURCE_DIR="$PLUGIN_DIR/hooks"
  fi
fi

# Verify we found the hooks
if [ -z "$HOOKS_SOURCE_DIR" ] || [ ! -f "$HOOKS_SOURCE_DIR/memory-capture.sh" ]; then
  cat <<'NOFIND'
{
  "systemMessage": "[lavra] Memory hook scripts not found. Install via: npx lavra@latest"
}
NOFIND
  exit 0
fi

# --- Auto-install memory features ---

# 1. Set up memory directory
PROVISION_SCRIPT="$HOOKS_SOURCE_DIR/provision-memory.sh"

if [ -f "$PROVISION_SCRIPT" ]; then
  source "$PROVISION_SCRIPT"
  migrate_beads_to_lavra "." >/dev/null 2>&1 || true
  provision_memory_dir "." "$HOOKS_SOURCE_DIR" >/dev/null 2>&1 || true
else
  # Fallback: minimal setup if provision script missing
  MEMORY_DIR=".lavra/memory"
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

# Write version marker so future updates are detected
if [ -n "$GLOBAL_VERSION" ]; then
  echo "$GLOBAL_VERSION" > "$HOOKS_DIR/.lavra-version"
fi

# Cortex Code: ensure dispatcher is in the global hooks dir
if [ "$PLATFORM" = "cortex" ] && [ -f "$HOOKS_SOURCE_DIR/dispatch-hook.sh" ] && [ ! -f "$GLOBAL_HOOKS_DIR/dispatch-hook.sh" ]; then
  cp "$HOOKS_SOURCE_DIR/dispatch-hook.sh" "$GLOBAL_HOOKS_DIR/dispatch-hook.sh"
  chmod +x "$GLOBAL_HOOKS_DIR/dispatch-hook.sh"
fi

# 3. Configure settings.json with hook definitions
SETTINGS="$SETTINGS_FILE"

if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  EXISTING=$(cat "$SETTINGS")

  # Cortex/Codex use dispatcher (space-separated args), Claude uses direct paths (slash-separated)
  if [ "$PLATFORM" = "cortex" ] || [ "$PLATFORM" = "codex" ]; then
    RECALL_CMD="$HOOK_CMD_PREFIX auto-recall.sh"
    CAPTURE_CMD="$HOOK_CMD_PREFIX memory-capture.sh"
    WRAPUP_CMD="$HOOK_CMD_PREFIX subagent-wrapup.sh"
  else
    RECALL_CMD="$HOOK_CMD_PREFIX/auto-recall.sh"
    CAPTURE_CMD="$HOOK_CMD_PREFIX/memory-capture.sh"
    WRAPUP_CMD="$HOOK_CMD_PREFIX/subagent-wrapup.sh"
  fi

  UPDATED=$(echo "$EXISTING" | jq --arg recall "$RECALL_CMD" --arg capture "$CAPTURE_CMD" --arg wrapup "$WRAPUP_CMD" --arg matcher "$BASH_TOOL_NAME" --arg platform "$PLATFORM" '
    .hooks.SessionStart = (
      [(.hooks.SessionStart // [])[] | select(.hooks[]?.command | contains("auto-recall") | not)] +
      [if ($platform == "cortex" or $platform == "codex")
       then empty
       else {"hooks":[{"type":"command","command":($recall),"async":true}]}
       end]
    ) |
    .hooks.PostToolUse = (
      [(.hooks.PostToolUse // [])[] | select(.hooks[]?.command | contains("memory-capture") | not)] +
      [if ($platform == "cortex" or $platform == "codex")
       then {"matcher":$matcher,"hooks":[{"type":"command","command":($capture)}]}
       else {"matcher":$matcher,"hooks":[{"type":"command","command":($capture),"async":true}]}
       end]
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
  # Reuse the same CMD vars (set above only in jq path); recompute for heredoc
  if [ "$PLATFORM" = "cortex" ] || [ "$PLATFORM" = "codex" ]; then
    _SEP=" "
    _ASYNC_FIELD=""
    _SESSION_CMD="bash $GLOBAL_HOOKS_DIR/check-memory.sh $PLATFORM"
  else
    _SEP="/"
    _ASYNC_FIELD=', "async": true'
    _SESSION_CMD="${HOOK_CMD_PREFIX}${_SEP}auto-recall.sh"
  fi
  cat > "$SETTINGS" << SETTINGS_EOF
{
  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "${_SESSION_CMD}"${_ASYNC_FIELD}}]}
    ],
    "PostToolUse": [
      {"matcher": "$BASH_TOOL_NAME", "hooks": [{"type": "command", "command": "${HOOK_CMD_PREFIX}${_SEP}memory-capture.sh"${_ASYNC_FIELD}}]}
    ],
    "SubagentStop": [
      {"hooks": [{"type": "command", "command": "${HOOK_CMD_PREFIX}${_SEP}subagent-wrapup.sh"}]}
    ]
  }
}
SETTINGS_EOF
fi

# Report success
cat <<EOF
{
  "systemMessage": "[lavra] Auto-installed memory hooks. Restart $PRODUCT_NAME to activate auto-recall and knowledge capture.",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Memory hooks were just auto-installed for this project (auto-recall, knowledge capture, subagent wrapup). Tell the user to restart $PRODUCT_NAME to activate them."
  }
}
EOF

#!/bin/bash
#
# Uninstall lavra plugin from a project
#
# What this removes:
#   - Hooks from .claude/hooks/
#   - Commands from .claude/commands/
#   - Agents from .claude/agents/
#   - Skills from .claude/skills/
#   - Hook configuration from .claude/settings.json
#
# What this PRESERVES:
#   - .beads/ directory and all data
#   - .beads/memory/ and knowledge.jsonl (your accumulated knowledge)
#   - Any beads you created
#   - .mcp.json (may contain non-plugin MCP servers)
#
# Usage:
#   Global uninstall:
#     ./uninstall.sh                         # uninstalls from ~/.claude
#
#   Project-specific uninstall:
#     ./uninstall.sh /path/to/your-project
#
#   From anywhere:
#     bash /path/to/lavra/uninstall.sh
#     bash /path/to/lavra/uninstall.sh /path/to/your-project
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default to ~/.claude if no argument provided
if [ $# -eq 0 ]; then
  TARGET="$HOME/.claude"
  GLOBAL_UNINSTALL=true
else
  TARGET="${1}"
  GLOBAL_UNINSTALL=false
fi

TARGET="$(cd "$TARGET" && pwd)"

echo "lavra plugin uninstaller"
if [ "$GLOBAL_UNINSTALL" = true ]; then
  echo "Target: $TARGET (global)"
else
  echo "Target: $TARGET (project-specific)"
fi
echo ""

REMOVED_COUNT=0

# Remove hooks
echo "[1/5] Removing hooks..."

if [ "$GLOBAL_UNINSTALL" = true ]; then
  HOOKS_DIR="$TARGET/hooks"
else
  HOOKS_DIR="$TARGET/.claude/hooks"
fi

if [ -d "$HOOKS_DIR" ]; then
  for hook in memory-capture.sh auto-recall.sh subagent-wrapup.sh knowledge-db.sh provision-memory.sh check-memory.sh; do
    if [ -f "$HOOKS_DIR/$hook" ]; then
      rm "$HOOKS_DIR/$hook"
      echo "  - Removed $hook"
      ((REMOVED_COUNT++))
    fi
  done
else
  echo "  - No hooks directory found"
fi

# Remove global source path sentinel
if [ "$GLOBAL_UNINSTALL" = true ] && [ -f "$TARGET/.lavra-source" ]; then
  rm "$TARGET/.lavra-source"
  echo "  - Removed plugin source path"
  ((REMOVED_COUNT++))
fi

# Remove commands (all plugin commands)
echo "[2/5] Removing workflow commands..."

if [ "$GLOBAL_UNINSTALL" = true ]; then
  COMMANDS_DIR="$TARGET/commands"
else
  COMMANDS_DIR="$TARGET/.claude/commands"
fi

if [ -d "$COMMANDS_DIR" ]; then
  PLUGIN_COMMANDS=(
    lavra-plan.md lavra-work.md lavra-work-ralph.md lavra-work-teams.md lavra-parallel.md lavra-review.md lavra-checkpoint.md
    lavra-brainstorm.md lavra-compound.md
    lavra-research.md lavra-eng-review.md lavra-triage.md
    changelog.md create-agent-skill.md deploy-docs.md
    heal-skill.md lfg.md
    release-docs.md report-bug.md
    resolve-pr-parallel.md resolve-todo-parallel.md
    test-browser.md
  )

  for cmd in "${PLUGIN_COMMANDS[@]}"; do
    if [ -f "$COMMANDS_DIR/$cmd" ]; then
      rm "$COMMANDS_DIR/$cmd"
      echo "  - Removed /${cmd%.md} command"
      ((REMOVED_COUNT++))
    fi
  done
else
  echo "  - No commands directory found"
fi

# Remove agents
echo "[3/5] Removing agents..."

if [ "$GLOBAL_UNINSTALL" = true ]; then
  AGENTS_DIR="$TARGET/agents"
else
  AGENTS_DIR="$TARGET/.claude/agents"
fi

if [ -d "$AGENTS_DIR" ]; then
  AGENT_CATEGORIES=(review research design docs workflow)

  for category in "${AGENT_CATEGORIES[@]}"; do
    if [ -d "$AGENTS_DIR/$category" ]; then
      agent_count=$(find "$AGENTS_DIR/$category" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
      rm -rf "$AGENTS_DIR/$category"
      echo "  - Removed $category/ ($agent_count agents)"
      ((REMOVED_COUNT++))
    fi
  done

  # Remove agents dir if empty
  if [ -d "$AGENTS_DIR" ] && [ -z "$(ls -A "$AGENTS_DIR" 2>/dev/null)" ]; then
    rmdir "$AGENTS_DIR"
    echo "  - Removed empty agents directory"
  fi
else
  echo "  - No agents directory found"
fi

# Remove skills
echo "[4/5] Removing skills..."

if [ "$GLOBAL_UNINSTALL" = true ]; then
  SKILLS_DIR="$TARGET/skills"
else
  SKILLS_DIR="$TARGET/.claude/skills"
fi

if [ -d "$SKILLS_DIR" ]; then
  PLUGIN_SKILLS=(git-worktree brainstorming create-agent-skills agent-native-architecture lavra-knowledge agent-browser andrew-kane-gem-writer dhh-rails-style dspy-ruby every-style-editor file-todos frontend-design gemini-imagegen rclone)

  for skill in "${PLUGIN_SKILLS[@]}"; do
    if [ -L "$SKILLS_DIR/$skill" ]; then
      echo "  - Kept $skill (symlink, not ours)"
    elif [ -d "$SKILLS_DIR/$skill" ]; then
      if [ -f "$SKILLS_DIR/$skill/.lavra" ]; then
        rm -rf "$SKILLS_DIR/$skill"
        echo "  - Removed $skill skill"
        ((REMOVED_COUNT++))
      else
        echo "  - Kept $skill (not managed by this plugin)"
      fi
    fi
  done

  # Remove skills dir if empty
  if [ -d "$SKILLS_DIR" ] && [ -z "$(ls -A "$SKILLS_DIR" 2>/dev/null)" ]; then
    rmdir "$SKILLS_DIR"
    echo "  - Removed empty skills directory"
  fi
else
  echo "  - No skills directory found"
fi

# Update settings.json to remove hook configuration
echo "[5/5] Updating settings..."

if [ "$GLOBAL_UNINSTALL" = true ]; then
  SETTINGS="$TARGET/settings.json"
else
  SETTINGS="$TARGET/.claude/settings.json"
fi

if [ -f "$SETTINGS" ]; then
  if command -v jq &>/dev/null; then
    EXISTING=$(cat "$SETTINGS")

    # Remove our hooks from configuration and clean up empty/null arrays
    UPDATED=$(echo "$EXISTING" | jq '
      .hooks.SessionStart = [(.hooks.SessionStart // [])[] | select(.hooks[]?.command | (contains("auto-recall") or contains("check-memory")) | not)] |
      if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end |
      .hooks.PostToolUse = [(.hooks.PostToolUse // [])[] | select(.hooks[]?.command | contains("memory-capture") | not)] |
      if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end |
      .hooks.SubagentStop = [(.hooks.SubagentStop // [])[] | select(.hooks[]?.command | contains("subagent-wrapup") | not)] |
      if (.hooks.SubagentStop | length) == 0 then del(.hooks.SubagentStop) else . end |
      # Remove null hook arrays if they exist
      if .hooks.PreToolUse == null then del(.hooks.PreToolUse) else . end |
      # Remove hooks object if empty
      if (.hooks | to_entries | length) == 0 then del(.hooks) else . end
    ')

    echo "$UPDATED" > "$SETTINGS"
    echo "  - Removed hook configuration from settings.json"
    ((REMOVED_COUNT++))
  else
    echo "  [!] jq not found -- manual settings.json cleanup required"
    echo "      Remove SessionStart, PostToolUse, and SubagentStop hooks manually"
  fi
else
  echo "  - No settings.json found"
fi

# Summary
echo ""
if [ $REMOVED_COUNT -gt 0 ]; then
  echo "Uninstall complete. Removed $REMOVED_COUNT component(s)."
  echo ""
  echo "PRESERVED:"
  echo "  - .beads/ directory with all your data"
  echo "  - .beads/memory/knowledge.jsonl with accumulated knowledge"
  echo "  - All beads you created"
  echo "  - .mcp.json (remove manually if no longer needed)"
  echo ""
  echo "To completely remove beads data:"
  echo "  rm -rf $TARGET/.beads/"
  echo ""
  echo "Restart Claude Code to complete uninstallation."
else
  echo "Nothing to uninstall. lavra may not be installed here."
fi

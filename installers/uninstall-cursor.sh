#!/bin/bash
#
# Uninstall lavra plugin from Cursor IDE
#
# Removes:
#   - .cursor/hooks.json
#   - .cursor/hooks/ (hook scripts)
#   - .cursor/agents/ (lavra agents)
#   - .cursor/skills/ (lavra skills)
#   - .cursor/mcp.json context7 entry (or whole file if context7 was the only entry)
#
# Preserves:
#   - .lavra/ (knowledge base and config — user data)
#
# Usage:
#   Called by uninstall.sh -cursor [target]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default to ~/.cursor if no argument provided
if [ $# -eq 0 ]; then
  TARGET="$HOME/.cursor"
  GLOBAL_UNINSTALL=true
else
  TARGET="$1"
  GLOBAL_UNINSTALL=false
fi

# Resolve to absolute path
if [ ! -d "$TARGET" ]; then
  echo "[!] Error: Target directory does not exist: $TARGET"
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"

echo "lavra Cursor IDE Uninstaller"
echo ""
echo "  Target: $TARGET"
if [ "$GLOBAL_UNINSTALL" = true ]; then
  echo "  Type: Global uninstallation"
else
  echo "  Type: Project-specific uninstallation"
fi
echo ""

echo "This will remove:"
echo "  - .cursor/hooks.json (hook manifest)"
echo "  - .cursor/hooks/ (hook scripts)"
echo "  - .cursor/agents/ (lavra agents)"
echo "  - .cursor/skills/ (lavra skills)"
echo "  - context7 entry from .cursor/mcp.json"
echo ""
echo "Note: .lavra/ (knowledge base and config) will be preserved"
echo ""

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Uninstall cancelled."
  exit 0
fi

echo ""
echo "Removing files..."

# Remove hooks.json
if [ -f "$TARGET/.cursor/hooks.json" ]; then
  rm "$TARGET/.cursor/hooks.json"
  echo "  - Removed .cursor/hooks.json"
fi

# Remove hook scripts
HOOKS_DIR="$TARGET/.cursor/hooks"
if [ -d "$HOOKS_DIR" ]; then
  for hook in sanitize-content.sh auto-recall.sh auto-recall-cursor.sh memory-capture.sh \
              subagent-wrapup.sh knowledge-db.sh provision-memory.sh extract-bead-context.sh; do
    if [ -f "$HOOKS_DIR/$hook" ]; then
      rm "$HOOKS_DIR/$hook"
      echo "  - Removed $hook"
    fi
  done
  # Remove directory if now empty
  if [ -z "$(ls -A "$HOOKS_DIR" 2>/dev/null)" ]; then
    rmdir "$HOOKS_DIR"
    echo "  - Removed .cursor/hooks/ (empty)"
  fi
fi

# Remove agents
AGENTS_DIR="$TARGET/.cursor/agents"
if [ -d "$AGENTS_DIR" ]; then
  for category in review research design workflow docs; do
    if [ -d "$AGENTS_DIR/$category" ]; then
      rm -rf "$AGENTS_DIR/$category"
      echo "  - Removed agents/$category/"
    fi
  done
  # Remove directory if now empty
  if [ -z "$(ls -A "$AGENTS_DIR" 2>/dev/null)" ]; then
    rmdir "$AGENTS_DIR"
    echo "  - Removed .cursor/agents/ (empty)"
  fi
fi

# Remove skills (only directories marked with .lavra sentinel)
SKILLS_DIR="$TARGET/.cursor/skills"
if [ -d "$SKILLS_DIR" ]; then
  for skill_dir in "$SKILLS_DIR"/*/; do
    if [ -d "$skill_dir" ] && [ -f "$skill_dir/.lavra" ]; then
      skill_name=$(basename "$skill_dir")
      rm -rf "$skill_dir"
      echo "  - Removed skills/$skill_name/"
    fi
  done
  if [ -z "$(ls -A "$SKILLS_DIR" 2>/dev/null)" ]; then
    rmdir "$SKILLS_DIR"
    echo "  - Removed .cursor/skills/ (empty)"
  fi
fi

# Remove context7 from mcp.json (preserve other MCP servers)
MCP_JSON="$TARGET/.cursor/mcp.json"
if [ -f "$MCP_JSON" ] && command -v jq &>/dev/null; then
  if jq -e '.mcpServers["context7"]' "$MCP_JSON" &>/dev/null; then
    REMAINING=$(jq 'del(.mcpServers["context7"])' "$MCP_JSON")
    # If no MCP servers remain and the file is now effectively empty, remove it
    REMAINING_COUNT=$(echo "$REMAINING" | jq '.mcpServers | length' 2>/dev/null || echo "0")
    if [ "$REMAINING_COUNT" -eq 0 ]; then
      rm "$MCP_JSON"
      echo "  - Removed .cursor/mcp.json (context7 was the only entry)"
    else
      echo "$REMAINING" > "$MCP_JSON"
      echo "  - Removed context7 from .cursor/mcp.json"
    fi
  fi
fi

echo ""
echo "Done."
echo ""

if [ -d "$TARGET/.lavra" ]; then
  echo "Note: .lavra/ preserved (knowledge base and config retained)"
  echo ""
fi

if [ "$GLOBAL_UNINSTALL" = true ]; then
  echo "Global uninstallation complete."
else
  echo "Project-specific uninstallation complete for: $TARGET"
fi

#!/bin/bash
#
# Install lavra plugin for Cursor IDE
#
# What this installs:
#   - Hooks: auto-recall-cursor.sh (Cursor adapter), memory-capture.sh,
#     subagent-wrapup.sh, and supporting scripts
#   - Hook manifest: .cursor/hooks.json
#   - Agents: .cursor/agents/ (30 agents, 5 categories, direct copy)
#   - Knowledge store: .lavra/memory/knowledge.jsonl
#   - MCP server: .cursor/mcp.json (Context7)
#
# Requirements: Cursor v2.4 or later (earlier versions ignore sessionStart)
#
# Usage:
#   Called by install.sh -cursor [target]
#

set -euo pipefail

# Security: Set restrictive umask
umask 077

# Use marketplace root from router if available, else derive from script location
if [ -n "${BEADS_MARKETPLACE_ROOT:-}" ]; then
  SCRIPT_DIR="$BEADS_MARKETPLACE_ROOT"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
fi

PLUGIN_DIR="$SCRIPT_DIR/plugins/lavra"

# Source shared functions
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALLER_DIR/shared-functions.sh"

LAVRA_GLOBAL_DEFAULT="$HOME/.cursor"
LAVRA_HOOKS_ARE_GLOBAL=false
eval "$(parse_installer_args "$@")"
[ "$NO_BANNER" = false ] && print_banner "Cursor IDE" "0.7.1"

# Resolve to absolute path
TARGET="$(resolve_target_dir "$TARGET")"
echo "  Target: $TARGET"
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "  Type: Global installation"
else
  echo "  Type: Project-specific installation"
fi
echo ""
echo "  Note: Requires Cursor v2.4 or later (earlier versions ignore sessionStart)"
echo ""

# Security: Verify target is not a symlink
if [[ -L "$TARGET" ]]; then
  echo "[!] Error: Target directory is a symlink: $TARGET"
  echo "    This is a security risk. Please use a real directory."
  exit 1
fi

# Security: Verify ownership
TARGET_OWNER=$(stat -f%Su "$TARGET" 2>/dev/null || stat -c%U "$TARGET" 2>/dev/null)
if [[ "$TARGET_OWNER" != "$USER" ]]; then
  echo "[!] Error: Target directory is owned by a different user"
  echo "    Owner: $TARGET_OWNER"
  echo "    Current user: $USER"
  exit 1
fi

# For project installs, files go into $CURSOR_DIR/
# For global installs, TARGET is already ~/.cursor so use it directly
if [ "$GLOBAL_INSTALL" = true ]; then
  CURSOR_DIR="$TARGET"
else
  CURSOR_DIR="$TARGET/.cursor"
fi

# Step 1: Copy hooks
echo "[1/4] Installing hooks..."

HOOKS_DIR="$CURSOR_DIR/hooks"
create_dir_with_symlink_handling "$HOOKS_DIR"

# auto-recall-cursor.sh is the Cursor-specific wrapper — install it first,
# then install the canonical hooks it delegates to.
# NOTE: auto-recall-cursor.sh is Cursor-only and must NOT be copied by
# other platform installers (Claude Code, OpenCode, Gemini).
for hook in sanitize-content.sh auto-recall.sh auto-recall-cursor.sh memory-capture.sh subagent-wrapup.sh knowledge-db.sh provision-memory.sh extract-bead-context.sh; do
  cp "$PLUGIN_DIR/hooks/$hook" "$HOOKS_DIR/"
  chmod 755 "$HOOKS_DIR/$hook"
  echo "  - $hook"
done

echo ""

# Step 2: Write .cursor/hooks.json
echo "[2/4] Writing hooks manifest..."

HOOKS_JSON="$CURSOR_DIR/hooks.json"
cat > "$HOOKS_JSON" << 'EOF'
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      {
        "command": ".cursor/hooks/auto-recall-cursor.sh",
        "timeout": 30
      }
    ],
    "afterShellExecution": [
      {
        "command": ".cursor/hooks/memory-capture.sh",
        "timeout": 5
      }
    ],
    "subagentStop": [
      {
        "command": ".cursor/hooks/subagent-wrapup.sh"
      }
    ]
  }
}
EOF
chmod 644 "$HOOKS_JSON"
echo "  - .cursor/hooks.json"
echo ""

# Step 3: Copy agents (direct copy — Cursor reads .md frontmatter natively)
echo "[3/4] Installing agents..."

AGENTS_DIR="$CURSOR_DIR/agents"
for category in review research design workflow docs; do
  mkdir -p "$AGENTS_DIR/$category"
  if [ -d "$PLUGIN_DIR/agents/$category" ]; then
    find "$PLUGIN_DIR/agents/$category" -name "*.md" -exec cp {} "$AGENTS_DIR/$category/" \;
  fi
done
find "$AGENTS_DIR" -type f -exec chmod 644 {} \;

AGENT_COUNT=$(find "$AGENTS_DIR" -name "*.md" | wc -l | tr -d ' ')
echo "  - Installed $AGENT_COUNT agents (.cursor/agents/)"
echo ""

# Step 4: Provision memory system
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "[4/4] Skipping memory system (global install)"
  echo "  Memory system will be provisioned per-project on first session"
  echo ""
else
  echo "[4/4] Provisioning memory system..."

  source "$PLUGIN_DIR/hooks/provision-memory.sh"
  migrate_beads_to_lavra "$TARGET"
  provision_memory_dir "$TARGET" "$PLUGIN_DIR/hooks"

  echo "  - Memory system ready"
  echo ""
fi

# Configure MCP server (Context7 for framework documentation)
echo "[5/4] Configuring MCP servers..."

MCP_JSON="$CURSOR_DIR/mcp.json"
CONTEXT7_ENTRY='{"url":"https://mcp.context7.com/mcp","type":"http"}'

if ! command -v jq &>/dev/null; then
  echo "  [!] jq not found -- skipping MCP config (add context7 to $MCP_JSON manually)"
elif [ -f "$MCP_JSON" ] && jq -e '.mcpServers["context7"]' "$MCP_JSON" &>/dev/null; then
  echo "  - Context7 already in $MCP_JSON -- skipping"
else
  if [ -f "$MCP_JSON" ]; then
    UPDATED=$(jq --argjson c7 "$CONTEXT7_ENTRY" '.mcpServers = ((.mcpServers // {}) + {"context7": $c7})' "$MCP_JSON")
    echo "$UPDATED" > "$MCP_JSON"
    echo "  - Added Context7 to $MCP_JSON"
  else
    mkdir -p "$(dirname "$MCP_JSON")"
    printf '{"mcpServers":{"context7":%s}}\n' "$CONTEXT7_ENTRY" > "$MCP_JSON"
    chmod 644 "$MCP_JSON"
    echo "  - Created $MCP_JSON with Context7 MCP server"
  fi
fi
echo ""

# Installation complete
echo "Done."
echo ""
echo "Next steps:"
echo ""
echo "1. Hooks are active via .cursor/hooks.json"
echo "   - sessionStart: knowledge recall injected as additional_context"
echo "   - afterShellExecution: bd comments add commands captured automatically"
echo "   - subagentStop: subagent knowledge logging enforced"
echo ""
echo "2. Agents available via @agent-name in Cursor chat:"
echo "   - @architecture-strategist, @security-sentinel, @performance-oracle, ..."
echo "   - All $AGENT_COUNT lavra agents installed to .cursor/agents/"
echo ""
echo "3. Context7 MCP server configured (framework documentation lookup)"
echo ""
echo "4. Knowledge base at .lavra/memory/knowledge.jsonl"
echo "   Use: bd comments add <BEAD_ID> \"LEARNED: ...\" to log insights"
echo ""

if [ "$GLOBAL_INSTALL" = true ]; then
  echo "Global installation complete. All Cursor projects will have access to lavra agents."
else
  echo "Project-specific installation complete for: $TARGET"
fi

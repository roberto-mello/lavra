#!/bin/bash
#
# Install lavra plugin for Gemini CLI
#
# What this installs:
#   - Extension manifest (gemini-extension.json)
#   - Memory capture and auto-recall hooks
#   - Knowledge store (.lavra/memory/knowledge.jsonl)
#   - Converted commands (.toml format), agents, and skills
#   - MCP server configuration documentation
#
# Usage:
#   Called by install.sh -gemini [target]
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
# Use BASH_SOURCE to get the correct path when sourced
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALLER_DIR/shared-functions.sh"

LAVRA_GLOBAL_DEFAULT="$HOME/.config/gemini"
LAVRA_HOOKS_ARE_GLOBAL=false
eval "$(parse_installer_args "$@")"

# Resolve to absolute path
TARGET="$(resolve_target_dir "$TARGET")"

print_banner "Gemini CLI" "0.7.0"
echo "  Target: $TARGET"
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "  Type: Global installation"
else
  echo "  Type: Project-specific installation"
fi
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

# Step 1: Run conversion scripts
echo "[1/4] Converting files to Gemini CLI format..."
echo ""

# Check if Bun is available
if ! command -v bun &>/dev/null; then
  echo "[!] Error: Bun is required for Gemini CLI installation"
  echo "    Install Bun: curl -fsSL https://bun.sh/install | bash"
  exit 1
fi

# Run conversion
cd "$SCRIPT_DIR/scripts"
if ! bun run convert-gemini.ts; then
  echo "[!] Error: Conversion failed"
  exit 1
fi

echo ""

# Step 2: Copy hooks
echo "[2/4] Installing hooks..."

HOOKS_DIR="$TARGET/hooks"
create_dir_with_symlink_handling "$HOOKS_DIR"

for hook in sanitize-content.sh auto-recall.sh memory-capture.sh subagent-wrapup.sh; do
  cp "$PLUGIN_DIR/hooks/$hook" "$HOOKS_DIR/"
  chmod 755 "$HOOKS_DIR/$hook"
  echo "  - $hook"
done

echo ""

# Step 3: Copy converted files
echo "[3/4] Installing commands, agents, and skills..."

# Commands (.toml format)
COMMANDS_DIR="$TARGET/commands"
create_dir_with_symlink_handling "$COMMANDS_DIR"

find "$PLUGIN_DIR/gemini/commands" -name "*.toml" -exec cp {} "$COMMANDS_DIR/" \;
find "$COMMANDS_DIR" -type f -exec chmod 644 {} \;

echo "  - Installed $(find "$PLUGIN_DIR/gemini/commands" -name "*.toml" | wc -l | tr -d ' ') commands (.toml)"

# Agents
AGENTS_DIR="$TARGET/agents"
create_dir_with_symlink_handling "$AGENTS_DIR"

for category in review research design workflow docs; do
  mkdir -p "$AGENTS_DIR/$category"
  if [ -d "$PLUGIN_DIR/gemini/agents/$category" ]; then
    find "$PLUGIN_DIR/gemini/agents/$category" -name "*.md" -exec cp {} "$AGENTS_DIR/$category/" \;
  fi
done

find "$AGENTS_DIR" -type f -exec chmod 644 {} \;

echo "  - Installed $(find "$PLUGIN_DIR/gemini/agents" -name "*.md" | wc -l | tr -d ' ') agents"

# Skills
SKILLS_DIR="$TARGET/skills"
mkdir -p "$SKILLS_DIR"

for skill_dir in "$PLUGIN_DIR/gemini/skills"/*; do
  if [ -d "$skill_dir" ]; then
    skill_name=$(basename "$skill_dir")
    mkdir -p "$SKILLS_DIR/$skill_name"
    cp "$skill_dir/SKILL.md" "$SKILLS_DIR/$skill_name/" 2>/dev/null || true
    chmod 444 "$SKILLS_DIR/$skill_name/SKILL.md" 2>/dev/null || true
  fi
done

echo "  - Installed $(find "$PLUGIN_DIR/gemini/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') skills"
echo ""

# Step 4: Provision memory (only for project-specific installs)
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "[4/4] Skipping memory system (global install)"
  echo "  Memory system will be provisioned per-project when using Gemini CLI"
  echo ""
else
  echo "[4/4] Provisioning memory system..."

  source "$PLUGIN_DIR/hooks/provision-memory.sh"
  migrate_beads_to_lavra "$TARGET"
  provision_memory_dir "$TARGET" "$PLUGIN_DIR/hooks"

  echo "  - Memory system ready"
  echo ""
fi

# Configure MCP servers
echo "[5/4] Configuring MCP servers..."

GEMINI_CONFIG="$HOME/.config/gemini/settings.json"
if ! command -v jq &>/dev/null; then
  echo "  [!] jq not found -- skipping MCP config (add context7 to $GEMINI_CONFIG manually)"
elif [ -f "$GEMINI_CONFIG" ] && jq -e '.mcpServers["context7"]' "$GEMINI_CONFIG" &>/dev/null; then
  echo "  - Context7 already in $GEMINI_CONFIG -- skipping"
else
  CONTEXT7_ENTRY='{"url":"https://mcp.context7.com/mcp","type":"http"}'
  if [ -f "$GEMINI_CONFIG" ]; then
    UPDATED=$(jq --argjson c7 "$CONTEXT7_ENTRY" '.mcpServers = ((.mcpServers // {}) + {"context7": $c7})' "$GEMINI_CONFIG")
    echo "$UPDATED" > "$GEMINI_CONFIG"
    echo "  - Added Context7 to $GEMINI_CONFIG"
  else
    mkdir -p "$(dirname "$GEMINI_CONFIG")"
    printf '{"mcpServers":{"context7":%s}}\n' "$CONTEXT7_ENTRY" > "$GEMINI_CONFIG"
    echo "  - Created $GEMINI_CONFIG with Context7 MCP server"
  fi
fi
echo ""

# Installation complete
echo "Done."
echo ""
echo "Next steps:"
echo ""
echo "1. Configure hooks in settings.json:"
echo "   See: $PLUGIN_DIR/gemini-src/settings.json for hook configuration"
echo ""
echo "2. Context7 MCP server configured (framework documentation lookup)"
echo ""
echo "3. Commands are available as slash commands:"
echo "   - /lavra-plan, /lavra-work, /lavra-review, etc."
echo ""

if [ "$GLOBAL_INSTALL" = true ]; then
  echo "Global installation complete. All Gemini CLI projects will have access to the plugin."
else
  echo "Project-specific installation complete for: $TARGET"
fi

#!/bin/bash
#
# Install beads-compound plugin for OpenCode
#
# What this installs:
#   - TypeScript plugin (plugin.ts) for hook integration
#   - Memory capture and auto-recall hooks
#   - Knowledge store (.beads/memory/knowledge.jsonl)
#   - Converted commands, agents, and skills
#   - MCP server configuration documentation
#
# Usage:
#   Called by install.sh -opencode [target]
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

PLUGIN_DIR="$SCRIPT_DIR/plugins/beads-compound"

# Source shared functions
# Use BASH_SOURCE to get the correct path when sourced
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALLER_DIR/shared-functions.sh"

# Parse --yes/-y flag (skip confirmation prompts)
AUTO_YES=false
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --yes|-y) AUTO_YES=true ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

# Default to ~/.config/opencode if no positional argument provided
if [ ${#POSITIONAL_ARGS[@]} -eq 0 ]; then
  TARGET="$HOME/.config/opencode"
  GLOBAL_INSTALL=true
else
  TARGET="${POSITIONAL_ARGS[0]}"
  GLOBAL_INSTALL=false
fi

# Resolve to absolute path
TARGET="$(resolve_target_dir "$TARGET")"

echo "beads-compound OpenCode Installer"
echo ""
echo "Target: $TARGET"
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "Type: Global installation"
else
  echo "Type: Project-specific installation"
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

# Step 1: Model selection (interactive unless --yes)
if [ "$AUTO_YES" = false ] && command -v opencode &>/dev/null; then
  echo "[1/6] Model selection..."
  echo ""
  echo "Would you like to customize model selections for each tier?"
  echo "(haiku/sonnet/opus)"
  echo ""
  read -p "Customize models? (y/N): " customize

  if [[ "$customize" =~ ^[Yy]$ ]]; then
    if ! "$SCRIPT_DIR/scripts/select-opencode-models.sh"; then
      echo "[!] Warning: Model selection failed, using defaults"
    fi
    echo ""
  fi
else
  echo "[1/6] Using default model configuration..."
  echo ""
fi

# Step 2: Run conversion scripts
echo "[2/6] Converting files to OpenCode format..."
echo ""

# Check if Bun is available
if ! command -v bun &>/dev/null; then
  echo "[!] Error: Bun is required for OpenCode installation"
  echo "    Install Bun: curl -fsSL https://bun.sh/install | bash"
  exit 1
fi

# Run conversion (with flag to suppress standalone instructions)
cd "$SCRIPT_DIR/scripts"
if ! BEADS_INSTALLING=1 bun run convert-opencode.ts; then
  echo "[!] Error: Conversion failed"
  exit 1
fi

echo ""

# Step 3: Install TypeScript plugin
echo "[3/6] Installing TypeScript plugin..."

# Determine plugin directory: global uses $TARGET/plugins, project uses $TARGET/.opencode/plugins
if [ "$GLOBAL_INSTALL" = true ]; then
  PLUGINS_DIR="$TARGET/plugins/beads-compound"
else
  PLUGINS_DIR="$TARGET/.opencode/plugins/beads-compound"
fi

create_dir_with_symlink_handling "$PLUGINS_DIR"

cp "$PLUGIN_DIR/opencode-src/plugin.ts" "$PLUGINS_DIR/"
cp "$PLUGIN_DIR/opencode-src/package.json" "$PLUGINS_DIR/"

# Set permissions
chmod 644 "$PLUGINS_DIR/plugin.ts"
chmod 644 "$PLUGINS_DIR/package.json"

echo "  - Installed plugin.ts and package.json"

# Install plugin dependencies
cd "$PLUGINS_DIR"
if ! bun install --frozen-lockfile 2>/dev/null; then
  echo "  - Frozen lockfile not found, running regular install..."
  bun install
fi

echo "  - Installed plugin dependencies"
echo ""

# Step 4: Copy hooks
echo "[4/6] Installing hooks..."

# Determine base directory: global uses $TARGET directly, project uses $TARGET/.opencode
if [ "$GLOBAL_INSTALL" = true ]; then
  HOOKS_DIR="$TARGET/hooks"
else
  HOOKS_DIR="$TARGET/.opencode/hooks"
fi

create_dir_with_symlink_handling "$HOOKS_DIR"

for hook in auto-recall.sh memory-capture.sh subagent-wrapup.sh; do
  cp "$PLUGIN_DIR/hooks/$hook" "$HOOKS_DIR/"
  chmod 755 "$HOOKS_DIR/$hook"
  echo "  - $hook"
done

echo ""

# Step 5: Copy converted files
echo "[5/6] Installing commands, agents, and skills..."

# Determine base directory: global uses $TARGET directly, project uses $TARGET/.opencode
if [ "$GLOBAL_INSTALL" = true ]; then
  BASE_DIR="$TARGET"
else
  BASE_DIR="$TARGET/.opencode"
fi

# Commands
COMMANDS_DIR="$BASE_DIR/commands"
create_dir_with_symlink_handling "$COMMANDS_DIR"

find "$PLUGIN_DIR/opencode/commands" -name "*.md" -exec cp {} "$COMMANDS_DIR/" \;
find "$COMMANDS_DIR" -type f -exec chmod 644 {} \;

echo "  - Installed $(find "$PLUGIN_DIR/opencode/commands" -name "*.md" | wc -l | tr -d ' ') commands"

# Agents
AGENTS_DIR="$BASE_DIR/agents"
create_dir_with_symlink_handling "$AGENTS_DIR"

for category in review research design workflow docs; do
  mkdir -p "$AGENTS_DIR/$category"
  if [ -d "$PLUGIN_DIR/opencode/agents/$category" ]; then
    find "$PLUGIN_DIR/opencode/agents/$category" -name "*.md" -exec cp {} "$AGENTS_DIR/$category/" \;
  fi
done

find "$AGENTS_DIR" -type f -exec chmod 644 {} \;

echo "  - Installed $(find "$PLUGIN_DIR/opencode/agents" -name "*.md" | wc -l | tr -d ' ') agents"

# Skills
SKILLS_DIR="$BASE_DIR/skills"
create_dir_with_symlink_handling "$SKILLS_DIR"

for skill_dir in "$PLUGIN_DIR/opencode/skills"/*; do
  if [ -d "$skill_dir" ]; then
    skill_name=$(basename "$skill_dir")
    mkdir -p "$SKILLS_DIR/$skill_name"
    cp "$skill_dir/SKILL.md" "$SKILLS_DIR/$skill_name/" 2>/dev/null || true
    chmod 444 "$SKILLS_DIR/$skill_name/SKILL.md" 2>/dev/null || true
  fi
done

echo "  - Installed $(find "$PLUGIN_DIR/opencode/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') skills"
echo ""

# Step 6: Provision memory (only for project-specific installs)
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "[6/6] Skipping memory system (global install)"
  echo "  Memory system will be provisioned per-project when using OpenCode"
  echo ""
else
  echo "[6/6] Provisioning memory system..."

  source "$PLUGIN_DIR/hooks/provision-memory.sh"
  provision_memory_dir "$TARGET" "$PLUGIN_DIR/hooks"

  echo "  - Memory system ready"
  echo ""
fi

# Installation complete
echo "Done."
echo ""
echo "Next steps:"
echo ""
echo "1. Configure MCP servers (optional):"
echo "   See: $PLUGIN_DIR/opencode/docs/MCP_SETUP.md"
echo ""
echo "2. The TypeScript plugin will automatically load on next OpenCode session"
echo ""
echo "3. Commands are available via Ctrl+K:"
echo "   - beads-plan, beads-work, beads-review, etc."
echo ""

if [ "$GLOBAL_INSTALL" = true ]; then
  echo "Global installation complete. All OpenCode projects will have access to the plugin."
else
  echo "Project-specific installation complete for: $TARGET"
fi

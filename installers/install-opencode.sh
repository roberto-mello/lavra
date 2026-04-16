#!/bin/bash
#
# Install lavra plugin for OpenCode
#
# What this installs:
#   - TypeScript plugin (plugin.ts) for hook integration
#   - Memory capture and auto-recall hooks
#   - Knowledge store (.lavra/memory/knowledge.jsonl)
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

PLUGIN_DIR="$SCRIPT_DIR/plugins/lavra"

# Source shared functions
# Use BASH_SOURCE to get the correct path when sourced
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALLER_DIR/shared-functions.sh"

LAVRA_GLOBAL_DEFAULT="$HOME/.config/opencode"
LAVRA_HOOKS_ARE_GLOBAL=false
eval "$(parse_installer_args "$@")"
[ "$NO_BANNER" = false ] && print_banner "OpenCode" "0.7.4"

# Resolve to absolute path
TARGET="$(resolve_target_dir "$TARGET")"
MANIFEST_FILE="$TARGET/.lavra/.lavra-manifest"
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

# Dependency check: jq is required for model selection and MCP config
if ! command -v jq &>/dev/null; then
  echo "[!] Error: jq is required for OpenCode installation"
  echo "    Install jq:"
  echo "      macOS:  brew install jq"
  echo "      Ubuntu: sudo apt-get install jq"
  echo "      Other:  https://jqlang.github.io/jq/download/"
  exit 1
fi

# Step 1: Model selection (interactive unless --yes or non-interactive)
if [ "$AUTO_YES" = false ] && [[ -t 0 ]] && command -v opencode &>/dev/null; then
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

# Install conversion dependencies (js-yaml) if needed
cd "$SCRIPT_DIR/scripts"
if [ ! -d "node_modules/js-yaml" ]; then
  echo "  Installing conversion dependencies..."
  bun install --frozen-lockfile 2>/dev/null || bun install
fi

# Run conversion (with flag to suppress standalone instructions)
if ! BEADS_INSTALLING=1 bun run convert-opencode.ts; then
  echo "[!] Error: Conversion failed"
  exit 1
fi

echo ""

# Step 3: Install TypeScript plugin
echo "[3/6] Installing TypeScript plugin..."

# Determine plugin directory: global uses $TARGET/plugins, project uses $TARGET/.opencode/plugins
if [ "$GLOBAL_INSTALL" = true ]; then
  PLUGINS_DIR="$TARGET/plugins/lavra"
else
  PLUGINS_DIR="$TARGET/.opencode/plugins/lavra"
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

for hook in sanitize-content.sh auto-recall.sh memory-capture.sh subagent-wrapup.sh extract-bead-context.sh; do
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

begin_manifest "$MANIFEST_FILE"

# Commands
COMMANDS_DIR="$BASE_DIR/commands"
create_dir_with_symlink_handling "$COMMANDS_DIR"

CMD_COUNT=$(sync_flat_dir "$PLUGIN_DIR/opencode/commands" "$COMMANDS_DIR" "$MANIFEST_FILE" "commands")
find "$COMMANDS_DIR" -type f -exec chmod 644 {} \;
echo "  - Installed $CMD_COUNT commands"

# Agents
AGENTS_DIR="$BASE_DIR/agents"
create_dir_with_symlink_handling "$AGENTS_DIR"

AGENT_COUNT=$(sync_nested_dir "$PLUGIN_DIR/opencode/agents" "$AGENTS_DIR" "$MANIFEST_FILE" "agents")
find "$AGENTS_DIR" -type f -exec chmod 644 {} \;
echo "  - Installed $AGENT_COUNT agents"

# Skills
SKILLS_DIR="$BASE_DIR/skills"
create_dir_with_symlink_handling "$SKILLS_DIR"

source_skill_list_oc=""
SKILL_COUNT=0
for skill_dir in "$PLUGIN_DIR/opencode/skills"/*; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  source_skill_list_oc="${source_skill_list_oc}${skill_name}"$'\n'
  cp -r "$skill_dir" "$SKILLS_DIR/$skill_name"
  chmod 644 "$SKILLS_DIR/$skill_name/SKILL.md" 2>/dev/null || true
  printf 'skills:%s\n' "$skill_name" >> "${MANIFEST_FILE}.new"
  SKILL_COUNT=$((SKILL_COUNT + 1))
done

# Remove stale skill dirs
if [ -f "$MANIFEST_FILE" ]; then
  while IFS= read -r line; do
    [[ "$line" == "skills:"* ]] || continue
    stale_skill="${line#skills:}"
    if ! printf '%s' "$source_skill_list_oc" | grep -qxF "$stale_skill" \
       && [ -d "$SKILLS_DIR/$stale_skill" ]; then
      rm -rf "$SKILLS_DIR/$stale_skill"
      echo "  - Removed stale skill: $stale_skill"
    fi
  done < "$MANIFEST_FILE"
fi

echo "  - Installed $SKILL_COUNT skills"
echo ""

commit_manifest "$MANIFEST_FILE"

# Step 6: Provision memory (only for project-specific installs)
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "[6/6] Skipping memory system (global install)"
  echo "  Memory system will be provisioned per-project when using OpenCode"
  echo ""
else
  echo "[6/6] Provisioning memory system..."

  source "$PLUGIN_DIR/hooks/provision-memory.sh"
  migrate_beads_to_lavra "$TARGET"
  provision_memory_dir "$TARGET" "$PLUGIN_DIR/hooks"

  echo "  - Memory system ready"
  echo ""
fi

# Configure MCP servers
echo "[7/6] Configuring MCP servers..."

OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"
if [ -f "$OPENCODE_CONFIG" ] && jq -e '.mcp["context7"]' "$OPENCODE_CONFIG" &>/dev/null; then
  echo "  - Context7 already in $OPENCODE_CONFIG -- skipping"
else
  CONTEXT7_ENTRY='{"type":"remote","url":"https://mcp.context7.com/mcp"}'
  if [ -f "$OPENCODE_CONFIG" ]; then
    UPDATED=$(jq --argjson c7 "$CONTEXT7_ENTRY" '.mcp = ((.mcp // {}) + {"context7": $c7})' "$OPENCODE_CONFIG")
    echo "$UPDATED" > "$OPENCODE_CONFIG"
    echo "  - Added Context7 to $OPENCODE_CONFIG"
  else
    mkdir -p "$(dirname "$OPENCODE_CONFIG")"
    printf '{"mcp":{"context7":%s}}\n' "$CONTEXT7_ENTRY" > "$OPENCODE_CONFIG"
    echo "  - Created $OPENCODE_CONFIG with Context7 MCP server"
  fi
fi
echo ""

# Installation complete
echo "Done."
echo ""
echo "Main workflow:"
echo "  /lavra-design <feature description>   Plan a feature end-to-end before writing code"
echo "  /lavra-work <bead id>                 Execute work on a bead"
echo "  /lavra-qa                             Browser-based QA verification (web apps)"
echo "  /lavra-ship                           Finalize, open PR, close beads"
echo ""
echo "Restart OpenCode to load the plugin."
echo ""

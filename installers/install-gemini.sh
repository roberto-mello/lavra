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
INSTALLER_VERSION=$(get_lavra_version "$PLUGIN_DIR")
[ "$NO_BANNER" = false ] && print_banner "Gemini CLI" "$INSTALLER_VERSION"

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

# Check .beads exists (skip for global install)
if [ "$GLOBAL_INSTALL" != true ]; then
  if [ ! -d "$TARGET/.beads" ]; then
    echo "[!] No .beads directory found in $TARGET."
    echo ""
    echo "    Run this first:"
    echo "      cd $TARGET && bd init"
    echo ""
    exit 1
  fi
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

# Install conversion dependencies (js-yaml) if needed
cd "$SCRIPT_DIR/scripts"
if [ ! -d "node_modules/js-yaml" ]; then
  echo "  Installing conversion dependencies..."
  bun install --frozen-lockfile 2>/dev/null || bun install
fi

# Run conversion
if ! bun run convert-gemini.ts; then
  echo "[!] Error: Conversion failed"
  exit 1
fi

echo ""

# Step 2: Copy hooks
echo "[2/4] Installing hooks..."

HOOKS_DIR="$TARGET/hooks"
create_dir_with_symlink_handling "$HOOKS_DIR"

for hook in sanitize-content.sh auto-recall.sh memory-capture.sh subagent-wrapup.sh memory-sanitize.sh extract-bead-context.sh; do
  cp "$PLUGIN_DIR/hooks/$hook" "$HOOKS_DIR/"
  chmod 755 "$HOOKS_DIR/$hook"
  echo "  - $hook"
done
if [[ -d "$PLUGIN_DIR/hooks/memorysanitize" ]]; then
  rm -rf "$HOOKS_DIR/memorysanitize"
  cp -R "$PLUGIN_DIR/hooks/memorysanitize" "$HOOKS_DIR/memorysanitize"
  echo "  - memorysanitize/"
fi

# Write version marker for hook auto-update
echo "$INSTALLER_VERSION" > "$HOOKS_DIR/.lavra-version"

echo ""

# Detect if commands/agents/skills are already installed globally
GLOBALLY_INSTALLED=false
if [ "$GLOBAL_INSTALL" = false ] && [ -f "$HOME/.config/gemini/commands/lavra-plan.toml" ]; then
  GLOBALLY_INSTALLED=true
fi

# Version check: if global is current, per-project install is hook-only
GLOBAL_VERSION="0.0.0"
if [ -f "$HOME/.config/gemini/hooks/.lavra-version" ]; then
  GLOBAL_VERSION=$(cat "$HOME/.config/gemini/hooks/.lavra-version")
fi

LIGHTWEIGHT_MODE=false
if [ "$GLOBAL_INSTALL" = false ] && [ "$GLOBALLY_INSTALLED" = true ] && [ "$GLOBAL_VERSION" = "$INSTALLER_VERSION" ]; then
  LIGHTWEIGHT_MODE=true
  echo ""
  echo "[i] Global install v${INSTALLER_VERSION} is current — lightweight project sync"
  echo "    Updating hooks only. Commands, agents, and skills stay global."
  echo ""
fi

if [ "$GLOBAL_INSTALL" = false ] && [ "$GLOBALLY_INSTALLED" = true ] && [ "$GLOBAL_VERSION" != "$INSTALLER_VERSION" ]; then
  echo ""
  echo "[!] Version mismatch: global install is v${GLOBAL_VERSION}, this installer is v${INSTALLER_VERSION}"
  echo "    Global commands/agents/skills are outdated. Options:"
  echo "      1) Update global first (recommended), then re-run this installer"
  echo "      2) Install full copy into this project anyway"
  echo "      3) Skip commands/agents/skills, update hooks only"
  echo ""
  if [ "$AUTO_YES" = true ]; then
    echo "    --yes set: defaulting to option 3 (hooks only)"
    CHOICE=3
  elif [ -t 0 ]; then
    read -r -p "  Choose [1/2/3, default: 1]: " CHOICE </dev/tty
  else
    CHOICE=1
  fi
  case "$CHOICE" in
    2)
      GLOBALLY_INSTALLED=false
      ;;
    3)
      LIGHTWEIGHT_MODE=true
      ;;
    *)
      echo ""
      echo "  Run global update first:"
      echo "    bunx @lavralabs/lavra@latest --gemini"
      echo ""
      exit 0
      ;;
  esac
fi

# Step 3: Copy converted files
if [ "$LIGHTWEIGHT_MODE" = true ]; then
  echo "[3/4] Skipping commands, agents, and skills (global install is current)"
  CMD_COUNT=0
  AGENT_COUNT=0
  SKILL_COUNT=0
else
  echo "[3/4] Installing commands, agents, and skills..."

  begin_manifest "$MANIFEST_FILE"

  # Commands (.toml format)
  COMMANDS_DIR="$TARGET/commands"
  create_dir_with_symlink_handling "$COMMANDS_DIR"

  CMD_COUNT=$(sync_flat_dir "$PLUGIN_DIR/gemini/commands" "$COMMANDS_DIR" "$MANIFEST_FILE" "commands" "*.toml")
  find "$COMMANDS_DIR" -type f -exec chmod 644 {} \;
  echo "  - Installed $CMD_COUNT commands (.toml)"

  # Agents
  AGENTS_DIR="$TARGET/agents"
  create_dir_with_symlink_handling "$AGENTS_DIR"

  AGENT_COUNT=$(sync_nested_dir "$PLUGIN_DIR/gemini/agents" "$AGENTS_DIR" "$MANIFEST_FILE" "agents")
  find "$AGENTS_DIR" -type f -exec chmod 644 {} \;
  echo "  - Installed $AGENT_COUNT agents"

  # Skills
  SKILLS_DIR="$TARGET/skills"
  mkdir -p "$SKILLS_DIR"

  source_skill_list_gm=""
  SKILL_COUNT=0
  for skill_dir in "$PLUGIN_DIR/gemini/skills"/*; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    source_skill_list_gm="${source_skill_list_gm}${skill_name}"$'\n'
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
      if ! printf '%s' "$source_skill_list_gm" | grep -qxF "$stale_skill" \
         && [ -d "$SKILLS_DIR/$stale_skill" ]; then
        rm -rf "$SKILLS_DIR/$stale_skill"
        echo "  - Removed stale skill: $stale_skill"
      fi
    done < "$MANIFEST_FILE"
  fi

  echo "  - Installed $SKILL_COUNT skills"
  echo ""

  commit_manifest "$MANIFEST_FILE"
fi

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
if ! command -v sqlite3 &>/dev/null; then
  echo "[!] sqlite3 not found. Memory recall will use JSONL linear search (slower)."
  echo "    Install sqlite3 for optimal recall performance:"
  echo "      macOS:  brew install sqlite"
  echo "      Ubuntu: sudo apt-get install sqlite3"
  echo ""
fi

echo "Done."
echo ""

if [ "$GLOBAL_INSTALL" = true ]; then
  echo "Commands, agents, and skills are now available in all Gemini CLI sessions."
  echo ""
  echo "For beads integration (memory system + hooks):"
  echo "  bunx @lavralabs/lavra@latest --gemini /path/to/your-project"
  echo ""
else
  if [ "$LIGHTWEIGHT_MODE" = true ]; then
    echo "Hooks updated. Commands, agents, and skills remain global (v${INSTALLER_VERSION})."
    echo ""
  else
    echo "$CMD_COUNT commands, $AGENT_COUNT agents, and $SKILL_COUNT skills installed."
    echo ""
  fi
  echo "Context7 MCP server added (framework docs on demand)."
  echo ""
  echo "Main workflow:"
  echo "  /lavra-design <feature description>   Plan a feature end-to-end before writing code"
  echo "  /lavra-work <bead id>                 Execute work on a bead"
  echo "  /lavra-qa                             Browser-based QA verification (web apps)"
  echo "  /lavra-ship                           Finalize, open PR, close beads"
  echo ""
fi

echo "Restart Gemini CLI to load the plugin."
echo ""

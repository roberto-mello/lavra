#!/bin/bash
#
# Install lavra plugin into a project
#
# What this installs:
#   - Memory capture and auto-recall hooks
#   - Knowledge store (.lavra/memory/knowledge.jsonl)
#   - Recall script (.lavra/memory/recall.sh)
#   - Beads-aware workflow commands (24 core commands)
#   - Specialized agents (29 agent definitions)
#   - Skills (16 skills including git-worktree, brainstorming, etc.)
#   - MCP server configuration (Context7)
#
# Usage:
#   Global installation (recommended):
#     ./install.sh                          # installs to ~/.claude
#
#   Project-specific installation:
#     ./install.sh /path/to/your-project
#
#   From anywhere:
#     bash /path/to/lavra/install.sh
#     bash /path/to/lavra/install.sh /path/to/your-project
#

set -euo pipefail

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

LAVRA_GLOBAL_DEFAULT="$HOME/.claude"
LAVRA_HOOKS_ARE_GLOBAL=false
eval "$(parse_installer_args "$@")"
INSTALLER_VERSION=$(get_lavra_version "$PLUGIN_DIR")
[ "$NO_BANNER" = false ] && print_banner "Claude Code" "$INSTALLER_VERSION"

# Resolve target to absolute path
TARGET="$(resolve_target_dir "$TARGET")"
MANIFEST_FILE="$TARGET/.lavra/.lavra-manifest"

# Detect if user is trying to install into the plugin directory itself
if [[ "$TARGET" == "$SCRIPT_DIR" || "$TARGET" == "$PLUGIN_DIR" ]]; then
  echo "[!] Error: Cannot install plugin into itself."
  echo ""
  echo "    You're trying to install into: $TARGET"
  echo "    This is the plugin source directory, not a project."
  echo ""
  echo "    Usage:"
  echo "      ./install.sh                      # global install to ~/.claude"
  echo "      ./install.sh /path/to/project     # project-specific install"
  echo ""
  exit 1
fi

# Verify plugin directory exists
if [ ! -d "$PLUGIN_DIR" ]; then
  echo "[!] Error: Plugin directory not found at $PLUGIN_DIR"
  echo "    Expected marketplace structure with plugins/lavra/"
  exit 1
fi
echo "  Plugin: $PLUGIN_DIR"
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "  Target: $TARGET (global)"
else
  echo "  Target: $TARGET (project-specific)"
fi
echo ""

# Global install: warn about memory features and confirm
if [ "$GLOBAL_INSTALL" = true ] && [ "$AUTO_YES" = false ]; then
  echo "[!] Note: Global install provides commands, agents, and skills everywhere,"
  echo "    but memory features (auto-recall, knowledge capture) require per-project"
  echo "    setup. Run /lavra-setup once in each project to configure stack,"
  echo "    review agents, and workflow settings."
  echo ""
  read -r -p "    Continue? [Y/n] " response
  case "$response" in
    [nN]|[nN][oO])
      echo "Aborted."
      exit 0
      ;;
  esac
  echo ""
fi

# Check for bd (skip for global install)
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "[1/9] Skipping bd check (global install)"
  echo "[2/9] Skipping .beads init (global install)"
else
  if ! command -v bd &>/dev/null; then
    echo "[!] beads CLI (bd) not found."
    echo ""
    echo "    Install it first:"
    echo "      macOS:  brew install steveyegge/beads/bd"
    echo "      npm:    npm install -g @beads/bd"
    echo "      go:     go install github.com/steveyegge/beads/cmd/bd@latest"
    echo ""
    exit 1
  fi

  echo "[1/9] bd found: $(which bd)"

  # Check .beads exists
  if [ ! -d "$TARGET/.beads" ]; then
    echo "[!] No .beads directory found in $TARGET."
    echo ""
    echo "    Run this first:"
    echo "      cd $TARGET && bd init"
    echo ""
    exit 1
  else
    echo "[2/9] .beads already exists"
  fi
fi

# Set up memory directory and recall script (skip for global install)
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "[3/9] Skipping memory system (global install)"
else
  echo "[3/9] Setting up memory system..."

  PROVISION_SCRIPT="$PLUGIN_DIR/hooks/provision-memory.sh"

  if [ -f "$PROVISION_SCRIPT" ]; then
    source "$PROVISION_SCRIPT"
    migrate_beads_to_lavra "$TARGET"
    provision_memory_dir "$TARGET" "$PLUGIN_DIR/hooks"
    echo "  - Memory system configured"
  fi

  # Nudge toward /lavra-setup (skip if --yes or --quiet)
  if [ "$AUTO_YES" = false ] && [ "$QUIET" = false ] && [ -t 0 ]; then
    echo ""
    echo "  Run /lavra-setup to configure stack, review agents, and workflow"
    echo "  settings for this project. Takes about 1 minute."
    echo ""
  fi
fi

# Install hooks (only for project-specific installs)
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "[4/9] Skipping hooks (use project-specific install for beads integration)"
else
  echo "[4/9] Installing hooks..."

  HOOKS_DIR="$TARGET/.claude/hooks"
  create_dir_with_symlink_handling "$HOOKS_DIR"

  for hook in sanitize-content.sh memory-capture.sh auto-recall.sh subagent-wrapup.sh memory-sanitize.sh knowledge-db.sh provision-memory.sh extract-bead-context.sh; do
    cp "$PLUGIN_DIR/hooks/$hook" "$HOOKS_DIR/$hook"
    chmod +x "$HOOKS_DIR/$hook"
    echo "  - Installed $hook"
  done
  if [[ -d "$PLUGIN_DIR/hooks/memorysanitize" ]]; then
    rm -rf "$HOOKS_DIR/memorysanitize"
    cp -R "$PLUGIN_DIR/hooks/memorysanitize" "$HOOKS_DIR/memorysanitize"
    echo "  - Installed memorysanitize/"
  fi

  # Write version marker so check-memory.sh can detect future updates
  INSTALLER_VERSION=$(get_lavra_version "$PLUGIN_DIR")
  echo "$INSTALLER_VERSION" > "$HOOKS_DIR/.lavra-version"
fi

# Detect if commands/agents/skills are already installed globally
GLOBALLY_INSTALLED=false

if [ "$GLOBAL_INSTALL" = false ] && [ -f "$HOME/.claude/commands/lavra-plan.md" ]; then
  GLOBALLY_INSTALLED=true
fi

# Version check: if global is current, per-project install is hook-only
INSTALLER_VERSION=$(get_lavra_version "$PLUGIN_DIR")
GLOBAL_VERSION="0.0.0"
if [ -f "$HOME/.claude/hooks/.lavra-version" ]; then
  GLOBAL_VERSION=$(cat "$HOME/.claude/hooks/.lavra-version")
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
      echo "    bunx @lavralabs/lavra@latest"
      echo ""
      exit 0
      ;;
  esac
fi

# Start manifest for tracking installed files (enables stale cleanup on upgrade).
# Skip if globally installed (lightweight or full global).
if [ "$GLOBALLY_INSTALLED" = false ]; then
  begin_manifest "$MANIFEST_FILE"
fi

# Install commands (all from commands directory)
echo "[5/9] Installing workflow commands..."

if [ "$GLOBALLY_INSTALLED" = true ]; then
  CMD_COUNT=0
  echo "  - Already installed globally -- skipping"
else
  if [ "$GLOBAL_INSTALL" = true ]; then
    COMMANDS_DIR="$TARGET/commands"
  else
    COMMANDS_DIR="$TARGET/.claude/commands"
  fi
  create_dir_with_symlink_handling "$COMMANDS_DIR"

  CMD_COUNT=$(sync_flat_dir "$PLUGIN_DIR/commands" "$COMMANDS_DIR" "$MANIFEST_FILE" "commands")
  echo "  - Installed $CMD_COUNT commands"
fi

# Install agents
echo "[6/9] Installing agents..."

if [ "$GLOBALLY_INSTALLED" = true ]; then
  AGENT_COUNT=0
  echo "  - Already installed globally -- skipping"
else
  if [ "$GLOBAL_INSTALL" = true ]; then
    AGENTS_DIR="$TARGET/agents"
  else
    AGENTS_DIR="$TARGET/.claude/agents"
  fi
  mkdir -p "$AGENTS_DIR"

  AGENT_COUNT=$(sync_nested_dir "$PLUGIN_DIR/agents" "$AGENTS_DIR" "$MANIFEST_FILE" "agents")
  echo "  - Installed $AGENT_COUNT agents"
fi

# Install skills
echo "[7/9] Installing skills..."

SKILL_COUNT=0
SKILL_SKIPPED=0

if [ "$GLOBALLY_INSTALLED" = true ]; then
  echo "  - Already installed globally -- skipping"
else
  if [ "$GLOBAL_INSTALL" = true ]; then
    SKILLS_DIR="$TARGET/skills"
  else
    SKILLS_DIR="$TARGET/.claude/skills"
  fi
  mkdir -p "$SKILLS_DIR"

  # Build newline-delimited list of source skill names for stale detection
  source_skill_list=""
  if [ -d "$PLUGIN_DIR/skills" ]; then
    for skill_dir in "$PLUGIN_DIR/skills"/*/; do
      [ -d "$skill_dir" ] || continue
      skill_name=$(basename "$skill_dir")
      source_skill_list="${source_skill_list}${skill_name}"$'\n'

      if [ -L "$SKILLS_DIR/$skill_name" ]; then
        echo "  - Skipped $skill_name (symlink, not ours)"
        SKILL_SKIPPED=$((SKILL_SKIPPED + 1))
        continue
      elif [ -d "$SKILLS_DIR/$skill_name" ]; then
        if [ -f "$SKILLS_DIR/$skill_name/.lavra" ]; then
          rm -rf "$SKILLS_DIR/$skill_name"
        else
          echo "  - Skipped $skill_name (already exists, not ours)"
          SKILL_SKIPPED=$((SKILL_SKIPPED + 1))
          continue
        fi
      fi

      cp -r "$skill_dir" "$SKILLS_DIR/$skill_name"
      touch "$SKILLS_DIR/$skill_name/.lavra"
      printf 'skills:%s\n' "$skill_name" >> "${MANIFEST_FILE}.new"
      SKILL_COUNT=$((SKILL_COUNT + 1))
    done
  fi

  # Remove stale skill dirs: previously installed but no longer in source
  if [ -f "$MANIFEST_FILE" ]; then
    while IFS= read -r line; do
      [[ "$line" == "skills:"* ]] || continue
      stale_skill="${line#skills:}"
      if ! printf '%s' "$source_skill_list" | grep -qxF "$stale_skill" \
         && [ -d "$SKILLS_DIR/$stale_skill" ] && [ -f "$SKILLS_DIR/$stale_skill/.lavra" ]; then
        rm -rf "$SKILLS_DIR/$stale_skill"
        echo "  - Removed stale skill: $stale_skill"
      fi
    done < "$MANIFEST_FILE"
  fi

  echo "  - Installed $SKILL_COUNT skills"
  if [ "$SKILL_SKIPPED" -gt 0 ]; then
    echo "  - Skipped $SKILL_SKIPPED existing skill(s) not managed by this plugin"
  fi
fi

# Install MCP configuration
echo "[8/9] Configuring MCP servers..."

if [ "$GLOBAL_INSTALL" = true ]; then
  # Global install: merge into ~/.claude.json (user-level MCP config)
  CLAUDE_JSON="$HOME/.claude.json"
  if ! command -v jq &>/dev/null; then
    echo "  [!] jq not found -- skipping MCP config (add context7 to ~/.claude.json manually)"
  elif [ -f "$CLAUDE_JSON" ] && jq -e '.mcpServers["context7"]' "$CLAUDE_JSON" &>/dev/null; then
    echo "  - Context7 already in ~/.claude.json -- skipping"
  else
    CONTEXT7_ENTRY='{"type":"http","url":"https://mcp.context7.com/mcp"}'
    if [ -f "$CLAUDE_JSON" ]; then
      UPDATED=$(jq --argjson c7 "$CONTEXT7_ENTRY" '.mcpServers = ((.mcpServers // {}) + {"context7": $c7})' "$CLAUDE_JSON")
      echo "$UPDATED" > "$CLAUDE_JSON"
      echo "  - Added Context7 to ~/.claude.json"
    else
      printf '{"mcpServers":{"context7":%s}}\n' "$CONTEXT7_ENTRY" > "$CLAUDE_JSON"
      echo "  - Created ~/.claude.json with Context7 MCP server"
    fi
  fi
else
  if [ -f "$PLUGIN_DIR/.mcp.json" ]; then
    if [ -f "$TARGET/.mcp.json" ]; then
      if command -v jq &>/dev/null; then
        # Merge MCP servers into existing config
        EXISTING=$(cat "$TARGET/.mcp.json")
        PLUGIN_MCP=$(cat "$PLUGIN_DIR/.mcp.json")
        MERGED=$(printf '%s\n%s\n' "$EXISTING" "$PLUGIN_MCP" | jq -s '.[0].mcpServers = ((.[0].mcpServers // {}) * .[1].mcpServers) | .[0]')
        echo "$MERGED" > "$TARGET/.mcp.json"
        echo "  - Merged MCP servers into existing .mcp.json"
      else
        echo "  [!] jq not found -- skipping MCP merge (manual setup required)"
      fi
    else
      cp "$PLUGIN_DIR/.mcp.json" "$TARGET/.mcp.json"
      echo "  - Created .mcp.json with Context7 MCP server"
    fi
  else
    echo "  - No MCP configuration found in plugin"
  fi
fi

# Wire up settings.json
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "[9/9] Configuring global settings..."

  # Install all hook scripts for auto-installation in beads projects
  mkdir -p "$TARGET/hooks"

  for hook in sanitize-content.sh check-memory.sh auto-recall.sh memory-capture.sh subagent-wrapup.sh memory-sanitize.sh knowledge-db.sh provision-memory.sh recall.sh extract-bead-context.sh; do
    if [ -f "$PLUGIN_DIR/hooks/$hook" ]; then
      cp "$PLUGIN_DIR/hooks/$hook" "$TARGET/hooks/$hook"
      chmod +x "$TARGET/hooks/$hook"
    fi
  done
  if [[ -d "$PLUGIN_DIR/hooks/memorysanitize" ]]; then
    rm -rf "$TARGET/hooks/memorysanitize"
    cp -R "$PLUGIN_DIR/hooks/memorysanitize" "$TARGET/hooks/memorysanitize"
  fi

  # Write version marker for hook auto-update
  LAVRA_VERSION=$(get_lavra_version "$PLUGIN_DIR")
  echo "$LAVRA_VERSION" > "$TARGET/hooks/.lavra-version"
  echo "  - Version marker: $LAVRA_VERSION"

  echo "  - Installed hook scripts (check-memory + memory hooks for auto-install)"

  # Add SessionStart hook for check-memory to global settings.json
  SETTINGS="$TARGET/settings.json"

  if [ -f "$SETTINGS" ]; then
    if command -v jq &>/dev/null; then
      EXISTING=$(cat "$SETTINGS")

      UPDATED=$(echo "$EXISTING" | jq --arg cmd "bash ~/.claude/hooks/check-memory.sh" '
        .hooks.SessionStart = (
          [(.hooks.SessionStart // [])[] | select(.hooks[]?.command | contains("check-memory") | not)] +
          [{"matcher":"","hooks":[{"type":"command","command":$cmd}]}]
        )
      ')
      echo "$UPDATED" > "$SETTINGS"
      echo "  - Added check-memory hook to settings.json"
    else
      echo "  [!] jq not found -- manual settings.json setup required"
    fi
  else
    cat > "$SETTINGS" << SETTINGS_EOF
{
  "hooks": {
    "SessionStart": [
      {"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/check-memory.sh"}]}
    ]
  }
}
SETTINGS_EOF
    echo "  - Created settings.json with check-memory hook"
  fi
else
  echo "[9/9] Configuring settings..."

  SETTINGS="$TARGET/.claude/settings.json"

  if [ -f "$SETTINGS" ]; then
    if command -v jq &>/dev/null; then
      EXISTING=$(cat "$SETTINGS")

      UPDATED=$(echo "$EXISTING" | jq '
        # Add/update SessionStart hook
        .hooks.SessionStart = (
          [(.hooks.SessionStart // [])[] | select(.hooks[]?.command | contains("auto-recall") | not)] +
          [{"hooks":[{"type":"command","command":"bash .claude/hooks/auto-recall.sh","async":true}]}]
        ) |
        # Add/update PostToolUse hook with matcher
        .hooks.PostToolUse = (
          [(.hooks.PostToolUse // [])[] | select(.hooks[]?.command | contains("memory-capture") | not)] +
          [{"matcher":"Bash","hooks":[{"type":"command","command":"bash .claude/hooks/memory-capture.sh","async":true}]}]
        ) |
        # Add/update SubagentStop hook for auto-wrapup
        .hooks.SubagentStop = (
          [(.hooks.SubagentStop // [])[] | select(.hooks[]?.command | contains("subagent-wrapup") | not)] +
          [{"hooks":[{"type":"command","command":"bash .claude/hooks/subagent-wrapup.sh"}]}]
        ) |
        # Remove any null hook arrays
        if .hooks.PreToolUse == null then del(.hooks.PreToolUse) else . end |
        if .hooks.SubagentStop == null then del(.hooks.SubagentStop) else . end
      ')
      echo "$UPDATED" > "$SETTINGS"
      echo "  - Merged hooks into existing settings.json"
    else
      echo "  [!] jq not found -- manual settings.json setup required"
      echo "      Add SessionStart and PostToolUse hooks manually"
    fi
  else
    mkdir -p "$(dirname "$SETTINGS")"
    cat > "$SETTINGS" << 'SETTINGS_EOF'
{
  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "bash .claude/hooks/auto-recall.sh", "async": true}]}
    ],
    "PostToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash .claude/hooks/memory-capture.sh", "async": true}]}
    ],
    "SubagentStop": [
      {"hooks": [{"type": "command", "command": "bash .claude/hooks/subagent-wrapup.sh"}]}
    ]
  }
}
SETTINGS_EOF
    echo "  - Created settings.json"
  fi
fi

# Note: we do NOT add .beads/ to .gitignore.
# bd init manages .beads/ visibility via .beads/.gitignore and (for stealth mode)
# .git/info/exclude. Adding .beads/ to the project .gitignore would silently
# prevent issues.jsonl and comments from being committed, causing data loss.

# Finalize manifest (enables stale cleanup on next install)
if [ "$GLOBALLY_INSTALLED" = false ]; then
  commit_manifest "$MANIFEST_FILE"
fi

if ! command -v sqlite3 &>/dev/null; then
  echo "[!] sqlite3 not found. Memory recall will use JSONL linear search (slower)."
  echo "    Install sqlite3 for optimal recall performance:"
  echo "      macOS:  brew install sqlite"
  echo "      Ubuntu: sudo apt-get install sqlite3"
  echo ""
fi

echo ""
echo "Done."
echo ""

if [ "$GLOBAL_INSTALL" = true ]; then
  echo "$CMD_COUNT commands, $AGENT_COUNT agents, and $SKILL_COUNT skills are now available in all Claude Code sessions."
  echo ""
  echo "For beads integration (memory system + hooks):"
  echo "  bunx @lavralabs/lavra@latest --claude /path/to/your-project"
  echo ""
else
  if [ "$LIGHTWEIGHT_MODE" = true ]; then
    echo "Hooks updated. Commands, agents, and skills remain global (v${INSTALLER_VERSION})."
    echo ""
  elif [ "$GLOBALLY_INSTALLED" = false ]; then
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

echo "Restart Claude Code to load the plugin."
echo ""

if [ "$GLOBAL_INSTALL" = false ]; then
  echo "To uninstall: bunx @lavralabs/lavra@latest --uninstall"
fi

echo ""
echo "Tip: Pair Lavra with the caveman skill for token-efficient /caveman mode."
echo "  https://github.com/JuliusBrussee/caveman (MIT, Julius Brussee)"
echo ""

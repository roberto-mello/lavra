#!/bin/bash
#
# Install lavra plugin for Cortex Code
#
# What this installs:
#   - Memory capture and auto-recall hooks
#   - Knowledge store (.lavra/memory/knowledge.jsonl)
#   - Converted commands, agents, and skills
#
# Usage:
#   Called by install.sh -cortex [target]
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

# Parse --yes/-y flag (skip confirmation prompts)
AUTO_YES=false
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --yes|-y) AUTO_YES=true ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

# Default to ~/.snowflake/cortex if no positional argument provided
if [ ${#POSITIONAL_ARGS[@]} -eq 0 ]; then
  TARGET="$HOME/.snowflake/cortex"
  GLOBAL_INSTALL=true
else
  TARGET="${POSITIONAL_ARGS[0]}"
  GLOBAL_INSTALL=false
fi

# Resolve target to absolute path
TARGET="$(resolve_target_dir "$TARGET")"

# Detect if user is trying to install into the plugin directory itself
if [[ "$TARGET" == "$SCRIPT_DIR" || "$TARGET" == "$PLUGIN_DIR" ]]; then
  echo "[!] Error: Cannot install plugin into itself."
  echo ""
  echo "    You're trying to install into: $TARGET"
  echo "    This is the plugin source directory, not a project."
  echo ""
  echo "    Usage:"
  echo "      ./install.sh -cortex                      # global install to ~/.snowflake/cortex"
  echo "      ./install.sh -cortex /path/to/project     # project-specific install"
  echo ""
  exit 1
fi

# Verify plugin directory exists
if [ ! -d "$PLUGIN_DIR" ]; then
  echo "[!] Error: Plugin directory not found at $PLUGIN_DIR"
  echo "    Expected marketplace structure with plugins/lavra/"
  exit 1
fi

eval "$(parse_installer_args "$@")"
[ "$NO_BANNER" = false ] && print_banner "Cortex Code" "0.7.1"
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

# Global install: warn about memory features and confirm
if [ "$GLOBAL_INSTALL" = true ] && [ "$AUTO_YES" = false ]; then
  echo "[!] Note: Global install provides commands, agents, and skills everywhere,"
  echo "    but memory features (auto-recall, knowledge capture) require per-project"
  echo "    installation. You'll be prompted automatically in projects that use beads."
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

# [1/8] Check for bd (skip for global install)
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "[1/8] Skipping bd check (global install)"
  echo "[2/8] Skipping .beads init (global install)"
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

  echo "[1/8] bd found: $(which bd)"

  # [2/8] Initialize .beads if needed
  if [ ! -d "$TARGET/.beads" ]; then
    echo "[2/8] Initializing .beads..."
    (cd "$TARGET" && bd init)
  else
    echo "[2/8] .beads already exists"
  fi
fi

# [3/8] Set up memory directory and recall script (skip for global install)
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "[3/8] Skipping memory system (global install)"
else
  echo "[3/8] Setting up memory system..."

  PROVISION_SCRIPT="$PLUGIN_DIR/hooks/provision-memory.sh"

  if [ -f "$PROVISION_SCRIPT" ]; then
    source "$PROVISION_SCRIPT"
    migrate_beads_to_lavra "$TARGET"
    provision_memory_dir "$TARGET" "$PLUGIN_DIR/hooks"
    echo "  - Memory system configured"
  fi
fi

# [4/8] Install hooks
if [ "$GLOBAL_INSTALL" = true ]; then
  echo "[4/8] Installing global hooks..."

  mkdir -p "$TARGET/hooks"

  for hook in check-memory.sh dispatch-hook.sh auto-recall.sh memory-capture.sh subagent-wrapup.sh knowledge-db.sh provision-memory.sh recall.sh; do
    if [ -f "$PLUGIN_DIR/hooks/$hook" ]; then
      cp "$PLUGIN_DIR/hooks/$hook" "$TARGET/hooks/$hook"
      chmod +x "$TARGET/hooks/$hook"
    fi
  done

  echo "  - Installed hook scripts (check-memory + dispatch-hook + memory hooks)"
else
  echo "[4/8] Installing hooks..."

  HOOKS_DIR="$TARGET/.cortex/hooks"
  create_dir_with_symlink_handling "$HOOKS_DIR"

  for hook in memory-capture.sh auto-recall.sh subagent-wrapup.sh knowledge-db.sh provision-memory.sh; do
    cp "$PLUGIN_DIR/hooks/$hook" "$HOOKS_DIR/$hook"
    chmod +x "$HOOKS_DIR/$hook"
    echo "  - Installed $hook"
  done

  # Ensure dispatcher is in global hooks dir (needed even without a global install)
  GLOBAL_HOOKS="$HOME/.snowflake/cortex/hooks"
  mkdir -p "$GLOBAL_HOOKS"
  for hook in dispatch-hook.sh check-memory.sh; do
    if [ -f "$PLUGIN_DIR/hooks/$hook" ]; then
      cp "$PLUGIN_DIR/hooks/$hook" "$GLOBAL_HOOKS/$hook"
      chmod +x "$GLOBAL_HOOKS/$hook"
    fi
  done
  echo "  - Installed dispatcher to $GLOBAL_HOOKS"
fi

# Detect if commands/agents/skills are already installed globally
GLOBALLY_INSTALLED=false

if [ "$GLOBAL_INSTALL" = false ] && [ -f "$HOME/.snowflake/cortex/commands/lavra-plan.md" ]; then
  GLOBALLY_INSTALLED=true
fi

# [5/8] Install commands (requires bun, run convert-cortex.ts)
echo "[5/8] Installing workflow commands..."

if [ "$GLOBALLY_INSTALLED" = true ]; then
  CMD_COUNT=0
  echo "  - Already installed globally -- skipping"
else
  # Check if bun is available
  if ! command -v bun &>/dev/null; then
    echo "[!] Error: Bun is required for Cortex Code installation"
    echo "    Install Bun: curl -fsSL https://bun.sh/install | bash"
    exit 1
  fi

  # Run conversion
  echo "  Running convert-cortex.ts..."
  cd "$SCRIPT_DIR/scripts"
  if ! BEADS_INSTALLING=1 bun run convert-cortex.ts; then
    echo "[!] Error: Conversion failed"
    exit 1
  fi

  if [ "$GLOBAL_INSTALL" = true ]; then
    COMMANDS_DIR="$TARGET/commands"
  else
    COMMANDS_DIR="$TARGET/.cortex/commands"
  fi
  create_dir_with_symlink_handling "$COMMANDS_DIR"

  CMD_COUNT=0

  for cmd in "$PLUGIN_DIR/cortex/commands"/*.md; do
    if [ -f "$cmd" ]; then
      cp "$cmd" "$COMMANDS_DIR/$(basename "$cmd")"
      CMD_COUNT=$((CMD_COUNT + 1))
    fi
  done

  echo "  - Installed $CMD_COUNT commands"
fi

# [6/8] Install agents
echo "[6/8] Installing agents..."

if [ "$GLOBALLY_INSTALLED" = true ]; then
  AGENT_COUNT=0
  echo "  - Already installed globally -- skipping"
else
  if [ "$GLOBAL_INSTALL" = true ]; then
    AGENTS_DIR="$TARGET/agents"
  else
    AGENTS_DIR="$TARGET/.cortex/agents"
  fi
  mkdir -p "$AGENTS_DIR"

  AGENT_COUNT=0

  if [ -d "$PLUGIN_DIR/cortex/agents" ]; then
    for category in "$PLUGIN_DIR/cortex/agents"/*/; do
      if [ -d "$category" ]; then
        category_name=$(basename "$category")
        mkdir -p "$AGENTS_DIR/$category_name"

        for agent in "$category"/*.md; do
          if [ -f "$agent" ]; then
            cp "$agent" "$AGENTS_DIR/$category_name/$(basename "$agent")"
            AGENT_COUNT=$((AGENT_COUNT + 1))
          fi
        done
      fi
    done
  fi

  echo "  - Installed $AGENT_COUNT agents"
fi

# [7/8] Install skills
echo "[7/8] Installing skills..."

SKILL_COUNT=0
SKILL_SKIPPED=0

if [ "$GLOBALLY_INSTALLED" = true ]; then
  echo "  - Already installed globally -- skipping"
else
  if [ "$GLOBAL_INSTALL" = true ]; then
    SKILLS_DIR="$TARGET/skills"
  else
    SKILLS_DIR="$TARGET/.cortex/skills"
  fi
  mkdir -p "$SKILLS_DIR"

  if [ -d "$PLUGIN_DIR/cortex/skills" ]; then
    for skill_dir in "$PLUGIN_DIR/cortex/skills"/*/; do
      if [ -d "$skill_dir" ]; then
        skill_name=$(basename "$skill_dir")

        if [ -L "$SKILLS_DIR/$skill_name" ]; then
          # Symlink -- installed by plugin system, don't touch
          echo "  - Skipped $skill_name (symlink, not ours)"
          SKILL_SKIPPED=$((SKILL_SKIPPED + 1))
          continue
        elif [ -d "$SKILLS_DIR/$skill_name" ]; then
          if [ -f "$SKILLS_DIR/$skill_name/.lavra" ]; then
            # Our plugin installed this -- safe to overwrite
            rm -rf "$SKILLS_DIR/$skill_name"
          else
            # User's own skill -- skip it
            echo "  - Skipped $skill_name (already exists, not ours)"
            SKILL_SKIPPED=$((SKILL_SKIPPED + 1))
            continue
          fi
        fi

        # Copy entire skill directory
        cp -r "$skill_dir" "$SKILLS_DIR/$skill_name"
        touch "$SKILLS_DIR/$skill_name/.lavra"
        SKILL_COUNT=$((SKILL_COUNT + 1))
      fi
    done
  fi

  echo "  - Installed $SKILL_COUNT skills"
  if [ "$SKILL_SKIPPED" -gt 0 ]; then
    echo "  - Skipped $SKILL_SKIPPED existing skill(s) not managed by this plugin"
  fi
fi

# [8/8] Configure hooks.json (ALWAYS at ~/.snowflake/cortex/hooks.json)
echo "[8/8] Configuring hooks.json..."

HOOKS_JSON="$HOME/.snowflake/cortex/hooks.json"
mkdir -p "$(dirname "$HOOKS_JSON")"

if [ "$GLOBAL_INSTALL" = true ]; then
  # Global install: check-memory + dispatcher hooks (all absolute paths)
  DISPATCH="bash ~/.snowflake/cortex/hooks/dispatch-hook.sh .cortex/hooks"
  CHECK_MEM="bash ~/.snowflake/cortex/hooks/check-memory.sh cortex"

  if [ -f "$HOOKS_JSON" ]; then
    if command -v jq &>/dev/null; then
      EXISTING=$(cat "$HOOKS_JSON")

      UPDATED=$(echo "$EXISTING" | jq \
        --arg check_mem "$CHECK_MEM" \
        --arg recall "$DISPATCH auto-recall.sh" \
        --arg capture "$DISPATCH memory-capture.sh" \
        --arg wrapup "$DISPATCH subagent-wrapup.sh" '
        .hooks.SessionStart = (
          [(.hooks.SessionStart // [])[] | select(.hooks[]?.command | (contains("check-memory") or contains("auto-recall")) | not)] +
          [{"hooks":[{"type":"command","command":$check_mem}]},
           {"hooks":[{"type":"command","command":$recall,"async":true}]}]
        ) |
        .hooks.PostToolUse = (
          [(.hooks.PostToolUse // [])[] | select(.hooks[]?.command | contains("memory-capture") | not)] +
          [{"matcher":"bash","hooks":[{"type":"command","command":$capture,"async":true}]}]
        ) |
        .hooks.SubagentStop = (
          [(.hooks.SubagentStop // [])[] | select(.hooks[]?.command | contains("subagent-wrapup") | not)] +
          [{"hooks":[{"type":"command","command":$wrapup}]}]
        )
      ')
      echo "$UPDATED" > "$HOOKS_JSON"
      echo "  - Updated hooks.json with dispatcher hooks"
    else
      echo "  [!] jq not found -- manual hooks.json setup required"
    fi
  else
    cat > "$HOOKS_JSON" << HOOKS_EOF
{
  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "$CHECK_MEM"}]},
      {"hooks": [{"type": "command", "command": "$DISPATCH auto-recall.sh", "async": true}]}
    ],
    "PostToolUse": [
      {"matcher": "bash", "hooks": [{"type": "command", "command": "$DISPATCH memory-capture.sh", "async": true}]}
    ],
    "SubagentStop": [
      {"hooks": [{"type": "command", "command": "$DISPATCH subagent-wrapup.sh"}]}
    ]
  }
}
HOOKS_EOF
    echo "  - Created hooks.json with dispatcher hooks"
  fi
else
  # Project install: dispatcher hooks (same absolute-path pattern as global)
  DISPATCH="bash ~/.snowflake/cortex/hooks/dispatch-hook.sh .cortex/hooks"

  if [ -f "$HOOKS_JSON" ]; then
    if command -v jq &>/dev/null; then
      EXISTING=$(cat "$HOOKS_JSON")

      UPDATED=$(echo "$EXISTING" | jq \
        --arg recall "$DISPATCH auto-recall.sh" \
        --arg capture "$DISPATCH memory-capture.sh" \
        --arg wrapup "$DISPATCH subagent-wrapup.sh" '
        # Add/update SessionStart hook
        .hooks.SessionStart = (
          [(.hooks.SessionStart // [])[] | select(.hooks[]?.command | contains("auto-recall") | not)] +
          [{"hooks":[{"type":"command","command":$recall,"async":true}]}]
        ) |
        # Add/update PostToolUse hook with matcher
        .hooks.PostToolUse = (
          [(.hooks.PostToolUse // [])[] | select(.hooks[]?.command | contains("memory-capture") | not)] +
          [{"matcher":"bash","hooks":[{"type":"command","command":$capture,"async":true}]}]
        ) |
        # Add/update SubagentStop hook for auto-wrapup
        .hooks.SubagentStop = (
          [(.hooks.SubagentStop // [])[] | select(.hooks[]?.command | contains("subagent-wrapup") | not)] +
          [{"hooks":[{"type":"command","command":$wrapup}]}]
        ) |
        # Remove any null hook arrays
        if .hooks.PreToolUse == null then del(.hooks.PreToolUse) else . end |
        if .hooks.SubagentStop == null then del(.hooks.SubagentStop) else . end
      ')
      echo "$UPDATED" > "$HOOKS_JSON"
      echo "  - Merged dispatcher hooks into existing hooks.json"
    else
      echo "  [!] jq not found -- manual hooks.json setup required"
      echo "      Add SessionStart, PostToolUse, and SubagentStop hooks manually"
    fi
  else
    cat > "$HOOKS_JSON" << HOOKS_EOF
{
  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "$DISPATCH auto-recall.sh", "async": true}]}
    ],
    "PostToolUse": [
      {"matcher": "bash", "hooks": [{"type": "command", "command": "$DISPATCH memory-capture.sh", "async": true}]}
    ],
    "SubagentStop": [
      {"hooks": [{"type": "command", "command": "$DISPATCH subagent-wrapup.sh"}]}
    ]
  }
}
HOOKS_EOF
    echo "  - Created hooks.json with dispatcher hooks"
  fi
fi

# Summary
echo ""
echo "Done. Installed:"
echo ""
echo "  Commands ($CMD_COUNT):"
echo "    Workflow: /lavra-plan, /lavra-brainstorm, /lavra-work, /lavra-work-ralph, /lavra-work-teams, /lavra-review, /lavra-compound, /lavra-checkpoint"
echo "    Planning: /lavra-research, /lavra-eng-review, /lavra-triage"
echo "    Utility:  /lfg, /changelog, /create-agent-skill, /heal-skill"
echo "    Testing:  /test-browser, /report-bug"
echo "    Docs:     /deploy-docs, /release-docs"
echo "    Parallel: /resolve-pr-parallel, /resolve-todo-parallel"
echo ""
echo "  Agents ($AGENT_COUNT):"
echo "    Review, research, design, workflow, and docs agents"
echo ""
echo "  Core Skills ($SKILL_COUNT):"
echo "    git-worktree, brainstorming, create-agent-skills, agent-native-architecture, lavra-knowledge,"
echo "    agent-browser, file-todos, project-setup,"
echo ""
echo "  Optional Skills (7, not installed by default):"
echo "    andrew-kane-gem-writer, dhh-rails-style, dspy-ruby, every-style-editor,"
echo "    frontend-design, gemini-imagegen, rclone"
echo ""

if [ "$GLOBAL_INSTALL" = false ]; then
  echo "  Memory System:"
  echo "    - Auto-recall at session start (based on current beads)"
  echo "    - Auto-capture from bd comment (LEARNED/DECISION/FACT/PATTERN/INVESTIGATION)"
  echo "    - Knowledge stored at .lavra/memory/knowledge.jsonl"
  echo "    - Search: .lavra/memory/recall.sh \"keyword\""
  echo ""
fi

if [ "$GLOBAL_INSTALL" = true ]; then
  echo "Global installation complete!"
  echo ""
  echo "Commands, agents, and skills are now available in all Cortex Code sessions."
  echo ""
  echo "For beads integration (memory system + hooks):"
  echo "  bash $SCRIPT_DIR/install.sh -cortex /path/to/your-project"
  echo ""
  echo "[!] IMPORTANT: If you have existing projects with a previous version of"
  echo "    lavra installed, re-run the installer on each to update hooks:"
  echo "    bash $SCRIPT_DIR/install.sh -cortex /path/to/your-project"
  echo "    (Auto-provisioning only installs hooks for the first time, not updates.)"
  echo ""
else
  echo "Usage:"
  echo "  1. Create or work on beads normally with bd commands"
  echo "  2. Use /lavra-plan for complex features requiring research"
  echo "  3. Use /lavra-brainstorm to explore ideas before planning"
  echo "  4. Use /lavra-review before closing beads to catch issues"
  echo "  5. Log learnings with: bd comment add ID \"LEARNED: ...\""
  echo "  6. Knowledge will be recalled automatically next session"
  echo ""
fi

echo "Restart Cortex Code to load the plugin."
echo ""

if [ "$GLOBAL_INSTALL" = false ]; then
  echo "To uninstall: bash $SCRIPT_DIR/installers/uninstall-cortex.sh $TARGET"
fi

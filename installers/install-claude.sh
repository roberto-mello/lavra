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

print_banner "Claude Code" "0.7.0"
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
  echo "    setup. Run /project-setup once in each project to configure stack,"
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

  # Initialize .beads if needed
  if [ ! -d "$TARGET/.beads" ]; then
    echo "[2/9] Initializing .beads..."
    (cd "$TARGET" && bd init)
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

  # Nudge toward /project-setup (skip if --yes or --quiet)
  if [ "$AUTO_YES" = false ] && [ "$QUIET" = false ] && [ -t 0 ]; then
    echo ""
    echo "  Run /project-setup to configure stack, review agents, and workflow"
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

  for hook in memory-capture.sh auto-recall.sh subagent-wrapup.sh knowledge-db.sh provision-memory.sh; do
    cp "$PLUGIN_DIR/hooks/$hook" "$HOOKS_DIR/$hook"
    chmod +x "$HOOKS_DIR/$hook"
    echo "  - Installed $hook"
  done
fi

# Detect if commands/agents/skills are already installed globally
GLOBALLY_INSTALLED=false

if [ "$GLOBAL_INSTALL" = false ] && [ -f "$HOME/.claude/commands/lavra-plan.md" ]; then
  GLOBALLY_INSTALLED=true
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

  CMD_COUNT=0

  for cmd in "$PLUGIN_DIR/commands"/*.md; do
    if [ -f "$cmd" ]; then
      cp "$cmd" "$COMMANDS_DIR/$(basename "$cmd")"
      ((CMD_COUNT++))
    fi
  done

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

  AGENT_COUNT=0

  if [ -d "$PLUGIN_DIR/agents" ]; then
    for category in "$PLUGIN_DIR/agents"/*/; do
      if [ -d "$category" ]; then
        category_name=$(basename "$category")
        mkdir -p "$AGENTS_DIR/$category_name"

        for agent in "$category"/*.md; do
          if [ -f "$agent" ]; then
            cp "$agent" "$AGENTS_DIR/$category_name/$(basename "$agent")"
            ((AGENT_COUNT++))
          fi
        done
      fi
    done
  fi

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

  if [ -d "$PLUGIN_DIR/skills" ]; then
    for skill_dir in "$PLUGIN_DIR/skills"/*/; do
      if [ -d "$skill_dir" ]; then
        skill_name=$(basename "$skill_dir")

        if [ -L "$SKILLS_DIR/$skill_name" ]; then
          # Symlink -- installed by Claude's plugin system, don't touch
          echo "  - Skipped $skill_name (symlink, not ours)"
          ((SKILL_SKIPPED++))
          continue
        elif [ -d "$SKILLS_DIR/$skill_name" ]; then
          if [ -f "$SKILLS_DIR/$skill_name/.lavra" ]; then
            # Our plugin installed this -- safe to overwrite
            rm -rf "$SKILLS_DIR/$skill_name"
          else
            # User's own skill -- skip it
            echo "  - Skipped $skill_name (already exists, not ours)"
            ((SKILL_SKIPPED++))
            continue
          fi
        fi

        # Copy entire skill directory (may contain references/, templates/, etc.)
        cp -r "$skill_dir" "$SKILLS_DIR/$skill_name"
        touch "$SKILLS_DIR/$skill_name/.lavra"
        ((SKILL_COUNT++))
      fi
    done
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

  for hook in check-memory.sh auto-recall.sh memory-capture.sh subagent-wrapup.sh knowledge-db.sh provision-memory.sh recall.sh; do
    if [ -f "$PLUGIN_DIR/hooks/$hook" ]; then
      cp "$PLUGIN_DIR/hooks/$hook" "$TARGET/hooks/$hook"
      chmod +x "$TARGET/hooks/$hook"
    fi
  done

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
echo "    Install with: cp -r plugins/lavra/skills/optional/<name> .claude/skills/"
echo ""

if [ "$GLOBAL_INSTALL" = false ]; then
  echo "  Memory System:"
  echo "    - Auto-recall at session start (based on current beads)"
  echo "    - Auto-capture from bd comment (LEARNED/DECISION/FACT/PATTERN/INVESTIGATION)"
  echo "    - Knowledge stored at .lavra/memory/knowledge.jsonl"
  echo "    - Search: .lavra/memory/recall.sh \"keyword\""
  echo ""
fi

echo "  MCP Servers:"
echo "    - Context7 (framework documentation)"
echo ""

if [ "$GLOBAL_INSTALL" = true ]; then
  echo "Global installation complete!"
  echo ""
  echo "Commands, agents, and skills are now available in all Claude Code sessions."
  echo ""
  echo "For beads integration (memory system + hooks):"
  echo "  bash $SCRIPT_DIR/install.sh /path/to/your-project"
  echo ""
  echo "[!] IMPORTANT: If you have existing projects with a previous version of"
  echo "    lavra installed, re-run the installer on each to update hooks:"
  echo "    bash $SCRIPT_DIR/install.sh /path/to/your-project"
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

echo "Restart Claude Code to load the plugin."
echo ""

if [ "$GLOBAL_INSTALL" = false ]; then
  echo "To uninstall: bash $SCRIPT_DIR/uninstall.sh $TARGET"
fi

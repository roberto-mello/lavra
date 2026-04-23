#!/bin/bash
#
# Shared memory provisioning for lavra
#
# Provides a single function to set up .lavra/ with knowledge tracking.
# Used by auto-recall.sh (native plugin), check-memory.sh (global install),
# and install.sh (manual install) to avoid duplicating setup logic.
#
# Usage:
#   source provision-memory.sh
#   provision_memory_dir "/path/to/project" "/path/to/hooks/dir"
#

provision_memory_dir() {
  local PROJECT_DIR="$1"
  local HOOKS_SOURCE_DIR="$2"

  local MEMORY_DIR="$PROJECT_DIR/.lavra/memory"
  local LAVRA_DIR="$PROJECT_DIR/.lavra"

  mkdir -p -m 700 "$MEMORY_DIR"
  mkdir -p -m 700 "$PROJECT_DIR/.lavra/config"
  mkdir -p -m 700 "$PROJECT_DIR/.lavra/retros"

  # Create empty knowledge file if missing
  if [[ ! -f "$MEMORY_DIR/knowledge.jsonl" ]]; then
    touch "$MEMORY_DIR/knowledge.jsonl"
  fi

  # Copy recall.sh if available
  if [[ -f "$HOOKS_SOURCE_DIR/recall.sh" ]]; then
    cp "$HOOKS_SOURCE_DIR/recall.sh" "$MEMORY_DIR/recall.sh"
    chmod +x "$MEMORY_DIR/recall.sh"
  fi

  # Copy knowledge-db.sh if available
  if [[ -f "$HOOKS_SOURCE_DIR/knowledge-db.sh" ]]; then
    cp "$HOOKS_SOURCE_DIR/knowledge-db.sh" "$MEMORY_DIR/knowledge-db.sh"
    chmod +x "$MEMORY_DIR/knowledge-db.sh"
  fi

  # Setup .lavra/.gitattributes for union merge (folder-level, paths use memory/ prefix)
  local GITATTR="$LAVRA_DIR/.gitattributes"

  if [[ ! -f "$GITATTR" ]] || ! grep -q 'memory/knowledge.jsonl' "$GITATTR" 2>/dev/null; then
    echo "memory/knowledge.jsonl merge=union" > "$GITATTR"
    echo "memory/knowledge.archive.jsonl merge=union" >> "$GITATTR"
  fi

  # Write installed version for staleness detection by auto-recall.sh
  # .lavra-version lives at .lavra/ root, not .lavra/memory/
  echo "0.7.7" > "$LAVRA_DIR/.lavra-version"

  # Create .lavra/.gitignore (folder-level) to ignore SQLite cache and ephemeral state
  # Paths are relative to .lavra/ root, so they use memory/ prefix
  local LAVRA_GITIGNORE="$LAVRA_DIR/.gitignore"
  if [[ ! -f "$LAVRA_GITIGNORE" ]]; then
    cat > "$LAVRA_GITIGNORE" << 'EOF'
# SQLite FTS cache (rebuilt from knowledge.jsonl on first use)
memory/knowledge.db
memory/knowledge.db-journal
memory/knowledge.db-wal
memory/knowledge.db-shm

# Ephemeral session state (survives compaction, recalled once, then deleted)
memory/session-state.md
EOF
  elif ! grep -q 'session-state.md' "$LAVRA_GITIGNORE" 2>/dev/null; then
    # Append session-state.md to existing gitignore if missing
    echo "" >> "$LAVRA_GITIGNORE"
    echo "# Ephemeral session state (survives compaction, recalled once, then deleted)" >> "$LAVRA_GITIGNORE"
    echo "memory/session-state.md" >> "$LAVRA_GITIGNORE"
  fi

  # Create default lavra.json config if missing
  local CONFIG_DIR="$PROJECT_DIR/.lavra/config"
  if [[ ! -f "$CONFIG_DIR/lavra.json" ]]; then
    cat > "$CONFIG_DIR/lavra.json" << 'EOF'
{
  "workflow": {
    "research": true,
    "plan_review": true,
    "goal_verification": true,
    "testing_scope": "full"
  },
  "execution": {
    "max_parallel_agents": 3,
    "commit_granularity": "task"
  },
  "model_profile": "balanced"
}
EOF
  fi

  # Check if project .gitignore contains a .lavra/ pattern, which would cause
  # all Lavra knowledge and config data to be untracked (data loss risk on new clones).
  if git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null 2>&1; then
    local GITIGNORE="$PROJECT_DIR/.gitignore"
    if [[ -f "$GITIGNORE" ]] && grep -qE '^\s*\.lavra/?(\s|$)' "$GITIGNORE" 2>/dev/null \
      && ! grep -qE '^\s*!\.lavra/' "$GITIGNORE" 2>/dev/null; then
      echo ""
      echo "[!] Warning: .lavra/ is listed in your project .gitignore."
      echo "    This means your Lavra knowledge and config are not"
      echo "    tracked by git. If you lose your local copy, all of this data"
      echo "    will be permanently lost."
      echo ""
      echo "    To keep .lavra/ invisible to git without data loss, use git's"
      echo "    exclude file: echo '.lavra/' >> .git/info/exclude"
      echo ""
      if [[ "${BEADS_AUTO_YES:-false}" == "true" ]] || ! [[ -t 0 ]]; then
        # Non-interactive mode (hook context or --yes flag): warn but don't modify
        echo "    [non-interactive] Leaving .gitignore unchanged. Re-run install to fix interactively."
      else
        read -r -p "    Remove .lavra/ from .gitignore? [Y/n] " response
        case "${response:-Y}" in
          [nN]|[nN][oO])
            echo "    Left unchanged. Your Lavra data may not be committed to git."
            ;;
          *)
            # Remove lines matching .lavra/ (with optional trailing slash and whitespace)
            local TMPFILE
            TMPFILE=$(mktemp)
            grep -vE '^\s*\.lavra/?(\s|$)' "$GITIGNORE" > "$TMPFILE"
            mv "$TMPFILE" "$GITIGNORE"
            echo "    Removed .lavra/ from .gitignore."
            echo "    Run: git add .lavra/ && git commit -m 'track lavra data'"
            ;;
        esac
      fi
      echo ""
    fi
  fi

  # Stage specific known files only (no -f: respect user's .gitignore)
  if git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null 2>&1; then
    (cd "$PROJECT_DIR" && git add \
      .lavra/.gitattributes \
      .lavra/.gitignore \
      .lavra/.lavra-version \
      .lavra/memory/knowledge.jsonl \
      .lavra/memory/recall.sh \
      .lavra/memory/knowledge-db.sh \
      2>/dev/null) || true
  fi
}

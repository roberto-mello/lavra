#!/bin/bash
#
# Shared memory provisioning for beads-compound
#
# Provides a single function to set up .beads/memory/ with knowledge tracking.
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

  local MEMORY_DIR="$PROJECT_DIR/.beads/memory"

  mkdir -p "$MEMORY_DIR"

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

  # Setup .gitattributes for union merge (per-directory, scoped to .beads/memory/)
  local GITATTR="$MEMORY_DIR/.gitattributes"

  if [[ ! -f "$GITATTR" ]] || ! grep -q 'knowledge.jsonl' "$GITATTR" 2>/dev/null; then
    echo "knowledge.jsonl merge=union" > "$GITATTR"
    echo "knowledge.archive.jsonl merge=union" >> "$GITATTR"
  fi

  # Write installed version for staleness detection by auto-recall.sh
  echo "0.6.7" > "$MEMORY_DIR/.beads-compound-version"

  # Create .beads/memory/.gitignore to ignore the SQLite FTS cache
  # (rebuilt from knowledge.jsonl on first use — no need to commit it)
  local MEMORY_GITIGNORE="$MEMORY_DIR/.gitignore"
  if [[ ! -f "$MEMORY_GITIGNORE" ]]; then
    cat > "$MEMORY_GITIGNORE" << 'EOF'
# SQLite FTS cache (rebuilt from knowledge.jsonl on first use)
knowledge.db
knowledge.db-journal
knowledge.db-wal
knowledge.db-shm
EOF
  fi

  # Check if project .gitignore contains a .beads/ pattern, which would cause
  # all beads issue/comment data to be untracked (data loss risk on new clones).
  # bd init no longer adds .beads/ to project .gitignore — if it's there, it's
  # from an older version of beads-compound or a manual addition.
  if git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null 2>&1; then
    local GITIGNORE="$PROJECT_DIR/.gitignore"
    if [[ -f "$GITIGNORE" ]] && grep -qE '^\s*\.beads/?(\s|$)' "$GITIGNORE" 2>/dev/null \
      && ! grep -qE '^\s*!\.beads/' "$GITIGNORE" 2>/dev/null; then
      echo ""
      echo "[!] Warning: .beads/ is listed in your project .gitignore."
      echo "    This means your beads issues, comments, and knowledge are not"
      echo "    tracked by git. If you lose your local copy, all of this data"
      echo "    will be permanently lost."
      echo ""
      echo "    Modern beads (bd init) no longer adds .beads/ to .gitignore."
      echo "    If you want .beads/ to be invisible to git, use: bd init --stealth"
      echo "    (which uses .git/info/exclude instead, keeping data safe)."
      echo ""
      if [[ "${BEADS_AUTO_YES:-false}" == "true" ]] || ! [[ -t 0 ]]; then
        # Non-interactive mode (hook context or --yes flag): warn but don't modify
        echo "    [non-interactive] Leaving .gitignore unchanged. Re-run install to fix interactively."
      else
        read -r -p "    Remove .beads/ from .gitignore? [Y/n] " response
        case "${response:-Y}" in
          [nN]|[nN][oO])
            echo "    Left unchanged. Your beads data may not be committed to git."
            ;;
          *)
            # Remove lines matching .beads/ (with optional trailing slash and whitespace)
            local TMPFILE
            TMPFILE=$(mktemp)
            grep -vE '^\s*\.beads/?(\s|$)' "$GITIGNORE" > "$TMPFILE"
            mv "$TMPFILE" "$GITIGNORE"
            echo "    Removed .beads/ from .gitignore."
            echo "    Run: git add .beads/ && git commit -m 'track beads data'"
            ;;
        esac
      fi
      echo ""
    fi
  fi

  # Stage specific known files only (use -f to override parent .gitignore
  # in case negation rules haven't been picked up yet by this git session)
  if git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null 2>&1; then
    (cd "$PROJECT_DIR" && git add -f \
      .beads/memory/knowledge.jsonl \
      .beads/memory/.gitattributes \
      .beads/memory/.gitignore \
      .beads/memory/.beads-compound-version \
      .beads/memory/recall.sh \
      .beads/memory/knowledge-db.sh \
      2>/dev/null) || true
  fi
}

#!/bin/bash
#
# SessionStart: Auto-inject relevant knowledge from memory
#
# Searches the knowledge base for entries relevant to:
# 1. Currently open beads
# 2. Recent activity
# 3. Current git branch context
#
# Injects top results as context for the session
#
# Bootstrap: auto-creates .beads/memory/ if missing
#

# Resolve script directory early (works for both native plugin and manual install)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Version of beads-compound that wrote this hook (updated by installer)
BEADS_COMPOUND_VERSION="0.6.7"

# Exit silently if bd is not installed
if ! command -v bd &>/dev/null; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# If .beads/ doesn't exist, hint to run bd init
if [[ ! -d "$PROJECT_DIR/.beads" ]]; then
  cat << 'HINT'
{"hookSpecificOutput":{"systemMessage":"## Beads Not Initialized\n\nThis project doesn't have beads set up yet. Run `bd init` to enable issue tracking and knowledge management."}}
HINT
  exit 0
fi

# Auto-bootstrap memory directory if missing
if [[ ! -d "$PROJECT_DIR/.beads/memory" ]]; then
  source "$SCRIPT_DIR/provision-memory.sh"
  provision_memory_dir "$PROJECT_DIR" "$SCRIPT_DIR"

  cat << 'BOOTSTRAP'
{"hookSpecificOutput":{"systemMessage":"## Memory System Bootstrapped\n\nAuto-created `.beads/memory/` with knowledge tracking. Your discoveries will be captured automatically via beads comments.\n\nUse `bd comments add <BEAD_ID> \"LEARNED: ...\"` to log knowledge."}}
BOOTSTRAP
  exit 0
fi

# Warn if .beads/ is gitignored at the project level -- this means beads
# issues, comments, and knowledge are not tracked and will be lost if the
# local copy is deleted. Emit every session until fixed so it's not missed.
GITIGNORE="$PROJECT_DIR/.gitignore"
if [[ -f "$GITIGNORE" ]] && grep -qE '^\s*\.beads/?(\s|$)' "$GITIGNORE" 2>/dev/null \
  && ! grep -qE '^\s*!\.beads/' "$GITIGNORE" 2>/dev/null; then
  cat << 'WARN'
{"hookSpecificOutput":{"systemMessage":"## Warning: Beads Data Not Tracked by Git\n\nYour `.gitignore` contains `.beads/`, which means your beads issues, comments, and knowledge are **not committed to git**. If you lose your local copy, this data will be permanently lost.\n\nTo fix: re-run the installer interactively:\n```\nbash /path/to/beads-compound-plugin/install.sh\n```\nOr manually remove `.beads/` from `.gitignore`, then `git add .beads/`.\n\nIf you intentionally want beads invisible to collaborators, use `bd init --stealth` instead (stores the ignore in `.git/info/exclude`, which keeps data safe)."}}
WARN
  exit 0
fi

# Warn if hooks are out of date with the installed plugin version
MEMORY_DIR="$PROJECT_DIR/.beads/memory"
VERSION_FILE="$MEMORY_DIR/.beads-compound-version"
if [[ -f "$VERSION_FILE" ]]; then
  INSTALLED_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
  if [[ "$INSTALLED_VERSION" != "$BEADS_COMPOUND_VERSION" ]]; then
    cat << EOF
{"hookSpecificOutput":{"systemMessage":"## beads-compound update available\n\nThis project has beads-compound **$INSTALLED_VERSION** but the plugin is now **$BEADS_COMPOUND_VERSION**. Re-run the installer to get the latest hooks and fixes:\n\n\`\`\`\nbash /path/to/beads-compound-plugin/install.sh $(pwd)\n\`\`\`"}}
EOF
    exit 0
  fi
fi

# Memory directory exists -- proceed with recall
KNOWLEDGE_FILE="$MEMORY_DIR/knowledge.jsonl"

# Get currently open beads
OPEN_BEADS=$(bd list --status=open --json 2>/dev/null | jq -r '.[].id' 2>/dev/null | head -5)
IN_PROGRESS=$(bd list --status=in_progress --json 2>/dev/null | jq -r '.[].id' 2>/dev/null | head -5)

# Get current branch name for context
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)

# Build search terms from bead titles and branch
SEARCH_TERMS=""

# Extract keywords from open/in-progress bead titles
for BEAD_ID in $OPEN_BEADS $IN_PROGRESS; do
  TITLE=$(bd show "$BEAD_ID" --json 2>/dev/null | jq -r '.[0].title // empty' 2>/dev/null)
  if [[ -n "$TITLE" ]]; then
    # Extract key words (ignore common words)
    KEYWORDS=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | grep -oE '\b[a-z]{4,}\b' | grep -vE '^(the|and|for|with|from|that|this|have|been|will|into)$' | head -3)
    SEARCH_TERMS="$SEARCH_TERMS $KEYWORDS"
  fi
done

# Add branch name keywords
if [[ -n "$CURRENT_BRANCH" ]] && [[ "$CURRENT_BRANCH" != "main" ]] && [[ "$CURRENT_BRANCH" != "master" ]]; then
  BRANCH_KEYWORDS=$(echo "$CURRENT_BRANCH" | tr '-_' ' ' | grep -oE '\b[a-z]{4,}\b' | head -2)
  SEARCH_TERMS="$SEARCH_TERMS $BRANCH_KEYWORDS"
fi

# Remove duplicates and limit to top terms
SEARCH_TERMS=$(echo "$SEARCH_TERMS" | tr ' ' '\n' | sort -u | head -5 | tr '\n' ' ')

# If no search terms, show recent entries instead
if [[ -z "$SEARCH_TERMS" ]]; then
  RELEVANT_KNOWLEDGE=$(tail -10 "$KNOWLEDGE_FILE" | jq -r '"\(.type | ascii_upcase): \(.content)"' 2>/dev/null)
else
  RELEVANT_KNOWLEDGE=""

  # Try FTS5 first
  if command -v sqlite3 &>/dev/null; then
    if [[ -f "$SCRIPT_DIR/knowledge-db.sh" ]]; then
      source "$SCRIPT_DIR/knowledge-db.sh"
      DB_PATH="$MEMORY_DIR/knowledge.db"

      # Incremental sync (imports new entries from JSONL into FTS5)
      kb_sync "$DB_PATH" "$MEMORY_DIR"
      kb_ensure_db "$DB_PATH"

      RELEVANT_KNOWLEDGE=$(kb_search "$DB_PATH" "$SEARCH_TERMS" 10 | while IFS='|' read -r type content bead tags; do
        echo "$(echo "$type" | tr '[:lower:]' '[:upper:]'): $content"
      done)
    fi
  fi

  # Grep fallback if FTS5 didn't produce results
  if [[ -z "$RELEVANT_KNOWLEDGE" ]]; then
    for TERM in $SEARCH_TERMS; do
      MATCHES=$(grep -i "$TERM" "$KNOWLEDGE_FILE" 2>/dev/null | jq -r '"\(.type | ascii_upcase): \(.content)"' 2>/dev/null | head -3)
      if [[ -n "$MATCHES" ]]; then
        RELEVANT_KNOWLEDGE="$RELEVANT_KNOWLEDGE
$MATCHES"
      fi
    done

    RELEVANT_KNOWLEDGE=$(echo "$RELEVANT_KNOWLEDGE" | sort -u | head -10)
  fi
fi

# If we found relevant knowledge, output it
if [[ -n "$RELEVANT_KNOWLEDGE" ]]; then
  cat << EOF
{"hookSpecificOutput":{"systemMessage":"## Relevant Knowledge from Memory\n\nBased on your current work context:\n\n$RELEVANT_KNOWLEDGE\n\n_Use \`.beads/memory/recall.sh \"keyword\"\` to search for more._"}}
EOF
fi

exit 0

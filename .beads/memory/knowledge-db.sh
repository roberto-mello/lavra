#!/bin/bash
#
# knowledge-db.sh - Shared library for SQLite FTS5 knowledge operations
#
# Provides functions for creating, inserting, searching, and backfilling
# a SQLite FTS5 knowledge database. All inserts use CSV .import via temp
# files to avoid SQL string interpolation (injection-safe).
#
# Usage: source knowledge-db.sh
#
# Functions:
#   kb_ensure_db DB_PATH         - Create schema if missing
#   kb_insert DB_PATH KEY TYPE CONTENT SOURCE TAGS_TEXT TS BEAD - Insert entry
#   kb_search DB_PATH QUERY TOP_N - FTS5 search with BM25 ranking
#   kb_sync DB_PATH MEMORY_DIR     - Incremental sync from JSONL + first-time beads import
#   kb_backfill DB_PATH MEMORY_DIR - Alias for kb_sync (backward compat)
#

# Create knowledge.db with FTS5 schema if missing
kb_ensure_db() {
  local DB_PATH="$1"

  if [[ -z "$DB_PATH" ]]; then
    return 1
  fi

  # Check if table already exists
  if [[ -f "$DB_PATH" ]]; then
    local HAS_TABLE
    HAS_TABLE=$(sqlite3 "$DB_PATH" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='knowledge';" 2>/dev/null || echo "0")

    if [[ "$HAS_TABLE" -gt 0 ]]; then
      return 0
    fi
  fi

  sqlite3 "$DB_PATH" <<'SQL'
CREATE TABLE IF NOT EXISTS knowledge(
  key TEXT PRIMARY KEY,
  type TEXT,
  content TEXT,
  source TEXT,
  tags_text TEXT,
  ts INTEGER,
  bead TEXT
);

CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_fts USING fts5(
  content, tags_text, type, key,
  content=knowledge,
  content_rowid=rowid,
  tokenize='porter unicode61'
);

CREATE TRIGGER IF NOT EXISTS knowledge_ai AFTER INSERT ON knowledge BEGIN
  INSERT INTO knowledge_fts(rowid, content, tags_text, type, key)
  VALUES (new.rowid, new.content, new.tags_text, new.type, new.key);
END;
SQL
}

# Insert a knowledge entry using CSV .import (zero SQL string interpolation)
kb_insert() {
  local DB_PATH="$1"
  local KEY="$2"
  local TYPE="$3"
  local CONTENT="$4"
  local SOURCE="$5"
  local TAGS_TEXT="$6"
  local TS="$7"
  local BEAD="$8"

  if [[ -z "$DB_PATH" ]] || [[ -z "$KEY" ]]; then
    return 1
  fi

  # Check for duplicate key (sanitize key for safe SQL literal)
  local SAFE_KEY
  SAFE_KEY=$(echo "$KEY" | tr -cd 'a-zA-Z0-9_-')
  local EXISTS
  EXISTS=$(sqlite3 "$DB_PATH" "SELECT count(*) FROM knowledge WHERE key='$SAFE_KEY';" 2>/dev/null || echo "0")

  if [[ "$EXISTS" -gt 0 ]]; then
    return 0
  fi

  # Write CSV temp file using jq for proper escaping
  local TMPFILE
  TMPFILE=$(mktemp "${TMPDIR:-/tmp}/kb-insert.XXXXXX")

  jq -nr \
    --arg key "$KEY" \
    --arg type "$TYPE" \
    --arg content "$CONTENT" \
    --arg source "$SOURCE" \
    --arg tags_text "$TAGS_TEXT" \
    --argjson ts "${TS:-0}" \
    --arg bead "$BEAD" \
    '[$key, $type, $content, $source, $tags_text, $ts, $bead] | @csv' > "$TMPFILE"

  sqlite3 "$DB_PATH" ".mode csv" ".import '$TMPFILE' knowledge" 2>/dev/null
  local RC=$?

  rm -f "$TMPFILE"
  return $RC
}

# FTS5 MATCH search with BM25 ranking
# Output: type|content|bead|tags_text (pipe-delimited)
kb_search() {
  local DB_PATH="$1"
  local QUERY="$2"
  local TOP_N="${3:-10}"

  if [[ -z "$DB_PATH" ]] || [[ -z "$QUERY" ]] || [[ ! -f "$DB_PATH" ]]; then
    return 0
  fi

  # Extract 2+ char alphanumeric terms (strips all SQL-dangerous characters)
  local TERMS
  TERMS=$(echo "$QUERY" | grep -oE '\b[a-zA-Z0-9_.]{2,}\b' | sort -u)

  if [[ -z "$TERMS" ]]; then
    return 0
  fi

  # Build FTS5 MATCH expression: quote each term, join with OR
  local FTS_QUERY=""
  while IFS= read -r TERM; do
    if [[ -n "$FTS_QUERY" ]]; then
      FTS_QUERY="$FTS_QUERY OR \"$TERM\""
    else
      FTS_QUERY="\"$TERM\""
    fi
  done <<< "$TERMS"

  if [[ -z "$FTS_QUERY" ]]; then
    return 0
  fi

  # BM25 weights: content=-10, tags_text=-5, type=-2, key=-1
  sqlite3 -separator '|' "$DB_PATH" <<SQL
SELECT k.type, k.content, k.bead, k.tags_text
FROM knowledge_fts fts
JOIN knowledge k ON k.rowid = fts.rowid
WHERE knowledge_fts MATCH '$FTS_QUERY'
ORDER BY bm25(knowledge_fts, -10.0, -5.0, -2.0, -1.0)
LIMIT $TOP_N;
SQL
}

# Incremental sync from JSONL files into SQLite FTS5
# Compares line counts to import only new entries. Safe to call every session.
# First-time: also imports knowledge-prefixed comments from beads.db.
kb_sync() {
  local DB_PATH="$1"
  local MEMORY_DIR="$2"

  if [[ -z "$DB_PATH" ]] || [[ -z "$MEMORY_DIR" ]]; then
    return 1
  fi

  kb_ensure_db "$DB_PATH"

  local DB_COUNT
  DB_COUNT=$(sqlite3 "$DB_PATH" "SELECT count(*) FROM knowledge;" 2>/dev/null || echo "0")

  # First-time: import from beads.db comments (only when SQLite is empty)
  if [[ "$DB_COUNT" -eq 0 ]]; then
    local BEADS_DB
    BEADS_DB="${CLAUDE_PROJECT_DIR:-.}/.beads/beads.db"

    if [[ -f "$BEADS_DB" ]] && command -v sqlite3 &>/dev/null; then
      local COMMENTS
      COMMENTS=$(sqlite3 "$BEADS_DB" "SELECT text FROM comments WHERE text LIKE 'LEARNED:%' OR text LIKE 'DECISION:%' OR text LIKE 'FACT:%' OR text LIKE 'PATTERN:%' OR text LIKE 'INVESTIGATION:%';" 2>/dev/null || true)

      if [[ -n "$COMMENTS" ]]; then
        while IFS= read -r COMMENT; do
          [[ -z "$COMMENT" ]] && continue

          local PREFIX TYPE CONTENT SLUG KEY

          for P in INVESTIGATION LEARNED DECISION FACT PATTERN; do
            if echo "$COMMENT" | grep -q "^${P}:"; then
              PREFIX="$P"
              break
            fi
          done

          [[ -z "$PREFIX" ]] && continue

          TYPE=$(echo "$PREFIX" | tr '[:upper:]' '[:lower:]')
          CONTENT=$(echo "$COMMENT" | sed "s/^${PREFIX}:[[:space:]]*//" | head -c 2048)
          SLUG=$(echo "$CONTENT" | head -c 60 | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')
          KEY="${TYPE}-${SLUG}"

          kb_insert "$DB_PATH" "$KEY" "$TYPE" "$CONTENT" "backfill" "" "$(date +%s)" ""
        done <<< "$COMMENTS"
      fi
    fi

    # Re-read count after beads import
    DB_COUNT=$(sqlite3 "$DB_PATH" "SELECT count(*) FROM knowledge;" 2>/dev/null || echo "0")
  fi

  # Incremental import from JSONL files
  _kb_sync_jsonl "$DB_PATH" "$MEMORY_DIR/knowledge.jsonl" "$DB_COUNT"
  _kb_sync_jsonl "$DB_PATH" "$MEMORY_DIR/knowledge.archive.jsonl" "$DB_COUNT"
}

# Import tail of a JSONL file, skipping lines likely already in SQLite.
# $3 = current DB row count (used to compute how many lines to skip).
# kb_insert already deduplicates on key, so re-importing a few lines is safe.
_kb_sync_jsonl() {
  local DB_PATH="$1"
  local JSONL_FILE="$2"
  local DB_COUNT="$3"

  [[ ! -f "$JSONL_FILE" ]] && return 0

  local FILE_LINES
  FILE_LINES=$(wc -l < "$JSONL_FILE" 2>/dev/null | tr -d ' ')
  [[ "$FILE_LINES" -eq 0 ]] && return 0

  # How many lines to import: difference + 50 margin for safety
  local SKIP=$(( DB_COUNT - 50 ))
  [[ "$SKIP" -lt 0 ]] && SKIP=0

  tail -n +"$(( SKIP + 1 ))" "$JSONL_FILE" | while IFS= read -r LINE; do
    [[ -z "$LINE" ]] && continue

    local KEY TYPE CONTENT SOURCE TAGS_TEXT TS BEAD
    KEY=$(echo "$LINE" | jq -r '.key // empty' 2>/dev/null)
    [[ -z "$KEY" ]] && continue

    TYPE=$(echo "$LINE" | jq -r '.type // ""' 2>/dev/null)
    CONTENT=$(echo "$LINE" | jq -r '.content // ""' 2>/dev/null)
    SOURCE=$(echo "$LINE" | jq -r '.source // ""' 2>/dev/null)
    TAGS_TEXT=$(echo "$LINE" | jq -r '(.tags // []) | join(" ")' 2>/dev/null)
    TS=$(echo "$LINE" | jq -r '.ts // 0' 2>/dev/null)
    BEAD=$(echo "$LINE" | jq -r '.bead // ""' 2>/dev/null)

    kb_insert "$DB_PATH" "$KEY" "$TYPE" "$CONTENT" "$SOURCE" "$TAGS_TEXT" "$TS" "$BEAD"
  done
}

# Backward-compatible alias
kb_backfill() {
  kb_sync "$@"
}

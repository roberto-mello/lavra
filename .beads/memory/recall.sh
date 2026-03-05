#!/bin/bash
#
# Search the knowledge base (.beads/memory/knowledge.jsonl)
#
# Usage:
#   recall.sh "keyword"                    # Search by keyword
#   recall.sh "keyword" --type learned     # Filter by type
#   recall.sh --recent 10                  # Show latest N entries
#   recall.sh --stats                      # Knowledge base stats
#   recall.sh "keyword" --all              # Include archive
#   recall.sh --topic BD-005               # Filter by epic parent
#

MEMORY_DIR="${CLAUDE_PROJECT_DIR:-.}/.beads/memory"
KNOWLEDGE_FILE="$MEMORY_DIR/knowledge.jsonl"
ARCHIVE_FILE="$MEMORY_DIR/knowledge.archive.jsonl"

if [[ ! -f "$KNOWLEDGE_FILE" ]]; then
  echo "No knowledge base found at $KNOWLEDGE_FILE"
  exit 0
fi

# Parse args
QUERY=""
TYPE_FILTER=""
RECENT=0
SHOW_STATS=false
INCLUDE_ARCHIVE=false
TOPIC_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) TYPE_FILTER="$2"; shift 2 ;;
    --recent) RECENT="$2"; shift 2 ;;
    --stats) SHOW_STATS=true; shift ;;
    --all) INCLUDE_ARCHIVE=true; shift ;;
    --topic) TOPIC_ID="$2"; shift 2 ;;
    *) QUERY="$1"; shift ;;
  esac
done

# Stats mode
if $SHOW_STATS; then
  TOTAL=$(wc -l < "$KNOWLEDGE_FILE" | tr -d ' ')
  ARCHIVE_COUNT=0
  [[ -f "$ARCHIVE_FILE" ]] && ARCHIVE_COUNT=$(wc -l < "$ARCHIVE_FILE" | tr -d ' ')

  echo "Knowledge base: $KNOWLEDGE_FILE"
  echo "Active entries: $TOTAL"
  echo "Archived: $ARCHIVE_COUNT"
  echo ""
  echo "By type:"
  jq -r '.type' "$KNOWLEDGE_FILE" 2>/dev/null | sort | uniq -c | sort -rn
  echo ""
  echo "Top tags:"
  jq -r '.tags[]' "$KNOWLEDGE_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -15
  exit 0
fi

# Topic mode -- filter by bead parent
if [[ -n "$TOPIC_ID" ]]; then
  if ! command -v bd &>/dev/null; then
    echo "bd not found -- cannot query topic children"
    exit 1
  fi

  CHILDREN=$(bd list --parent "$TOPIC_ID" --json 2>/dev/null | jq -r '.[].id' 2>/dev/null)

  if [[ -z "$CHILDREN" ]]; then
    echo "No children found for topic $TOPIC_ID"
    exit 0
  fi

  for CHILD_ID in $CHILDREN; do
    grep "\"bead\":\"$CHILD_ID\"" "$KNOWLEDGE_FILE" 2>/dev/null
  done | jq -r '"\(.type | ascii_upcase): \(.content)"' 2>/dev/null
  exit 0
fi

# Build input (optionally include archive)
INPUT_FILES="$KNOWLEDGE_FILE"
$INCLUDE_ARCHIVE && [[ -f "$ARCHIVE_FILE" ]] && INPUT_FILES="$ARCHIVE_FILE $KNOWLEDGE_FILE"

# Recent mode
if [[ "$RECENT" -gt 0 ]]; then
  cat $INPUT_FILES | tail -"$RECENT" | jq -r '"\(.type | ascii_upcase): \(.content)"' 2>/dev/null
  exit 0
fi

# Search mode
if [[ -z "$QUERY" ]]; then
  echo "Usage: recall.sh \"keyword\" [--type TYPE] [--recent N] [--stats] [--all] [--topic ID]"
  exit 0
fi

# FTS5 search if available
USED_FTS5=false

if command -v sqlite3 &>/dev/null; then
  DB_PATH="$MEMORY_DIR/knowledge.db"
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

  if [[ -f "$DB_PATH" ]] && [[ -f "$SCRIPT_DIR/knowledge-db.sh" ]]; then
    source "$SCRIPT_DIR/knowledge-db.sh"
    RAW_RESULTS=$(kb_search "$DB_PATH" "$QUERY" 20)

    if [[ -n "$RAW_RESULTS" ]]; then
      # Apply type filter and format
      RESULTS=""

      while IFS='|' read -r type content bead tags; do
        [[ -z "$type" ]] && continue

        if [[ -n "$TYPE_FILTER" ]] && [[ "$type" != "$TYPE_FILTER" ]]; then
          continue
        fi

        TYPE_UPPER=$(echo "$type" | tr '[:lower:]' '[:upper:]')
        RESULTS="${RESULTS}[$TYPE_UPPER] $content
  bead: $bead | $tags
"
      done <<< "$RAW_RESULTS"

      if [[ -n "$RESULTS" ]]; then
        echo "$RESULTS"
        USED_FTS5=true
      fi
    fi
  fi
fi

if [[ "$USED_FTS5" = false ]]; then
  # Grep fallback
  RESULTS=$(grep -i "$QUERY" $INPUT_FILES 2>/dev/null)

  if [[ -n "$TYPE_FILTER" ]]; then
    RESULTS=$(echo "$RESULTS" | jq -r "select(.type == \"$TYPE_FILTER\")" 2>/dev/null)
  fi

  echo "$RESULTS" | jq -rs '
    [.[] | select(.key != null)] |
    unique_by(.key) |
    sort_by(-.ts) |
    .[] |
    "[\(.type | ascii_upcase)] \(.content)\n  bead: \(.bead) | \(.tags | join(", "))"
  ' 2>/dev/null
fi

#!/bin/bash
#
# PostToolUse:Bash (async) - Capture knowledge from bd comments add commands
#
# Detects: bd comments add {BEAD_ID} "INVESTIGATION: ..." / "LEARNED: ..." /
#          "DECISION: ..." / "FACT: ..." / "PATTERN: ..."
# Extracts knowledge entries into .lavra/memory/knowledge.jsonl
#

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

[[ "$TOOL_NAME" != "Bash" ]] && exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$COMMAND" ]] && exit 0

echo "$COMMAND" | grep -qE 'bd\s+comments?\s+add\s+' || exit 0
echo "$COMMAND" | grep -qE '(INVESTIGATION:|LEARNED:|DECISION:|FACT:|PATTERN:|DEVIATION:)' || exit 0

# Extract BEAD_ID
BEAD_ID=$(echo "$COMMAND" | sed -E 's/.*bd[[:space:]]+comments?[[:space:]]+add[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+.*/\1/')
[[ -z "$BEAD_ID" || "$BEAD_ID" == "$COMMAND" ]] && exit 0

# Extract comment body
COMMENT_BODY=$(echo "$COMMAND" | sed -E 's/.*bd[[:space:]]+comments?[[:space:]]+add[[:space:]]+[A-Za-z0-9._-]+[[:space:]]+["'\'']//' | sed -E 's/["'\''][[:space:]]*$//' | head -c 4096)
[[ -z "$COMMENT_BODY" ]] && exit 0

# Detect type from prefix
TYPE=""
CONTENT=""

for PREFIX in INVESTIGATION LEARNED DECISION FACT PATTERN DEVIATION; do
  if echo "$COMMENT_BODY" | grep -q "${PREFIX}:"; then
    TYPE=$(echo "$PREFIX" | tr '[:upper:]' '[:lower:]')
    CONTENT=$(echo "$COMMENT_BODY" | sed "s/.*${PREFIX}:[[:space:]]*//" | head -c 2048)
    break
  fi
done

[[ -z "$TYPE" || -z "$CONTENT" ]] && exit 0

# Generate key
SLUG=$(echo "$CONTENT" | head -c 60 | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')
KEY="${TYPE}-${SLUG}"

# Detect source
SOURCE="user"
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if echo "$CWD" | grep -q '\.worktrees/'; then
  SOURCE="supervisor"
fi

# Build tags
TAGS_ARRAY=("$TYPE")

for tag in swift swiftui appkit menubar api security test database \
           networking ui layout performance crash bug fix workaround \
           gotcha pattern convention architecture auth middleware \
           async concurrency model protocol adapter scanner engine \
           decision tradeoff rationale constraint deprecat migration \
           schema endpoint route validation error config env deploy \
           cache queue retry timeout rate-limit pagination rollback \
           react nextjs typescript python rust go docker postgres \
           redis graphql rest webhook cron worker job; do
  if echo "$CONTENT" | grep -qi "$tag"; then
    TAGS_ARRAY+=("$tag")
  fi
done

TAGS_JSON=$(printf '%s\n' "${TAGS_ARRAY[@]}" | jq -R . | jq -s .)

TS=$(date +%s)

ENTRY=$(jq -cn \
  --arg key "$KEY" \
  --arg type "$TYPE" \
  --arg content "$CONTENT" \
  --arg source "$SOURCE" \
  --argjson tags "$TAGS_JSON" \
  --argjson ts "$TS" \
  --arg bead "$BEAD_ID" \
  '{key: $key, type: $type, content: $content, source: $source, tags: $tags, ts: $ts, bead: $bead}')

[[ -z "$ENTRY" ]] && exit 0
echo "$ENTRY" | jq . >/dev/null 2>&1 || exit 0

MEMORY_DIR="${CLAUDE_PROJECT_DIR:-${CWD:-.}}/.lavra/memory"
mkdir -p "$MEMORY_DIR"
KNOWLEDGE_FILE="$MEMORY_DIR/knowledge.jsonl"

# SQLite dual-write (graceful fallback if sqlite3 unavailable)
if command -v sqlite3 &>/dev/null; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  if [[ -f "$SCRIPT_DIR/knowledge-db.sh" ]]; then
    source "$SCRIPT_DIR/knowledge-db.sh"
    TAGS_TEXT=$(echo "$TAGS_JSON" | jq -r '.[]' 2>/dev/null | tr '\n' ' ')
    kb_ensure_db "$MEMORY_DIR/knowledge.db"
    kb_insert "$MEMORY_DIR/knowledge.db" "$KEY" "$TYPE" "$CONTENT" "$SOURCE" "$TAGS_TEXT" "$TS" "$BEAD_ID"
  fi
fi

echo "$ENTRY" >> "$KNOWLEDGE_FILE"

# Rotation: archive oldest 2500 when file exceeds 5000 lines
# High threshold avoids rewriting the file (which breaks merge=union)
LINE_COUNT=$(wc -l < "$KNOWLEDGE_FILE" 2>/dev/null | tr -d ' ')

if [[ "$LINE_COUNT" -gt 5000 ]]; then
  ARCHIVE_FILE="$MEMORY_DIR/knowledge.archive.jsonl"
  head -2500 "$KNOWLEDGE_FILE" >> "$ARCHIVE_FILE"
  tail -n +2501 "$KNOWLEDGE_FILE" > "$KNOWLEDGE_FILE.tmp"
  mv "$KNOWLEDGE_FILE.tmp" "$KNOWLEDGE_FILE"
fi

exit 0

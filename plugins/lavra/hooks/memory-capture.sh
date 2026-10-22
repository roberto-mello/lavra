#!/bin/bash
#
# PostToolUse:Bash (async) - Capture knowledge from bd comments add commands
#
# Detects: bd comments add {BEAD_ID} "INVESTIGATION: ..." / "LEARNED: ..." /
#          "DECISION: ..." / "FACT: ..." / "PATTERN: ..." / "DEVIATION: ..."
# Extracts knowledge entries into .lavra/memory/knowledge.jsonl
#

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

[[ "$TOOL_NAME" != "Bash" && "$TOOL_NAME" != "bash" ]] && exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$COMMAND" ]] && exit 0

echo "$COMMAND" | grep -qE 'bd\s+comments?\s+add\s+' || exit 0
echo "$COMMAND" | grep -qE '(INVESTIGATION:|LEARNED:|DECISION:|FACT:|PATTERN:|DEVIATION:|SKIP:|MUST-CHECK:)' || exit 0

# SKIP is a valid gate-satisfier but produces no knowledge entry
echo "$COMMAND" | grep -qE 'SKIP:' && exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=sanitize-content.sh
if [[ -f "$SCRIPT_DIR/sanitize-content.sh" ]]; then
  source "$SCRIPT_DIR/sanitize-content.sh"
else
  sanitize_untrusted_content() { cat; }
fi

# Validate CLAUDE_PROJECT_DIR to prevent redirect attacks
# Placed AFTER early-exit guards (PostToolUse fires very frequently; this runs on ~1% of calls)
if [[ -n "$CLAUDE_PROJECT_DIR" ]]; then
  CANONICAL=$(realpath -m "$CLAUDE_PROJECT_DIR" 2>/dev/null || echo "")
  if [[ -z "$CANONICAL" ]] || [[ "$CANONICAL" != /* ]] || \
     [[ "$CANONICAL" != "$HOME"/* && "$CANONICAL" != /tmp/* ]]; then
    CLAUDE_PROJECT_DIR=""  # fall through to CWD
  fi
fi

# Scope extraction to the first bd comments add call that carries a knowledge prefix.
# A shell line can hold several chained calls ("a && b", "a; b"). A pattern with a
# leading greedy .* matches the *last* call, so the first body was dropped and the
# second body was attributed to the first bead id. Put every call on its own line
# first, then keep the first line that has a prefix after the bead id.
CALLS=$(echo "$COMMAND" \
  | sed -E 's/bd[[:space:]]+comments?[[:space:]]+add[[:space:]]+/\nBDCOMMENTADD /g' \
  | grep -E '^BDCOMMENTADD ')
[[ -z "$CALLS" ]] && exit 0

PREFIX_RE='(INVESTIGATION:|LEARNED:|DECISION:|FACT:|PATTERN:|DEVIATION:|MUST-CHECK:)'
MATCH_LINE=$(echo "$CALLS" | grep -m1 -E "^BDCOMMENTADD [A-Za-z0-9._-]+[[:space:]]+[\"']?${PREFIX_RE}")
[[ -z "$MATCH_LINE" ]] && exit 0
MATCH_LINE=${MATCH_LINE#BDCOMMENTADD }

# Extract BEAD_ID: the token right after the subcommand.
BEAD_ID=${MATCH_LINE%%[[:space:]]*}
# Explicit post-extraction strip: makes sanitization intent visible at the use-site
BEAD_ID=$(echo "$BEAD_ID" | tr -cd 'A-Za-z0-9._-')
[[ -z "$BEAD_ID" ]] && exit 0

# Extract comment body as the text between the first and the last quote.
# `#` strips the shortest prefix and `%` the shortest suffix, so neither runs past
# the first opening quote or the last closing quote. The previous sed stripped
# from the first quote that sat before a shell operator, which cut the body at an
# embedded quoted term ("... a separate 'qmd embed' pass" became "... a separate ").
# ponytail: heuristic parser, a body that ends with an unbalanced quote still loses
# its tail; use a real tokenizer if comment bodies ever need exact round-trips.
QUOTE_CHARS="\"'"
COMMENT_BODY=${MATCH_LINE#*[$QUOTE_CHARS]}
COMMENT_BODY=${COMMENT_BODY%[$QUOTE_CHARS]*}
COMMENT_BODY=$(echo "$COMMENT_BODY" | head -c 4096)
[[ -z "$COMMENT_BODY" ]] && exit 0

# Detect type from prefix
TYPE=""
CONTENT=""

for PREFIX in INVESTIGATION LEARNED DECISION FACT PATTERN DEVIATION MUST_CHECK; do
  # MUST_CHECK uses hyphen in the comment prefix but underscore as bash variable name
  COMMENT_PREFIX="${PREFIX//_/-}"
  if echo "$COMMENT_BODY" | grep -q "${COMMENT_PREFIX}:"; then
    if [[ "$PREFIX" == "MUST_CHECK" ]]; then
      TYPE="must-check"
    else
      TYPE=$(echo "$PREFIX" | tr '[:upper:]' '[:lower:]')
    fi
    CONTENT=$(echo "$COMMENT_BODY" | sed "s/.*${COMMENT_PREFIX}:[[:space:]]*//" | sanitize_untrusted_content | head -c 2048)
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

for tag in swift swiftui appkit menubar api security test database must-check \
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
  if [[ -f "$SCRIPT_DIR/knowledge-db.sh" ]]; then
    source "$SCRIPT_DIR/knowledge-db.sh"
    TAGS_TEXT=$(echo "$TAGS_JSON" | jq -r '.[]' 2>/dev/null | tr '\n' ' ')
    kb_ensure_db "$MEMORY_DIR/knowledge.db"
    kb_insert "$MEMORY_DIR/knowledge.db" "$KEY" "$TYPE" "$CONTENT" "$SOURCE" "$TAGS_TEXT" "$TS" "$BEAD_ID"
  fi
fi

# Check for duplicate key before appending to JSONL
if [[ -f "$KNOWLEDGE_FILE" ]] && grep -qF "\"key\":\"$KEY\"" "$KNOWLEDGE_FILE"; then
  exit 0  # Skip duplicate
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

# Curate active knowledge in the background. Keep this off the hot path:
# the scheduler only marks memory as dirty and spawns a sanitizer if idle.
if [[ -f "$SCRIPT_DIR/memory-sanitize.sh" ]]; then
  "$SCRIPT_DIR/memory-sanitize.sh" --schedule memory-capture "$MEMORY_DIR" >/dev/null 2>&1 || true
fi

exit 0

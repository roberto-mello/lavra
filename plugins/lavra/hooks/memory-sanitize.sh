#!/bin/bash
#
# Background memory sanitization for Lavra
#
# Hot-path hooks should call:
#   memory-sanitize.sh --schedule [reason] [memory_dir]
#
# The scheduler is cheap: it marks memory as dirty, acquires no long-lived
# resources, and only spawns a background sanitizer if one is not already
# running. The sanitizer then builds a curated active knowledge file and FTS
# index from raw append-only memory.
#

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GO_HELPER_DIR="$SCRIPT_DIR/memorysanitize"

resolve_memory_dir() {
  local EXPLICIT_DIR="${1:-}"

  if [[ -n "$EXPLICIT_DIR" ]]; then
    echo "$EXPLICIT_DIR"
    return 0
  fi

  local PROJECT_ROOT
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    PROJECT_ROOT="$CLAUDE_PROJECT_DIR"
  else
    PROJECT_ROOT="$PWD"
    while [[ "$PROJECT_ROOT" != "/" ]] && [[ ! -d "$PROJECT_ROOT/.lavra" ]]; do
      PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
    done
  fi

  echo "$PROJECT_ROOT/.lavra/memory"
}

canonical_dir() {
  local DIR_PATH="$1"
  cd "$DIR_PATH" 2>/dev/null && pwd -P
}

assert_safe_memory_path() {
  local MEMORY_DIR="$1"
  local TARGET_PATH="$2"
  local REQUIRE_EXISTING_PARENT="${3:-false}"
  local MEMORY_REAL
  local PARENT_REAL
  local PARENT_DIR

  MEMORY_REAL="$(canonical_dir "$MEMORY_DIR")" || return 1

  if [[ -L "$TARGET_PATH" ]]; then
    return 1
  fi

  PARENT_DIR="$(dirname "$TARGET_PATH")"
  if [[ "$REQUIRE_EXISTING_PARENT" == "true" && ! -d "$PARENT_DIR" ]]; then
    return 1
  fi

  PARENT_REAL="$(canonical_dir "$PARENT_DIR")" || return 1
  [[ "$PARENT_REAL" == "$MEMORY_REAL" ]]
}

write_marker_file() {
  local MEMORY_DIR="$1"
  local TARGET_PATH="$2"
  local CONTENT="$3"
  local TMPFILE

  assert_safe_memory_path "$MEMORY_DIR" "$TARGET_PATH" true || return 1

  TMPFILE=$(mktemp "$MEMORY_DIR/.marker.XXXXXX") || return 1
  printf '%s\n' "$CONTENT" > "$TMPFILE" || {
    rm -f "$TMPFILE"
    return 1
  }

  rm -f "$TARGET_PATH"
  mv "$TMPFILE" "$TARGET_PATH"
}

build_go_helper() {
  local MEMORY_DIR="$1"
  local MEMORY_REAL
  MEMORY_REAL="$(canonical_dir "$MEMORY_DIR")" || return 1
  local BIN_PATH="$MEMORY_REAL/.memory-sanitize-go"

  if [[ ! -d "$GO_HELPER_DIR" ]]; then
    return 1
  fi

  if ! command -v go &>/dev/null; then
    return 1
  fi

  if [[ -x "$BIN_PATH" && "$BIN_PATH" -nt "$GO_HELPER_DIR/main.go" && "$BIN_PATH" -nt "$GO_HELPER_DIR/go.mod" ]]; then
    echo "$BIN_PATH"
    return 0
  fi

  local TMP_BIN
  TMP_BIN=$(mktemp "$MEMORY_REAL/.memory-sanitize-go.tmp.XXXXXX") || return 1

  if ! (cd "$GO_HELPER_DIR" && go build -o "$TMP_BIN" .) >/dev/null 2>&1; then
    rm -f "$TMP_BIN"
    return 1
  fi

  chmod +x "$TMP_BIN" || {
    rm -f "$TMP_BIN"
    return 1
  }

  mv "$TMP_BIN" "$BIN_PATH" || {
    rm -f "$TMP_BIN"
    return 1
  }

  echo "$BIN_PATH"
}

sanitize_once() {
  local MEMORY_DIR="$1"
  local KNOWLEDGE_FILE="$MEMORY_DIR/knowledge.jsonl"
  local ARCHIVE_FILE="$MEMORY_DIR/knowledge.archive.jsonl"
  local ACTIVE_FILE="$MEMORY_DIR/knowledge.active.jsonl"
  local AUDIT_FILE="$MEMORY_DIR/knowledge.audit.jsonl"
  local ACTIVE_DB="$MEMORY_DIR/knowledge.active.db"
  local PROJECT_ROOT=""
  local GO_BIN=""
  local TMPFILE
  TMPFILE=$(mktemp "${TMPDIR:-/tmp}/lavra-active.XXXXXX")
  PROJECT_ROOT="$(canonical_dir "$MEMORY_DIR/../.." 2>/dev/null || true)"

  assert_safe_memory_path "$MEMORY_DIR" "$ACTIVE_FILE" true || {
    rm -f "$TMPFILE"
    return 1
  }
  assert_safe_memory_path "$MEMORY_DIR" "$AUDIT_FILE" true || {
    rm -f "$TMPFILE"
    return 1
  }
  assert_safe_memory_path "$MEMORY_DIR" "$ACTIVE_DB" true || {
    rm -f "$TMPFILE"
    return 1
  }

  GO_BIN="$(build_go_helper "$MEMORY_DIR" || true)"

  if [[ -n "$GO_BIN" ]]; then
    local AUDIT_TMP
    AUDIT_TMP=$(mktemp "${TMPDIR:-/tmp}/lavra-audit.XXXXXX")
    if "$GO_BIN" \
      --knowledge-file "$KNOWLEDGE_FILE" \
      --archive-file "$ARCHIVE_FILE" \
      --active-file "$TMPFILE" \
      --audit-file "$AUDIT_TMP" \
      --project-root "$PROJECT_ROOT"; then
      mv "$TMPFILE" "$ACTIVE_FILE"
      mv "$AUDIT_TMP" "$AUDIT_FILE"
    else
      rm -f "$AUDIT_TMP"
      rm -f "$TMPFILE"
      return 1
    fi
  elif [[ ! -f "$KNOWLEDGE_FILE" ]]; then
    : > "$TMPFILE"
    : > "$AUDIT_FILE"
    mv "$TMPFILE" "$ACTIVE_FILE"
  else
    local INPUTS=()
    [[ -f "$ARCHIVE_FILE" ]] && INPUTS+=("$ARCHIVE_FILE")
    INPUTS+=("$KNOWLEDGE_FILE")

    jq -c -Rcs '
      def normalize_text:
        ascii_downcase
        | gsub("\"[[:space:]]*(2>&1|\\|\\||&&|\\||;).*$"; "")
        | gsub("[[:space:]]+(2>&1|\\|\\||&&|\\||;).*$"; "")
        | gsub("[[:space:]]+"; " ")
        | gsub("^ +| +$"; "");
      def canonical_text:
        normalize_text
        | gsub("[^a-z0-9]+"; " ")
        | gsub("^ +| +$"; "");
      def noisy_entry:
        (.content | normalize_text) as $text
        | ($text | test("^(bd|git|bash|cat|echo|for|if) ")) or
          ($text | startswith("## ")) or
          ($text | test("^```")) or
          ($text | test("^<[^>]+>$"));

      split("\n")
      | map(select(length > 0) | fromjson?)
      | map(select(type == "object" and (.key // "") != "" and (.content // "") != ""))
      | map(.content = (.content | normalize_text))
      | map(select((.content | length) > 0))
      | map(select(noisy_entry | not))
      |
      sort_by(.ts // 0) |
      reverse |
      unique_by((.key // "") | ascii_downcase) |
      unique_by(
        ((.type // "") | ascii_downcase) + "|" +
        ((.content // "") | canonical_text)
      ) |
      sort_by(.ts // 0) |
      .[]
    ' "${INPUTS[@]}" > "$TMPFILE" 2>/dev/null || cp "$KNOWLEDGE_FILE" "$TMPFILE"
    : > "$AUDIT_FILE"
    mv "$TMPFILE" "$ACTIVE_FILE"
  fi

  if command -v sqlite3 &>/dev/null && [[ -f "$SCRIPT_DIR/knowledge-db.sh" ]]; then
    # shellcheck source=knowledge-db.sh
    source "$SCRIPT_DIR/knowledge-db.sh"
    kb_rebuild_from_files "$ACTIVE_DB" "$ACTIVE_FILE"
  fi
}

schedule_run() {
  local MEMORY_DIR="$1"
  local REASON="${2:-unknown}"
  local MARKER_FILE="$MEMORY_DIR/.sanitize-needed"
  local LOCK_DIR="$MEMORY_DIR/.sanitize.lock"
  local TOKEN

  mkdir -p "$MEMORY_DIR"
  TOKEN="$(date +%s)-$$-$REASON"
  write_marker_file "$MEMORY_DIR" "$MARKER_FILE" "$TOKEN" || exit 0

  if [[ -L "$LOCK_DIR" ]]; then
    exit 0
  fi

  if [[ -d "$LOCK_DIR" ]]; then
    exit 0
  fi

  if command -v nohup &>/dev/null; then
    nohup bash "$0" --run "$MEMORY_DIR" >/dev/null 2>&1 &
  else
    (bash "$0" --run "$MEMORY_DIR" >/dev/null 2>&1 &)
  fi
}

run_sanitizer() {
  local MEMORY_DIR="$1"
  local LOCK_DIR="$MEMORY_DIR/.sanitize.lock"
  local MARKER_FILE="$MEMORY_DIR/.sanitize-needed"
  local LAST_RUN_FILE="$MEMORY_DIR/.sanitize.last-run"
  local PASS=0

  mkdir -p "$MEMORY_DIR"
  assert_safe_memory_path "$MEMORY_DIR" "$MARKER_FILE" true || exit 0
  assert_safe_memory_path "$MEMORY_DIR" "$LAST_RUN_FILE" true || exit 0
  if [[ -L "$LOCK_DIR" ]]; then
    exit 0
  fi
  mkdir "$LOCK_DIR" 2>/dev/null || exit 0

  trap "rmdir '$LOCK_DIR' 2>/dev/null || true" EXIT INT TERM

  while [[ "$PASS" -lt 3 ]]; do
    PASS=$((PASS + 1))
    local START_MARKER=""
    local END_MARKER=""

    [[ -f "$MARKER_FILE" ]] && START_MARKER="$(cat "$MARKER_FILE" 2>/dev/null || true)"

    if ! sanitize_once "$MEMORY_DIR"; then
      exit 1
    fi

    write_marker_file "$MEMORY_DIR" "$LAST_RUN_FILE" "$(date +%s)" || exit 1
    [[ -f "$MARKER_FILE" ]] && END_MARKER="$(cat "$MARKER_FILE" 2>/dev/null || true)"

    if [[ -z "$END_MARKER" || "$END_MARKER" == "$START_MARKER" ]]; then
      rm -f "$MARKER_FILE"
      break
    fi
  done
}

MODE="${1:-}"
ARG2="${2:-}"
ARG3="${3:-}"

case "$MODE" in
  --schedule)
    schedule_run "$(resolve_memory_dir "$ARG3")" "${ARG2:-scheduled}"
    ;;
  --run)
    run_sanitizer "$(resolve_memory_dir "$ARG2")"
    ;;
  *)
    cat <<'EOF'
Usage:
  memory-sanitize.sh --schedule [reason] [memory_dir]
  memory-sanitize.sh --run [memory_dir]
EOF
    exit 1
    ;;
esac

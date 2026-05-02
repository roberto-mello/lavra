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

sanitize_once() {
  local MEMORY_DIR="$1"
  local KNOWLEDGE_FILE="$MEMORY_DIR/knowledge.jsonl"
  local ARCHIVE_FILE="$MEMORY_DIR/knowledge.archive.jsonl"
  local ACTIVE_FILE="$MEMORY_DIR/knowledge.active.jsonl"
  local ACTIVE_DB="$MEMORY_DIR/knowledge.active.db"
  local TMPFILE
  TMPFILE=$(mktemp "${TMPDIR:-/tmp}/lavra-active.XXXXXX")

  if [[ ! -f "$KNOWLEDGE_FILE" ]]; then
    : > "$TMPFILE"
  else
    local INPUTS=()
    [[ -f "$ARCHIVE_FILE" ]] && INPUTS+=("$ARCHIVE_FILE")
    INPUTS+=("$KNOWLEDGE_FILE")

    jq -c -s '
      map(select(type == "object" and (.key // "") != "" and (.content // "") != "")) |
      sort_by(.ts // 0) |
      reverse |
      unique_by((.key // "") | ascii_downcase) |
      unique_by(
        ((.type // "") | ascii_downcase) + "|" +
        (
          (.content // "")
          | ascii_downcase
          | gsub("[^a-z0-9]+"; " ")
          | gsub("^ +| +$"; "")
        )
      ) |
      sort_by(.ts // 0) |
      .[]
    ' "${INPUTS[@]}" > "$TMPFILE" 2>/dev/null || cp "$KNOWLEDGE_FILE" "$TMPFILE"
  fi

  mv "$TMPFILE" "$ACTIVE_FILE"

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
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
  fi

  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

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

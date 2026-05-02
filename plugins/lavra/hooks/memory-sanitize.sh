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
  local AUDIT_FILE="$MEMORY_DIR/knowledge.audit.jsonl"
  local ACTIVE_DB="$MEMORY_DIR/knowledge.active.db"
  local PROJECT_ROOT=""
  local PYTHON_BIN=""
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

  PYTHON_BIN="$(command -v python3 || command -v python || true)"

  if [[ -n "$PYTHON_BIN" ]]; then
    local AUDIT_TMP
    AUDIT_TMP=$(mktemp "${TMPDIR:-/tmp}/lavra-audit.XXXXXX")
    MEMORY_DIR="$MEMORY_DIR" \
    KNOWLEDGE_FILE="$KNOWLEDGE_FILE" \
    ARCHIVE_FILE="$ARCHIVE_FILE" \
    ACTIVE_FILE="$TMPFILE" \
    AUDIT_FILE="$AUDIT_TMP" \
    PROJECT_ROOT="$PROJECT_ROOT" \
    "$PYTHON_BIN" <<'PY'
import json
import os
import re
import shutil
import subprocess
import time

memory_dir = os.environ["MEMORY_DIR"]
knowledge_file = os.environ["KNOWLEDGE_FILE"]
archive_file = os.environ["ARCHIVE_FILE"]
active_file = os.environ["ACTIVE_FILE"]
audit_file = os.environ["AUDIT_FILE"]
project_root = os.environ.get("PROJECT_ROOT", "")
timestamp = int(time.time())

path_re = re.compile(r"(?:^|[`(\s])((?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+\.[A-Za-z0-9_-]+)")
backtick_symbol_re = re.compile(r"`([A-Za-z_][A-Za-z0-9_]{2,})`")
call_symbol_re = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]{2,})\(")


def normalize_text(value: str) -> str:
    value = value.lower()
    value = re.sub(r'"\s*(2>&1|\|\||&&|\||;).*$','', value)
    value = re.sub(r'\s+(2>&1|\|\||&&|\||;).*$','', value)
    value = re.sub(r'\s+',' ', value)
    return value.strip()


def canonical_text(value: str) -> str:
    value = normalize_text(value)
    value = re.sub(r'[^a-z0-9]+', ' ', value)
    value = re.sub(r'\s+', ' ', value)
    return value.strip()


def is_noisy(content: str) -> bool:
    text = normalize_text(content)
    return (
        re.match(r'^(bd|git|bash|cat|echo|for|if)\s', text) is not None
        or text.startswith("## ")
        or text.startswith("```")
        or re.match(r"^<[^>]+>$", text) is not None
    )


def extract_files(content: str):
    seen = []
    for match in path_re.findall(content):
        if match not in seen:
            seen.append(match)
    return seen[:8]


def extract_symbols(content: str):
    seen = []
    for regex in (backtick_symbol_re, call_symbol_re):
        for match in regex.findall(content):
            if match not in seen:
                seen.append(match)
    return seen[:6]


def resolve_anchor(path: str):
    if not project_root:
        return None
    full = os.path.realpath(os.path.join(project_root, path))
    if not full.startswith(project_root + os.sep):
        return None
    return full


def symbol_exists(symbol: str) -> bool:
    if not project_root:
        return False
    rg = shutil.which("rg")
    if not rg:
        return False
    cmd = [
        rg,
        "--files-with-matches",
        "--fixed-strings",
        "--max-count",
        "1",
        "-g",
        "!.git/**",
        "-g",
        "!.lavra/**",
        "-g",
        "!node_modules/**",
        symbol,
        project_root,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0


audit_entries = []
valid_entries = []
summary = {
    "invalid_json": 0,
    "filtered_noise": 0,
    "duplicate_key": 0,
    "duplicate_content": 0,
    "stale_candidate": 0,
    "needs_review": 0,
    "active": 0,
}

sources = []
if os.path.exists(archive_file):
    sources.append(("archive", archive_file))
sources.append(("raw", knowledge_file))

for source_name, path in sources:
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        for lineno, line in enumerate(handle, 1):
            line = line.rstrip("\n")
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                summary["invalid_json"] += 1
                audit_entries.append({
                    "ts": timestamp,
                    "action": "skip_invalid_json",
                    "source": source_name,
                    "line": lineno,
                    "reason": "invalid_json",
                })
                continue
            if not isinstance(obj, dict):
                continue
            if not obj.get("key") or not obj.get("content"):
                continue
            obj["content"] = normalize_text(str(obj.get("content", "")))
            if not obj["content"]:
                continue
            if is_noisy(obj["content"]):
                summary["filtered_noise"] += 1
                audit_entries.append({
                    "ts": timestamp,
                    "action": "filter_noise",
                    "key": obj.get("key", ""),
                    "source": source_name,
                    "reason": "command_like_content",
                })
                continue
            valid_entries.append(obj)

valid_entries.sort(key=lambda item: item.get("ts", 0), reverse=True)

by_key = {}
for entry in valid_entries:
    lowered = str(entry.get("key", "")).lower()
    if lowered in by_key:
        summary["duplicate_key"] += 1
        audit_entries.append({
            "ts": timestamp,
            "action": "dedupe_key",
            "key": entry.get("key", ""),
            "kept_key": by_key[lowered].get("key", ""),
            "reason": "duplicate_key",
        })
        continue
    by_key[lowered] = entry

deduped = list(by_key.values())
by_content = {}
final_entries = []
for entry in deduped:
    content_key = f"{str(entry.get('type', '')).lower()}|{canonical_text(entry.get('content', ''))}"
    if content_key in by_content:
        summary["duplicate_content"] += 1
        audit_entries.append({
            "ts": timestamp,
            "action": "dedupe_content",
            "key": entry.get("key", ""),
            "kept_key": by_content[content_key].get("key", ""),
            "reason": "duplicate_content",
        })
        continue
    by_content[content_key] = entry
    final_entries.append(entry)

final_entries.sort(key=lambda item: item.get("ts", 0))
active_entries = []

for entry in final_entries:
    files = extract_files(entry.get("content", ""))
    symbols = extract_symbols(entry.get("content", ""))
    existing_files = []
    missing_files = []
    for rel in files:
        full = resolve_anchor(rel)
        if full and os.path.exists(full):
            existing_files.append(rel)
        else:
            missing_files.append(rel)

    existing_symbols = []
    missing_symbols = []
    if not files:
        for symbol in symbols[:4]:
            if symbol_exists(symbol):
                existing_symbols.append(symbol)
            else:
                missing_symbols.append(symbol)

    reasons = []
    status = "active"
    confidence = "medium"

    if files:
        if existing_files and missing_files:
            status = "needs_review"
            confidence = "medium"
            reasons.append("partial_missing_file_anchor")
        elif missing_files and not existing_files:
            status = "stale_candidate"
            confidence = "low"
            reasons.append("missing_file_anchor")
        else:
            status = "active"
            confidence = "high"
            reasons.append("file_anchor_match")
    elif existing_symbols:
        status = "active"
        confidence = "medium"
        reasons.append("symbol_anchor_match")
    elif missing_symbols:
        status = "needs_review"
        confidence = "low"
        reasons.append("missing_symbol_anchor")
    else:
        reasons.append("unanchored_memory")

    entry["local_sanitized_ts"] = timestamp
    entry["local_confidence"] = confidence
    entry["local_status"] = status
    entry["local_reasons"] = reasons
    entry["local_anchors"] = {
        "files": files,
        "symbols": symbols,
        "existing_files": existing_files,
        "missing_files": missing_files,
    }

    summary[status] = summary.get(status, 0) + 1

    if status == "stale_candidate":
        audit_entries.append({
            "ts": timestamp,
            "action": "drop_stale_candidate",
            "key": entry.get("key", ""),
            "status": status,
            "confidence": confidence,
            "reasons": reasons,
            "anchors": entry["local_anchors"],
        })
        continue

    if status == "needs_review":
        audit_entries.append({
            "ts": timestamp,
            "action": "flag_needs_review",
            "key": entry.get("key", ""),
            "status": status,
            "confidence": confidence,
            "reasons": reasons,
            "anchors": entry["local_anchors"],
        })

    active_entries.append(entry)

audit_entries.append({
    "ts": timestamp,
    "action": "summary",
    "summary": summary,
})

with open(active_file, "w", encoding="utf-8") as handle:
    for entry in active_entries:
        handle.write(json.dumps(entry, ensure_ascii=True, separators=(",", ":")) + "\n")

with open(audit_file, "w", encoding="utf-8") as handle:
    for entry in audit_entries:
        handle.write(json.dumps(entry, ensure_ascii=True, separators=(",", ":")) + "\n")
PY
    local PY_RC=$?
    if [[ "$PY_RC" -eq 0 ]]; then
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

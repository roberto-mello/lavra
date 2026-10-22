#!/usr/bin/env bash
#
# Self-check for plugins/lavra/hooks/memory-capture.sh extraction.
#
# Guards two regressions:
#   1. two chained `bd comments add` calls on one line: the first call must win;
#   2. an embedded quoted term inside the body must survive extraction.
#
# Usage: bash scripts/test-memory-capture.sh [path/to/memory-capture.sh]

set -uo pipefail

HOOK="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/plugins/lavra/hooks/memory-capture.sh}"
# Resolve to an absolute path: cases run with a temporary directory as CWD.
HOOK=$(cd "$(dirname "$HOOK")" 2>/dev/null && pwd)/$(basename "$HOOK")
[[ -f "$HOOK" ]] || { echo "FAIL hook not found: $HOOK"; exit 1; }

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

FAILURES=0
CASE=0

# run_case <name> <command> -> leaves .type/.content/.bead of the first entry in $OUT_*
run_case() {
  local name="$1" command="$2"
  CASE=$((CASE + 1))
  local dir="$TMP_ROOT/case$CASE"
  mkdir -p "$dir"
  jq -cn --arg c "$command" --arg d "$dir" \
    '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' > "$dir/in.json"
  ( cd "$dir" && env -u CLAUDE_PROJECT_DIR bash "$HOOK" < in.json >/dev/null 2>&1 )
  local file="$dir/.lavra/memory/knowledge.jsonl"
  if [[ -f "$file" ]]; then
    OUT_TYPE=$(jq -r '.type' "$file" | head -1)
    OUT_CONTENT=$(jq -r '.content' "$file" | head -1)
    OUT_BEAD=$(jq -r '.bead' "$file" | head -1)
  else
    OUT_TYPE="" OUT_CONTENT="" OUT_BEAD=""
  fi
  OUT_NAME="$name"
}

check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok   [$OUT_NAME] $label"
  else
    echo "FAIL [$OUT_NAME] $label"
    echo "       expected: $expected"
    echo "       actual:   $actual"
    FAILURES=$((FAILURES + 1))
  fi
}

# 1. Two chained calls on one line: the first body and the first bead id win.
run_case "chained-calls" \
  'bd comments add medsimples-aa "LEARNED: first body." 2>&1 | tail -3 && bd comments add medsimples-bb "FACT: second body." 2>&1 | tail -3'
check "type" "learned" "$OUT_TYPE"
check "content" "first body." "$OUT_CONTENT"
check "bead" "medsimples-aa" "$OUT_BEAD"

# 2. Embedded quoted term inside the body is not a terminator.
run_case "embedded-quotes" \
  "bd comments add medsimples-cc \"LEARNED: run 'qmd embed' after qmd update.\" 2>&1 | tail -3"
check "content" "run 'qmd embed' after qmd update." "$OUT_CONTENT"

# 3. Semicolon-chained calls behave like && chaining.
run_case "semicolon-chained" \
  'bd comments add medsimples-dd "DECISION: keep block order."; bd comments add medsimples-ee "FACT: ignored."'
check "type" "decision" "$OUT_TYPE"
check "content" "keep block order." "$OUT_CONTENT"
check "bead" "medsimples-dd" "$OUT_BEAD"

# 4. A call without a knowledge prefix is skipped in favour of the next one.
run_case "skip-prefixless" \
  'bd comments add medsimples-ff "plain note" && bd comments add medsimples-gg "PATTERN: prefixed body."'
check "type" "pattern" "$OUT_TYPE"
check "content" "prefixed body." "$OUT_CONTENT"
check "bead" "medsimples-gg" "$OUT_BEAD"

# 5. MUST-CHECK keeps its hyphenated type.
run_case "must-check" \
  'bd comments add medsimples-hh "MUST-CHECK: verify the callback allowlist." 2>&1'
check "type" "must-check" "$OUT_TYPE"

# 6. Single quoted comment argument.
run_case "single-quoted" \
  "bd comments add medsimples-ii 'FACT: single quoted body.'"
check "content" "single quoted body." "$OUT_CONTENT"

echo
if [[ "$FAILURES" -eq 0 ]]; then
  echo "PASS memory-capture extraction ($CASE cases)"
  exit 0
fi

echo "FAIL memory-capture extraction: $FAILURES assertion(s) failed"
exit 1

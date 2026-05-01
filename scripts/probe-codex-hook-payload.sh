#!/bin/bash
#
# Capture raw Codex hook payload from stdin and print field map used by Lavra.
#
# Usage:
#   cat sample.json | scripts/probe-codex-hook-payload.sh
#   # or wire as temporary hook command in Codex and inspect output file
#

set -euo pipefail

OUT_DIR="${1:-/tmp/lavra-codex-probes}"
mkdir -p "$OUT_DIR"

TS="$(date +%Y%m%d-%H%M%S)"
RAW_FILE="$OUT_DIR/payload-$TS.json"
MAP_FILE="$OUT_DIR/field-map-$TS.txt"

INPUT="$(cat)"
if [[ -z "$INPUT" ]]; then
  echo "No stdin payload received."
  exit 1
fi

printf '%s\n' "$INPUT" > "$RAW_FILE"

{
  echo "raw_file=$RAW_FILE"
  echo "timestamp=$TS"
  echo ""
  echo "[top-level keys]"
  echo "$INPUT" | jq -r 'keys[]?' 2>/dev/null || true
  echo ""
  echo "[candidate tool name fields]"
  echo "tool_name=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  echo "toolName=$(echo "$INPUT" | jq -r '.toolName // empty' 2>/dev/null)"
  echo "event.tool_name=$(echo "$INPUT" | jq -r '.event.tool_name // empty' 2>/dev/null)"
  echo "event.toolName=$(echo "$INPUT" | jq -r '.event.toolName // empty' 2>/dev/null)"
  echo ""
  echo "[candidate command fields]"
  echo "tool_input.command=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  echo "toolInput.command=$(echo "$INPUT" | jq -r '.toolInput.command // empty' 2>/dev/null)"
  echo "input.command=$(echo "$INPUT" | jq -r '.input.command // empty' 2>/dev/null)"
  echo "event.tool_input.command=$(echo "$INPUT" | jq -r '.event.tool_input.command // empty' 2>/dev/null)"
  echo ""
  echo "[cwd candidates]"
  echo "cwd=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
  echo "project_dir=$(echo "$INPUT" | jq -r '.project_dir // empty' 2>/dev/null)"
  echo "event.cwd=$(echo "$INPUT" | jq -r '.event.cwd // empty' 2>/dev/null)"
} > "$MAP_FILE"

echo "Saved payload: $RAW_FILE"
echo "Saved field map: $MAP_FILE"

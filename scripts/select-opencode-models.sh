#!/bin/bash
#
# Interactive model selection for OpenCode installation
# Queries available models via 'opencode models' and lets user select preferences
# for each tier (haiku/sonnet/opus)
#
# Usage:
#   ./select-opencode-models.sh [--yes]
#
# With --yes: Uses defaults without prompting
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/shared/model-config.json"

# Parse --yes flag
AUTO_YES=false
for arg in "$@"; do
  case "$arg" in
    --yes|-y) AUTO_YES=true ;;
  esac
done

# Check if opencode is available
if ! command -v opencode &>/dev/null; then
  echo "[!] Error: 'opencode' command not found"
  echo "    OpenCode must be installed to query available models"
  exit 1
fi

# Query available models
echo "Querying available models from OpenCode..."
MODELS_OUTPUT=$(opencode models 2>&1 || true)

# Extract all models (not just Anthropic)
ALL_MODELS=$(echo "$MODELS_OUTPUT" | awk '{print $1}' | grep -E "/" | sort -u || true)

if [ -z "$ALL_MODELS" ]; then
  echo "[!] Warning: No models found in OpenCode"
  echo "    Using defaults from model-config.json"
  exit 0
fi

echo ""
echo "Found $(echo "$ALL_MODELS" | wc -l | tr -d ' ') models"
echo ""

# Load current config
if [ -f "$CONFIG_FILE" ]; then
  CURRENT_HAIKU=$(jq -r '.opencode.haiku' "$CONFIG_FILE")
  CURRENT_SONNET=$(jq -r '.opencode.sonnet' "$CONFIG_FILE")
  CURRENT_OPUS=$(jq -r '.opencode.opus' "$CONFIG_FILE")
else
  CURRENT_HAIKU="anthropic/claude-haiku-4-5-20251001"
  CURRENT_SONNET="anthropic/claude-sonnet-4-5-20250929"
  CURRENT_OPUS="anthropic/claude-opus-4-6"
fi

# If --yes flag, use current config
if [ "$AUTO_YES" = true ]; then
  echo "Using defaults (--yes flag):"
  echo "  haiku:  $CURRENT_HAIKU"
  echo "  sonnet: $CURRENT_SONNET"
  echo "  opus:   $CURRENT_OPUS"
  exit 0
fi

# Show all available models for every tier -- the user knows best which model
# fits each role. Trying to guess tiers from model names is brittle and hides
# models with unfamiliar names (Zen, Nemotron, Minimax, etc.).
HAIKU_MODELS="$ALL_MODELS"
SONNET_MODELS="$ALL_MODELS"
OPUS_MODELS="$ALL_MODELS"

# Interactive selection function
select_model() {
  local tier="$1"
  local description="$2"
  local current="$3"
  local models="$4"

  # All UI output goes to stderr so command substitution only captures the selection
  echo "---" >&2
  echo "" >&2
  echo "$tier tier: $description" >&2
  echo "" >&2

  # Create numbered list
  local i=1
  local model_array=()
  while IFS= read -r model; do
    [ -z "$model" ] && continue
    model_array+=("$model")
    if [ "$model" = "$current" ]; then
      printf "  %2d) %s  <-- current\n" "$i" "$model" >&2
    else
      printf "  %2d) %s\n" "$i" "$model" >&2
    fi
    i=$((i + 1))
  done <<< "$models"

  echo "" >&2

  # Get user selection (Enter = keep current)
  while true; do
    read -p "  Pick [1-$((i-1))], or Enter to keep current: " selection

    # Empty input = keep current
    if [ -z "$selection" ]; then
      echo "$current"
      return
    fi

    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -lt "$i" ]; then
      echo "${model_array[$((selection-1))]}"
      return
    fi

    echo "  Invalid. Enter a number between 1 and $((i-1)), or press Enter to keep current." >&2
  done
}

echo "Model Selection"
echo "==============="
echo ""
echo "Lavra uses three model tiers. Pick the model you want for each."
echo "You can use models from any provider (Anthropic, Google, OpenAI, etc)."
echo ""

# Select models for each tier
HAIKU_MODEL=$(select_model \
  "Haiku" \
  "Fast, cheap -- knowledge recall, lookups, simple tasks" \
  "$CURRENT_HAIKU" \
  "$HAIKU_MODELS")
echo ""

SONNET_MODEL=$(select_model \
  "Sonnet" \
  "Balanced -- most coding work, reviews, implementation" \
  "$CURRENT_SONNET" \
  "$SONNET_MODELS")
echo ""

OPUS_MODEL=$(select_model \
  "Opus" \
  "Most capable -- complex reasoning, architecture, planning" \
  "$CURRENT_OPUS" \
  "$OPUS_MODELS")
echo ""

# Confirm selections
echo "---"
echo ""
echo "Selected:"
echo "  Haiku:  $HAIKU_MODEL"
echo "  Sonnet: $SONNET_MODEL"
echo "  Opus:   $OPUS_MODEL"
echo ""

read -p "Save? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Not saved."
  exit 0
fi

# Create config directory if needed
mkdir -p "$(dirname "$CONFIG_FILE")"

# Load existing config or create new
if [ -f "$CONFIG_FILE" ]; then
  CONFIG=$(cat "$CONFIG_FILE")
else
  CONFIG='{}'
fi

# Update OpenCode models
CONFIG=$(echo "$CONFIG" | jq ".opencode.haiku = \"$HAIKU_MODEL\"")
CONFIG=$(echo "$CONFIG" | jq ".opencode.sonnet = \"$SONNET_MODEL\"")
CONFIG=$(echo "$CONFIG" | jq ".opencode.opus = \"$OPUS_MODEL\"")

# Ensure Gemini config exists (preserve existing if present)
if ! echo "$CONFIG" | jq -e '.gemini' >/dev/null 2>&1; then
  CONFIG=$(echo "$CONFIG" | jq '.gemini = {
    "haiku": "gemini-2.5-flash",
    "sonnet": "gemini-2.5-pro",
    "opus": "gemini-2.5-pro"
  }')
fi

# Write config file
echo "$CONFIG" | jq . > "$CONFIG_FILE"

echo ""
echo "Saved to: $CONFIG_FILE"

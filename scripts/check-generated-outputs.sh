#!/usr/bin/env bash
#
# Regenerate generated plugin outputs and fail if the checked-in artifacts drift.
#
# This keeps the runtime trees in sync with the canonical source under plugins/lavra/.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts"

echo "=== Generated output drift check ==="
echo "Regenerating OpenCode, Gemini, Cortex, and Codex outputs..."

(
  cd "$SCRIPTS_DIR"
  bun install --frozen-lockfile --silent
  bun run convert-opencode.ts
  bun run convert-gemini.ts
  bun run convert-cortex.ts
  bun run convert-codex.ts
)

CHANGED_FILES="$(git -C "$REPO_ROOT" diff --name-only -- \
  plugins/lavra/opencode \
  plugins/lavra/gemini \
  plugins/lavra/cortex \
  plugins/lavra/codex)"

if [[ -n "$CHANGED_FILES" ]]; then
  echo ""
  echo "FAIL Generated outputs drifted from source:"
  echo "$CHANGED_FILES"
  echo ""
  echo "Re-run the conversion scripts and commit the updated generated files."
  exit 1
fi

echo "PASS Generated outputs match canonical source"

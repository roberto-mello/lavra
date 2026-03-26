#!/usr/bin/env bash
# extract-bead-context.sh — Thin wrapper for source-tree usage.
# The canonical implementation lives in plugins/lavra/hooks/extract-bead-context.sh
# (installed to .claude/hooks/ in target projects).
# This wrapper delegates to that file so the source repo and installed projects
# run the same code.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CANONICAL="$SCRIPT_DIR/../plugins/lavra/hooks/extract-bead-context.sh"

if [[ ! -f "$CANONICAL" ]]; then
  echo "error: canonical extract-bead-context.sh not found at '$CANONICAL'" >&2
  exit 1
fi

exec bash "$CANONICAL" "$@"

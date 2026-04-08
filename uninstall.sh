#!/bin/bash
#
# lavra plugin uninstaller router
#
# Routes to platform-specific uninstallers based on flags.
# Defaults to Claude Code for backwards compatibility.
#
# Usage:
#   ./uninstall.sh                           # Claude Code (default)
#   ./uninstall.sh -claude /path/to/project  # Claude Code explicit
#   ./uninstall.sh -opencode                 # OpenCode
#   ./uninstall.sh -gemini                   # Gemini CLI
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM=""

# Display help
show_help() {
  cat <<EOF
lavra Plugin Uninstaller

Usage:
  ./uninstall.sh [PLATFORM] [TARGET]

Platforms:
  -claude, --claude       Uninstall from Claude Code (default)
  -opencode, --opencode   Uninstall from OpenCode
  -gemini, --gemini       Uninstall from Gemini CLI
  -cortex, --cortex       Uninstall from Cortex Code

Target:
  [path]                  Uninstall from specific project directory
  (omit)                  Uninstall from global install (~/.claude or platform equivalent)

Options:
  -h, --help              Show this help message

Examples:
  ./uninstall.sh                          # Global Claude Code uninstall
  ./uninstall.sh /path/to/project         # Project-specific Claude Code
  ./uninstall.sh -opencode                # Global OpenCode uninstall
  ./uninstall.sh -gemini /path/to/project # Project-specific Gemini uninstall
  ./uninstall.sh -cortex                  # Global Cortex Code uninstall

EOF
  exit 0
}

# Validate platform name (security: prevent command injection)
validate_platform() {
  local platform="$1"

  case "$platform" in
    claude|opencode|gemini|cortex)
      return 0
      ;;
    *)
      echo "[!] Error: Invalid platform '$platform'"
      echo "    Allowed platforms: claude, opencode, gemini, cortex"
      echo ""
      echo "Run './uninstall.sh --help' for usage information."
      exit 1
      ;;
  esac
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    -claude|--claude)
      PLATFORM="claude"
      shift
      ;;
    -opencode|--opencode)
      PLATFORM="opencode"
      shift
      ;;
    -gemini|--gemini)
      PLATFORM="gemini"
      shift
      ;;
    -cortex|--cortex)
      PLATFORM="cortex"
      shift
      ;;
    *)
      # Pass through to platform-specific uninstaller
      break
      ;;
  esac
done

# Default to Claude Code for backwards compatibility
if [ -z "$PLATFORM" ]; then
  PLATFORM="claude"
fi

# Validate platform name (security check)
validate_platform "$PLATFORM"

# Construct uninstaller path
UNINSTALLER="$SCRIPT_DIR/installers/uninstall-${PLATFORM}.sh"

# Verify uninstaller exists
if [[ ! -f "$UNINSTALLER" ]]; then
  echo "[!] Error: Uninstaller not found: $UNINSTALLER"
  echo "    Platform '$PLATFORM' may not be supported yet."
  exit 1
fi

# Security: Verify uninstaller path is in expected directory
UNINSTALLER_REAL="$(realpath "$UNINSTALLER")"
EXPECTED_DIR="$(realpath "$SCRIPT_DIR/installers")"

if [[ ! "$UNINSTALLER_REAL" =~ ^"$EXPECTED_DIR"/uninstall-[a-z]+\.sh$ ]]; then
  echo "[!] Error: Uninstaller path validation failed"
  echo "    Expected: $EXPECTED_DIR/uninstall-*.sh"
  echo "    Got: $UNINSTALLER_REAL"
  exit 1
fi

# Execute platform-specific uninstaller
# Use source instead of exec to allow better error handling
echo "🔄 Uninstalling lavra for $PLATFORM..."
echo ""

source "$UNINSTALLER" "$@"

#!/bin/bash
#
# lavra plugin installer router
#
# Routes to platform-specific installers based on flags.
# Defaults to Claude Code for backwards compatibility.
#
# Usage:
#   ./install.sh                           # Claude Code (default)
#   ./install.sh -claude /path/to/project  # Claude Code explicit
#   ./install.sh -opencode                 # OpenCode
#   ./install.sh -gemini                   # Gemini CLI
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM=""

# Display help
show_help() {
  cat <<EOF
lavra Plugin Installer

Usage:
  ./install.sh [PLATFORM] [TARGET] [OPTIONS]

Platforms:
  -claude, --claude       Install for Claude Code (default)
  -opencode, --opencode   Install for OpenCode
  -gemini, --gemini       Install for Gemini CLI
  -cortex, --cortex       Install for Cortex Code

Target:
  [path]                  Install to specific project directory
  (omit)                  Install globally to ~/.claude or platform equivalent

Options:
  -y, --yes               Skip confirmation prompts
  -h, --help              Show this help message

Examples:
  ./install.sh                          # Global Claude Code install
  ./install.sh /path/to/project         # Project-specific Claude Code
  ./install.sh -opencode                # Global OpenCode install
  ./install.sh -gemini /path/to/project # Project-specific Gemini install
  ./install.sh -cortex                  # Global Cortex Code install

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
      echo "Run './install.sh --help' for usage information."
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
      # Pass through to platform-specific installer
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

# Construct installer path
INSTALLER="$SCRIPT_DIR/installers/install-${PLATFORM}.sh"

# Verify installer exists
if [[ ! -f "$INSTALLER" ]]; then
  echo "[!] Error: Installer not found: $INSTALLER"
  echo "    Platform '$PLATFORM' may not be supported yet."
  exit 1
fi

# Security: Verify installer path is in expected directory
INSTALLER_REAL="$(realpath "$INSTALLER")"
EXPECTED_DIR="$(realpath "$SCRIPT_DIR/installers")"

if [[ ! "$INSTALLER_REAL" =~ ^"$EXPECTED_DIR"/install-[a-z]+\.sh$ ]]; then
  echo "[!] Error: Installer path validation failed"
  echo "    Expected: $EXPECTED_DIR/install-*.sh"
  echo "    Got: $INSTALLER_REAL"
  exit 1
fi

# Execute platform-specific installer
# Export SCRIPT_DIR so sourced installer can use it
export BEADS_MARKETPLACE_ROOT="$SCRIPT_DIR"

echo "Installing lavra for $PLATFORM..."
echo ""

source "$INSTALLER" "$@"
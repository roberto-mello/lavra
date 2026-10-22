#!/bin/bash
#
# Install lavra plugin for Codex.
# Current implementation reuses Cortex installer path.
#

set -euo pipefail

# shellcheck source=install-cortex.sh
export LAVRA_RUNTIME_VARIANT="codex"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-cortex.sh" "$@"

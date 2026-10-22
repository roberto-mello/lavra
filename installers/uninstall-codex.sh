#!/bin/bash
#
# Uninstall lavra plugin from Codex.
# Reuses Cortex uninstaller path with codex runtime variant.
#

set -euo pipefail

# shellcheck source=uninstall-cortex.sh
export LAVRA_RUNTIME_VARIANT="codex"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/uninstall-cortex.sh" "$@"

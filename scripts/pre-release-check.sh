#!/usr/bin/env bash
# Pre-release checks that mirror the CI verify-release job.
# Run this before tagging a release to catch failures locally.
#
# SYNC: This script must stay in sync with the `verify-release` job in
# .github/workflows/test-installation.yml. When modifying either file,
# update the other to match.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" 2>/dev/null; then
    echo "  PASS  $label"
    ((PASS++)) || true
  else
    echo "  FAIL  $label"
    ((FAIL++)) || true
  fi
}

fail() {
  local label="$1"
  local msg="$2"
  echo "  FAIL  $label: $msg"
  ((FAIL++)) || true
}

echo ""
echo "=== Version consistency ==="

PLUGIN_VERSION=$(jq -r '.version' plugins/lavra/.claude-plugin/plugin.json)
MARKETPLACE_VERSION=$(jq -r '.plugins[] | select(.name == "lavra") | .version' .claude-plugin/marketplace.json)

echo "  plugin.json:      $PLUGIN_VERSION"
echo "  marketplace.json: $MARKETPLACE_VERSION"

if [[ "$PLUGIN_VERSION" == "$MARKETPLACE_VERSION" ]]; then
  echo "  PASS  Versions match"
  ((PASS++)) || true
else
  fail "Version mismatch" "plugin.json=$PLUGIN_VERSION marketplace.json=$MARKETPLACE_VERSION"
fi

echo ""
echo "=== Hook version constants ==="

HOOK_VERSION=$(grep 'LAVRA_VERSION=' plugins/lavra/hooks/auto-recall.sh | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
PROVISION_VERSION=$(grep 'echo "' plugins/lavra/hooks/provision-memory.sh | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

echo "  auto-recall.sh:       $HOOK_VERSION"
echo "  provision-memory.sh:  $PROVISION_VERSION"

[[ "$HOOK_VERSION" == "$PLUGIN_VERSION" ]] && { echo "  PASS  auto-recall.sh version"; ((PASS++)) || true; } || fail "auto-recall.sh version" "has $HOOK_VERSION, expected $PLUGIN_VERSION"
[[ "$PROVISION_VERSION" == "$PLUGIN_VERSION" ]] && { echo "  PASS  provision-memory.sh version"; ((PASS++)) || true; } || fail "provision-memory.sh version" "has $PROVISION_VERSION, expected $PLUGIN_VERSION"

echo ""
echo "=== Conversion outputs ==="
echo "  Generating OpenCode and Gemini outputs..."
(cd scripts && bun install --frozen-lockfile --silent && bun run convert-opencode.ts && bun run convert-gemini.ts && bun run convert-cortex.ts) || {
  fail "Conversion scripts" "bun run failed"
}

echo ""
echo "=== Component counts ==="

COMMANDS=$(find plugins/lavra/commands -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
OPTIONAL_COMMANDS=$(find plugins/lavra/commands/optional -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
AGENTS=$(find plugins/lavra/agents -name "*.md" | wc -l | tr -d ' ')
SKILLS=$(find plugins/lavra/skills -name "SKILL.md" | wc -l | tr -d ' ')

echo "  Commands: $COMMANDS (need 23+) + $OPTIONAL_COMMANDS optional"
echo "  Agents:   $AGENTS (need 30+)"
echo "  Skills:   $SKILLS (need 15+)"

[[ "$COMMANDS" -ge 23 ]] && { echo "  PASS  Commands"; ((PASS++)) || true; } || fail "Commands" "$COMMANDS < 23"
[[ "$AGENTS"   -ge 30 ]] && { echo "  PASS  Agents";   ((PASS++)) || true; } || fail "Agents"   "$AGENTS < 30"
[[ "$SKILLS"   -ge 15 ]] && { echo "  PASS  Skills";   ((PASS++)) || true; } || fail "Skills"   "$SKILLS < 16"

echo ""
echo "=== Source files ==="

check "opencode-src/plugin.ts"    test -f plugins/lavra/opencode-src/plugin.ts
check "opencode-src/package.json" test -f plugins/lavra/opencode-src/package.json
check "gemini-src/settings.json"  test -f plugins/lavra/gemini-src/settings.json

echo ""
echo "=== Conversion output files ==="

check "opencode/ directory" test -d plugins/lavra/opencode
check "gemini/ directory"   test -d plugins/lavra/gemini
check "cortex/ directory"   test -d plugins/lavra/cortex

OPENCODE_COMMANDS=$(find plugins/lavra/opencode/commands -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
GEMINI_TOML=$(find plugins/lavra/gemini/commands -name "*.toml" 2>/dev/null | wc -l | tr -d ' ')

echo "  OpenCode .md commands: $OPENCODE_COMMANDS (need 23+)"
echo "  Gemini .toml commands: $GEMINI_TOML (need 23+)"

[[ "$OPENCODE_COMMANDS" -ge 23 ]] && { echo "  PASS  OpenCode commands"; ((PASS++)) || true; } || fail "OpenCode commands" "$OPENCODE_COMMANDS < 23"
[[ "$GEMINI_TOML"       -ge 23 ]] && { echo "  PASS  Gemini commands";   ((PASS++)) || true; } || fail "Gemini commands"   "$GEMINI_TOML < 23"

CORTEX_COMMANDS=$(find plugins/lavra/cortex/commands -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "  Cortex .md commands:   $CORTEX_COMMANDS (need 20+)"
[[ "$CORTEX_COMMANDS" -ge 20 ]] && { echo "  PASS  Cortex commands"; ((PASS++)) || true; } || fail "Cortex commands" "$CORTEX_COMMANDS < 20"

echo ""
echo "=== Command map ==="

check "site/public/command-map.html exists" test -f site/public/command-map.html

# Verify command map references current node counts (spot check: NODES array has entries)
MAP_NODES=$(grep -c "id:'" site/public/command-map.html || echo 0)
echo "  Command map nodes: $MAP_NODES (need 40+)"
[[ "$MAP_NODES" -ge 40 ]] && { echo "  PASS  Command map nodes"; ((PASS++)) || true; } || fail "Command map nodes" "$MAP_NODES < 40"

echo ""
echo "=== Compatibility tests ==="
(cd scripts && bun run test-compatibility.ts) && { echo "  PASS  Compatibility tests"; ((PASS++)) || true; } || fail "Compatibility tests" "see output above"

echo ""
echo "================================"
echo "  $PASS passed, $FAIL failed"
echo "================================"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "Fix the failures above before releasing."
  exit 1
fi

echo "All checks passed. Safe to release."

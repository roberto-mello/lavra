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

PLUGIN_VERSION=$(jq -r '.version' plugins/beads-compound/.claude-plugin/plugin.json)
MARKETPLACE_VERSION=$(jq -r '.plugins[] | select(.name == "beads-compound") | .version' .claude-plugin/marketplace.json)

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

HOOK_VERSION=$(grep 'BEADS_COMPOUND_VERSION=' plugins/beads-compound/hooks/auto-recall.sh | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
PROVISION_VERSION=$(grep 'echo "' plugins/beads-compound/hooks/provision-memory.sh | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

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

COMMANDS=$(find plugins/beads-compound/commands -name "*.md" | wc -l | tr -d ' ')
AGENTS=$(find plugins/beads-compound/agents -name "*.md" | wc -l | tr -d ' ')
SKILLS=$(find plugins/beads-compound/skills -name "SKILL.md" | wc -l | tr -d ' ')

echo "  Commands: $COMMANDS (need 29+)"
echo "  Agents:   $AGENTS (need 29+)"
echo "  Skills:   $SKILLS (need 16+)"

[[ "$COMMANDS" -ge 29 ]] && { echo "  PASS  Commands"; ((PASS++)) || true; } || fail "Commands" "$COMMANDS < 29"
[[ "$AGENTS"   -ge 29 ]] && { echo "  PASS  Agents";   ((PASS++)) || true; } || fail "Agents"   "$AGENTS < 29"
[[ "$SKILLS"   -ge 16 ]] && { echo "  PASS  Skills";   ((PASS++)) || true; } || fail "Skills"   "$SKILLS < 16"

echo ""
echo "=== Source files ==="

check "opencode-src/plugin.ts"    test -f plugins/beads-compound/opencode-src/plugin.ts
check "opencode-src/package.json" test -f plugins/beads-compound/opencode-src/package.json
check "gemini-src/settings.json"  test -f plugins/beads-compound/gemini-src/settings.json

echo ""
echo "=== Conversion output files ==="

check "opencode/ directory" test -d plugins/beads-compound/opencode
check "gemini/ directory"   test -d plugins/beads-compound/gemini
check "cortex/ directory"   test -d plugins/beads-compound/cortex

OPENCODE_COMMANDS=$(find plugins/beads-compound/opencode/commands -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
GEMINI_TOML=$(find plugins/beads-compound/gemini/commands -name "*.toml" 2>/dev/null | wc -l | tr -d ' ')

echo "  OpenCode .md commands: $OPENCODE_COMMANDS (need 29+)"
echo "  Gemini .toml commands: $GEMINI_TOML (need 29+)"

[[ "$OPENCODE_COMMANDS" -ge 29 ]] && { echo "  PASS  OpenCode commands"; ((PASS++)) || true; } || fail "OpenCode commands" "$OPENCODE_COMMANDS < 29"
[[ "$GEMINI_TOML"       -ge 29 ]] && { echo "  PASS  Gemini commands";   ((PASS++)) || true; } || fail "Gemini commands"   "$GEMINI_TOML < 29"

CORTEX_COMMANDS=$(find plugins/beads-compound/cortex/commands -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "  Cortex .md commands:   $CORTEX_COMMANDS (need 25+)"
[[ "$CORTEX_COMMANDS" -ge 25 ]] && { echo "  PASS  Cortex commands"; ((PASS++)) || true; } || fail "Cortex commands" "$CORTEX_COMMANDS < 25"

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

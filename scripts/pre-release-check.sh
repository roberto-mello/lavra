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
NPM_VERSION=$(jq -r '.version' package.json)

echo "  plugin.json:      $PLUGIN_VERSION"
echo "  marketplace.json: $MARKETPLACE_VERSION"
echo "  package.json:     $NPM_VERSION"

if [[ "$PLUGIN_VERSION" == "$MARKETPLACE_VERSION" ]]; then
  echo "  PASS  Versions match"
  ((PASS++)) || true
else
  fail "Version mismatch" "plugin.json=$PLUGIN_VERSION marketplace.json=$MARKETPLACE_VERSION"
fi

[[ "$NPM_VERSION" == "$PLUGIN_VERSION" ]] && { echo "  PASS  package.json version"; ((PASS++)) || true; } || fail "package.json version" "has $NPM_VERSION, expected $PLUGIN_VERSION"

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

echo "  Commands: $COMMANDS (need 18+) + $OPTIONAL_COMMANDS optional"
echo "  Agents:   $AGENTS (need 30+)"
echo "  Skills:   $SKILLS (need 21+)"

[[ "$COMMANDS" -ge 18 ]] && { echo "  PASS  Commands"; ((PASS++)) || true; } || fail "Commands" "$COMMANDS < 18"
[[ "$AGENTS"   -ge 30 ]] && { echo "  PASS  Agents";   ((PASS++)) || true; } || fail "Agents"   "$AGENTS < 30"
[[ "$SKILLS"   -ge 21 ]] && { echo "  PASS  Skills";   ((PASS++)) || true; } || fail "Skills"   "$SKILLS < 21"

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

echo "  OpenCode .md commands: $OPENCODE_COMMANDS (need 18+)"
echo "  Gemini .toml commands: $GEMINI_TOML (need 18+)"

[[ "$OPENCODE_COMMANDS" -ge 18 ]] && { echo "  PASS  OpenCode commands"; ((PASS++)) || true; } || fail "OpenCode commands" "$OPENCODE_COMMANDS < 18"
[[ "$GEMINI_TOML"       -ge 18 ]] && { echo "  PASS  Gemini commands";   ((PASS++)) || true; } || fail "Gemini commands"   "$GEMINI_TOML < 18"

CORTEX_COMMANDS=$(find plugins/lavra/cortex/commands -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "  Cortex .md commands:   $CORTEX_COMMANDS (need 18+)"
[[ "$CORTEX_COMMANDS" -ge 18 ]] && { echo "  PASS  Cortex commands"; ((PASS++)) || true; } || fail "Cortex commands" "$CORTEX_COMMANDS < 18"

echo ""
echo "=== Command map ==="

check "site/public/command-map.html exists" test -f site/public/command-map.html

# Verify command map references current node counts (spot check: NODES array has entries)
MAP_NODES=$(grep -c "id:'" site/public/command-map.html || echo 0)
echo "  Command map nodes: $MAP_NODES (need 40+)"
[[ "$MAP_NODES" -ge 40 ]] && { echo "  PASS  Command map nodes"; ((PASS++)) || true; } || fail "Command map nodes" "$MAP_NODES < 40"

echo ""
echo "=== Catalog accuracy ==="
# SYNC: This section must stay in sync with the verify-docs step in .github/workflows/test-installation.yml.
# When modifying either, update the other.

# Extract command names from CATALOG.md table rows only (lines starting with |)
# to avoid matching prose mentions like "Included in `/lavra-design`"
CATALOG_COMMANDS=$(grep -E '^\|' site/src/content/docs/CATALOG.md | \
  grep -oE '`/[a-z][a-z0-9-]+`' | tr -d '`' | sed 's|^/||' | sort -u)

# Actual command files (core + optional, recurse into subdirs)
ACTUAL_COMMANDS=$(find plugins/lavra/commands -name "*.md" | \
  xargs -I{} basename {} .md 2>/dev/null | sort -u)

GHOST_COUNT=0
MISSING_COUNT=0

# Check for ghost commands (in catalog, no file exists)
while IFS= read -r cmd; do
  if ! echo "$ACTUAL_COMMANDS" | grep -qx "$cmd"; then
    fail "Catalog ghost" "/${cmd} listed in CATALOG.md but no ${cmd}.md file found"
    ((GHOST_COUNT++)) || true
  fi
done <<< "$CATALOG_COMMANDS"

# Check for missing catalog entries (file exists, not in catalog)
while IFS= read -r cmd; do
  if ! echo "$CATALOG_COMMANDS" | grep -qx "$cmd"; then
    fail "Missing from catalog" "${cmd}.md exists but /${cmd} not in CATALOG.md"
    ((MISSING_COUNT++)) || true
  fi
done <<< "$ACTUAL_COMMANDS"

if [[ "$GHOST_COUNT" -eq 0 && "$MISSING_COUNT" -eq 0 ]]; then
  echo "  PASS  Catalog accuracy (no ghosts, no missing entries)"
  ((PASS++)) || true
fi

echo ""
echo "=== Sanitizer sync ==="
# Verify the wrapper in scripts/ delegates to the canonical hooks/ version
# (no inline fallback that could drift from sanitize-content.sh)
check "extract-bead-context.sh in hooks/ (canonical)" test -f plugins/lavra/hooks/extract-bead-context.sh
check "scripts/extract-bead-context.sh is a thin wrapper (no inline fallback)" \
  bash -c '! grep -q "sanitize_untrusted_content()" scripts/extract-bead-context.sh'

echo ""
echo "=== Compatibility tests ==="
(cd scripts && bun run test-compatibility.ts) && { echo "  PASS  Compatibility tests"; ((PASS++)) || true; } || fail "Compatibility tests" "see output above"

echo ""
echo "=== Prose style check ==="
FILLER='Make sure to|Note that|Be sure to|you will|In order to|simply|basically|actually'
if ! command -v rg &>/dev/null; then
  echo "  WARN  Prose style check skipped (ripgrep not installed)"
elif rg --quiet "$FILLER" plugins/lavra/commands/ plugins/lavra/skills/ plugins/lavra/agents/ 2>/dev/null; then
  echo "  WARN  Filler phrases found (not blocking):"
  rg --no-heading -n "$FILLER" plugins/lavra/commands/ plugins/lavra/skills/ plugins/lavra/agents/ | head -20
else
  echo "  PASS  No filler phrases detected"
  ((PASS++)) || true
fi

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

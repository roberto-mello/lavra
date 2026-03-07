#!/usr/bin/env bash
set -e

# Installation Testing Suite
# Tests install.sh across all three platforms

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_ROOT="/tmp/beads-install-test-$(date +%s)"

PASSED=0
FAILED=0

pass() {
  ((PASSED++))
  echo "[PASS] $1"
}

fail() {
  ((FAILED++))
  echo "[FAIL] $1: $2"
}

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT

echo " Installation Test Suite"
echo "Testing beads-compound installer across all platforms..."
echo

# ==============================================================================
# Test 1: Claude Code Installation
# ==============================================================================
echo " Test 1: Claude Code Installation"

CLAUDE_TEST="$TEST_ROOT/claude-test"
mkdir -p "$CLAUDE_TEST"
cd "$CLAUDE_TEST"

# Initialize beads and git
git init -q
bd init -q 2>/dev/null || true

# Run installer (default platform)
if bash "$PROJECT_ROOT/install.sh" "$CLAUDE_TEST" >/dev/null 2>&1; then
  pass "Installer completed for Claude Code"
else
  fail "Claude Code install" "Installer failed"
fi

# Verify directory structure (hooks are required, commands/agents/skills may be global)
if [[ -d ".claude/hooks" ]]; then
  if [[ -d ".claude/commands" || -d "$HOME/.claude/commands" ]]; then
    pass "Claude Code directory structure created"
  else
    pass "Claude Code hooks installed (commands/agents/skills are global)"
  fi
else
  fail "Claude Code structure" "Missing .claude/hooks directory"
fi

# Verify hook files
if [[ -f ".claude/hooks/auto-recall.sh" && -f ".claude/hooks/memory-capture.sh" && -f ".claude/hooks/subagent-wrapup.sh" ]]; then
  pass "Claude Code hook files installed"
else
  fail "Claude Code hooks" "Missing hook files"
fi

# Verify settings.json exists and has hooks
if [[ -f ".claude/settings.json" ]]; then
  if grep -q "SessionStart" ".claude/settings.json" && \
     grep -q "PostToolUse" ".claude/settings.json" && \
     grep -q "SubagentStop" ".claude/settings.json"; then
    pass "Claude Code hooks configured in settings.json"
  else
    fail "Claude Code settings" "Hooks not configured"
  fi
else
  fail "Claude Code settings" "settings.json not created"
fi

# Verify commands (should be 25+ in project OR global)
# Follow symlinks with -L flag
COMMAND_COUNT=$(find .claude/commands -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
GLOBAL_COMMAND_COUNT=$(find -L "$HOME/.claude/commands" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$COMMAND_COUNT" -ge 25 ]]; then
  pass "Claude Code commands installed locally ($COMMAND_COUNT files)"
elif [[ "$GLOBAL_COMMAND_COUNT" -ge 25 ]]; then
  pass "Claude Code commands installed globally ($GLOBAL_COMMAND_COUNT files)"
else
  fail "Claude Code commands" "Expected 25+, found $COMMAND_COUNT local, $GLOBAL_COMMAND_COUNT global"
fi

# Verify agents (should be 28+ in project OR global)
# Follow symlinks with -L flag
AGENT_COUNT=$(find .claude/agents -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
GLOBAL_AGENT_COUNT=$(find -L "$HOME/.claude/agents" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$AGENT_COUNT" -ge 28 ]]; then
  pass "Claude Code agents installed locally ($AGENT_COUNT files)"
elif [[ "$GLOBAL_AGENT_COUNT" -ge 28 ]]; then
  pass "Claude Code agents installed globally ($GLOBAL_AGENT_COUNT files)"
else
  fail "Claude Code agents" "Expected 28+, found $AGENT_COUNT local, $GLOBAL_AGENT_COUNT global"
fi

# Verify skills (should be 15+ in project OR global)
# Follow symlinks with -L flag
SKILL_COUNT=$(find .claude/skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
GLOBAL_SKILL_COUNT=$(find -L "$HOME/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$SKILL_COUNT" -ge 15 ]]; then
  pass "Claude Code skills installed locally ($SKILL_COUNT files)"
elif [[ "$GLOBAL_SKILL_COUNT" -ge 15 ]]; then
  pass "Claude Code skills installed globally ($GLOBAL_SKILL_COUNT files)"
else
  fail "Claude Code skills" "Expected 15+, found $SKILL_COUNT local, $GLOBAL_SKILL_COUNT global"
fi

# Verify MCP server config (optional for project-specific installs)
if [[ -f ".mcp.json" ]]; then
  if grep -q "context7" ".mcp.json"; then
    pass "Claude Code MCP server configured"
  else
    fail "Claude Code MCP" "context7 not found in config"
  fi
elif [[ -f "$HOME/.claude/.mcp.json" ]]; then
  if grep -q "context7" "$HOME/.claude/.mcp.json"; then
    pass "Claude Code MCP server configured globally"
  else
    pass "Claude Code MCP config exists but context7 not configured"
  fi
else
  pass "Claude Code MCP not configured (optional)"
fi

# ==============================================================================
# Test 2: OpenCode Installation
# ==============================================================================
echo
echo " Test 2: OpenCode Installation"

OPENCODE_TEST="$TEST_ROOT/opencode-test"
mkdir -p "$OPENCODE_TEST"
cd "$OPENCODE_TEST"

git init -q
bd init -q 2>/dev/null || true

# Run installer with --opencode flag
if bash "$PROJECT_ROOT/install.sh" --opencode "$OPENCODE_TEST" >/dev/null 2>&1; then
  pass "Installer completed for OpenCode"
else
  fail "OpenCode install" "Installer failed"
fi

# Verify directory structure (OpenCode installs to project root)
if [[ -d "plugins/beads-compound" ]]; then
  pass "OpenCode directory structure created"
else
  fail "OpenCode structure" "Missing plugin directory"
fi

# Verify plugin.ts exists
if [[ -f "plugins/beads-compound/plugin.ts" ]]; then
  pass "OpenCode plugin.ts installed"
else
  fail "OpenCode plugin" "plugin.ts missing"
fi

# Verify package.json exists
if [[ -f "plugins/beads-compound/package.json" ]]; then
  pass "OpenCode package.json installed"
else
  fail "OpenCode package" "package.json missing"
fi

# Verify hook files at project root
if [[ -f "hooks/auto-recall.sh" ]]; then
  pass "OpenCode hook files installed"
else
  fail "OpenCode hooks" "Hook files missing"
fi

# Verify AGENTS.md exists (OpenCode uses this for beads workflow)
if [[ -f "AGENTS.md" ]]; then
  # Should contain beads workflow instructions
  if grep -q "bd ready" "AGENTS.md"; then
    pass "OpenCode AGENTS.md created with workflow instructions"
  else
    fail "OpenCode AGENTS" "AGENTS.md missing workflow content"
  fi
else
  fail "OpenCode AGENTS" "AGENTS.md not created"
fi

# ==============================================================================
# Test 3: Gemini Installation
# ==============================================================================
echo
echo " Test 3: Gemini Installation"

GEMINI_TEST="$TEST_ROOT/gemini-test"
mkdir -p "$GEMINI_TEST"
cd "$GEMINI_TEST"

git init -q
bd init -q 2>/dev/null || true

# Run installer with --gemini flag
if bash "$PROJECT_ROOT/install.sh" --gemini "$GEMINI_TEST" >/dev/null 2>&1; then
  pass "Installer completed for Gemini"
else
  fail "Gemini install" "Installer failed"
fi

# Verify directory structure (Gemini installs to project root)
if [[ -d "hooks" ]]; then
  pass "Gemini directory structure created"
else
  fail "Gemini structure" "Missing hooks directory"
fi

# Verify commands are .toml format (Gemini-specific)
TOML_COUNT=$(find commands -name "*.toml" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$TOML_COUNT" -ge 25 ]]; then
  pass "Gemini commands installed as .toml ($TOML_COUNT files)"
else
  fail "Gemini commands" "Expected 25+ .toml files, found $TOML_COUNT"
fi

# Verify template syntax conversion ($ARGUMENTS → {{args}})
if grep -q "{{args}}" commands/*.toml 2>/dev/null; then
  pass "Gemini template syntax converted"
else
  fail "Gemini templates" "Template conversion not applied"
fi

# Verify agents (should be .md for Gemini)
GEMINI_AGENT_COUNT=$(find agents -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$GEMINI_AGENT_COUNT" -ge 28 ]]; then
  pass "Gemini agents installed ($GEMINI_AGENT_COUNT files)"
else
  fail "Gemini agents" "Expected 28+, found $GEMINI_AGENT_COUNT"
fi

# Verify skills
GEMINI_SKILL_COUNT=$(find skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$GEMINI_SKILL_COUNT" -ge 15 ]]; then
  pass "Gemini skills installed ($GEMINI_SKILL_COUNT files)"
else
  fail "Gemini skills" "Expected 15+, found $GEMINI_SKILL_COUNT"
fi

# ==============================================================================
# Test 4: Cortex Code Installation
# ==============================================================================
echo
echo " Test 4: Cortex Code Installation"

CORTEX_TEST="$TEST_ROOT/cortex-test"
mkdir -p "$CORTEX_TEST"
cd "$CORTEX_TEST"

git init -q
bd init -q 2>/dev/null || true

# Save and override HOME for test isolation
# The installer writes to ~/.snowflake/cortex/hooks.json (real global config)
REAL_HOME="$HOME"
export HOME="$TEST_ROOT/fake-home"
mkdir -p "$HOME/.snowflake/cortex"

# Run installer with --cortex flag
if bash "$PROJECT_ROOT/install.sh" --cortex "$CORTEX_TEST" >/dev/null 2>&1; then
  pass "Installer completed for Cortex Code"
else
  fail "Cortex Code install" "Installer failed"
fi

# Verify directory structure
if [[ -d ".cortex/hooks" ]]; then
  pass "Cortex Code directory structure created"
else
  fail "Cortex Code structure" "Missing .cortex/hooks directory"
fi

# Verify hook files
if [[ -f ".cortex/hooks/auto-recall.sh" && -f ".cortex/hooks/memory-capture.sh" && -f ".cortex/hooks/subagent-wrapup.sh" ]]; then
  pass "Cortex Code hook files installed"
else
  fail "Cortex Code hooks" "Missing hook files"
fi

# Verify teammate-idle-check.sh is NOT present (TeammateIdle not supported)
if [[ ! -f ".cortex/hooks/teammate-idle-check.sh" ]]; then
  pass "Cortex Code correctly excludes teammate-idle-check.sh"
else
  fail "Cortex Code hooks" "teammate-idle-check.sh should not be installed (TeammateIdle not supported)"
fi

# Verify hooks.json exists and has correct entries
if [[ -f "$HOME/.snowflake/cortex/hooks.json" ]]; then
  if grep -q "SessionStart" "$HOME/.snowflake/cortex/hooks.json" && \
     grep -q "PostToolUse" "$HOME/.snowflake/cortex/hooks.json" && \
     grep -q "SubagentStop" "$HOME/.snowflake/cortex/hooks.json"; then
    pass "Cortex Code hooks configured in hooks.json"
  else
    fail "Cortex Code hooks.json" "Missing SessionStart, PostToolUse, or SubagentStop entries"
  fi
else
  fail "Cortex Code hooks.json" "hooks.json not created at $HOME/.snowflake/cortex/hooks.json"
fi

# Verify commands (should be 25+)
CMD_COUNT=$(find .cortex/commands -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$CMD_COUNT" -ge 25 ]]; then
  pass "Cortex Code commands installed ($CMD_COUNT files)"
else
  fail "Cortex Code commands" "Expected 25+, found $CMD_COUNT"
fi

# Verify agents (should be 28+)
AGENT_COUNT=$(find .cortex/agents -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$AGENT_COUNT" -ge 28 ]]; then
  pass "Cortex Code agents installed ($AGENT_COUNT files)"
else
  fail "Cortex Code agents" "Expected 28+, found $AGENT_COUNT"
fi

# Verify skills (should be 15+)
SKILL_COUNT=$(find .cortex/skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SKILL_COUNT" -ge 15 ]]; then
  pass "Cortex Code skills installed ($SKILL_COUNT files)"
else
  fail "Cortex Code skills" "Expected 15+, found $SKILL_COUNT"
fi

# Verify MCP is NOT installed (skipped for Cortex)
if [[ ! -f ".mcp.json" ]]; then
  pass "Cortex Code correctly skips MCP config"
else
  fail "Cortex Code MCP" ".mcp.json should not exist for Cortex installs"
fi

# Verify generation headers
if grep -rl "Generated by beads-compound" .cortex/commands/ >/dev/null 2>&1; then
  pass "Cortex Code generation headers present"
else
  fail "Cortex Code headers" "No 'Generated by beads-compound' header found in commands"
fi

# Restore real HOME
export HOME="$REAL_HOME"

# ==============================================================================
# Test 5: Uninstallation (Optional - requires user confirmation)
# ==============================================================================
echo
echo "  Test 5: Uninstallation (skipped - requires interactive confirmation)"
echo "  [WARN]  Uninstallers require confirmation prompt - test manually if needed"

# ==============================================================================
# Summary
# ==============================================================================
echo
echo "======================================================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "======================================================================"

if [[ "$FAILED" -gt 0 ]]; then
  echo
  echo " Some installation tests failed"
  exit 1
else
  echo
  echo " All installation tests passed!"
fi

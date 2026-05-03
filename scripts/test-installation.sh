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
  PASSED=$((PASSED + 1))
  echo "[PASS] $1"
}

fail() {
  FAILED=$((FAILED + 1))
  echo "[FAIL] $1: $2"
}

assert_file_exists() {
  local LABEL="$1"
  local FILE_PATH="$2"
  local MESSAGE="$3"

  if [[ -e "$FILE_PATH" || -L "$FILE_PATH" ]]; then
    pass "$LABEL"
  else
    fail "$LABEL" "$MESSAGE"
  fi
}

assert_file_absent() {
  local LABEL="$1"
  local FILE_PATH="$2"
  local MESSAGE="$3"

  if [[ -e "$FILE_PATH" || -L "$FILE_PATH" ]]; then
    fail "$LABEL" "$MESSAGE"
  else
    pass "$LABEL"
  fi
}

seed_memory_fixture() {
  local MEMORY_DIR="$1"

  mkdir -p "$MEMORY_DIR"
  cat > "$MEMORY_DIR/knowledge.jsonl" <<'EOF'
{"key":"alpha","type":"learned","content":"OAuth redirect URI must match exactly","ts":10}
{"key":"noise","type":"learned","content":"git status","ts":9}
EOF
  cat > "$MEMORY_DIR/knowledge.archive.jsonl" <<'EOF'
{"key":"older","type":"learned","content":"Old auth flow detail","ts":1}
EOF
}

run_uninstall() {
  local TARGET_DIR="$1"
  shift

  if printf 'y\n' | "$@" "$TARGET_DIR" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT

echo " Installation Test Suite"
echo "Testing lavra installer across all platforms..."
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

if [[ -f ".claude/hooks/memorysanitize/main.go" && -f ".lavra/memory/memorysanitize/main.go" ]]; then
  pass "Claude Code Go helper source installed"
else
  fail "Claude Code Go helper" "memorysanitize source missing from hooks or .lavra/memory"
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

# Verify commands (should be 18+ in project OR global)
# Follow symlinks with -L flag
COMMAND_COUNT=$(find .claude/commands -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
GLOBAL_COMMAND_COUNT=$(find -L "$HOME/.claude/commands" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$COMMAND_COUNT" -ge 18 ]]; then
  pass "Claude Code commands installed locally ($COMMAND_COUNT files)"
elif [[ "$GLOBAL_COMMAND_COUNT" -ge 18 ]]; then
  pass "Claude Code commands installed globally ($GLOBAL_COMMAND_COUNT files)"
else
  fail "Claude Code commands" "Expected 18+, found $COMMAND_COUNT local, $GLOBAL_COMMAND_COUNT global"
fi

# Verify agents (should be 28+ in project OR global)
# Follow symlinks with -L flag
AGENT_COUNT=$(find .claude/agents -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
GLOBAL_AGENT_COUNT=$(find -L "$HOME/.claude/agents" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$AGENT_COUNT" -ge 30 ]]; then
  pass "Claude Code agents installed locally ($AGENT_COUNT files)"
elif [[ "$GLOBAL_AGENT_COUNT" -ge 28 ]]; then
  pass "Claude Code agents installed globally ($GLOBAL_AGENT_COUNT files)"
else
  fail "Claude Code agents" "Expected 30+, found $AGENT_COUNT local, $GLOBAL_AGENT_COUNT global"
fi

# Verify skills (should be 8+ in project OR global)
# Follow symlinks with -L flag
SKILL_COUNT=$(find .claude/skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
GLOBAL_SKILL_COUNT=$(find -L "$HOME/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$SKILL_COUNT" -ge 8 ]]; then
  pass "Claude Code skills installed locally ($SKILL_COUNT files)"
elif [[ "$GLOBAL_SKILL_COUNT" -ge 8 ]]; then
  pass "Claude Code skills installed globally ($GLOBAL_SKILL_COUNT files)"
else
  fail "Claude Code skills" "Expected 8+, found $SKILL_COUNT local, $GLOBAL_SKILL_COUNT global"
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

# Verify the wrapper can build and run the Go helper end-to-end
seed_memory_fixture ".lavra/memory"

if env GOCACHE="$TEST_ROOT/go-cache" ".lavra/memory/memory-sanitize.sh" --run ".lavra/memory" >/dev/null 2>&1 && \
   [[ -f ".lavra/memory/.memory-sanitize-go" ]] && \
   [[ -f ".lavra/memory/knowledge.active.jsonl" ]] && \
   grep -q '"key":"alpha"' ".lavra/memory/knowledge.active.jsonl"; then
  pass "Claude Code Go helper builds and sanitizes knowledge"
else
  fail "Claude Code Go helper runtime" "wrapper did not build helper or produce active knowledge"
fi

if bash "$PROJECT_ROOT/uninstall.sh" "$CLAUDE_TEST" >/dev/null 2>&1; then
  pass "Claude Code uninstall completed"
else
  fail "Claude Code uninstall" "Uninstaller failed"
fi

assert_file_absent "Claude Code hook helper removed" ".claude/hooks/memorysanitize" "memorysanitize directory still present in .claude/hooks"
assert_file_absent "Claude Code memory helper source removed" ".lavra/memory/memorysanitize" "memorysanitize directory still present in .lavra/memory"
assert_file_absent "Claude Code compiled helper removed" ".lavra/memory/.memory-sanitize-go" "compiled helper still present after uninstall"
assert_file_exists "Claude Code knowledge preserved" ".lavra/memory/knowledge.jsonl" "knowledge.jsonl should be preserved"
assert_file_exists "Claude Code archive preserved" ".lavra/memory/knowledge.archive.jsonl" "knowledge.archive.jsonl should be preserved"

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

# Run installer with --opencode flag (--yes skips interactive model selection)
mkdir -p "$TEST_ROOT/tmp"
if env TMPDIR="$TEST_ROOT/tmp" bash "$PROJECT_ROOT/install.sh" --opencode --yes "$OPENCODE_TEST" >/dev/null 2>&1; then
  pass "Installer completed for OpenCode"
else
  fail "OpenCode install" "Installer failed"
fi

# Verify directory structure (project install goes to .opencode/plugins/lavra)
if [[ -d ".opencode/plugins/lavra" ]]; then
  pass "OpenCode directory structure created"
else
  fail "OpenCode structure" "Missing plugin directory"
fi

# Verify plugin.ts exists
if [[ -f ".opencode/plugins/lavra/plugin.ts" ]]; then
  pass "OpenCode plugin.ts installed"
else
  fail "OpenCode plugin" "plugin.ts missing"
fi

# Verify package.json exists
if [[ -f ".opencode/plugins/lavra/package.json" ]]; then
  pass "OpenCode package.json installed"
else
  fail "OpenCode package" "package.json missing"
fi

# Verify hook files (project install: .opencode/hooks/)
if [[ -f ".opencode/hooks/auto-recall.sh" ]]; then
  pass "OpenCode hook files installed"
else
  fail "OpenCode hooks" "Hook files missing"
fi

if [[ -f ".opencode/hooks/memorysanitize/main.go" ]]; then
  pass "OpenCode Go helper source installed"
else
  fail "OpenCode Go helper" "memorysanitize source missing from .opencode/hooks"
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

seed_memory_fixture ".lavra/memory"
if env GOCACHE="$TEST_ROOT/go-cache" ".lavra/memory/memory-sanitize.sh" --run ".lavra/memory" >/dev/null 2>&1 && \
   [[ -f ".lavra/memory/.memory-sanitize-go" ]]; then
  pass "OpenCode Go helper builds and sanitizes knowledge"
else
  fail "OpenCode Go helper runtime" "wrapper did not build helper in .lavra/memory"
fi

if run_uninstall "$OPENCODE_TEST" bash "$PROJECT_ROOT/uninstall.sh" --opencode; then
  pass "OpenCode uninstall completed"
else
  fail "OpenCode uninstall" "Uninstaller failed"
fi

assert_file_absent "OpenCode hook helper removed" ".opencode/hooks/memorysanitize" "memorysanitize directory still present in .opencode/hooks"
assert_file_absent "OpenCode memory helper source removed" ".lavra/memory/memorysanitize" "memorysanitize directory still present in .lavra/memory"
assert_file_absent "OpenCode compiled helper removed" ".lavra/memory/.memory-sanitize-go" "compiled helper still present after uninstall"
assert_file_exists "OpenCode knowledge preserved" ".lavra/memory/knowledge.jsonl" "knowledge.jsonl should be preserved"
assert_file_exists "OpenCode archive preserved" ".lavra/memory/knowledge.archive.jsonl" "knowledge.archive.jsonl should be preserved"

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

if [[ -f "hooks/memorysanitize/main.go" ]]; then
  pass "Gemini Go helper source installed"
else
  fail "Gemini Go helper" "memorysanitize source missing from hooks/"
fi

# Verify commands are .toml format (Gemini-specific)
TOML_COUNT=$(find commands -name "*.toml" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$TOML_COUNT" -ge 18 ]]; then
  pass "Gemini commands installed as .toml ($TOML_COUNT files)"
else
  fail "Gemini commands" "Expected 18+ .toml files, found $TOML_COUNT"
fi

# Verify template syntax conversion ($ARGUMENTS → {{args}})
if grep -q "{{args}}" commands/*.toml 2>/dev/null; then
  pass "Gemini template syntax converted"
else
  fail "Gemini templates" "Template conversion not applied"
fi

# Verify agents (should be .md for Gemini)
GEMINI_AGENT_COUNT=$(find agents -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$GEMINI_AGENT_COUNT" -ge 30 ]]; then
  pass "Gemini agents installed ($GEMINI_AGENT_COUNT files)"
else
  fail "Gemini agents" "Expected 30+, found $GEMINI_AGENT_COUNT"
fi

# Verify skills
GEMINI_SKILL_COUNT=$(find skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$GEMINI_SKILL_COUNT" -ge 7 ]]; then
  pass "Gemini skills installed ($GEMINI_SKILL_COUNT files)"
else
  fail "Gemini skills" "Expected 7+, found $GEMINI_SKILL_COUNT"
fi

seed_memory_fixture ".lavra/memory"
if env GOCACHE="$TEST_ROOT/go-cache" ".lavra/memory/memory-sanitize.sh" --run ".lavra/memory" >/dev/null 2>&1 && \
   [[ -f ".lavra/memory/.memory-sanitize-go" ]]; then
  pass "Gemini Go helper builds and sanitizes knowledge"
else
  fail "Gemini Go helper runtime" "wrapper did not build helper in .lavra/memory"
fi

if run_uninstall "$GEMINI_TEST" bash "$PROJECT_ROOT/uninstall.sh" --gemini; then
  pass "Gemini uninstall completed"
else
  fail "Gemini uninstall" "Uninstaller failed"
fi

assert_file_absent "Gemini hook helper removed" "hooks/memorysanitize" "memorysanitize directory still present in hooks"
assert_file_absent "Gemini memory helper source removed" ".lavra/memory/memorysanitize" "memorysanitize directory still present in .lavra/memory"
assert_file_absent "Gemini compiled helper removed" ".lavra/memory/.memory-sanitize-go" "compiled helper still present after uninstall"
assert_file_exists "Gemini knowledge preserved" ".lavra/memory/knowledge.jsonl" "knowledge.jsonl should be preserved"
assert_file_exists "Gemini archive preserved" ".lavra/memory/knowledge.archive.jsonl" "knowledge.archive.jsonl should be preserved"

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

if [[ -f ".cortex/hooks/memorysanitize/main.go" ]]; then
  pass "Cortex Code Go helper source installed"
else
  fail "Cortex Code Go helper" "memorysanitize source missing from .cortex/hooks"
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

# Verify dispatch-hook.sh installed to global hooks dir
if [[ -f "$HOME/.snowflake/cortex/hooks/dispatch-hook.sh" ]]; then
  pass "Cortex Code dispatch-hook.sh installed globally"
else
  fail "Cortex Code dispatcher" "dispatch-hook.sh missing from $HOME/.snowflake/cortex/hooks/"
fi

# Verify hooks.json uses dispatcher (absolute paths), not direct relative paths
if grep -q "dispatch-hook.sh" "$HOME/.snowflake/cortex/hooks.json"; then
  pass "Cortex Code hooks.json uses dispatcher pattern"
else
  fail "Cortex Code hooks.json" "hooks.json does not reference dispatch-hook.sh"
fi

# Negative: hooks.json must NOT contain direct .cortex/hooks/ command targets
if grep -q '"bash \.cortex/hooks/' "$HOME/.snowflake/cortex/hooks.json" 2>/dev/null; then
  fail "Cortex Code hooks.json" "Contains direct relative .cortex/hooks/ paths (should use dispatcher)"
else
  pass "Cortex Code hooks.json has no direct relative paths"
fi

# Verify commands (should be 18+)
CMD_COUNT=$(find .cortex/commands -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$CMD_COUNT" -ge 18 ]]; then
  pass "Cortex Code commands installed ($CMD_COUNT files)"
else
  fail "Cortex Code commands" "Expected 18+, found $CMD_COUNT"
fi

# Verify agents (should be 28+)
AGENT_COUNT=$(find .cortex/agents -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$AGENT_COUNT" -ge 30 ]]; then
  pass "Cortex Code agents installed ($AGENT_COUNT files)"
else
  fail "Cortex Code agents" "Expected 30+, found $AGENT_COUNT"
fi

# Verify skills (should be 7+ — lavra-work has no SKILL.md, it's internal-only)
SKILL_COUNT=$(find .cortex/skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SKILL_COUNT" -ge 7 ]]; then
  pass "Cortex Code skills installed ($SKILL_COUNT files)"
else
  fail "Cortex Code skills" "Expected 7+, found $SKILL_COUNT"
fi

# Verify MCP is NOT installed (skipped for Cortex)
if [[ ! -f ".mcp.json" ]]; then
  pass "Cortex Code correctly skips MCP config"
else
  fail "Cortex Code MCP" ".mcp.json should not exist for Cortex installs"
fi

# Verify generation headers
if grep -rl "Generated by lavra" .cortex/commands/ >/dev/null 2>&1; then
  pass "Cortex Code generation headers present"
else
  fail "Cortex Code headers" "No 'Generated by lavra' header found in commands"
fi

seed_memory_fixture ".lavra/memory"
if env GOCACHE="$TEST_ROOT/go-cache" ".lavra/memory/memory-sanitize.sh" --run ".lavra/memory" >/dev/null 2>&1 && \
   [[ -f ".lavra/memory/.memory-sanitize-go" ]]; then
  pass "Cortex Code Go helper builds and sanitizes knowledge"
else
  fail "Cortex Code Go helper runtime" "wrapper did not build helper in .lavra/memory"
fi

if run_uninstall "$CORTEX_TEST" env HOME="$HOME" bash "$PROJECT_ROOT/uninstall.sh" --cortex; then
  pass "Cortex Code uninstall completed"
else
  fail "Cortex Code uninstall" "Uninstaller failed"
fi

assert_file_absent "Cortex Code hook helper removed" ".cortex/hooks/memorysanitize" "memorysanitize directory still present in .cortex/hooks"
assert_file_absent "Cortex Code memory helper source removed" ".lavra/memory/memorysanitize" "memorysanitize directory still present in .lavra/memory"
assert_file_absent "Cortex Code compiled helper removed" ".lavra/memory/.memory-sanitize-go" "compiled helper still present after uninstall"
assert_file_exists "Cortex Code knowledge preserved" ".lavra/memory/knowledge.jsonl" "knowledge.jsonl should be preserved"
assert_file_exists "Cortex Code archive preserved" ".lavra/memory/knowledge.archive.jsonl" "knowledge.archive.jsonl should be preserved"

# Restore real HOME
export HOME="$REAL_HOME"

# ==============================================================================
# Test 5: New Feature Provisioning (v0.7.0)
# ==============================================================================
echo
echo " Test 5: New Feature Provisioning"

# Use the Claude test directory which already has a full install
cd "$CLAUDE_TEST"

# F6: lavra.json provisioned by installer
if [[ -f ".lavra/config/lavra.json" ]]; then
  if grep -q '"goal_verification"' ".lavra/config/lavra.json" && \
     grep -q '"max_parallel_agents"' ".lavra/config/lavra.json" && \
     grep -q '"commit_granularity"' ".lavra/config/lavra.json"; then
    pass "lavra.json provisioned with all expected keys"
  else
    fail "lavra.json content" "Missing expected configuration keys"
  fi
else
  fail "lavra.json" "Not created by installer"
fi

# F3: session-state.md in .lavra/.gitignore (folder-level, with memory/ prefix)
if [[ -f ".lavra/.gitignore" ]]; then
  if grep -q "memory/session-state.md" ".lavra/.gitignore"; then
    pass "session-state.md in .lavra/.gitignore"
  else
    fail "session-state gitignore" "memory/session-state.md not in .lavra/.gitignore"
  fi
else
  fail "memory .gitignore" ".lavra/.gitignore not found"
fi

# F1: goal-verifier agent exists
if [[ -f ".claude/agents/review/goal-verifier.md" ]]; then
  pass "goal-verifier agent installed"
else
  fail "goal-verifier" "Agent file not installed"
fi

# F6: lavra.json is valid JSON
if jq . ".lavra/config/lavra.json" >/dev/null 2>&1; then
  pass "lavra.json is valid JSON"
else
  fail "lavra.json validation" "File is not valid JSON"
fi

# F6: lavra.json idempotent (re-run installer, should not overwrite)
ORIGINAL_CONTENT=$(cat ".lavra/config/lavra.json")
bash "$PROJECT_ROOT/install.sh" "$CLAUDE_TEST" >/dev/null 2>&1
AFTER_CONTENT=$(cat ".lavra/config/lavra.json")
if [[ "$ORIGINAL_CONTENT" == "$AFTER_CONTENT" ]]; then
  pass "lavra.json idempotent on re-install"
else
  fail "lavra.json idempotency" "File was overwritten on re-install"
fi

# ==============================================================================
# Test 6: Migration (upgrade from .beads/ to .lavra/)
# ==============================================================================
echo
echo " Test 6: Migration (.beads/ → .lavra/)"

MIGRATE_TEST="$TEST_ROOT/migrate-test"
mkdir -p "$MIGRATE_TEST"
cd "$MIGRATE_TEST"
git init -q
bd init -q 2>/dev/null || true

# Simulate existing 0.7.0 Lavra data in .beads/
mkdir -p .beads/memory .beads/config .beads/retros
echo '{"key":"test-key","type":"learned","content":"Test migration knowledge","tags":["test"],"ts":1000000}' > .beads/memory/knowledge.jsonl
echo '{"workflow":{"research":true,"plan_review":true}}' > .beads/config/lavra.json
echo '{"date":"2026-01-01","items":[]}' > .beads/retros/2026-01-01.json
# Add a SQLite file that must NOT be migrated
touch .beads/memory/knowledge.db

LINES_BEFORE=$(wc -l < .beads/memory/knowledge.jsonl | tr -d ' ')

bash "$PROJECT_ROOT/install.sh" "$MIGRATE_TEST" >/dev/null 2>&1

# M1: knowledge.jsonl migrated with correct content
if [[ -f ".lavra/memory/knowledge.jsonl" ]]; then
  LINES_AFTER=$(wc -l < .lavra/memory/knowledge.jsonl | tr -d ' ')
  if [[ "$LINES_AFTER" -ge "$LINES_BEFORE" ]] && grep -q "test-key" .lavra/memory/knowledge.jsonl; then
    pass "Migration: knowledge.jsonl copied with data intact"
  else
    fail "Migration: knowledge.jsonl content" "Line count mismatch or key not found (before=$LINES_BEFORE after=$LINES_AFTER)"
  fi
else
  fail "Migration: knowledge.jsonl" ".lavra/memory/knowledge.jsonl not created"
fi

# M2: config migrated
if [[ -f ".lavra/config/lavra.json" ]] && grep -q '"plan_review"' .lavra/config/lavra.json; then
  pass "Migration: lavra.json config copied"
else
  fail "Migration: config" ".lavra/config/lavra.json missing or wrong content"
fi

# M3: retros migrated
if [[ -f ".lavra/retros/2026-01-01.json" ]]; then
  pass "Migration: retros copied"
else
  fail "Migration: retros" ".lavra/retros/2026-01-01.json not found"
fi

# M4: .beads/ originals preserved (not deleted)
if [[ -f ".beads/memory/knowledge.jsonl" ]]; then
  pass "Migration: .beads/ originals preserved"
else
  fail "Migration: .beads/ preservation" ".beads/memory/knowledge.jsonl was deleted"
fi

# M5: SQLite cache NOT migrated
if [[ ! -f ".lavra/memory/knowledge.db" ]]; then
  pass "Migration: SQLite cache not copied"
else
  fail "Migration: SQLite exclusion" "knowledge.db was copied to .lavra/memory/"
fi

# M6: idempotency — second install skips migration, data unchanged
LINES_BEFORE_SECOND=$(wc -l < .lavra/memory/knowledge.jsonl | tr -d ' ')
bash "$PROJECT_ROOT/install.sh" "$MIGRATE_TEST" >/dev/null 2>&1
LINES_AFTER_SECOND=$(wc -l < .lavra/memory/knowledge.jsonl | tr -d ' ')
if [[ "$LINES_BEFORE_SECOND" -eq "$LINES_AFTER_SECOND" ]]; then
  pass "Migration: idempotent (second install does not overwrite)"
else
  fail "Migration: idempotency" "knowledge.jsonl changed on second install (before=$LINES_BEFORE_SECOND after=$LINES_AFTER_SECOND)"
fi

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

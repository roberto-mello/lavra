#!/usr/bin/env bash
set -e

# Feature Testing Suite (v0.7.0)
# Tests new hook behaviors: DEVIATION capture, session state, version self-heal
#
# These tests exercise the actual hook scripts with mock inputs,
# not the full installer flow (that's test-installation.sh).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/plugins/lavra/hooks"
TEST_ROOT="/tmp/beads-feature-test-$(date +%s)"

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

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT

echo "Feature Test Suite (v0.7.0)"
echo "Testing new hook behaviors..."
echo

# ==============================================================================
# Setup: Create a minimal test project
# ==============================================================================
mkdir -p "$TEST_ROOT/project/.lavra/memory"
touch "$TEST_ROOT/project/.lavra/memory/knowledge.jsonl"
echo "0.6.7" > "$TEST_ROOT/project/.lavra/memory/.lavra-version"

# Create minimal gitignore (pre-existing, missing session-state.md)
cat > "$TEST_ROOT/project/.lavra/memory/.gitignore" << 'EOF'
knowledge.db
knowledge.db-journal
knowledge.db-wal
knowledge.db-shm
EOF

cd "$TEST_ROOT/project"
git init -q

# ==============================================================================
# Test 1: DEVIATION prefix in memory-capture regex
# ==============================================================================
echo
echo "Test 1: DEVIATION prefix capture"

# Check that the regex in memory-capture.sh matches DEVIATION:
if grep -q 'DEVIATION:' "$HOOKS_DIR/memory-capture.sh"; then
  pass "memory-capture.sh contains DEVIATION: in detection regex"
else
  fail "DEVIATION regex" "DEVIATION: not found in memory-capture.sh"
fi

# Check the prefix loop includes DEVIATION
if grep -q 'INVESTIGATION LEARNED DECISION FACT PATTERN DEVIATION' "$HOOKS_DIR/memory-capture.sh"; then
  pass "DEVIATION in prefix extraction loop"
else
  fail "DEVIATION loop" "DEVIATION not in the for PREFIX loop"
fi

# Simulate a DEVIATION: comment capture by feeding mock input
MOCK_INPUT='{"tool_name":"Bash","tool_input":{"command":"bd comments add test-001 \"DEVIATION: Fixed missing import to unblock auth\""},"cwd":"'"$TEST_ROOT/project"'"}'
echo "$MOCK_INPUT" | bash "$HOOKS_DIR/memory-capture.sh" 2>/dev/null || true

if [[ -f "$TEST_ROOT/project/.lavra/memory/knowledge.jsonl" ]] && \
   grep -q '"type":"deviation"' "$TEST_ROOT/project/.lavra/memory/knowledge.jsonl" 2>/dev/null; then
  pass "DEVIATION: comment captured to knowledge.jsonl"
else
  fail "DEVIATION capture" "Entry not written to knowledge.jsonl (bd may not be installed)"
fi

# ==============================================================================
# Test 2: provision-memory.sh creates lavra.json
# ==============================================================================
echo
echo "Test 2: provision-memory.sh creates lavra.json"

# Remove lavra.json if it exists from a prior run
rm -f "$TEST_ROOT/project/.lavra/config/lavra.json"

source "$HOOKS_DIR/provision-memory.sh"
provision_memory_dir "$TEST_ROOT/project" "$HOOKS_DIR"

if [[ -f "$TEST_ROOT/project/.lavra/config/lavra.json" ]]; then
  pass "lavra.json created by provision_memory_dir"
else
  fail "lavra.json creation" "File not created"
fi

# Verify it's valid JSON with expected keys
if jq -e '.workflow.goal_verification' "$TEST_ROOT/project/.lavra/config/lavra.json" >/dev/null 2>&1; then
  pass "lavra.json has workflow.goal_verification key"
else
  fail "lavra.json structure" "Missing workflow.goal_verification"
fi

if jq -e '.execution.commit_granularity' "$TEST_ROOT/project/.lavra/config/lavra.json" >/dev/null 2>&1; then
  pass "lavra.json has execution.commit_granularity key"
else
  fail "lavra.json structure" "Missing execution.commit_granularity"
fi

# ==============================================================================
# Test 3: provision-memory.sh appends session-state.md to existing .gitignore
# ==============================================================================
echo
echo "Test 3: session-state.md gitignore append"

if grep -q "session-state.md" "$TEST_ROOT/project/.lavra/.gitignore"; then
  pass "session-state.md appended to existing .gitignore"
else
  fail "session-state gitignore" "Not appended to .gitignore"
fi

# ==============================================================================
# Test 4: provision-memory.sh is idempotent
# ==============================================================================
echo
echo "Test 4: provision-memory.sh idempotency"

BEFORE_GITIGNORE=$(cat "$TEST_ROOT/project/.lavra/memory/.gitignore")
BEFORE_LAVRA=$(cat "$TEST_ROOT/project/.lavra/config/lavra.json")

# Run again
provision_memory_dir "$TEST_ROOT/project" "$HOOKS_DIR"

AFTER_GITIGNORE=$(cat "$TEST_ROOT/project/.lavra/memory/.gitignore")
AFTER_LAVRA=$(cat "$TEST_ROOT/project/.lavra/config/lavra.json")

if [[ "$BEFORE_GITIGNORE" == "$AFTER_GITIGNORE" ]]; then
  pass ".gitignore unchanged on second provision"
else
  fail "gitignore idempotency" "Content changed on re-run"
fi

if [[ "$BEFORE_LAVRA" == "$AFTER_LAVRA" ]]; then
  pass "lavra.json unchanged on second provision"
else
  fail "lavra.json idempotency" "Content changed on re-run"
fi

# ==============================================================================
# Test 5: memory-sanitize provisioning and dedupe
# ==============================================================================
echo
echo "Test 5: memory sanitization pipeline"

if [[ -f "$TEST_ROOT/project/.lavra/memory/memory-sanitize.sh" ]]; then
  pass "memory-sanitize.sh provisioned into .lavra/memory"
else
  fail "memory-sanitize provision" "Script not copied into memory dir"
fi

if grep -q "knowledge.active.jsonl" "$TEST_ROOT/project/.lavra/.gitignore"; then
  pass "knowledge.active.jsonl gitignored"
else
  fail "knowledge.active gitignore" "Curated active file not gitignored"
fi

cat > "$TEST_ROOT/project/.lavra/memory/knowledge.jsonl" << 'EOF'
{"key":"decision-auth-callback","type":"decision","content":"OAuth callback URI must match exactly including trailing slash.","source":"user","tags":["auth","oauth"],"ts":10,"bead":"test-001"}
{"key":"decision-auth-callback","type":"decision","content":"OAuth callback URI must match exactly including trailing slash.","source":"user","tags":["auth","oauth"],"ts":20,"bead":"test-001"}
{"key":"decision-auth-callback-alt","type":"decision","content":"OAuth callback URI must match exactly, including trailing slash.","source":"user","tags":["auth","oauth"],"ts":30,"bead":"test-002"}
EOF

bash "$HOOKS_DIR/memory-sanitize.sh" --run "$TEST_ROOT/project/.lavra/memory" 2>/dev/null || true

ACTIVE_LINES=$(wc -l < "$TEST_ROOT/project/.lavra/memory/knowledge.active.jsonl" 2>/dev/null | tr -d ' ')
if [[ "$ACTIVE_LINES" -eq 1 ]]; then
  pass "memory-sanitize dedupes identical knowledge into one active entry"
else
  fail "memory-sanitize dedupe" "Expected 1 active entry, found $ACTIVE_LINES"
fi

if [[ -f "$TEST_ROOT/project/.lavra/memory/knowledge.active.db" ]] || ! command -v sqlite3 >/dev/null 2>&1; then
  pass "memory-sanitize builds active sqlite cache when sqlite3 is available"
else
  fail "memory-sanitize sqlite" "knowledge.active.db not created"
fi

CANARY_FILE="$TEST_ROOT/canary.txt"
echo "do-not-touch" > "$CANARY_FILE"
rm -f "$TEST_ROOT/project/.lavra/memory/.sanitize-needed"
ln -s "$CANARY_FILE" "$TEST_ROOT/project/.lavra/memory/.sanitize-needed"

bash "$HOOKS_DIR/memory-sanitize.sh" --schedule security-test "$TEST_ROOT/project/.lavra/memory" 2>/dev/null || true

if [[ "$(cat "$CANARY_FILE")" == "do-not-touch" ]]; then
  pass "memory-sanitize refuses symlinked marker targets"
else
  fail "memory-sanitize symlink guard" "Symlink target was overwritten"
fi

rm -f "$TEST_ROOT/project/.lavra/memory/.sanitize-needed"

# ==============================================================================
# Test 6: Session state lifecycle (write -> read -> delete)
# ==============================================================================
echo
echo "Test 6: Session state lifecycle"

# Write a session state file
cat > "$TEST_ROOT/project/.lavra/memory/session-state.md" << 'EOF'
# Session State
## Current Position
- Bead(s): test-001
- Phase: lavra-work / Phase 2 (Implement)
- Task: 2 of 5 complete
## Just Completed
- Implemented auth middleware
## Next
- Route guards (task 3)
EOF

if [[ -f "$TEST_ROOT/project/.lavra/memory/session-state.md" ]]; then
  pass "Session state file written"
else
  fail "Session state write" "File not created"
fi

# Verify session-state.md is gitignored
cd "$TEST_ROOT/project"
if git check-ignore -q ".lavra/memory/session-state.md" 2>/dev/null; then
  pass "session-state.md is gitignored"
else
  fail "session-state gitignore" "File is NOT gitignored"
fi

# ==============================================================================
# Test 7: goal-verifier agent file exists and has correct structure
# ==============================================================================
echo
echo "Test 7: goal-verifier agent structure"

GOAL_VERIFIER="$PROJECT_ROOT/plugins/lavra/agents/review/goal-verifier.md"

if [[ -f "$GOAL_VERIFIER" ]]; then
  pass "goal-verifier.md exists"
else
  fail "goal-verifier" "Agent file missing"
fi

if grep -q 'name: goal-verifier' "$GOAL_VERIFIER"; then
  pass "goal-verifier has correct name frontmatter"
else
  fail "goal-verifier name" "Missing name field in frontmatter"
fi

if grep -q 'model: sonnet' "$GOAL_VERIFIER"; then
  pass "goal-verifier assigned to sonnet tier"
else
  fail "goal-verifier model" "Missing or wrong model tier"
fi

# Check for the three verification levels
if grep -q 'Level 1: Exists' "$GOAL_VERIFIER" && \
   grep -q 'Level 2: Substantive' "$GOAL_VERIFIER" && \
   grep -q 'Level 3: Wired' "$GOAL_VERIFIER"; then
  pass "goal-verifier has all three verification levels"
else
  fail "goal-verifier levels" "Missing one or more verification levels"
fi

# ==============================================================================
# Test 8: Agent count verification (30 total, 16 review)
# ==============================================================================
echo
echo "Test 8: Agent counts"

TOTAL_AGENTS=$(find "$PROJECT_ROOT/plugins/lavra/agents" -name "*.md" | wc -l | tr -d ' ')
REVIEW_AGENTS=$(find "$PROJECT_ROOT/plugins/lavra/agents/review" -name "*.md" | wc -l | tr -d ' ')

if [[ "$TOTAL_AGENTS" -eq 30 ]]; then
  pass "Total agent count: 30"
else
  fail "Total agents" "Expected 30, found $TOTAL_AGENTS"
fi

if [[ "$REVIEW_AGENTS" -eq 16 ]]; then
  pass "Review agent count: 16"
else
  fail "Review agents" "Expected 16, found $REVIEW_AGENTS"
fi

# ==============================================================================
# Test 9: DEVIATION in documentation consistency
# ==============================================================================
echo
echo "Test 9: DEVIATION documentation consistency"

# hooks-system.md should document DEVIATION:
if grep -q 'DEVIATION:' "$PROJECT_ROOT/.claude/rules/hooks-system.md"; then
  pass "hooks-system.md documents DEVIATION prefix"
else
  fail "hooks-system docs" "DEVIATION not documented"
fi

# plugin-catalog.md should list 6 knowledge prefixes
if grep -q 'DEVIATION' "$PROJECT_ROOT/.claude/rules/plugin-catalog.md"; then
  pass "plugin-catalog.md mentions DEVIATION"
else
  fail "plugin-catalog docs" "DEVIATION not mentioned"
fi

# CLAUDE.md should list DEVIATION
if grep -q 'DEVIATION' "$PROJECT_ROOT/CLAUDE.md"; then
  pass "CLAUDE.md lists DEVIATION prefix"
else
  fail "CLAUDE.md docs" "DEVIATION not listed"
fi

# ==============================================================================
# Test 9: lavra-work.md contains new features
# ==============================================================================
echo
echo "Test 9: Command file feature integration"

WORK_CMD="$PROJECT_ROOT/plugins/lavra/commands/lavra-work.md"

if grep -q 'Deviation Rules' "$WORK_CMD"; then
  pass "lavra-work.md has Deviation Rules section"
else
  fail "lavra-work deviation" "Deviation Rules section missing"
fi

if grep -q 'goal-verifier' "$WORK_CMD"; then
  pass "lavra-work.md references goal-verifier agent"
else
  fail "lavra-work goal-verify" "goal-verifier not referenced"
fi

if grep -q 'session-state.md' "$WORK_CMD"; then
  pass "lavra-work.md writes session-state.md"
else
  fail "lavra-work session-state" "session-state.md not referenced"
fi

if grep -q 'commit_granularity' "$WORK_CMD"; then
  pass "lavra-work.md reads commit_granularity config"
else
  fail "lavra-work commit config" "commit_granularity not referenced"
fi

if grep -q 'Locked.*Discretion.*Deferred' "$WORK_CMD" || \
   (grep -q 'Locked' "$WORK_CMD" && grep -q 'Discretion' "$WORK_CMD" && grep -q 'Deferred' "$WORK_CMD"); then
  pass "lavra-work.md reads decision categories"
else
  fail "lavra-work decisions" "Decision categories not referenced"
fi

SHIP_CMD="$PROJECT_ROOT/plugins/lavra/commands/lavra-ship.md"

if grep -q 'Goal Verification' "$SHIP_CMD"; then
  pass "lavra-ship.md has Goal Verification section"
else
  fail "lavra-ship goal-verify" "Goal Verification section missing"
fi

if grep -q 'Deviations' "$SHIP_CMD"; then
  pass "lavra-ship.md has Deviations in PR body"
else
  fail "lavra-ship deviations" "Deviations section missing from PR body"
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
  echo "Some feature tests failed"
  exit 1
else
  echo
  echo "All feature tests passed!"
fi

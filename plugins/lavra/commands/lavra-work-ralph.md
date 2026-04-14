---
name: lavra-work-ralph
description: Autonomous retry mode for bead work -- iterates until completion criteria are met or retry budget is exhausted
argument-hint: "[bead ID or epic ID or comma-separated IDs] [--retries N] [--max-turns N] [--yes]"
---

<objective>
Work on beads autonomously with iterative retry. Each subagent loops until its completion criteria pass or retries are exhausted, using the ralph-wiggum promise pattern. Combines the full lavra-work quality standard with self-healing execution.
</objective>

<execution_context>
<bead_input> #$ARGUMENTS </bead_input>
</execution_context>

<process>

## 1. Parse Arguments

Parse flags from the `$ARGUMENTS` string:

- `--retries N`: max retries per subagent (default 5, range 1-20)
- `--max-turns N`: max turns per subagent (default 50, range 10-200)
- `--yes`: skip user approval gate (but NOT pre-push review)

Remaining arguments (after removing flags) are the bead input (epic ID, comma-separated IDs, or empty).

Echo parsed config: `Configuration: retries={N}, max-turns={N}`

## 2. Permission Check

Subagents in ralph mode run with `bypassPermissions` and need Bash, Write, and Edit tool access without human approval. Restricted permissions cause workers to stall silently.

If tool permissions appear restricted:
- Warn: "Ralph mode works best with tool permissions pre-approved. See docs/AUTONOMOUS_EXECUTION.md"
- Suggest granular permissions in `settings.json` or `--dangerously-skip-permissions` as a last resort.

This is a warning only -- continue regardless of the result.

## 3. Resolve Completion Promise & Test Command

Determine what "done" means for each agent and extract the test command.

### 3a. Extract test command (optional)

1. Read CLAUDE.md (or AGENTS.md) for test command references
2. If found, validate against known runner allowlist: `bundle exec rspec`, `pytest`, `npm test`, `npx vitest`, `go test`, `cargo test`, `mix test`, `bun test`, `yarn test`, `make test`
3. Reject commands containing shell metacharacters: `;`, `&&`, `||`, `|`, `` ` ``, `$()`, `${}`, `<()`, `>`, `<`, `>>`, `2>`, newline
4. If no valid test command found: use AskUserQuestion to ask the user. Do NOT let workers self-discover test commands.
5. Store as `TEST_COMMAND` for injection into agent prompts (may be empty)

### 3b. Determine completion promise per bead

The **completion promise** is how the subagent signals it is done -- following the ralph-wiggum pattern. Each subagent must output `<promise>DONE</promise>` when its completion criteria are met.

For each bead, derive the completion criteria from (in priority order):
1. **`## Validation` section** in the bead description (from `/lavra-plan`) -- use these criteria directly
2. **`## Testing` section** in the bead description -- "all specified tests pass"
3. **`TEST_COMMAND` exists** -- "all tests pass"
4. **None of the above** -- "implementation matches the bead description and no errors on manual review"

Store as `COMPLETION_CRITERIA` per bead for injection into the subagent prompt.

## 4. Gather Beads

Follow Phase M1 from `/lavra-work` (MULTI-BEAD PATH): resolve epic/comma-separated/empty input, validate bead IDs, skip `.lavra/` deletion beads, register swarm for epic input.

## 5. Branch Check

Check the current branch:

```bash
current_branch=$(git branch --show-current)
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
if [ -z "$default_branch" ]; then
  default_branch=$(git rev-parse --verify origin/main >/dev/null 2>&1 && echo "main" || echo "master")
fi
```

**Record pre-branch SHA** (used for pre-push diff in section 12):
```bash
PRE_BRANCH_SHA=$(git rev-parse HEAD)
```

**If on the default branch**, use AskUserQuestion:

**Question:** "You're on the default branch. Create a working branch for these changes?"

**Options:**
1. **Yes, create branch** - Create `bd-ralph/{short-description}` and work there
2. **No, work here** - Commit directly to the current branch

If creating a branch:
```bash
git pull origin {default_branch}
git checkout -b bd-ralph/{short-description-from-bead-titles}
PRE_BRANCH_SHA=$(git rev-parse HEAD)
```

**If already on a feature branch**, continue working there.

## 6. File-Scope Conflict Detection

Follow Phase M3 from `/lavra-work` (MULTI-BEAD PATH): analyze per-bead file scope, validate paths, detect overlaps, force sequential ordering where needed.

## 7. Dependency Analysis & Wave Building

Follow Phase M4 from `/lavra-work` (MULTI-BEAD PATH): use `bd swarm validate` for epic input or `bd graph` for other input. Organize into waves. Output mermaid diagram.

## 8. User Approval

Present the plan once with AskUserQuestion including execution parameters:

**Question:** "Autonomous execution plan: {N} beads across {M} waves, max {retries} retries/bead, max {max_turns} turns/subagent. Estimated max subagent invocations: {beads * (retries + 1)}. Proceed?"

**Options:**
1. **Proceed** - Execute the plan as shown
2. **Adjust** - Remove beads from the run (cannot reorder against conflict-forced deps)
3. **Cancel** - Abort

If `--yes` is set, skip this approval and proceed automatically.

## 9. Recall Knowledge & Read Project Config *(required -- do not skip)*

Follow Phase M6 from `/lavra-work` (MULTI-BEAD PATH): run `recall.sh` with combined keywords, read project config, sanitize `reviewer_context_note`, detect installed skills. Output recall results before building agent prompts.

## 10. Execute Waves (Autonomous Retry)

**Before each wave (epic input):** Query swarm status to determine the next wave's bead set:
```bash
bd swarm status {EPIC_ID} --json
```
Use the "ready" list from swarm status as this wave's beads. Beads in the "blocked" list are skipped entirely and reported in the wave status.

**Before each wave (non-epic input):** Verify all blocking beads for this wave's beads are closed. If any blocker is not closed, skip the blocked beads entirely and report them in the wave status.

**Before each wave:** Record the pre-wave git SHA:
```bash
PRE_WAVE_SHA=$(git rev-parse HEAD)
```

For each wave, spawn **general-purpose** agents in parallel -- one per bead.

Each agent gets a detailed prompt containing:
- The full bead description (from `bd show`)
- Related bead context (from `relates_to` links)
- Relevant knowledge entries from the recall step
- Clear instructions to follow the lavra-work methodology
- Completion criteria and retry budget

**Resolve related beads:** For each bead in the wave, check for `relates_to` links:
```bash
bd dep list {BEAD_ID} --json
```
Filter for `relates_to` type entries. For each related bead, fetch its title and description to include in the subagent prompt.

**Spawn with `bypassPermissions`** so agents run autonomously without prompting:

```
Task(general-purpose, mode="bypassPermissions", "...prompt for BD-001...")
Task(general-purpose, mode="bypassPermissions", "...prompt for BD-002...")
Task(general-purpose, mode="bypassPermissions", "...prompt for BD-003...")
```

**Wait for the entire wave to complete before starting the next wave.**

### Agent Prompt Template

**Build agent prompts** by reading the agent prompt template and filling all `{PLACEHOLDERS}`:

```bash
AGENT_TEMPLATE=$(cat ".claude/skills/lavra-work-multi/references/subagent-prompt.md")
```

Fill all {PLACEHOLDERS} in `$AGENT_TEMPLATE` with the gathered values.

Fill `{EXTRA_INSTRUCTIONS}` with the ralph-specific sections below:

```
## Completion Criteria
{COMPLETION_CRITERIA derived from bead's Validation/Testing sections}

You are DONE when ALL completion criteria above are satisfied.
When done, output exactly: <promise>DONE</promise>

## Test Command
{TEST_COMMAND or "none -- no test suite configured"}

## Retry Loop (replaces standard phases 6-9 in the shared template)

After implementing (phase 4 of the shared template), enter this loop:

1. Verify completion:
   - If a test command is configured, run it: {TEST_COMMAND}
   - Check each item in your Completion Criteria
   - If ALL criteria met: proceed to step 3
   - If ANY criterion fails: proceed to step 2

2. Fix and retry (max {MAX_RETRIES} retries):
   - Analyze what failed, identify root cause, fix the issue
   - Go back to step 1
   - If the same error repeats on 2+ consecutive retries,
     pivot to a fundamentally different approach. Log:
     bd comments add {BEAD_ID} "INVESTIGATION: Same error repeated -- switching approach"
   - If retries exhausted:
     - Log: bd comments add {BEAD_ID} "INVESTIGATION: Failed after {MAX_RETRIES} retries. Last error: {summary}. Approaches tried: {list}"
     - Report the failure -- do NOT output <promise>DONE</promise>

3. Report results and signal completion:
   - What changed, completion criteria status, retries used, issues
   - Do NOT run git commit or git add
   - If all criteria met: <promise>DONE</promise>
```

## 11. Verify Results

After each wave completes:

1. **Review agent outputs** for any reported issues or conflicts
2. **Check completion promise:** For each agent, check whether its output contains `<promise>DONE</promise>`. If absent, treat that bead as failed -- the agent either ran out of turns or could not meet its completion criteria.
3. **Check file ownership violations** -- diff the changed files against each agent's ownership list. If an agent modified files outside its ownership, revert those changes and flag them for the next wave or manual resolution
4. **Run tests** to verify nothing is broken:
   ```bash
   # Use project's test command from CLAUDE.md or AGENTS.md
   ```
5. **Run linting** if applicable
6. **Resolve conflicts** if multiple agents touched the same files
7. **Handle failed beads:**
   - Revert failed beads' file changes using the pre-wave SHA:
     ```bash
     git checkout {PRE_WAVE_SHA} -- {files owned by failed bead}
     ```
   - Leave failed beads as `in_progress`
   - Log: `bd comments add {BEAD_ID} "INVESTIGATION: Agent failed after {N} retries. Reverted changes to pre-wave state."`
8. **Create an incremental commit** for the wave:
   ```bash
   git add <changed files>
   git commit -m "feat: resolve wave N beads (BD-XXX, BD-YYY)"
   ```
9. **Close completed beads:**
   ```bash
   bd close {BD-XXX} {BD-YYY} {BD-ZZZ}
   ```

Proceed to the next wave only after verification passes.

**Wave-completion status:** After each wave verification, emit brief status:
```
Wave {N} complete: {X} beads closed, {Y} beads failed, {Z} total retries used.
```

**Before starting the next wave**, recall knowledge captured during this wave to inject into the next wave's agent prompts:

```bash
# Recall by bead IDs from the completed wave
.lavra/memory/recall.sh "{BD-XXX BD-YYY}"
```

Include these results in the next wave's agent prompts under the "## Relevant Knowledge" section. This ensures discoveries from Wave N inform Wave N+1 agents.

## 12. Pre-Push Diff Review

Before pushing, show the diff summary and require confirmation.

**Diff base:** Use `PRE_BRANCH_SHA` (recorded in section 5) as the diff base:
```bash
git diff --stat {PRE_BRANCH_SHA}..HEAD
```

Use AskUserQuestion:

**Question:** "Review the changes above before pushing. Proceed with push?"

**Options:**
1. **Push** - Push changes to remote
2. **Cancel** - Do not push (changes remain committed locally)

**Note:** `--yes` does NOT skip this gate. The pre-push review always requires explicit approval.

## 13. Final Steps

After all waves complete and push is approved:

1. **Push to remote:**
   ```bash
   git push
   bd backup
   ```

2. **Scan for substantial findings:**

   Check all closed beads for `LEARNED:` or `INVESTIGATION:` comments:
   ```bash
   for id in {closed-bead-ids}; do bd show $id | grep -E "LEARNED:|INVESTIGATION:" && echo "  bead: $id"; done
   ```
   Store the list of beads with matches as `COMPOUND_CANDIDATES` for use in the handoff.

3. **Output summary:**

```markdown
## Autonomous Execution Complete

**Waves executed:** {count}
**Beads resolved:** {count}
**Beads failed:** {count} (left as in_progress)
**Beads skipped:** {count} (blocked by failed dependencies)

### Wave 1:
- BD-XXX: {title} - Closed ({N} retries)
- BD-YYY: {title} - Closed (0 retries)

### Wave 2:
- BD-ZZZ: {title} - FAILED after {N} retries. Error: {summary}

### Skipped (blocked by failures):
- BD-AAA: {title} - blocked by BD-ZZZ

### Conflict-Forced Orderings:
- BD-002 after BD-001 (file overlap: src/auth/login.ts)

### Knowledge captured:
- {count} entries logged across all beads
```

</process>

<success_criteria>
- All resolved beads are closed with `bd close`
- Each bead has at least one knowledge comment logged (`LEARNED:`, `DECISION:`, `FACT:`, `PATTERN:`, or `INVESTIGATION:`)
- Code changes are committed and pushed to remote
- Any failing beads are reported with reasons (not silently dropped)
- All beads either closed or exhausted retries with failure summary
- Completion promise (`<promise>DONE</promise>`) checked for every subagent
</success_criteria>

<handoff>
All work complete. What next?

1. **Run `/lavra-review`** on all changes
2. **Create a PR** with all changes
3. **Run `/lavra-compound {COMPOUND_CANDIDATES}`** - Document non-obvious findings as reusable knowledge *(only shown if COMPOUND_CANDIDATES is non-empty)*
4. **Retry failed beads** - Re-run with only the failed bead IDs
5. **Continue** with remaining open beads
</handoff>
</content>
</invoke>
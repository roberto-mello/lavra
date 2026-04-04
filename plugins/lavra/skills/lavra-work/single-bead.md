# Single-Bead Work Path

Internal reference for `/lavra-work` when exactly one bead is being worked on. Full-quality interactive flow with built-in review, fix loop, and learn phases.

**State machine:** IMPLEMENTING -> REVIEWING -> FIXING -> RE_REVIEWING -> LEARNING -> DONE

---

<phase name="quick-start" order="1">

## Phase 1: Quick Start

1. **Read Bead and Clarify**

   If a bead ID was provided:
   ```bash
   bd show {BEAD_ID} --long
   ```

   Read the bead description completely including:
   - What section (implementation requirements)
   - Context section (research findings, constraints)
   - Decisions section (Locked = must honor, Discretion = agent's flexibility budget, Deferred = do NOT implement)
   - Testing section (test cases to implement)
   - Validation section (acceptance criteria)
   - Dependencies section (blockers)
   - Comments (INVESTIGATION/FACT/PATTERN/DECISION/LEARNED from research phase -- treat as implementation constraints with the same weight as Locked Decisions)

   **If the bead has a parent epic**, also read the epic's decision sections:
   ```bash
   bd show {BEAD_ID} --json | jq -r '.[0].parent // empty'
   # If parent exists:
   bd show {PARENT_EPIC_ID}
   ```
   Extract `## Locked Decisions`, `## Agent Discretion`, and `## Deferred` sections. Locked = must honor. Discretion = deviation budget. Deferred = do NOT implement (these are explicitly out of scope).

   If a specification path was provided instead:
   - Read the document completely
   - Create a bead for tracking: `bd create "{title from spec}" -d "{spec content}" --type task`

   **Clarify ambiguities:**
   - If anything is unclear or ambiguous, use **AskUserQuestion tool** now
   - Get user approval to proceed
   - **Do not skip this** -- better to ask questions now than build the wrong thing

2. **Recall Relevant Knowledge** *(required -- do not skip)*

   ```bash
   .lavra/memory/recall.sh "{keywords from bead title}"
   .lavra/memory/recall.sh "{tech stack keywords}"
   ```

   **You MUST output the recall results here before continuing.** If recall returns nothing, output: "No relevant knowledge found." Do not proceed to step 3 until this is done.

3. **Check Dependencies & Related Beads**

   ```bash
   bd dep list {BEAD_ID} --json
   ```

   If there are unresolved blockers, list them and ask if the user wants to work on those first.

   Check for `relates_to` links in the dependency list. For each related bead, fetch its title and description:
   ```bash
   bd show {RELATED_BEAD_ID}
   ```

4. **Setup Environment**

   Check the current branch:

   ```bash
   current_branch=$(git branch --show-current)
   default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
   if [ -z "$default_branch" ]; then
     default_branch=$(git rev-parse --verify origin/main >/dev/null 2>&1 && echo "main" || echo "master")
   fi
   ```

   Use **AskUserQuestion tool**:

   **Question:** "How do you want to handle branching for this work?"

   **Options:**
   1. **Work on current branch** -- Continue on `[current_branch]` as-is
   2. **Create a feature branch** -- `bd-{BEAD_ID}/{short-description}`
   3. **Use a worktree** -- Isolated copy for parallel development

   Then execute the chosen option.

5. **Update Bead Status**

   ```bash
   bd update {BEAD_ID} --status in_progress
   ```

6. **Create Task List**
   - Use TaskCreate to break the bead description into actionable tasks
   - Use TaskUpdate with addBlockedBy/addBlocks for dependencies between tasks
   - Include testing and quality check tasks

</phase>

<phase name="implement" order="2">

## Phase 2: Implement (IMPLEMENTING state)

**Read workflow config (no-op if missing):**

```bash
[ -f .lavra/config/lavra.json ] && cat .lavra/config/lavra.json
```

Parse `execution.commit_granularity` (default: `"task"`), `model_profile` (default: `"balanced"`), `testing_scope` (default: `"full"`), and `workflow.review_scope` (default: `"full"`). When `testing_scope` is `"targeted"`, deviation rule 2 applies only to hooks, API routes, external service calls, and complex business logic -- skip adding tests for structural/render-only code.

**Detect installed skills (no-op if directory missing):**

```bash
ls .claude/skills/ 2>/dev/null
```

For each skill directory found, read the `description:` line from its `SKILL.md` frontmatter. Filter to only skills that contain an explicit "Use when" or "Triggers on" phrase. Skip utility skills with no clear trigger condition. Store the filtered list as `{available_skills}`.

**Deviation Rules:**

| Rule | Scope | Action | Log |
|------|-------|--------|-----|
| 1. Bug blocking your task | Auto-fix is OK | Fix it, run tests | `DEVIATION: Fixed {bug} because it blocked {task}` |
| 2. Missing critical functionality | Auto-add is OK | Add it, run tests | `DEVIATION: Added {what} -- missing and critical for {reason}` |
| 3. Blocking infrastructure | Auto-fix is OK | Fix it, run tests | `DEVIATION: Fixed {issue} to unblock {task}` |
| 4. Architectural changes | **STOP** | Ask user before proceeding | N/A -- user decides |

**3-attempt limit:** If a deviation fix fails after 3 attempts, document and move on:
```bash
bd comments add {BEAD_ID} "DEVIATION: Unable to fix {issue} after 3 attempts. Documented for manual resolution."
```

**Use available skills during implementation:** If `{available_skills}` is non-empty, review each skill's trigger condition against the bead content and the files you're about to touch. Invoke any that apply using the Skill tool.

1. **Task Execution Loop**

   For each task in priority order:

   ```
   while (tasks remain):
     - Mark task as in_progress with TaskUpdate
     - Read any referenced files from the bead description
     - Look for similar patterns in codebase
     - Implement following existing conventions
     - Write tests for new functionality
     - Run tests after changes
     - Mark task as completed with TaskUpdate
     - Commit per task (see below)
     - Write session state (see below)
   ```

2. **Atomic Commits Per Task**

   After completing each task and tests pass:

   ```bash
   git add <files related to this task>
   git commit -m "{type}({BEAD_ID}): {description of this task}"
   ```

   Format: `{type}({BEAD_ID}): {description}` -- makes `git log --grep="BD-001"` work.
   Types: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`

   **If `commit_granularity` is `"wave"`:** batch commits per phase instead of per task.

   Skip commit when: tests are failing, task is purely scaffolding, or would need a "WIP" message.

3. **Log Knowledge as You Work** *(required -- inline, not at the end)*

   <mandatory>
   Log a comment the moment you encounter any of these triggers. Do not batch them for later.

   | Trigger | Prefix | Example |
   |---------|--------|---------|
   | Read code that surprises you | `FACT:` | Column is a string `'kg'\|'lbs'`, not a boolean |
   | Make a non-obvious implementation choice | `DECISION:` | Chose 2.5 lb rounding because smaller increments cause UI jitter |
   | Hit an error and figure out why | `LEARNED:` | Enum comparison fails unless you cast to string first |
   | Notice a pattern you'll want to reuse | `PATTERN:` | Service uses `.tap` to log before returning |
   | Find a constraint that limits options | `FACT:` | API rate-limits to 10 req/s per tenant |

   ```bash
   bd comments add {BEAD_ID} "LEARNED: {key technical insight}"
   bd comments add {BEAD_ID} "DECISION: {what was chosen and why}"
   ```

   **You MUST log at least one comment per task completed.** If you finish a task with nothing logged, go back and add it before marking the task complete.
   </mandatory>

4. **Write Session State** *(at milestones)*

   Update `.lavra/memory/session-state.md`:

   ```bash
   cat > .lavra/memory/session-state.md << EOF
   # Session State
   ## Current Position
   - Bead(s): {BEAD_ID}
   - Phase: lavra-work / Phase 2 (Implement)
   - Task: {completed} of {total} complete
   ## Just Completed
   - {last completed task description}
   ## Next
   - {next task description}
   ## Deviations
   - {count} auto-fixes applied
   EOF
   ```

5. **Follow Existing Patterns**

   - Read referenced files first, match naming conventions exactly
   - Reuse existing components, follow project coding standards
   - When in doubt, grep for similar implementations

6. **Track Progress**
   - Keep task list updated (TaskUpdate) as you complete tasks
   - Note blockers or unexpected discoveries
   - Create new tasks if scope expands

</phase>

<phase name="review" order="3" gate="must-complete-before-learn">

## Phase 3: Review (REVIEWING state)

<mandatory>
This phase MUST complete before Phase 4 (Learn) or Phase 5 (Ship). Do NOT skip any step. If you reach Phase 4 without completing this phase, STOP and come back here.
</mandatory>

1. **Run Core Quality Checks**

   ```bash
   # Run full test suite (use project's test command)
   # Run linting (per CLAUDE.md or AGENTS.md)
   ```

2. **Focused Self-Review**

   Review the diff of all changes:
   ```bash
   git diff HEAD~{N}..HEAD  # or against the pre-work SHA
   ```

   Check for:

   | Category | What to look for |
   |----------|-----------------|
   | **Security** | Hardcoded secrets, SQL injection, unvalidated input, exposed endpoints |
   | **Debug leftovers** | console.log, binding.pry, debugger statements, TODO/FIXME/HACK |
   | **Spec compliance** | Does implementation match every item in the bead's Validation section? |
   | **Error handling** | Missing error cases, swallowed exceptions, unhelpful messages |
   | **Edge cases** | Off-by-one, nil/null handling, empty collections, boundary conditions |

   If no issues found, state "Self-review: clean" and proceed to step 3.
   If issues found, proceed to the Fix Loop below.

3. **Full Multi-Agent Review** *(controlled by `workflow.review_scope`)*

   <mandatory>
   This step invokes `/lavra-review`. It is not optional under `review_scope: "full"`.
   </mandatory>

   - `"full"` (default): invoke `/lavra-review` using the Skill tool now. Wait for it to complete. Proceed to the Fix Loop for any findings.
   - `"targeted"`: invoke `/lavra-review` if the bead meets any of:
     - Priority P0 or P1
     - Title/description contains: "architecture", "schema", "migration", "refactor", "restructure", "redesign"
     - Title/description contains: "auth", "permission", "security", "secret", "token", "encrypt", "password", "access control", "vulnerability"

     Otherwise skip -- self-review only.

4. **Goal Verification** *(skippable via `lavra.json` `workflow.goal_verification: false`)*

   If the bead has a `## Validation` section, dispatch the `goal-verifier` agent. Add `model: opus` when `model_profile` is `"quality"`.

   **Interpret results:**
   - Exists-level failures -> CRITICAL: return to Phase 2
   - Substantive failures -> CRITICAL: return to Phase 2
   - Wired-level failures -> WARNING: note in PR description
   - Anti-patterns -> WARNING: fix if trivial, otherwise note

   If CRITICAL failures, enter the Fix Loop targeting the specific failures.

### Fix Loop (FIXING -> RE_REVIEWING states)

For each issue found during review:

1. **Create fix items** from the review findings
2. **Implement fixes** -- follow the same conventions as Phase 2
3. **Run tests** after each fix
4. **Log knowledge** for non-obvious fixes:
   ```bash
   bd comments add {BEAD_ID} "LEARNED: {what the review caught and why}"
   ```

After all fixes, **re-review** (return to step 2 above). Loop continues until:
- Self-review returns clean, OR
- Two consecutive passes find only cosmetic issues

Maximum fix iterations: 3. If issues persist after 3 rounds, report remaining issues and proceed.

</phase>

<phase name="learn" order="4" requires="review-complete">

## Phase 4: Learn (LEARNING state)

<prerequisite>
Phase 3 (Review) must be complete before this phase. If review has not run, STOP and go back to Phase 3 now.
</prerequisite>

After review is clean, extract and structure knowledge from this work session.

1. **Gather raw entries** from this bead:
   ```bash
   bd show {BEAD_ID} --json
   # Extract comments matching LEARNED:|DECISION:|FACT:|PATTERN:|INVESTIGATION: prefixes
   ```

2. **Check for duplicates** against existing knowledge:
   ```bash
   .lavra/memory/recall.sh "{keywords from entries}" --all
   ```

3. **Structure and store** -- for each raw comment, ensure it has clear, searchable content. If a comment is too terse, rewrite it self-contained, then re-log:
   ```bash
   bd comments add {BEAD_ID} "LEARNED: {structured, self-contained version}"
   ```

4. **Synthesize patterns** -- if 3+ entries share a theme, create a connecting entry:
   ```bash
   bd comments add {BEAD_ID} "PATTERN: {higher-level insight connecting multiple observations}"
   ```

   Only synthesize when the pattern is genuine. Do not force connections.

This step should take 1-2 minutes. It is curation of what was already captured, not new research.

</phase>

<phase name="ship" order="5" requires="review-complete">

## Phase 5: Ship It (DONE state)

1. **Final Validation**
   - All tasks marked completed (TaskList shows none pending)
   - All tests pass
   - Linting passes
   - Code follows existing patterns
   - Bead's validation criteria are met

2. **Create Commit** (if not already committed incrementally)

   ```bash
   git add <changed files>
   git status
   git diff --staged
   git commit -m "feat(scope): description of what and why"
   ```

3. **Create Pull Request**

   ```bash
   git push -u origin bd-{BEAD_ID}/{short-description}

   gh pr create --title "BD-{BEAD_ID}: {description}" --body "## Summary
   - What was built
   - Key decisions made

   ## Bead
   {BEAD_ID}: {bead title}

   ## Testing
   - Tests added/modified
   - Manual testing performed

   ## Knowledge Captured
   - {key learnings logged to bead}
   "
   ```

4. **Verify Knowledge Was Captured** *(required gate)*

   Run `bd show {BEAD_ID}` and check comments. You must have at least one knowledge comment per task. If there are none, add them now.

5. **Offer Next Steps**

   Check for `LEARNED:` or `INVESTIGATION:` comments:
   ```bash
   bd show {BEAD_ID} | grep -E "LEARNED:|INVESTIGATION:"
   ```

   Use **AskUserQuestion tool**:

   **Question:** "Work complete on {BEAD_ID}. What next?"

   **Base options** (always shown):
   1. **Close bead** -- Mark as complete: `bd close {BEAD_ID}`
   2. **Run `/lavra-checkpoint`** -- Save progress without closing
   3. **Continue working** -- Keep implementing

   **Conditional options** (add when applicable):
   - Add **Run `/lavra-learn`** if `LEARNED:` or `INVESTIGATION:` comments exist (deeper curation than inline pass)
   - Add **Run `/lavra-review`** as first option if `review_scope: "targeted"` and review was skipped for this bead

</phase>

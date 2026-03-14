---
name: beads-quick
description: Fast-track small tasks — abbreviated plan then straight to execution
argument-hint: "[task description or bead ID]"
---

<objective>
Fast-track small tasks with an abbreviated plan and immediate execution. Skips brainstorm and deepen phases, runs a MINIMAL plan (1-3 child tasks), then transitions directly to `/beads-work`. Still captures knowledge throughout.
</objective>

<execution_context>
<raw_argument> #$ARGUMENTS </raw_argument>

**Determine if the argument is a bead ID or a task description:**

Check if the argument matches a bead ID pattern:
- Pattern: lowercase alphanumeric segments separated by hyphens (e.g., `fix-auth`, `beads-123`)
- Regex: `^[a-z0-9]+-[a-z0-9]+(-[a-z0-9]+)*$`

**If bead ID pattern:**

1. Load the bead:
   ```bash
   bd show "#$ARGUMENTS" --json
   ```
2. If it exists: extract title and description, announce "Quick-tracking bead #$ARGUMENTS: {title}"
3. If not found: report error and stop

**If task description:**
- Create a bead:
  ```bash
  bd create --title="{concise title}" --description="#$ARGUMENTS" --type=task
  ```
- Capture the new bead ID

**If empty:**
- Ask: "What small task do you want to quick-track? Provide a bead ID or describe the task."
- Do not proceed until input is provided
</execution_context>

<context>
Use `/beads-quick` for small, well-understood tasks: bug fixes, config changes, small refactors, adding a field, writing a utility function.

If the task turns out larger than expected, the scope escalation check (step 3) will catch it and offer to switch to `/beads-design`.
</context>

<process>

### 1. Quick Context Scan

Run in parallel:

```bash
# Recall relevant knowledge
.beads/memory/recall.sh "{keywords from task}"
```

```bash
# Quick repo scan for related patterns
# (grep/glob for relevant files based on task description)
```

Output recall results before continuing. If nothing found, state "No relevant knowledge found."

### 2. Abbreviated Plan (MINIMAL)

Create 1-3 child tasks as beads. No deep research, no deepen, no review.

```bash
bd create "{step title}" --parent {BEAD_ID} -d "## What
{what to implement}

## Validation
- [ ] {acceptance criterion}"
```

Keep descriptions short -- this is the fast path. Each child bead needs only What and Validation sections.

If two tasks touch the same file, add a dependency:
```bash
bd dep add {later_bead} {earlier_bead}
```

### 3. Scope Escalation Check

After creating the abbreviated plan but BEFORE starting implementation, evaluate whether the task has outgrown quick-fix territory. Check for these signals:

- **File count**: More than 3 files need changes
- **Cross-bead dependencies**: Dependencies on other existing beads discovered
- **Architectural decisions**: The task requires architectural choices, not just implementation choices
- **Security implications**: Auth, permissions, data exposure, or input validation concerns found
- **Multi-component impact**: Changes span multiple components, services, or layers
- **Change volume**: Estimated total changes exceed ~100 lines

**If one or more signals are detected**, pause execution and report:

<scope_escalation>
"This task has grown beyond quick-fix scope.

Signals detected:
- {list each signal that fired with a brief explanation}

Switch to /beads-design for proper planning? This preserves all work done so far."
</scope_escalation>

**If the user accepts escalation:**

1. Save current progress -- update the parent bead description with a note summarizing the abbreviated plan and the escalation signals:
   ```bash
   bd comments add {BEAD_ID} "DECISION: Escalated from /beads-quick to /beads-design. Signals: {signals}. Child tasks preserved as starting point."
   ```
2. Invoke `/beads-design` with the bead ID so the full planning pipeline picks up where this left off.
3. Stop the beads-quick workflow. Do not continue to step 4.

**If the user declines escalation:**

1. Log the decision:
   ```bash
   bd comments add {BEAD_ID} "DECISION: User chose to proceed with /beads-quick despite scope signals: {signals}. Rationale: user preference."
   ```
2. Continue to step 4.

**If no signals are detected**, proceed to step 4 without interruption.

### 4. Begin Execution

Update the parent bead status and transition to execution:

```bash
bd update {BEAD_ID} --status in_progress
```

Execute using the `/beads-work` workflow on the first ready child bead. Follow all `/beads-work` phases (Quick Start, Execute, Quality Check, Ship It) -- the abbreviated plan does not mean abbreviated execution.

**Log knowledge as you work** -- at least one LEARNED/DECISION/FACT/PATTERN comment per task:

```bash
bd comments add {BEAD_ID} "LEARNED: {insight}"
```

### 5. Wrap Up

After all child tasks are complete:

1. Run tests and linting
2. Commit with conventional format
3. Close the bead: `bd close {BEAD_ID}`

</process>

<success_criteria>
- Bead created (if description provided) or loaded (if ID provided)
- 1-3 child tasks created with What/Validation sections
- All tasks executed and tests passing
- At least one knowledge comment captured
- Bead closed on completion
</success_criteria>

<guardrails>
- Do NOT use for complex features, architectural changes, or tasks with unclear requirements
- If scope creep is detected, the formal escalation check in step 3 handles it -- do not skip that checkpoint
- Do NOT skip knowledge capture -- the fast path still feeds the memory system
- Do NOT skip tests -- abbreviated planning does not mean lower quality
</guardrails>

<handoff>
After completion, present options:

1. **Quick-track another task** -- run `/beads-quick` again
2. **Review the work** -- run `/beads-review` for a code review
3. **Checkpoint** -- run `/beads-checkpoint` to save progress
</handoff>

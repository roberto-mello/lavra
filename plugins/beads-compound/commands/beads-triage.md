---
name: beads-triage
description: Triage and categorize beads for prioritization
argument-hint: "[bead ID or empty]"
disable-model-invocation: true
---

<objective>
Present all findings, decisions, or issues one by one for triage. Go through each bead and decide whether to keep, modify, dismiss, or defer it. Useful for triaging code review findings, security audit results, performance analysis, or any categorized findings that need tracking.
</objective>

<execution_context>
<bead_input> #$ARGUMENTS </bead_input>

**First, determine if the argument is a bead ID or empty:**

Check if the argument matches a bead ID pattern:
- Pattern: lowercase alphanumeric segments separated by hyphens (e.g., `bikiniup-xhr`, `beads-123`, `fix-auth-bug2`)
- Regex: `^[a-z0-9]+-[a-z0-9]+(-[a-z0-9]+)*$`

**If the argument matches a bead ID pattern:**

1. Try to load the bead using the Bash tool:
   ```bash
   bd show "#$ARGUMENTS" --json
   ```

2. If the bead exists:
   - Extract the `title` and `type` fields from the JSON array (first element)
   - Example: `bd show "#$ARGUMENTS" --json | jq -r '.[0].type'`
   - Announce: "Triaging bead #$ARGUMENTS: {title}"

   **If the bead is an epic:**
   - List all child beads:
     ```bash
     bd list --parent "#$ARGUMENTS" --json
     ```
   - Triage the epic's child beads

   **If the bead is not an epic:**
   - Triage just that single bead

3. If the bead doesn't exist (command fails):
   - Report: "Bead ID '#$ARGUMENTS' not found. Please check the ID or provide a valid bead ID."
   - Stop execution

**If the argument does NOT match a bead ID pattern (or is empty):**
- Triage all open beads (original behavior):
  ```bash
  bd list --status=open --json
  ```

Read each bead's full details:
```bash
bd show {BEAD_ID}
```
</execution_context>

<process>

### Step 1: Present Each Bead

For each bead, present in this format:

```
---
Bead #X: {BEAD_ID} - [Brief Title]

Severity: P1 (CRITICAL) / P2 (IMPORTANT) / P3 (NICE-TO-HAVE)

Category: [Security/Performance/Architecture/Bug/Feature/etc.]

Description:
[Detailed explanation from bead description]

Location: [file_path:line_number if applicable]

Problem Scenario:
[Step by step what's wrong or could happen]

Proposed Solution:
[How to fix it]

Estimated Effort: [Small (< 2 hours) / Medium (2-8 hours) / Large (> 8 hours)]

---
What would you like to do with this bead?
1. Keep - approve for work
2. Modify - change priority, description, or details
3. Dismiss - close/remove this bead
4. Defer - keep but lower priority
```

### Step 2: Handle User Decision

**When user says "Keep":**
1. Update bead status to ready: `bd update {BEAD_ID} --status=open`
2. Confirm: "Approved: `{BEAD_ID}` - {title} -> Ready to work on"

**When user says "Modify":**
- Ask what to modify (priority, description, details)
- Update the bead: `bd update {BEAD_ID} --priority {N} -d "{new description}"`
- Present revised version
- Ask again: Keep/Modify/Dismiss/Defer

**When user says "Dismiss":**
- Close the bead: `bd close {BEAD_ID} --reason "Dismissed during triage"`
- Log: `bd comments add {BEAD_ID} "DECISION: Dismissed during triage - {reason}"`
- Skip to next item

**When user says "Defer":**
- Lower priority: `bd update {BEAD_ID} --priority 5`
- Add tag: `bd update {BEAD_ID} --tags "deferred"`
- Log: `bd comments add {BEAD_ID} "DECISION: Deferred during triage - {reason}"`

### Step 3: Progress Tracking

Every time you present a bead, include:
- **Progress:** X/Y completed (e.g., "3/10 completed")

### Step 4: Final Summary

After all items processed:

```markdown
## Triage Complete

**Total Items:** [X]
**Kept (ready for work):** [Y]
**Modified:** [Z]
**Dismissed:** [A]
**Deferred:** [B]

### Approved Beads (Ready for Work):
- {BD-XXX}: {title} - Priority {N}
- {BD-YYY}: {title} - Priority {N}

### Dismissed Beads:
- {BD-ZZZ}: {title} - Reason: {reason}

### Deferred Beads:
- {BD-AAA}: {title} - Reason: {reason}
```

</process>

<guardrails>
- DO NOT implement fixes or write code during triage
- Triage is for decisions only
- Implementation happens in `/beads-parallel` or `/beads-work`
</guardrails>

<handoff>
What would you like to do next?

1. Run /beads-parallel to resolve the approved beads
2. Run /beads-work on a specific bead
3. Nothing for now
</handoff>

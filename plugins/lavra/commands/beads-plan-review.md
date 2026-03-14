---
name: beads-plan-review
description: Have multiple specialized agents review a plan in parallel
argument-hint: "[epic bead ID]"
---

<objective>
Review an epic plan using multiple specialized agents in parallel to catch issues before implementation begins.
</objective>

<execution_context>
<epic_bead_id> #$ARGUMENTS </epic_bead_id>

**If the epic bead ID above is empty:**
1. Check for recent epic beads: `bd list --type epic --status=open --json`
2. Ask the user: "Which epic plan would you like reviewed? Please provide the bead ID (e.g., `BD-001`)."

Do not proceed until you have a valid epic bead ID.
</execution_context>

<process>

### Step 1: Load the Plan

```bash
# Read the epic
bd show {EPIC_ID}

# List and read all child beads
bd list --parent {EPIC_ID} --json
```

For each child bead, read its full description:

```bash
bd show {CHILD_ID}
```

Assemble the full plan content from epic description + all child bead descriptions.

### Step 2: Recall Relevant Knowledge

```bash
# Search for knowledge related to the plan's topic
.beads/memory/recall.sh "{keywords from epic title}"
.beads/memory/recall.sh "{tech stack keywords}"
```

Include any relevant LEARNED/DECISION/FACT/PATTERN entries as context for reviewers.

### Step 3: Dispatch Review Agents in Parallel

Run these 4 agents simultaneously, passing the full plan content to each:

1. Task architecture-strategist("Review this plan for architectural soundness, scalability, and maintainability. Plan: [full plan content]")
2. Task code-simplicity-reviewer("Review this plan for unnecessary complexity, over-engineering, and opportunities to simplify. Plan: [full plan content]")
3. Task security-sentinel("Review this plan for security vulnerabilities, missing auth checks, data exposure risks. Plan: [full plan content]")
4. Task performance-oracle("Review this plan for performance bottlenecks, N+1 queries, missing caching, scalability issues. Plan: [full plan content]")

### Step 4: Synthesize Findings

After all agents complete, synthesize their feedback into a categorized report:

```markdown
## Plan Review: {EPIC_ID} - {epic title}

### Architecture
[Findings from architecture-strategist]
- Strengths: [what's well designed]
- Concerns: [architectural issues]
- Suggestions: [improvements]

### Simplicity
[Findings from code-simplicity-reviewer]
- Over-engineering risks: [what could be simpler]
- Unnecessary abstractions: [what to remove]
- Suggestions: [simplifications]

### Security
[Findings from security-sentinel]
- Vulnerabilities: [security risks found]
- Missing protections: [what needs adding]
- Suggestions: [security improvements]

### Performance
[Findings from performance-oracle]
- Bottlenecks: [performance concerns]
- Missing optimizations: [what to add]
- Suggestions: [performance improvements]

### Summary
- **Critical issues:** [count] - Must fix before implementing
- **Important suggestions:** [count] - Should consider
- **Minor improvements:** [count] - Nice to have

### Recommended Changes
1. [Most impactful change]
2. [Second most impactful]
3. [Third most impactful]
```

### Step 5: Log Key Findings

For significant findings, log knowledge:

```bash
bd comments add {EPIC_ID} "LEARNED: Plan review found: {key insight}"
```

</process>

<success_criteria>
- All 4 review agents dispatched and completed
- Findings synthesized into categorized report with severity levels
- Critical issues clearly identified
- Top 3 recommended changes listed
- Key findings logged as knowledge comments
</success_criteria>

<handoff>
After presenting the review, use the **AskUserQuestion tool** to present these options:

**Question:** "Plan review complete for `{EPIC_ID}`. What would you like to do next?"

**Options:**
1. **Apply feedback** - Update child beads with review suggestions
2. **Run `/beads-research`** - Gather additional evidence with domain-matched agents
3. **Start `/beads-work`** - Begin implementing the first child bead
4. **Run `/beads-work {EPIC_ID}`** - Work on multiple child beads in parallel
5. **Dismiss** - Acknowledge review without changes

## Applying Feedback (when option 1 is selected)

**Do not proceed informally.** Follow this exact protocol.

### Step A: Build the Recommendation Checklist

Before touching any bead, extract every actionable recommendation from the review report. Number them sequentially:

```
RECOMMENDATIONS TO APPLY:
[ ] 1. [Exact recommendation from Architecture section]
[ ] 2. [Exact recommendation from Architecture section]
[ ] 3. [Exact recommendation from Simplicity section]
[ ] 4. [Exact recommendation from Security section]
[ ] 5. [Exact recommendation from Performance section]
...
```

Print this numbered list to the user before starting. If the review had a "Recommended Changes" section, include all items from it. Also include any critical/important issues from each category.

**Total count:** State how many recommendations you found (e.g., "Found 12 recommendations. Applying now.")

### Step B: Apply Each Recommendation

Work through the list one at a time. For each recommendation:

1. **Identify the target bead** - Which child bead (or epic) does this apply to?
2. **Read the current description**: `bd show {BEAD_ID}`
3. **Update it**: `bd update {BEAD_ID} -d "{updated description with recommendation applied}"`
4. **Mark complete** in your working list: `[x] 1. ...`

If a recommendation applies to multiple beads, update each one.

If a recommendation is architectural (affects the whole plan), update the epic description.

If a recommendation is contradictory or inapplicable, mark it `[SKIPPED: reason]` -- do NOT silently omit it.

### Step C: Completeness Verification

After applying all changes, do a completeness pass:

1. Re-read the original review report
2. Compare each recommendation against your working checklist
3. For any item not marked `[x]` or `[SKIPPED]`, apply it now

Then print the final checklist state:

```
APPLIED:
[x] 1. [recommendation] -> Updated {BEAD_ID}
[x] 2. [recommendation] -> Updated {BEAD_ID}
[x] 3. [recommendation] -> Updated {EPIC_ID}

SKIPPED:
[SKIPPED: contradicts architectural decision] 4. [recommendation]

TOTAL: {N} applied, {M} skipped out of {N+M} recommendations
```

**Do not say "done" until every recommendation is either marked applied or explicitly skipped with a reason.**

### Step D: Log Changes

```bash
bd comments add {EPIC_ID} "DECISION: Applied plan review feedback. {N} recommendations applied across {K} beads. Key changes: {top 3 changes}"
```
</handoff>

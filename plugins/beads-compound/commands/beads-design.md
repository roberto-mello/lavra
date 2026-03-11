---
name: beads-design
description: Orchestrate the full planning pipeline — brainstorm, plan, deepen, review — for a feature
argument-hint: "[brainstorm bead ID or phase bead IDs]"
---

<objective>
Orchestrate the full planning pipeline as a single invocation: brainstorm (collaborative), plan (auto), deepen (auto), and plan-review (auto). Delegates every step to existing commands with zero code duplication. Produces a fully planned, deepened, and reviewed epic ready for `/beads-work` or `/beads-parallel`.
</objective>

<execution_context>
<raw_argument> #$ARGUMENTS </raw_argument>

**Parse the input to determine the entry point:**

1. **If argument is empty:** Ask the user for a feature description or bead ID using the **AskUserQuestion tool**.

2. **If argument matches a bead ID pattern** (`^[a-z0-9]+-[a-z0-9]+(-[a-z0-9]+)*$`):
   ```bash
   bd show "#$ARGUMENTS" --json
   ```
   - If the bead has a `brainstorm` label or DECISION comments, treat it as a **brainstorm bead** -- skip brainstorming, proceed to Plan.
   - If the bead is type `epic` with child beads, treat it as an **existing epic** -- skip brainstorm and plan, proceed to Deepen.
   - If the bead exists but has neither, treat its title/description as the feature description and start from Brainstorm.
   - If the bead doesn't exist: report "Bead ID '#$ARGUMENTS' not found" and stop.

3. **If multiple bead IDs are provided** (space-separated): treat each as a phase bead ID. Load each and proceed to Deepen for all of them.

4. **If argument is free text:** treat it as a feature description and start from Brainstorm.

**Set DETAIL_LEVEL:**
- Default: **Comprehensive** (this command is the full-thoroughness pipeline)
- If the argument contains "standard" or "minimal" as the first word, extract it as the detail level override and use the rest as the feature description.
</execution_context>

<context>
**Note: The current year is 2026.**

**Architecture decisions (locked):** This command is a pure orchestrator. It delegates to `/beads-brainstorm`, `/beads-plan`, `/beads-deepen`, and `/beads-plan-review`. No planning logic, research dispatch, or bead creation lives here. When those commands improve, this command automatically inherits the improvements.

**Precedent:** Follows the `/lfg` pattern for compound commands that chain multiple steps.
</context>

<process>

## Step 0: Brainstorm (Interactive -- only if no existing brainstorm context)

**Skip condition:** If the input is a brainstorm bead ID (has `brainstorm` label or DECISION comments) or an existing epic, skip to Step 1.

Run the brainstorm command:

```
/beads-brainstorm {feature_description_or_bead_id}
```

This is fully interactive -- the user will have a collaborative dialogue exploring WHAT to build. The brainstorm produces a bead with DECISION/INVESTIGATION/FACT/PATTERN comments.

After brainstorm completes, capture the brainstorm bead ID for the next step.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Brainstorm complete: {BRAINSTORM_BEAD_ID}
  Proceeding to planning...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Step 1: Plan (Auto -- Comprehensive detail)

**Skip condition:** If the input is an existing epic with child beads, skip to Step 2.

Run the plan command with the brainstorm bead ID. The plan command will auto-detect the brainstorm context and skip its own idea refinement phase:

```
/beads-plan {BRAINSTORM_BEAD_ID}
```

When `/beads-plan` reaches its detail level selection, select **Comprehensive** (or the user's override if provided). When it reaches its handoff question, do not present it to the user -- continue the pipeline.

After the plan completes, capture the epic bead ID and its child beads:

```bash
# Get the epic ID from the plan output
bd list --type epic --status=open --json | jq -r 'sort_by(.created_at) | last | .id'

# List phase child beads
bd list --parent {EPIC_ID} --json
```

**Phase gate:** Verify the plan was created successfully:

```bash
bd swarm validate {EPIC_ID}
```

If validation fails, run the **phase gate recovery** (see below).

### Plan Confirmation Pause

Display the plan summary and ask the user to confirm before investing heavy compute:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Plan created: {EPIC_ID} — {epic_title}
  Phases: {N} child beads

  1. {child_1_id} — {child_1_title}
  2. {child_2_id} — {child_2_title}
  ...

  Next: Deepen + Review (~20-40 agents)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Use the **AskUserQuestion tool** to confirm:

**Question:** "Plan looks good? This will run deepen (~20-40 agents) and plan-review (4 agents)."

**Options:**
1. **Proceed** -- Continue with deepen + review
2. **Adjust plan first** -- Make changes before heavy compute
3. **Stop here** -- Keep the plan as-is, skip deepen + review

If "Adjust plan first": accept changes, re-validate, then ask again.
If "Stop here": jump to the Output Summary.

## Step 2: Deepen (Auto -- parallel agents)

Display the progress banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Deepening: {EPIC_ID} — {epic_title}
  [x] Brainstorm
  [x] Plan ({N} child beads)
  [ ] Deepening...
  [ ] Review pending
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Run the deepen command:

```
/beads-deepen {EPIC_ID}
```

When `/beads-deepen` completes, do not present its handoff to the user -- continue the pipeline.

**Phase gate:** Verify deepen enriched the child beads. Check that child bead descriptions grew or received new comments:

```bash
bd list --parent {EPIC_ID} --json | jq -r '.[] | "\(.id): \(.title)"'
```

If deepen fails, run the **phase gate recovery**.

## Step 3: Plan Review (Auto -- 4 agents)

Display the progress banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Reviewing: {EPIC_ID} — {epic_title}
  [x] Brainstorm
  [x] Plan ({N} child beads)
  [x] Deepened
  [ ] Reviewing...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Run the plan review command:

```
/beads-plan-review {EPIC_ID}
```

### Auto-Apply Safe Feedback

After plan-review completes, categorize the review findings:

**Safe to auto-apply** (do these without asking):
- Missing test cases -- add to child bead Testing section
- Documentation gaps -- add to child bead descriptions
- Typos or unclear wording -- fix in place
- Missing edge cases -- add to Validation section
- Straightforward improvements that don't change scope

**Requires user judgment** (pause for these):
- Architectural alternatives (e.g., "consider using X instead of Y")
- Scope changes (e.g., "this should also handle Z")
- Performance vs. simplicity trade-offs
- Security concerns that require design changes

If there are trade-off decisions, present them one at a time using the **AskUserQuestion tool**:

**Question:** "Review found a trade-off decision: {description}"

**Options:**
1. **Apply the suggestion** -- Update the plan accordingly
2. **Keep current approach** -- Log the alternative as a DECISION comment
3. **Discuss further** -- Explore the trade-off

After all review feedback is processed, run the **phase gate**:

```bash
bd swarm validate {EPIC_ID}
```

## Phase Gate Recovery

When any phase's verification fails:

1. Display what failed with details
2. Use the **AskUserQuestion tool**:

   **Question:** "{phase_name} verification failed: {failure_details}"

   **Options:**
   1. **Retry** -- Run the phase again
   2. **Skip this step** -- Continue to the next phase
   3. **Abort pipeline** -- Stop and show summary of completed work

If "Abort": jump directly to the Output Summary, marking incomplete phases.

## Output Summary

After all phases complete (or on abort), display:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Design complete!

  Epic: {EPIC_ID} — {epic_title}
  Phases: {N} planned, deepened, reviewed

  1. {child_1_id} — {child_1_title} ({child_1_child_count} tasks)
  2. {child_2_id} — {child_2_title} ({child_2_child_count} tasks)
  ...

  Decisions captured: {decision_count}
  Knowledge entries: {knowledge_count}

  Next: /beads-work {first_ready_child} or /beads-parallel {EPIC_ID}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

To get the counts:

```bash
# Child beads and their children
bd list --parent {EPIC_ID} --json

# Decision comments
bd show {EPIC_ID} --json | jq '[.[] | .comments[]? | select(.body | startswith("DECISION:"))] | length'

# Knowledge entries captured during this session
wc -l < .beads/memory/knowledge.jsonl
```

</process>

<success_criteria>
- Running `/beads-design` produces identical artifacts to running the 4 commands manually in sequence
- No functionality is lost from any individual command
- User interaction is reduced to: brainstorm dialogue + one plan confirmation + trade-off decisions only
- Bead IDs, knowledge comments, and enriched descriptions flow correctly between all phases
- Phase gate recovery works (retry/skip/abort) at every stage
- Each delegated command retains its internal parallelism (deepen spawns 20-40+ agents, plan-review runs 4 concurrently)
- Final summary accurately reports completed work and next steps
</success_criteria>

<guardrails>
- **Pure orchestration only** -- NEVER duplicate logic from `/beads-brainstorm`, `/beads-plan`, `/beads-deepen`, or `/beads-plan-review`. Delegate to them.
- **NEVER CODE** -- This command produces plans, not implementations
- **Do not skip steps silently** -- Always display progress banners so the user knows where they are
- **Do not invent new research or review agents** -- Use only what the delegated commands already provide
- **Respect the pause contract** -- Interactive brainstorm, auto-plan, pause to confirm plan, then auto-deepen + auto-review. No extra confirmations.
- **Do not suppress delegated command output** -- Let each command's output flow through. Only suppress their handoff questions to maintain pipeline continuity.
</guardrails>

<handoff>
After displaying the output summary, use the **AskUserQuestion tool**:

**Question:** "Design pipeline complete for `{EPIC_ID}`. What next?"

**Options:**
1. **`/beads-work {first_ready_child}`** -- Start implementing the first ready phase
2. **`/beads-parallel {EPIC_ID}`** -- Work all phases in parallel with multiple agents
3. **Revise the plan** -- Make adjustments before implementation
4. **Done for now** -- Come back later

Based on selection, invoke the chosen command or exit.
</handoff>

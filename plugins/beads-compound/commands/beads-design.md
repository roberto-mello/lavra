---
name: beads-design
description: Orchestrate the full design pipeline -- brainstorm, plan, research, revise, review, lock
argument-hint: "[brainstorm bead ID or feature description]"
---

<objective>
Orchestrate the full six-phase design pipeline as a single invocation: brainstorm (interactive), plan (auto), research (domain-matched agents), revise (integrate findings), adversarial review (4 agents), and final plan lock. Delegates every phase to existing commands with zero code duplication. The output must be so detailed that `/beads-work` execution is mechanical -- subagents can implement without asking questions.
</objective>

<execution_context>
<raw_argument> #$ARGUMENTS </raw_argument>

**Parse the input to determine the entry point:**

1. **If argument is empty:** Ask the user for a feature description or bead ID using the **AskUserQuestion tool**.

2. **If argument matches a bead ID pattern** (`^[a-z0-9]+-[a-z0-9]+(-[a-z0-9]+)*$`):
   ```bash
   bd show "#$ARGUMENTS" --json
   ```
   - If the bead has a `brainstorm` label or DECISION comments, treat it as a **brainstorm bead** -- skip Phase 1, proceed to Phase 2 (Plan).
   - If the bead is type `epic` with child beads, treat it as an **existing epic** -- skip Phases 1-2, proceed to Phase 3 (Research).
   - If the bead exists but has neither, treat its title/description as the feature description and start from Phase 1 (Brainstorm).
   - If the bead doesn't exist: report "Bead ID '#$ARGUMENTS' not found" and stop.

3. **If multiple bead IDs are provided** (space-separated): treat each as a phase bead ID. Load each and proceed to Phase 3 (Research) for all of them.

4. **If argument is free text:** treat it as a feature description and start from Phase 1 (Brainstorm).

**Set DETAIL_LEVEL:**
- Default: **Comprehensive** (this command is the full-thoroughness pipeline)
- If the argument contains "standard" or "minimal" as the first word, extract it as the detail level override and use the rest as the feature description.
</execution_context>

<context>
**Note: The current year is 2026.**

**Architecture decisions (locked):** This command is a pure orchestrator. It delegates to `/beads-brainstorm`, `/beads-plan`, `/beads-research`, and `/beads-plan-review`. No planning logic, research dispatch, or bead creation lives here. When those commands improve, this command automatically inherits the improvements.

**Design principle:** The output of `/beads-design` must be so good that `/beads-work` execution is mechanical. The final plan must be detailed enough that subagents can implement without asking questions.

**Precedent:** Follows the `/lfg` pattern for compound commands that chain multiple steps.
</context>

<process>

## Phase 1: Brainstorm (Interactive -- explore and sharpen scope)

**Skip condition:** If the input is a brainstorm bead ID (has `brainstorm` label or DECISION comments) or an existing epic, skip to Phase 2.

Run the brainstorm command:

```
/beads-brainstorm {feature_description_or_bead_id}
```

This is fully interactive -- the user will have a collaborative dialogue exploring WHAT to build. The brainstorm includes the CEO/sharpen phase that narrows scope and forces hard prioritization questions. Output: locked decisions, prioritized scope, phases filed as child beads.

After brainstorm completes, capture the brainstorm bead ID for the next phase.

```
----------------------------------------------------
  Phase 1 complete: Brainstorm
  Bead: {BRAINSTORM_BEAD_ID}
  Locked decisions: {count}
  Scope: {EXPANSION|HOLD|REDUCTION}
----------------------------------------------------
```

**GATE: User confirms scope direction.**

Use the **AskUserQuestion tool**:

**Question:** "Brainstorm complete. The locked decisions and scope above will drive the implementation plan. Confirm direction before investing compute in planning?"

**Options:**
1. **Proceed to planning** -- Scope and decisions look right
2. **Adjust scope** -- Revisit the sharpen phase
3. **Stop here** -- Keep brainstorm output, design later

If "Adjust scope": re-run the sharpen discussion, then ask again.
If "Stop here": jump to the Output Summary with only Phase 1 marked complete.

## Phase 2: Plan (Auto -- structured implementation plan)

**Skip condition:** If the input is an existing epic with child beads, skip to Phase 3.

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

```
----------------------------------------------------
  Phase 2 complete: Plan
  Epic: {EPIC_ID} -- {epic_title}
  Child beads: {N}
----------------------------------------------------
```

**GATE: User confirms plan structure.**

Display the plan summary and ask the user to confirm before investing heavy compute in research:

```
----------------------------------------------------
  Plan created: {EPIC_ID} -- {epic_title}
  Child beads: {N}

  1. {child_1_id} -- {child_1_title}
  2. {child_2_id} -- {child_2_title}
  ...

  Next: Research (domain-matched agents) + Review (4 agents)
----------------------------------------------------
```

Use the **AskUserQuestion tool**:

**Question:** "Plan structure looks good? Next phases: research with domain-matched agents, then adversarial review with 4 agents."

**Options:**
1. **Proceed** -- Continue with research + review
2. **Adjust plan first** -- Make changes before heavy compute
3. **Stop here** -- Keep the plan as-is, skip remaining phases

If "Adjust plan first": accept changes, re-validate, then ask again.
If "Stop here": jump to the Output Summary.

## Phase 3: Research (Auto -- domain-matched evidence gathering)

Display the progress banner:

```
----------------------------------------------------
  Researching: {EPIC_ID} -- {epic_title}
  [x] Brainstorm (locked decisions captured)
  [x] Plan ({N} child beads)
  [ ] Researching...
  [ ] Revise pending
  [ ] Review pending
  [ ] Final plan pending
----------------------------------------------------
```

Run the research command:

```
/beads-research {EPIC_ID}
```

`/beads-research` selects agents based on the plan's domain indicators (languages, frameworks, concerns). It gathers evidence -- docs, prior art, best practices, edge cases, knowledge recall -- and logs findings as INVESTIGATION/FACT/PATTERN comments on the relevant child beads. It does NOT modify the plan.

When `/beads-research` completes, do not present its handoff to the user -- continue the pipeline.

**Phase gate:** Verify research enriched the child beads. Check that child bead descriptions grew or received new comments:

```bash
bd list --parent {EPIC_ID} --json | jq -r '.[] | "\(.id): \(.title)"'
```

If research fails, run the **phase gate recovery**.

**Iteration check:** If research reveals the plan needs significant revision (e.g., a core assumption is wrong, a critical dependency was missed, or a selected technology is unsuitable), flag this for Phase 4. Note which findings require plan changes vs. which are additive context.

## Phase 4: Revise Plan (Auto -- integrate research findings)

Display the progress banner:

```
----------------------------------------------------
  Revising: {EPIC_ID} -- {epic_title}
  [x] Brainstorm
  [x] Plan ({N} child beads)
  [x] Researched ({agent_count} agents)
  [ ] Revising...
  [ ] Review pending
  [ ] Final plan pending
----------------------------------------------------
```

**4.1 Collect research findings:**

Read all comments added by `/beads-research`:

```bash
# Read comments on each child bead
bd comments list {CHILD_ID}
```

Categorize findings:
- **Additive context** -- new information that enriches the plan (add to bead descriptions)
- **Corrections** -- findings that contradict plan assumptions (must update the plan)
- **New risks** -- risks not anticipated in the original plan (add to risk sections)
- **Missing scope** -- gaps the research revealed (may need new child beads)

**4.2 Update child bead descriptions:**

For each child bead with research findings:

```bash
bd show {CHILD_ID} --json | jq -r '.[0].description'
```

Integrate findings into the existing structure:
- Add research evidence to the **Context** section
- Update **Testing** section with edge cases discovered
- Update **Validation** section with new acceptance criteria
- Update **Files** section if research revealed additional files to modify
- Add **Risks** subsection if high-severity findings exist

```bash
bd update {CHILD_ID} -d "{updated description with research findings integrated}"
```

**4.3 Resolve conflicts:**

If research findings conflict with plan assumptions or locked decisions from brainstorm:
- Document the conflict clearly
- If the conflict is minor (implementation detail), resolve it using the research evidence
- If the conflict is significant (architectural direction, scope change), log it for the user to address during the Phase 5 review gate

```bash
bd comments add {EPIC_ID} "DECISION: Research conflict resolved -- {description}. Research showed {finding}, original plan assumed {assumption}. Updated plan to {resolution}."
```

**4.4 Handle significant revision needs:**

If research reveals the plan needs major changes (new child beads, removed child beads, reordered dependencies):

1. Make the structural changes
2. Re-validate the epic:
   ```bash
   bd swarm validate {EPIC_ID}
   ```
3. Log what changed:
   ```bash
   bd comments add {EPIC_ID} "DECISION: Plan revised after research. Changes: {summary of structural changes}."
   ```

**Iteration gate:** If the revision was substantial enough that the new plan content would benefit from additional research (e.g., a new child bead was added covering unfamiliar territory), loop back to Phase 3 for a targeted research pass on just the new/changed beads. Limit to one iteration to avoid infinite loops.

```
----------------------------------------------------
  Phase 4 complete: Plan Revised
  Updated: {count} child beads
  New beads added: {count or 'none'}
  Conflicts resolved: {count or 'none'}
----------------------------------------------------
```

## Phase 5: Adversarial Review (Auto -- 4 agents)

Display the progress banner:

```
----------------------------------------------------
  Reviewing: {EPIC_ID} -- {epic_title}
  [x] Brainstorm
  [x] Plan ({N} child beads)
  [x] Researched
  [x] Revised
  [ ] Reviewing...
  [ ] Final plan pending
----------------------------------------------------
```

Run the plan review command:

```
/beads-plan-review {EPIC_ID}
```

This dispatches 4 agents in parallel:
1. `architecture-strategist` -- structural soundness, scalability, maintainability
2. `code-simplicity-reviewer` -- unnecessary complexity, over-engineering
3. `security-sentinel` -- vulnerabilities, auth gaps, data exposure
4. `performance-oracle` -- bottlenecks, N+1 queries, caching gaps

**GATE: User reviews findings before final plan.**

After `/beads-plan-review` completes, present its findings summary and categorize them:

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

Use the **AskUserQuestion tool** for each trade-off decision:

**Question:** "Review found a trade-off decision: {description}"

**Options:**
1. **Apply the suggestion** -- Update the plan accordingly
2. **Keep current approach** -- Log the alternative as a DECISION comment
3. **Discuss further** -- Explore the trade-off

After all review feedback is processed, validate:

```bash
bd swarm validate {EPIC_ID}
```

## Phase 6: Final Plan (Auto -- lock and annotate)

Display the progress banner:

```
----------------------------------------------------
  Locking: {EPIC_ID} -- {epic_title}
  [x] Brainstorm
  [x] Plan ({N} child beads)
  [x] Researched
  [x] Revised
  [x] Reviewed (4 agents)
  [ ] Locking final plan...
----------------------------------------------------
```

**6.1 Apply safe review feedback:**

Auto-apply all safe feedback items identified in Phase 5. For each child bead that needs updates:

```bash
bd show {CHILD_ID} --json | jq -r '.[0].description'
# Integrate safe feedback
bd update {CHILD_ID} -d "{updated description}"
```

**6.2 Ensure every child bead has the required final sections:**

Read each child bead and verify it contains all of:

- **File-level scope**: Specific files to create or modify (paths, not module names)
- **Dependencies**: What blocks this bead (other bead IDs)
- **Decisions already made**: Locked decisions from brainstorm and research that apply to this bead -- implementation must not re-debate these
- **Known risks with mitigations decided**: Risks from research/review with chosen mitigations
- **Anti-patterns to avoid**: From knowledge recall and review findings
- **Testing**: Specific test cases, edge cases, integration tests
- **Validation**: Acceptance criteria

If any section is missing or thin, fill it from the accumulated context (brainstorm decisions, research findings, review feedback).

```bash
bd update {CHILD_ID} -d "{final description with all required sections}"
```

**6.3 Update the epic with the final plan annotation:**

```bash
bd comments add {EPIC_ID} "DECISION: Plan reviewed and locked. {N} child beads, {review_finding_count} review findings addressed ({auto_applied} auto-applied, {user_decided} user-decided, {skipped} skipped). Dependency ordering validated. Ready for /beads-work."
```

**6.4 Add the plan label:**

```bash
bd update {EPIC_ID} --labels plan-reviewed
```

**6.5 Final validation:**

```bash
bd swarm validate {EPIC_ID}
```

```
----------------------------------------------------
  Phase 6 complete: Plan Locked
  Epic: {EPIC_ID} -- {epic_title}
  Status: Reviewed, concerns addressed
  Ready for implementation
----------------------------------------------------
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
----------------------------------------------------
  Design complete!

  Epic: {EPIC_ID} -- {epic_title}
  Phases completed: {list of completed phases}

  Child beads:
  1. {child_1_id} -- {child_1_title} ({child_1_child_count} tasks)
  2. {child_2_id} -- {child_2_title} ({child_2_child_count} tasks)
  ...

  File-level scope:
  - {child_1_id}: {file list summary}
  - {child_2_id}: {file list summary}
  ...

  Dependency ordering:
  - {child_a_id} blocks {child_b_id}
  ...

  Decisions locked: {decision_count}
  Knowledge entries: {knowledge_count}
  Review findings addressed: {finding_count}

  Next: /beads-work {first_ready_child} or /beads-work {EPIC_ID}
----------------------------------------------------
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
- Running `/beads-design` produces a fully planned, researched, reviewed, and locked epic
- Each phase delegates to its respective command with zero code duplication
- Phase 1 (brainstorm) output feeds directly into Phase 2 (plan) as locked decisions
- Phase 3 (research) gathers evidence without modifying the plan
- Phase 4 (revise) integrates research findings into bead descriptions
- Phase 5 (review) catches blind spots with 4 parallel agents
- Phase 6 (lock) ensures every child bead has file-level scope, dependency ordering, locked decisions, known risks, and anti-patterns
- User interaction is reduced to: brainstorm dialogue + scope confirmation + plan confirmation + review trade-off decisions only
- Bead IDs, knowledge comments, and enriched descriptions flow correctly between all phases
- Phase gate recovery works (retry/skip/abort) at every stage
- Each delegated command retains its internal parallelism (research dispatches domain-matched agents, plan-review runs 4 concurrently)
- The final plan is detailed enough that subagents can implement without asking questions
- Phases 3-4 can iterate once if research reveals the plan needs significant revision
</success_criteria>

<guardrails>
- **Pure orchestration only** -- NEVER duplicate logic from `/beads-brainstorm`, `/beads-plan`, `/beads-research`, or `/beads-plan-review`. Delegate to them.
- **NEVER CODE** -- This command produces plans, not implementations
- **Do not skip steps silently** -- Always display progress banners so the user knows where they are
- **Do not invent new research or review agents** -- Use only what the delegated commands already provide
- **Respect the gate contract** -- Gates after Phase 1, Phase 2, and Phase 5 require user confirmation. Phases 3-4 run without interruption unless iteration is needed.
- **Do not suppress delegated command output** -- Let each command's output flow through. Only suppress their handoff questions to maintain pipeline continuity.
- **Use /beads-research, not /beads-deepen** -- The research command was renamed. Always reference `/beads-research`.
</guardrails>

<handoff>
After displaying the output summary, use the **AskUserQuestion tool**:

**Question:** "Design pipeline complete for `{EPIC_ID}`. Plan is reviewed and locked. What next?"

**Options:**
1. **`/beads-work {first_ready_child}`** -- Start implementing the first ready child bead
2. **`/beads-work {EPIC_ID}`** -- Work all child beads in parallel with multiple agents
3. **Revise the plan** -- Make adjustments before implementation
4. **Done for now** -- Come back later

Based on selection, invoke the chosen command or exit.
</handoff>
</output>

---
name: lavra-work
description: Execute work on one or many beads -- auto-routes between single-bead and multi-bead paths based on input
argument-hint: "[bead ID, epic ID, comma-separated IDs, or empty for all ready beads] [--yes] [--no-parallel]"
---

<objective>
Execute work on beads efficiently while maintaining quality and finishing features. Auto-routes between single-bead direct execution and multi-bead parallel dispatch based on input. For autonomous retry, use `/lavra-work-ralph`. For persistent worker teams, use `/lavra-work-teams`.
</objective>

<execution_context>
<input_document> #$ARGUMENTS </input_document>
</execution_context>

<process>

## Phase 0: Parse Arguments and Auto-Route

### 0a. Parse Arguments

Parse flags from the `$ARGUMENTS` string:

- `--yes`: skip user approval gate (but NOT pre-push review)
- `--no-parallel`: disable parallel agent dispatch in multi-bead mode. Beads execute one at a time with a review pause between each.

Remaining arguments (after removing flags) are the bead input: a single bead ID, an epic bead ID, comma-separated IDs, a specification path, or empty.

### 0b. Permission Check

**Only when running as a subagent** (BEAD_ID was injected into the prompt):

Check whether the current permission mode will block autonomous execution. Subagents need Bash, Write, and Edit tool access without human approval.

If tool permissions appear restricted:
- Warn: "Permission mode may block autonomous execution. Subagents need Bash, Write, and Edit tool access without human approval."
- Suggest: "For autonomous execution, ensure your settings.json allows Bash and Write tools, or run with --dangerously-skip-permissions."

This is a warning only -- continue regardless.

### 0c. Determine Routing

Count beads to decide which path to take:

**If a single bead ID or specification path was provided:**
- Route = SINGLE

**If an epic bead ID was provided:**
```bash
bd list --parent {EPIC_ID} --status=open --json
```
- If 1 bead returned: Route = SINGLE (with that bead)
- If N > 1 beads returned: Route = MULTI

**If a comma-separated list of bead IDs was provided:**
- If 1 ID: Route = SINGLE
- If N > 1 IDs: Route = MULTI

**If nothing was provided:**
```bash
bd ready --json
```
- If 0 beads: inform user "No ready beads found. Use /lavra-design to plan new work or bd create to add a bead." Exit.
- If 1 bead: Route = SINGLE (with that bead)
- If N > 1 beads: Route = MULTI

---

## Execute the Routed Path

**Read the appropriate reference file** based on the route:

- **SINGLE**: Read `.claude/skills/lavra-work/single-bead.md` (fall back to `plugins/lavra/skills/lavra-work/single-bead.md`)
- **MULTI**: Read `.claude/skills/lavra-work/multi-bead.md` (fall back to `plugins/lavra/skills/lavra-work/multi-bead.md`)

**Follow the phases in the reference file in order.** Each `<phase>` tag has an `order` attribute and may have `requires` or `gate` attributes that enforce sequencing. Do not skip phases or reorder them.

Pass the parsed flags (`--yes`, `--no-parallel`) and resolved bead IDs to the path.

</process>

<success_criteria>

### Single-Bead Path
- [ ] All clarifying questions asked and answered
- [ ] All tasks marked completed
- [ ] Tests pass
- [ ] Linting passes
- [ ] Review completed (self-review + /lavra-review per review_scope config)
- [ ] Knowledge captured (at least one LEARNED/DECISION comment)
- [ ] Code follows existing patterns
- [ ] Bead validation criteria met
- [ ] Commit messages follow conventional format

### Multi-Bead Path
- [ ] All resolved beads are closed with `bd close`
- [ ] Each bead has at least one knowledge comment
- [ ] /lavra-review ran after each wave (per review_scope config)
- [ ] Code changes committed and pushed
- [ ] File ownership respected (no cross-bead file modifications)
- [ ] Any skipped beads reported with reasons

</success_criteria>

<guardrails>

### Start Fast, Execute Faster

- Get clarification once at the start, then execute
- Don't wait for perfect understanding -- ask questions and move
- The goal is to **finish the feature**, not create perfect process

### The Bead is Your Guide

- Bead descriptions reference similar code and patterns
- Load those references and follow them
- Don't reinvent -- match what exists

### Test As You Go

- Run tests after each change, not at the end
- Fix failures immediately

### Quality is Built In

- Follow existing patterns
- Write tests for new code
- Run linting before pushing
- The review phase catches what you missed -- trust the process

### Ship Complete Features

- Mark all tasks completed before moving on
- Don't leave features 80% done

### Multi-Bead: File Ownership is Law

- Subagents must only modify files in their ownership list
- Violations are reverted by the orchestrator

### For Autonomous Retry or Persistent Workers

Use the dedicated commands:
- `/lavra-work-ralph` -- autonomous retry with completion promises
- `/lavra-work-teams` -- persistent worker teammates with COMPLETED/ACCEPTED protocol

</guardrails>

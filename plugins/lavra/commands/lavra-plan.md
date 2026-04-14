---
name: lavra-plan
description: Transform feature descriptions into well-structured beads with parallel research and multi-phase planning
argument-hint: "[bead ID or feature description]"
---

<objective>
Transform feature descriptions, bug reports, or improvement ideas into well-structured beads with comprehensive research and multi-phase planning. Provides flexible detail levels to match your needs.
</objective>

<execution_context>
<raw_argument> #$ARGUMENTS </raw_argument>

**First, determine if the argument is a bead ID or a feature description:**

Check if the argument matches a bead ID pattern:
- Pattern: lowercase alphanumeric segments separated by hyphens (e.g., `bikiniup-xhr`, `beads-123`, `fix-auth-bug2`)
- Regex: `^[a-z0-9]+-[a-z0-9]+(-[a-z0-9]+)*$`

**If the argument matches a bead ID pattern:**

1. Try to load the bead using the Bash tool:
   ```bash
   bd show "#$ARGUMENTS" --json
   ```

2. If the bead exists:
   - Extract the `title` and `description` fields from the JSON array (first element)
   - Example: `bd show "#$ARGUMENTS" --json | jq -r '.[0].description'`
   - Use the bead's description as the `<feature_description>` for the rest of this workflow
   - Announce: "Planning epic bead #$ARGUMENTS: {title}"
   - If the bead already has child beads, list them and ask: "This bead already has child beads. Should I continue planning (will add more children) or was this a mistake?"

3. If the bead doesn't exist (command fails):
   - Report: "Bead ID '#$ARGUMENTS' not found. Please check the ID or provide a feature description instead."
   - Stop execution

**If the argument does NOT match a bead ID pattern:**
- Treat it as a feature description: `<feature_description>#$ARGUMENTS</feature_description>`
- Continue with the workflow

**If the argument is empty:**
- Ask: "What would you like to plan? Please provide either a bead ID (e.g., 'bikiniup-xhr') or describe the feature, bug fix, or improvement you have in mind."

Do not proceed until you have a clear feature description from the user.
</execution_context>

<context>
**Note: The current year is 2026.** Use this when dating plans and searching for recent documentation.
</context>

<process>

### 0. Idea Refinement

**Check for brainstorm output first:**

Use this decision tree — stop at the first match and skip idea refinement:

#### Step 0a. Label-Based Detection (fast, deterministic — check FIRST)

If the argument is a bead ID, check whether the bead itself or its parent has a `brainstorm` label:

```bash
# Check labels on the input bead
bd show "{BEAD_ID}" --json | jq -r '.[0].labels // [] | .[]'

# If it has a parent, check the parent's labels too
bd show "{BEAD_ID}" --json | jq -r '.[0].parent // empty'
# If parent exists:
bd show "{PARENT_ID}" --json | jq -r '.[0].labels // [] | .[]'
```

**Label match** = the bead itself, or its parent, has a label containing `brainstorm`.

If label match found: set `BRAINSTORM_ID` to the matching bead ID and jump to [**Brainstorm Detected**](#brainstorm-detected) below.

#### Step 0b. Keyword Match — Recent (<=14 days)

Search for brainstorm-related knowledge and beads using keywords from the feature description:

```bash
# Search for brainstorm-related knowledge
.lavra/memory/recall.sh "brainstorm"
.lavra/memory/recall.sh "{keywords from feature description}"

# Check for recent brainstorm beads (title-based)
bd list --status=open --json 2>/dev/null | jq -r '.[] | select(.title | test("brainstorm|explore|investigate"; "i")) | "\(.id): \(.title) (\(.updated_at // .created_at))"'
```

**Relevance criteria:** A brainstorm entry is relevant if:
- The topic semantically matches the feature description
- Created or updated within the last 14 days
- If multiple candidates match, use the most recent one

If a relevant brainstorm bead found within 14 days: set `BRAINSTORM_ID` and jump to [**Brainstorm Detected**](#brainstorm-detected).

#### Step 0c. Keyword Match — Older (>14 days)

If a semantically matching brainstorm bead exists but is older than 14 days, use **AskUserQuestion tool** to ask:

"Found brainstorm `{BRAINSTORM_ID}` from [date] that may be relevant: {title}. It's older than 14 days — use it as context for this plan?"

- **Yes** -> set `BRAINSTORM_ID` and proceed to [**Brainstorm Detected**](#brainstorm-detected)
- **No** -> proceed to idea refinement below

#### Step 0d. No Brainstorm — Run Idea Refinement

If no brainstorm found (or not relevant), refine the idea through collaborative dialogue using the **AskUserQuestion tool**:

- Ask questions one at a time to understand the idea fully
- Prefer multiple choice questions when natural options exist
- Focus on understanding: purpose, constraints and success criteria
- Continue until the idea is clear OR user says "proceed"

**Think Before Planning.** Before asking any refinement questions or proceeding to research, externalize your interpretation:

- State in 1–2 sentences what you understand the request to be
- List any assumptions you are making that the user did not explicitly state
- If anything is ambiguous: ask ONE focused question to resolve it — not a list
- If multiple valid interpretations exist: present them briefly and ask which is intended
- If the request is unambiguous: say so and continue without interruption

Do not silently assume. Do not ask multiple questions at once.

**Gather signals for research decision.** During refinement, note:

- **User's familiarity**: Do they know the codebase patterns? Are they pointing to examples?
- **User's intent**: Speed vs thoroughness? Exploration vs execution?
- **Topic risk**: Security, payments, external APIs warrant more caution
- **Uncertainty level**: Is the approach clear or open-ended?

**Skip option:** If the feature description is already detailed, offer:
"Your description is clear. Should I proceed with research, or would you like to refine it further?"

---

#### Brainstorm Detected

When any of steps 0a–0c identifies a brainstorm bead, execute this block:

1. Read the brainstorm bead and its comments in full:
   ```bash
   bd show {BRAINSTORM_ID}
   bd comments list {BRAINSTORM_ID}
   ```

2. Extract **locked decisions** — look for:
   - Comments or description lines explicitly marked "LOCKED", "DECIDED", or "DECISION:"
   - The chosen approach (what was selected over alternatives)
   - Key constraints that were agreed upon

3. Announce the handoff with specifics:
   ```
   Found brainstorm {BRAINSTORM_ID} from [date]: "{title}"
   Skipping idea refinement — locked decisions carried forward:
   - [Decision 1]
   - [Decision 2]
   - [Decision N]
   ```

4. Store for use in later steps:
   - `BRAINSTORM_ID` = the bead ID
   - `BRAINSTORM_TITLE` = the bead title
   - `LOCKED_DECISIONS` = list of extracted locked decisions (short phrases)

5. **Skip the idea refinement dialogue** — the brainstorm already answered WHAT to build.

6. Use locked decisions as direct input to the research phase (Step 1).

**Note:** In Step 5 (Create Epic and Child Beads):
- The epic's Sources section **MUST** include: `Brainstorm: {BRAINSTORM_ID} — {BRAINSTORM_TITLE} (locked decisions: {comma-separated LOCKED_DECISIONS})`
- Each child bead's **Context section** MUST include a "Locked decisions from brainstorm:" subsection listing the decisions that apply to that child bead

**If multiple brainstorms could match (step 0b/0c):**
Use **AskUserQuestion tool** to ask which brainstorm to use, or whether to proceed without one.

### 0.5. Read Workflow Config

```bash
[ -f .lavra/config/lavra.json ] && cat .lavra/config/lavra.json
```

If the file exists, parse and store settings for use during planning. If it does not exist, use defaults: `research: true`, `plan_review: true`, `goal_verification: true`, `max_parallel_agents: 3`, `commit_granularity: "task"`, `testing_scope: "full"`.

### 1. Local Research (Always Runs - Parallel)

<thinking>
First, I need to understand the project's conventions, existing patterns, and any documented learnings. This is fast and local - it informs whether external research is needed.
</thinking>

Run these agents **in parallel** to gather local context:

- Task repo-research-analyst(feature_description)
- Task learnings-researcher(feature_description)

**What to look for:**
- **Repo research:** existing patterns, CLAUDE.md or AGENTS.md guidance, technology familiarity, pattern consistency
- **Learnings:** knowledge.jsonl entries that might apply (gotchas, patterns, lessons learned)

These findings inform the next step.

### 1.5. Research Decision

Based on signals from Step 0 and findings from Step 1, decide on external research.

**High-risk topics -> always research.** Security, payments, external APIs, data privacy. The cost of missing something is too high. This takes precedence over speed signals.

**Strong local context -> skip external research.** Codebase has good patterns, CLAUDE.md or AGENTS.md has guidance, user knows what they want. External research adds little value.

**Uncertainty or unfamiliar territory -> research.** User is exploring, codebase has no examples, new technology. External perspective is valuable.

**Announce the decision and proceed.** Brief explanation, then continue. User can redirect if needed.

Examples:
- "Your codebase has solid patterns for this. Proceeding without external research."
- "This involves payment processing, so I'll research current best practices first."

### 1.5b. External Research (Conditional)

**Only run if Step 1.5 indicates external research is valuable.**

Run these agents in parallel:

- Task best-practices-researcher(feature_description)
- Task framework-docs-researcher(feature_description)

### 1.6. Consolidate Research

After all research steps complete, consolidate findings:

- Document relevant file paths from repo research (e.g., `app/services/example_service.rb:42`)
- **Include relevant institutional learnings** from knowledge.jsonl (key insights, gotchas to avoid)
- Note external documentation URLs and best practices (if external research was done)
- List related issues or PRs discovered
- Capture CLAUDE.md or AGENTS.md conventions

**Optional validation:** Briefly summarize findings and ask if anything looks off or missing before proceeding to planning.

### 2. Epic Bead Planning & Structure

<thinking>
Think like a product manager - what would make this issue clear and actionable? Consider multiple perspectives.
</thinking>

**Title & Categorization:**

- [ ] Draft clear, searchable title using conventional format (e.g., `Add user authentication`, `Fix cart total calculation`)
- [ ] Determine type: feature, bug, refactor, chore
- [ ] Log a DECISION comment explaining the chosen approach

**Stakeholder Analysis:**

- [ ] Identify who will be affected by this issue (end users, developers, operations)
- [ ] Consider implementation complexity and required expertise

**Content Planning:**

- [ ] Choose appropriate detail level based on complexity and audience
- [ ] List all necessary sections for the chosen template
- [ ] Gather supporting materials (error logs, screenshots, design mockups)
- [ ] Prepare code examples or reproduction steps if applicable

### 3. SpecFlow Analysis

After planning the structure, run SpecFlow Analyzer to validate and refine the feature specification:

- Task spec-flow-analyzer(feature_description, research_findings)

**SpecFlow Analyzer Output:**

- [ ] Review SpecFlow analysis results
- [ ] Incorporate any identified gaps or edge cases
- [ ] Update acceptance criteria based on SpecFlow findings

### 4. Choose Implementation Detail Level

Select how comprehensive you want the beads to be, simpler is mostly better.

Use **AskUserQuestion tool** to present options:

#### MINIMAL (Quick Plan)

**Best for:** Simple bugs, small improvements, clear features

**Bead descriptions include:**
- Problem statement or feature description
- Basic acceptance criteria
- Essential context only

#### STANDARD (Recommended)

**Best for:** Most features, complex bugs, team collaboration

**Bead descriptions include everything from MINIMAL plus:**
- Detailed background and motivation
- Technical considerations
- Success metrics
- Dependencies and risks
- Basic implementation suggestions

#### COMPREHENSIVE (Deep Plan)

**Best for:** Major features, architectural changes, complex integrations

**Bead descriptions include everything from STANDARD plus:**
- Detailed implementation plan with phases
- Alternative approaches considered
- Extensive technical specifications
- Risk mitigation strategies
- Future considerations and extensibility

### 5. Create Epic and Child Beads

**Create the epic bead:**

The epic bead description MUST include a Sources section capturing where the plan came from:

```
## Sources
- Brainstorm: {BRAINSTORM_BEAD_ID} — {title} (locked decisions: X, Y, Z)
- File: path/to/file.ext:42 — existing pattern used
- Knowledge: {knowledge-key} (LEARNED) — key insight
- Doc: https://example.com/docs — reference documentation
- Research: best-practices-researcher found X pattern
```

Include only the source types that apply. If a brainstorm bead was used in Step 0, it MUST appear as a `Brainstorm:` entry.

```bash
bd create "{title}" --type epic -d "{overview description with research findings and Sources section}"
```

**For each implementation step, create a child bead with thorough descriptions:**

Each child bead description MUST follow this structure. **Completeness over brevity** -- include every decision the agent needs so it makes zero judgment calls. If that takes 300 lines, fine. If 50, also fine. **Scope budget: ~1000 LOC of changes per bead.** If a bead would require more than ~1000 lines of code changes, split it into smaller beads.

```
## What

[Clear description of what needs to be implemented]

## Context

[Relevant findings from research - constraints, patterns, decisions]

## Decisions

### Locked
[Decisions inherited from parent epic that MUST be honored. Do not re-debate these.]
- {locked decision from epic}

### Discretion
[Areas where the implementing agent can choose. Deviation budget for this bead.]
- {area where agent can decide approach}

## Testing

When `testing_scope` is `"full"` (default):
- [ ] [Specific test case 1]
- [ ] [Specific test case 2]
- [ ] [Edge case tests]
- [ ] [Integration tests if needed]

When `testing_scope` is `"targeted"`: Specify tests only for: hooks, API routes, external service calls, complex state logic. Skip component render tests, static pages, and layout components.

## Validation

- [ ] [Acceptance criterion 1]
- [ ] [Acceptance criterion 2]
- [ ] [Performance/security requirements if applicable]

## Files

[Specific file paths or glob patterns this bead will modify]
- path/to/file.ext
- path/to/directory/*

## Dependencies

[List any child beads that must be completed first]

## References

[Sources relevant to this child bead — freeform bullet list]
- File: path/to/file.ext:42 — pattern used
- Knowledge: {key} (LEARNED) — relevant insight
```

**File-scope conflict prevention:**

When creating child beads, identify the specific files each bead will touch. **If two child beads would modify the same file, you MUST either:**
1. Merge them into a single bead, OR
2. Add an explicit dependency between them (`bd dep add {later} {earlier}`) so they execute sequentially

This prevents parallel agents from overwriting each other's changes during `/lavra-work` multi-bead execution. Be specific -- list file paths, not just module names.

**Create child beads:**

```bash
bd create "{step title}" --parent {EPIC_ID} -d "{comprehensive description}"
```

**Add research context as comments:**

```bash
bd comments add {CHILD_ID} "INVESTIGATION: {key research findings specific to this step}"
bd comments add {CHILD_ID} "PATTERN: {recommended patterns for this step}"
bd comments add {CHILD_ID} "FACT: {constraints or gotchas discovered}"
```

**Relate beads that share context:**

For beads that work in the same domain but don't block each other (e.g., "auth login" and "auth logout" touch different files but share auth knowledge), create relate links:

```bash
bd dep relate {BEAD_A} {BEAD_B}
```

This creates a bidirectional "see also" link. Related beads will have each other's context injected during `/lavra-work` multi-bead execution, improving agent awareness without forcing sequential ordering.

**When to use relate vs dep add:**
- `bd dep add`: Bead B cannot start until Bead A is done (blocking)
- `bd dep relate`: Beads share context but can run in parallel (non-blocking)

**AI-Era Considerations:**

- [ ] Account for accelerated development with AI pair programming
- [ ] Include prompts or instructions that worked well during research
- [ ] Emphasize comprehensive testing given rapid implementation

### 5.5. Cross-Check Validation

After creating all child beads, run a warning-only validation pass before final review.

**Checks to perform:**

1. **Required sections** — Each child bead description includes What/Context/Decisions/Testing/Validation/Files/Dependencies
2. **File-scope conflicts** — No two independent (non-dependent) child beads claim overlapping files (e.g., both modifying `src/auth/*`)
3. **Sources section** — Epic bead has a non-empty Sources section
4. **Brainstorm reference** — If a brainstorm bead was used in Step 0, the Sources section includes a `Brainstorm:` entry
5. **Completeness** — Each child bead description has enough detail that the implementing agent makes zero judgment calls. Missing What/Context/Decisions/Testing/Validation sections = incomplete.
6. **Scope budget** — Each child bead targets ~1000 LOC of changes or fewer. If estimated changes exceed this, flag for splitting.

**Output format:**

```
Cross-Check Results for {EPIC_ID}

! WARNING: {CHILD_ID} lacks "Files" section
! WARNING: {CHILD_1} and {CHILD_2} both modify src/auth/* without a dependency
! WARNING: Sources section missing brainstorm reference (brainstorm {ID} found)
! WARNING: {CHILD_ID} estimated >1000 LOC of changes -- split recommended
! WARNING: {CHILD_ID} missing required section(s): {missing sections}
v PASS: All child beads have Testing and Validation sections
v PASS: DAG validation passes (bd swarm validate)

-> Proceed to final review, or fix warnings first?
```

All checks are **warnings only** — they do not block submission. Use **AskUserQuestion tool** to ask whether to proceed or fix warnings first.

### 6. Final Review & Submission

**Pre-submission Checklist:**

- [ ] Epic title is searchable and descriptive
- [ ] All child bead descriptions include What/Context/Testing/Validation sections
- [ ] Dependencies between beads are correctly set
- [ ] No two independent child beads modify the same files (add dependency or merge if they do)
- [ ] Research findings are captured as knowledge comments
- [ ] Epic bead description includes a non-empty Sources section
- [ ] Add an ERD mermaid diagram if applicable for new model changes

**Validate the epic structure:**

```bash
bd swarm validate {EPIC_ID}
```

This checks for:
- Dependency cycles (impossible to resolve)
- Orphaned issues (no dependents, may be missing deps)
- Disconnected subgraphs
- Ready fronts (waves of parallel work)

Address any warnings before finalizing the plan.

</process>

<success_criteria>
- Epic bead created with clear, searchable title
- All child bead descriptions include What/Context/Decisions/Testing/Validation/Files/Dependencies sections
- Each child bead description is complete enough that the implementing agent makes zero judgment calls
- Each child bead targets ~1000 LOC of changes or fewer
- No two independent child beads modify the same files
- Dependencies correctly set between beads
- Research findings captured as knowledge comments (INVESTIGATION/PATTERN/FACT)
- `bd swarm validate {EPIC_ID}` passes without warnings
</success_criteria>

<guardrails>
- Don't create vague beads like "Add authentication" with no testing criteria, "Fix the bug" with no validation approach, or "Refactor code" with no acceptance criteria
- Do create thorough beads like "Implement OAuth2 login flow" with specific test scenarios, validation criteria, and constraints from research
- All research findings are logged to the epic bead with appropriate prefixes
- Knowledge is auto-captured and will be available in future sessions
- Child beads can be worked on independently with `/lavra-work`
- Use `bd ready` to see which child beads are ready to work on
- Each child bead description is complete enough that the implementing agent makes zero judgment calls
- NEVER CODE! Just research and write the plan.
</guardrails>

<handoff>
After creating the epic and child beads, use the **AskUserQuestion tool** to present these options:

**Question:** "Plan ready as epic `{EPIC_ID}`: {title}. What would you like to do next?"

**Options:**
1. **Run `/lavra-research`** - Gather evidence for each child bead with domain-matched research agents
2. **Run `/lavra-eng-review`** - Get feedback from reviewers on the plan
3. **Start `/lavra-work`** - Begin implementing the first child bead
4. **Run `/lavra-work {EPIC_ID}`** - Work on multiple child beads in parallel
5. **Simplify** - Reduce detail level

Based on selection:
- **`/lavra-research`** -> Call the /lavra-research command with the epic bead ID
- **`/lavra-eng-review`** -> Call the /lavra-eng-review command with the epic bead ID
- **`/lavra-work`** -> Call the /lavra-work command with the first ready child bead ID
- **`/lavra-work {EPIC_ID}`** -> Call the /lavra-work command with the epic bead ID
- **Simplify** -> Ask "What should I simplify?" then regenerate simpler descriptions
- **Other** (automatically provided) -> Accept free text for rework or specific changes

**Tip:** If this plan originated from `/lavra-brainstorm`, the brainstorm's locked decisions are already embedded in child bead descriptions.

Loop back to options after Simplify or Other changes until user selects `/lavra-work` or `/lavra-eng-review`.
</handoff>

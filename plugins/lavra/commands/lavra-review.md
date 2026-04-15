---
name: lavra-review
description: Perform exhaustive code reviews using multi-agent analysis and ultra-thinking
argument-hint: "[bead ID, PR number, GitHub URL, branch name, or latest]"
---

<objective>
Perform exhaustive code reviews using multi-agent analysis, ultra-thinking, and Git worktrees.
</objective>

<execution_context>
<review_target> #$ARGUMENTS </review_target>

<requirements>
- Git repository with GitHub CLI (`gh`) installed and authenticated
- Clean main/master branch
- Proper permissions to create worktrees and access the repository
- `bd` CLI installed for bead management
</requirements>
</execution_context>

<process>

### 1. Determine Review Target & Setup (ALWAYS FIRST)

#### Immediate Actions:

- [ ] Determine review type: bead ID (BD-xxx), PR number (numeric), GitHub URL, or empty (current in-progress bead)
- [ ] If bead ID provided: `bd show {BEAD_ID} --json`
- [ ] If no target: `bd list --status in_progress --json | jq -r '.[0].id'`
- [ ] Check current git branch
- [ ] If ALREADY on target branch -> proceed with analysis on current branch
- [ ] If DIFFERENT branch -> offer worktree: "Use git-worktree skill for isolated checkout." Call `skill: git-worktree` with branch name
- [ ] Fetch PR metadata via `gh pr view --json` for title, body, files, linked issues (if PR exists)
- [ ] Set up language-specific analysis tools
- [ ] Verify on the branch being reviewed

Code must be ready for analysis before proceeding.

### 2. Recall Relevant Knowledge

```bash
# Extract keywords from bead title/description
.lavra/memory/recall.sh "{keywords from bead title}"
.lavra/memory/recall.sh "{tech stack keywords}"
.lavra/memory/recall.sh --recent 10
```

Present relevant LEARNED/DECISION/FACT/PATTERN entries for reviewers.

#### Protected Artifacts

The following paths are lavra pipeline artifacts and must never be flagged for deletion, removal, or gitignore by any review agent:

- `.lavra/memory/knowledge.jsonl` -- Persistent knowledge store
- `.lavra/memory/knowledge.archive.jsonl` -- Archived knowledge
- `.lavra/memory/recall.sh` -- Knowledge search script
- `.lavra/config/project-setup.md` -- Project configuration (read-only input to pipeline)
- `.lavra/config/codebase-profile.md` -- Codebase analysis (read-only input to planning pipeline)
- `.lavra/config/lavra.json` -- Workflow configuration (toggle research, review, goal verification)

If a review agent flags any file in `.lavra/memory/` or `.lavra/config/` for cleanup or removal, discard that finding during synthesis. Do not create a bead for it.

### 3. Read Project Config & Dispatch Review Agents in Parallel

#### 3a. Read Project Config (optional)

```bash
[ -f .lavra/config/project-setup.md ] && cat .lavra/config/project-setup.md
[ -f .lavra/config/lavra.json ] && cat .lavra/config/lavra.json
```

From `project-setup.md`, parse YAML frontmatter for one field:
- `review_agents`: agent names to dispatch (replaces the default list below)

From `lavra.json`, parse `model_profile` (default: `"balanced"`).

**Model override rule:** When `model_profile` is `"quality"`, dispatch these critical agents with `model: opus`:
- `security-sentinel`
- `architecture-strategist`
- `performance-oracle`

All other agents run at their default tier regardless of profile.

> **Note:** `reviewer_context_note` is intentionally **not** injected into review agents. Review agents derive project context from the code itself. Context note injection is only done in `/lavra-work` multi-bead path (pre-work conventions for implementors) where the value is clearer and the injection surface is smaller.

**Agent allowlist validation** (when `review_agents` is present):

Derive allowlist from installed agent directories:
```bash
{ find .claude/agents ~/.claude/agents -name "*.md" 2>/dev/null; } | xargs -I{} basename {} .md | sort -u
```
Fall back to `plugins/lavra/agents/` if neither `.claude/agents/` nor `~/.claude/agents/` yields results.

- Reject names not matching `^[a-z][a-z0-9-]*$` or not in the derived allowlist
- Silently skip invalid names
- If all entries are invalid, fall back to dispatching all agents

**Config-missing behavior:** If `.lavra/config/project-setup.md` absent, dispatch ALL agents below.

#### 3b. Read Epic Plan (if provided)

If arguments include an `## Epic Plan` block (injected by `/lavra-work`), extract Locked Decisions and store as `{EPIC_LOCKED_DECISIONS}`. Do not pass to review agents (biases toward plan over code). Use only in synthesis step (step 6) as a discard filter: if a flagged item appears in Locked Decisions, discard and note: "Discarded: planned item per epic Locked Decisions."

If no `## Epic Plan` block present, `{EPIC_LOCKED_DECISIONS}` is empty and discard filter is a no-op.

#### 3c. Dispatch Agents in Parallel

Dispatch the validated agent list (from config) or ALL agents below:

1. Task kieran-rails-reviewer(PR content)
2. Task dhh-rails-reviewer(PR content)
3. Task kieran-typescript-reviewer(PR content)
4. Task kieran-python-reviewer(PR content)
5. Task git-history-analyzer(PR content)
6. Task pattern-recognition-specialist(PR content)
7. Task architecture-strategist(PR content) -- add `model: opus` if profile=quality
8. Task security-sentinel(PR content) -- add `model: opus` if profile=quality
9. Task performance-oracle(PR content) -- add `model: opus` if profile=quality
10. Task data-integrity-guardian(PR content)
11. Task agent-native-reviewer(PR content)
12. Task julik-frontend-races-reviewer(PR content)

#### Conditional Agents (run if applicable):

Run ONLY when PR matches specific criteria. Check PR files list:

**If PR contains migrations or schema changes (any ORM):**

13. Task data-migration-expert(PR content) - Validates migration code correctness: ID mappings match production, checks for swapped values, verifies rollback safety, SQL verification
14. Task deployment-verification-agent(PR content) - Creates Go/No-Go deployment checklist with SQL verification queries
15. Task migration-drift-detector(PR content) - Detects schema/migration drift: verifies schema artifacts are in sync with migration history across Rails, Alembic, Prisma, Drizzle, and Knex

**When to run migration agents:**
- PR includes migration files matching any ORM pattern:
  - `db/migrate/*.rb` (Rails)
  - `alembic/versions/*.py` (Alembic)
  - `prisma/migrations/*/migration.sql` (Prisma)
  - `drizzle/*/migration.sql` (Drizzle)
  - `migrations/*.js` or `migrations/*.ts` (Knex)
- PR modifies schema artifacts:
  - `db/schema.rb`, `prisma/schema.prisma`, `drizzle/meta/*.snapshot.json`
- PR modifies columns that store IDs, enums, or mappings
- PR includes data backfill scripts
- PR changes how data is read/written
- PR title/body mentions: migration, backfill, data transformation, ID mapping

**Agent roles are complementary:**
- `data-migration-expert`: migration **code** correctness (SQL logic, rollback safety, ID mapping values)
- `migration-drift-detector`: migration **consistency** (schema artifacts in sync with migration history)

### 4. Ultra-Thinking Deep Dive Phases

Spend maximum cognitive effort on each phase. Think step by step. Question assumptions. Synthesize all reviews for the user.

#### Phase A: Stakeholder Perspective Analysis

<thinking>
ULTRA-THINK: Put yourself in each stakeholder's shoes. What matters to them? What are their pain points?
</thinking>

1. **Developer Perspective**
   - Easy to understand and modify?
   - APIs intuitive?
   - Debugging straightforward?
   - Testable?

2. **Operations Perspective**
   - Safe to deploy?
   - Metrics and logs available?
   - Troubleshooting path clear?
   - Resource requirements known?

3. **End User Perspective**
   - Feature intuitive?
   - Error messages helpful?
   - Performance acceptable?
   - Solves the problem?

4. **Security Team Perspective**
   - Attack surface?
   - Compliance requirements?
   - Data protected?
   - Audit capabilities?

#### Phase B: Scenario Exploration

<thinking>
ULTRA-THINK: Explore edge cases and failure scenarios. What could go wrong? How does the system behave under stress?
</thinking>

- [ ] **Happy Path**: Normal operation with valid inputs
- [ ] **Invalid Inputs**: Null, empty, malformed data
- [ ] **Boundary Conditions**: Min/max values, empty collections
- [ ] **Concurrent Access**: Race conditions, deadlocks
- [ ] **Scale Testing**: 10x, 100x, 1000x normal load
- [ ] **Network Issues**: Timeouts, partial failures
- [ ] **Resource Exhaustion**: Memory, disk, connections
- [ ] **Security Attacks**: Injection, overflow, DoS
- [ ] **Data Corruption**: Partial writes, inconsistency
- [ ] **Cascading Failures**: Downstream service issues

### 5. Simplification and Minimalism Review

Run the Task code-simplicity-reviewer() to see if we can simplify the code.

### 6. Findings Synthesis and Bead Creation

ALL findings MUST be stored as child beads. Create beads immediately after synthesis -- do NOT present for user approval first.

#### Step 1: Build Agent Finding Inventory

Build a complete inventory of what each agent returned:

```
From kieran-rails-reviewer: [finding 1], [finding 2], ...
From dhh-rails-reviewer: [finding 1], [finding 2], ...
From security-sentinel: [finding 1], [finding 2], ...
From performance-oracle: [finding 1], [finding 2], ...
... (one row per agent that ran)
```

Source of truth for synthesis. Do not proceed to Step 2 until every agent's output is listed.

#### Step 2: Synthesize All Findings

<thinking>
Consolidate all agent reports into a categorized list of findings.
Remove duplicates, prioritize by severity and impact.
</thinking>

- [ ] Collect findings from the inventory
- [ ] Discard findings recommending deletion/gitignore of files in `.lavra/memory/` or `.lavra/config/` (see Protected Artifacts)
- [ ] If `{EPIC_LOCKED_DECISIONS}` non-empty: for each finding flagging a field, struct, behavior, or data flow as unused/dead/unnecessary -- check Locked Decisions. If present, discard with note: "Discarded: planned item per epic Locked Decisions (`{item name}`)."
- [ ] Categorize by type: security, performance, architecture, quality, etc.
- [ ] Assign severity: P1 CRITICAL, P2 IMPORTANT, P3 NICE-TO-HAVE
- [ ] Deduplicate -- `data-migration-expert` and `migration-drift-detector` may overlap; keep the more specific finding
- [ ] Estimate effort per finding (Small/Medium/Large)

#### Step 2a: Completeness Verification

Before creating beads:

- [ ] Every inventory finding is either included OR explicitly marked duplicate/inapplicable with reason
- [ ] Count: inventory total vs. categorized + discarded -- must reconcile
- [ ] Unaccounted items: categorize now

**Do not proceed to bead creation until inventory fully accounted for.**

#### Step 3: Create Beads for All Findings

```bash
bd create "{finding title}" \
  --parent {BEAD_ID} \
  --type {bug|task|improvement} \
  --priority {1-5} \
  --tags "review,{category},{BEAD_ID}" \
  -d "## Issue
{Detailed description}

## Severity
{P1/P2/P3} - {Why this severity}

## Location
{file:line references}

## Why This Matters
{Impact and consequences}

## Validation Criteria
- [ ] {Test that must pass}
- [ ] {Behavior to verify}

## Testing Steps
1. {How to reproduce/test}
2. {Expected outcome}"
```

**Priority mapping:**
- P1 CRITICAL -> priority 1 (blocks closing original bead)
- P2 IMPORTANT -> priority 2 (should fix before closing)
- P3 NICE-TO-HAVE -> priority 3-5 (can defer)

#### Step 4: Link Critical Issues

P1 findings: create blocking dependencies:

```bash
bd dep relate {FINDING_BEAD_ID} {ORIGINAL_BEAD_ID}
```

Ensures the original bead cannot close until critical issues are resolved.

#### Step 5: Mandatory Knowledge Capture *(required gate -- do not skip)*

Every P1/P2 finding **must** have at least one LEARNED or PATTERN entry before the summary. Captures root cause for future `/lavra-design` and `/lavra-work` auto-recall.

For each P1/P2 finding:

```bash
# Format: what was vulnerable/broken + root cause
bd comments add {BEAD_ID} "LEARNED: [component] was vulnerable to [issue] because [root cause]"
bd comments add {BEAD_ID} "PATTERN: [anti-pattern name] -- [where it appeared and why it's wrong]"
```

**Examples:**
- `"LEARNED: UserController was vulnerable to XSS because params[:name] was interpolated into HTML without sanitize()"`
- `"PATTERN: N+1 query in OrdersController#index -- .includes(:line_items) was missing from the scope"`
- `"LEARNED: migration 20240301 swaps source/target column IDs -- production data uses the reverse mapping"`

**Gate check:** Run `bd show {BEAD_ID}` and verify LEARNED/PATTERN count >= P1 + P2 count. If not, add missing entries. **Do not proceed to summary until gate passes.**

P3 findings may also have knowledge entries but are not required.

#### Step 6: Summary Report

```
## Code Review Complete

**Review Target:** {BEAD_ID} - {title}
**Branch:** {branch-name}

### Findings Summary:

- **Total Findings:** [X]
- **P1 CRITICAL:** [count] - BLOCKS CLOSURE
- **P2 IMPORTANT:** [count] - Should Fix
- **P3 NICE-TO-HAVE:** [count] - Enhancements

### Created Beads:

**P1 - Critical (BLOCKS CLOSURE):**
- {BD-XXX}: {description}
- {BD-XXX}: {description}

**P2 - Important:**
- {BD-XXX}: {description}

**P3 - Nice-to-Have:**
- {BD-XXX}: {description}

### Review Agents Used:
- {list of agents}

### Next Steps:

1. **Address P1 Findings**: CRITICAL - must be fixed before closing
   - `/lavra-work {P1_BEAD_ID}` for each critical finding
2. **Close bead** (if no P1/P2 findings): `bd close {BEAD_ID}`
3. **Resolve in parallel**: `/lavra-work {BEAD_ID}`
4. **Triage remaining**: `/lavra-triage {BEAD_ID}`
5. **View all findings**: `bd list --tags "review,{BEAD_ID}"`
```

### 7. End-to-End Testing (Optional)

**Detect project type from PR files:**

| Indicator | Project Type |
|-----------|--------------|
| `*.xcodeproj`, `*.xcworkspace`, `Package.swift` | iOS/macOS |
| `Gemfile`, `package.json`, `app/views/*` | Web |
| Both iOS files AND web files | Hybrid |

After the Summary Report, offer testing based on project type:

**Web:** "Want to run browser tests on the affected pages?"
1. Yes - run browser tests
2. No - skip

**iOS:** "Want to run Xcode simulator tests on the app?"
1. Yes - run Xcode tests
2. No - skip

</process>

<success_criteria>
- All review agents dispatched and findings collected
- Complete agent finding inventory built before synthesis
- Every finding accounted for (applied, deduplicated, or explicitly discarded with reason)
- All findings stored as child beads with severity, validation criteria, and testing steps
- P1 findings linked as blocking dependencies
- Knowledge logged for every P1/P2 finding (at least one LEARNED or PATTERN per critical/important finding)
- Summary report presented with next-step options
</success_criteria>

<guardrails>
- P1 (CRITICAL) findings must be addressed before closing the bead -- they are linked as blocking dependencies
- Each reviewer creates beads for issues found (not markdown files or comments)
- Each bead has a thorough description with severity level, validation criteria, and testing steps
- Beads are tagged with `review,{BEAD_ID}` for easy filtering
- Use `/lavra-work {ISSUE_BEAD_ID}` to fix issues found
- The original bead cannot be closed until all blocking dependencies are resolved
</guardrails>

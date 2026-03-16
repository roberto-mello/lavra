  ## Problem

  The current workflow for thorough feature planning requires running 4 commands manually in
  sequence:

  1. /lavra-brainstorm -- collaborative dialogue exploring WHAT to build, producing a brainstorm
  bead with DECISION/INVESTIGATION/FACT/PATTERN comments
  2. /lavra-plan -- transforms the idea into a structured epic with child task beads, each with
  detailed descriptions (What/Context/Testing/Validation/Files/Dependencies)
  3. /lavra-deepen -- enriches every child bead with parallel multi-agent research (20-40+ agents),
  applying skill discoveries, learnings, and review/research/design agent outputs
  4. /lavra-plan-review -- dispatches 4 review agents (architecture-strategist, code-simplicity-
  reviewer, security-sentinel, performance-oracle) to catch issues before implementation

  Each command produces artifacts (bead IDs, knowledge comments, enriched descriptions) that the
  next command consumes. The user must manually pass context between them and remember the correct
  sequence. This friction discourages using the full pipeline.

  ## Solution

  A new /lavra-design command that orchestrates the entire planning pipeline as a single
  invocation, without skipping steps or losing functionality.

  ## Architecture Decisions

  ### Delegation, not duplication

  /lavra-design is a pure orchestrator that calls the 4 existing commands in sequence. Zero code
  duplication. When individual commands are updated or improved, /lavra-design automatically
  inherits those improvements. The command file itself contains only orchestration logic: phase
  transitions, progress banners, verification gates, and the final summary.

  ### Smart pauses (user interaction model)

  • Phase 1 (Brainstorm): Fully interactive -- the brainstorm phase requires collaborative
  dialogue (questions, approach selection). Cannot be automated.
  • Phase 2 (Plan): Runs automatically after brainstorm completes, consuming brainstorm output. No
  user interaction needed.
  • Transition pause: After plan completes, the orchestrator shows a plan summary and asks the
  user to confirm before investing heavy compute in deepen. This is the single checkpoint between
  the interactive and autonomous portions.
  • Phase 3+4 (Deepen + Plan-Review): Auto-chains without stopping. Deepen output feeds directly
  into plan-review.

  ### Phase gates with recovery

  Each phase runs its existing verification logic. If verification fails at any phase, the
  orchestrator pauses and presents three options: retry the phase, skip it and continue, or abort
  the pipeline. This prevents wasted compute on downstream phases when an upstream phase has
  issues.

  ### Auto-apply safe feedback

  After plan-review runs, non-controversial feedback (typos, missing test cases, documentation
  gaps,
  straightforward improvements) is applied automatically to child beads. The orchestrator only
  pauses for trade-off decisions that require user judgment (e.g., architectural alternatives,
  scope changes, performance vs. simplicity trade-offs).

  ### Default Comprehensive detail level

  Since /lavra-design is the full-thoroughness pipeline, the plan phase defaults to Comprehensive
  detail level. The user can override this inline (e.g., /lavra-design standard "feature idea")
  but
  the default matches the intent of using the full pipeline.

  ### No skip flags, auto-detect context

  If the user passes a bead ID that already has brainstorm context (brainstorm label, DECISION
  comments), the brainstorm phase detects this and skips itself. No --skip-brainstorm or --
  from=plan
  flags needed. The interface stays simple: /lavra-design "feature idea" or /lavra-design {bead-
  id}.

  ### Parallelism preserved

  No new parallelism constraints introduced. Each delegated command retains its internal
  parallelism:

  • /lavra-plan spawns parallel research agents (repo-research-analyst + learnings-researcher,
  optionally best-practices-researcher + framework-docs-researcher)
  • /lavra-deepen spawns 20-40+ agents across skill discovery, learnings application, per-section
  research, and all review/research/design agents
  • /lavra-plan-review runs 4 review agents concurrently
  Model hints (haiku for lightweight research, sonnet for analysis, opus for deep review) are
  inherited from existing commands.

  ### Output style

  • Progress banners at each phase transition (e.g., '=== Phase 2/4: Planning... ===')
  • Clear verification status per phase (pass/fail with details)
  • Final consolidated summary: epic bead ID, child bead count, key decisions captured, review
  findings applied, and suggested next step (/lavra-work or /lavra-parallel)

  ## Precedent

  Follows the /lfg command pattern, which already chains plan -> deepen -> work -> review ->
  resolve-
  todo-parallel -> test-browser -> feature-video as a compound command.

  ## Usage

  /lavra-design "feature idea or description" /lavra-design {existing-bead-id}

  ## Success Criteria

  • Running /lavra-design produces identical artifacts to running the 4 commands manually
  • No functionality is lost from any individual command
  • User interaction is reduced to: brainstorm dialogue + one plan confirmation + trade-off
  decisions only
  • Total pipeline context (bead IDs, knowledge comments, enriched descriptions) flows correctly
  between all phases
  • Phase gate recovery works correctly (retry/skip/abort)

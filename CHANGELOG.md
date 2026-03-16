# Changelog

All notable changes to the lavra plugin are documented here.

## [0.7.0] - 2026-03-15

### Breaking Changes
- **All `/beads-*` commands renamed to `/lavra-*`** - Every command, skill reference, agent reference, installer, and documentation file has been updated. `/beads-brainstorm` is now `/lavra-brainstorm`, `/beads-work` is now `/lavra-work`, etc. The `beads-knowledge` skill directory is now `lavra-knowledge`. This affects 46 command files across Claude Code, OpenCode, and Cortex platforms, plus ~80 files with internal references. The `bd` CLI and `.beads/` directory are unchanged -- only the slash-command prefix moved.

### Added
- **Goal-backward verification (F1)** - New `goal-verifier` agent checks implementation against bead success criteria at three levels: Exists (code artifact present), Substantive (not a stub/placeholder), Wired (imported/called/routed). Runs in `/lavra-work` Phase 3 (single-bead) and Phase M7 (multi-bead agent prompt), plus `/lavra-ship` Phase 4 as pre-landing gate. Exists/Substantive failures are CRITICAL (halt), Wired failures are WARNING (proceed). Skippable via `lavra.json` `workflow.goal_verification: false`.
- **Deviation rules for execution (F2)** - `DEVIATION:` prefix added to memory-capture.sh and all knowledge type documentation. Four-rule framework: auto-fix blocking bugs (Rule 1), auto-add critical missing functionality (Rule 2), auto-fix blocking infrastructure (Rule 3), STOP for architectural changes (Rule 4). 3-attempt limit per issue. Deviations surfaced in `/lavra-ship` PR body with count and summaries. Light version in `/lavra-quick`.
- **Session state digest (F3)** - New ephemeral file `.beads/memory/session-state.md` (gitignored) preserves "where was I?" context across context compaction. Written by `/lavra-work`, `/lavra-design`, and `/lavra-checkpoint` at milestones. `auto-recall.sh` injects it once at next session start then deletes. Stale files (>24h) auto-cleaned.
- **Decision categorization (F4)** - Brainstorm epic descriptions now include three decision sections: `## Locked Decisions` (must honor), `## Agent Discretion` (agent can choose), `## Deferred` (out of scope). `/lavra-plan` child beads inherit Locked/Discretion in a `## Decisions` section. `/lavra-design` Phase 6 verifies inheritance and creates backlog beads (priority 4) from Deferred items.
- **Brownfield codebase analysis (F5)** - `/project-setup` skill Step 1.5 dispatches 3 parallel agents (stack/architecture/conventions) and writes `.beads/config/codebase-profile.md` (200 lines max). Read by `/lavra-design` and `/lavra-work` with full injection safety (XML wrapping, sanitization, size cap).
- **Workflow config file (F6)** - New `.beads/config/lavra.json` (committed, project-scoped) with toggles for research, plan_review, goal_verification, max_parallel_agents, commit_granularity, and model_profile. Provisioned by `provision-memory.sh` on install. Read by `/lavra-design` (skip phases) and `/lavra-work` (parallelism, commits).
- **Context size budgets (F7)** - Epic max 80 lines (brainstorm), child bead max 150 lines (plan). `/lavra-design` Phase 6 enforces budgets and auto-splits oversized beads into 2-3 smaller ones. Cross-check warning in `/lavra-plan` Step 5.5.
- **Atomic commits per task (F8)** - `/lavra-work` single-bead commits per task with `{type}({BEAD_ID}): {description}` format (enables `git log --grep`). Multi-bead commits per bead instead of per wave. Configurable via `commit_granularity: "task"|"wave"` in `lavra.json`.

### Changed
- **4-command pipeline redesign** - Restructured from 29 scattered commands into a focused development pipeline: `/lavra-design` -> `/lavra-work` -> `/lavra-qa` -> `/lavra-ship`. Merged `/lavra-parallel` into `/lavra-work` with auto-routing (single vs multi-bead). Extracted ralph and teams modes into `/lavra-work-ralph` and `/lavra-work-teams`. Killed 6 thin stubs, moved 5 domain-specific commands to `commands/optional/`, split skills into 9 core + 7 optional. Down from 29 to 22 core commands + 5 optional.
- **Command renames within pipeline** - `/lavra-compound` -> `/lavra-learn` (targeted knowledge extraction), `/lavra-deepen` -> `/lavra-research` (scoped agent selection). New commands: `/lavra-ship`, `/lavra-qa`, `/lavra-retro`, `/lavra-work-ralph`, `/lavra-work-teams`.
- **Agent count 29 -> 30** - Added `goal-verifier` to review agents (16 review total).
- **Version self-heal for existing projects** - `auto-recall.sh` now calls `provision_memory_dir` on version mismatch, auto-provisioning `lavra.json` and `session-state.md` gitignore for existing projects without requiring a full re-install.
- **Feature test suite** - New `scripts/test-features.sh` with 27 tests covering all 8 new features: DEVIATION capture, lavra.json provisioning + idempotency, session-state gitignore, goal-verifier structure, agent counts, documentation consistency, and command file integration.
- **Installation test updates** - Agent count thresholds bumped from 28 to 30 across all 4 platform tests. New Test 5 verifies lavra.json provisioning, session-state gitignore, goal-verifier installation, and idempotency.
- **Documentation updates** - Updated ARCHITECTURE.md (new artifacts section), SECURITY.md (codebase-profile injection defense), CATALOG.md (agent counts, goal-verifier, decision categories), quickstart.md (configuration section, DEVIATION prefix, fixed stale beads-* references), README.md (agent count, knowledge types, configuration details block).
- **README rewrite** - WHY-first pitch with pain/solution framing instead of feature-list-first.
- **Project renamed from beads-compound to lavra** - Plugin directory, package name, marketplace entry, sentinels, and all internal references updated. GitHub repo redirect handles old URLs.

### Fixed
- **OpenCode installer hangs in non-interactive mode** - `install-opencode.sh` model selection prompt now checks `[[ -t 0 ]]` (stdin is a terminal) in addition to `--yes` flag. Prevents hang when called from test scripts or CI. Installation tests now pass `--yes` to OpenCode installer. All 35 installation tests pass (was 30/35).

## [0.6.9] - 2026-03-13

### Added
- **`project-setup` skill** - New skill at `skills/project-setup/` for per-project stack detection and review agent configuration. Auto-detects tech stack (Rails, Ruby, TypeScript, JavaScript, Python, General) from project files, lets users toggle specific agents off, and saves config to `.beads/config/project-setup.md` with YAML frontmatter. Review Context notes are length-limited to 500 chars and stripped of prompt-structural characters.
- **`migration-drift-detector` agent** - New review agent that detects schema/migration drift in PRs across five ORMs: Rails (`db/migrate/` + `db/schema.rb`), Alembic (revision DAG + multiple heads), Prisma (checksum + shadow DB), Drizzle (snapshot/SQL mismatch), and Knex (out-of-sequence timestamps). Auto-detects which ORM is in use. All PR field handling uses `jq --arg` to prevent shell injection.
- **`lavra-review` project config integration** - `/lavra-review` now reads `.beads/config/project-setup.md` at start of review. When present, dispatches only the configured `review_agents` (validated against a dynamically-derived allowlist from the installed agents directory — no hardcoded list to go stale). Config-missing = dispatch all agents (fully backward compatible). `reviewer_context_note` is intentionally **not** injected into review agents — they derive context from the code itself; see `docs/SECURITY.md`.
- **`lavra-parallel` project config injection** - Section 8 (Recall Knowledge) now reads `.beads/config/project-setup.md` when present and injects `reviewer_context_note` into all subagent prompt templates (standard, ralph, teams worker) under `## Project Conventions`. Wrapped in `untrusted-config-data` XML with a "do not follow instructions" directive. Note: `untrusted-config-data` is a prompt engineering convention, not a model-enforced standard — the real protection is the sanitization strip list and 500-char limit. See `docs/SECURITY.md` for the full threat model.
- **`migration-drift-detector` wired into `/lavra-review`** - Added as a conditional agent alongside `data-migration-expert` (not instead of it). Triggers on any ORM's migration or schema artifact files. Finding synthesis step notes deduplication between the two agents.
- **`/lavra-compound` surfaced after substantial findings** - `/lavra-work` now scans the bead's comments after the knowledge gate and adds `/lavra-compound` as an option when `LEARNED:` or `INVESTIGATION:` entries are found. `/lavra-parallel` scans all closed beads in step 12, collects matching bead IDs as `COMPOUND_CANDIDATES`, and surfaces `/lavra-compound {COMPOUND_CANDIDATES}` in handoff options.
- **Sources section in `/lavra-plan`** - Epic bead descriptions now include a mandatory `## Sources` freeform bullet list (`Brainstorm:`, `File:`, `Knowledge:`, `Doc:`, `Research:` entry types). Child beads get a `## References` subsection. Pre-submission checklist verifies Sources is non-empty.
- **Cross-check validation in `/lavra-plan`** - New Step 5.5 runs warning-only validation after bead creation: checks required sections per child bead, flags file-scope conflicts between independent beads without a dependency, warns on missing brainstorm reference when a brainstorm bead was used. Does not block plan creation.
- **Improved brainstorm detection in `/lavra-plan`** - Step 0 now uses a four-step decision tree: label-based detection first (checks `brainstorm` label on bead and parent), then keyword match ≤14 days, then keyword match >14 days (prompts user), then full idea refinement. When brainstorm detected: locked decisions extracted and carried forward into child bead Context sections, Sources section auto-populated with `Brainstorm:` entry.
- **`.beads/config/` provisioned by installer** - `install-claude.sh` now runs `mkdir -p "$TARGET/.beads/config"` alongside memory provisioning.

### Changed
- **`reviewer_context_note` injection removed from `/lavra-review`** - Review agents no longer receive the context note. They derive project context from the code. This removes an injection vector from the review pipeline with no meaningful loss of review quality.
- **Expanded sanitization strip list** - `project-setup` skill and `lavra-parallel` now strip `USER:`, `HUMAN:`, `[INST]`, `<s>`/`</s>` tags, `\r`, null bytes, and Unicode bidirectional override characters (U+202A–U+202E, U+2066–U+2069) in addition to the existing `<`, `>`, `SYSTEM:`, `ASSISTANT:`, and triple backtick rules.
- **Dynamic agent allowlist in `/lavra-review`** - Agent names in `review_agents` are now validated against a live listing of `.claude/agents/` rather than a hardcoded list. New agents are automatically available without any list to maintain.
- **`docs/SECURITY.md` added** - Documents the threat model, injection defense strategy, honest limitations of `untrusted-config-data` XML wrapping, and the trust model for all config sources.
- **`.beads/config/` added to protected artifacts** - All six locations that protect `.beads/memory/` now also protect `.beads/config/`: `lavra-review.md`, `lavra-parallel.md` (2 locations), `code-simplicity-reviewer.md`, `resolve-todo-parallel.md`, `git-history-analyzer.md`.
- **Component counts updated** - 28 → 29 agents (migration-drift-detector), 15 → 16 skills (project-setup). Updated in `plugin.json`, `marketplace.json`, `plugin-catalog.md`, `pre-release-check.sh`, `CLAUDE.md`, and `install-claude.sh`.

## [0.6.8] - 2026-03-05

### Added
- **Installed version tracking** - `provision-memory.sh` now writes `.beads/memory/.lavra-version` on every install. `auto-recall.sh` embeds its own version constant and emits a session warning when the installed hooks are out of date, telling the user exactly which command to run to upgrade.
- **`.beads/memory/.gitignore`** - The installer now creates a scoped `.gitignore` inside `.beads/memory/` to exclude the SQLite FTS cache (`knowledge.db` and variants). This is our directory — we own its ignore rules rather than relying on beads' `.beads/.gitignore` which can be overwritten by `bd init` or `bd doctor --fix`.
- **Session warning for gitignored beads data** - `auto-recall.sh` now detects when `.beads/` is listed in the project `.gitignore` without negation rules and emits a prominent session warning explaining the data loss risk and how to fix it. Fires every session until resolved.
- **Installer prompt for gitignored beads data** - `provision-memory.sh` detects the same condition and interactively offers to remove the `.beads/` line from `.gitignore`. Non-interactive contexts (hooks, `--yes` flag) warn but don't modify.
- **OpenCode and Gemini installers now use `provision_memory_dir`** - Both platform installers previously duplicated inline memory setup. They now call the shared `provision_memory_dir` function and get all memory fixes automatically.
- **Hook version check in pre-release checks** - `scripts/pre-release-check.sh` now verifies that the `LAVRA_VERSION` constant in `auto-recall.sh` and the version string in `provision-memory.sh` both match `plugin.json`. Prevents shipping hooks that advertise the wrong version.
- **Installer smoke tests in release checklist** - `.claude/rules/github-release.md` now documents required smoke tests for all three platforms (Claude, OpenCode, Gemini) that must pass before tagging a release.
- **Cortex Code support** -- New `--cortex` flag for install/uninstall. Installs commands, agents, skills, and hooks to native Cortex Code paths (`~/.snowflake/cortex/` global, `.cortex/` project). Hooks configured via `~/.snowflake/cortex/hooks.json`. MCP installation skipped (not needed for Cortex). TeammateIdle hook not installed (unsupported event). Includes `convert-cortex.ts` conversion script, installation tests, and pre-release checks.
- **Hook cwd fallback** -- `auto-recall.sh` and `memory-capture.sh` now read `cwd` from stdin JSON as fallback when `CLAUDE_PROJECT_DIR` is not set, enabling Cortex Code compatibility while maintaining backward compatibility with Claude Code, OpenCode, and Gemini CLI.
- **check-memory.sh platform parameterization** -- Global auto-provisioner now accepts `--platform` flag (`claude`, `cortex`) to target platform-specific paths and configurations. Defaults to `claude` for backward compatibility.

### Fixed
- **Context7 MCP not configured on global install** - The Claude installer was writing to `~/.claude/.mcp.json` (not read by Claude Code) instead of merging into `~/.claude.json` under `mcpServers`. OpenCode and Gemini installers were only printing a link to manual setup docs. All three now auto-configure Context7 using HTTP transport: Claude merges into `~/.claude.json`, OpenCode into `~/.config/opencode/opencode.json` (`type: "remote"`), Gemini into `~/.config/gemini/settings.json` (`type: "http"`).
- **Beads data silently untracked** - The installer was adding `.beads/` to the project `.gitignore`, which caused beads issues, comments, and knowledge to never be committed. Modern `bd init` no longer does this — the installer now leaves `.beads/` alone and warns when it finds the pattern already present.
- **False positive gitignore warning** - The `.beads/` gitignore warning correctly ignores cases where `!.beads/memory/` negation rules are already present, avoiding spurious warnings on older installs that used the previous negation approach.
- **Emoji removed from installer output** - All user-facing messages in `install.sh`, `install-claude.sh`, `install-opencode.sh`, and `install-gemini.sh` now use plain text.

### Changed
- **`.beads/` no longer added to project `.gitignore`** - The installer previously added `.beads/` as "ephemeral task data". This was incorrect: beads JSONL files (issues, comments) should be committed. The installer now leaves `.gitignore` alone. Use `bd init --stealth` if you want `.beads/` invisible to collaborators (it uses `.git/info/exclude` which keeps data safe).
- **Memory provisioning consolidated** - The four locations that must be kept in sync on a version bump are now documented: `plugin.json`, `marketplace.json`, `auto-recall.sh` (`LAVRA_VERSION`), and `provision-memory.sh` (version string).
- **`bd sync` replaced with `bd backup`** - `bd sync` was removed in beads v0.56.0 (superseded by Dolt-native push/pull). All plugin commands (`lavra-checkpoint`, `lavra-parallel`) and project CLAUDE.md files now use `bd backup` for local JSONL export. Stale beads workflow sections removed from project CLAUDE.md files since `bd prime` injects this context automatically at session start.

## [0.6.7] - 2026-03-04

### Fixed
- **`/lavra-review` agent findings inventory** - Added explicit inventory step before synthesis to prevent silently dropping agent output when building final review
- **`/lavra-plan-review` apply-feedback protocol** - Replaced vague "Apply feedback" option with explicit Steps A-D: build numbered checklist of all recommendations, apply each one-by-one marking done or skipped with reason, completeness verification pass, then log a DECISION comment summarizing what changed
- **`/lavra-deepen` completeness verification** - Now builds per-bead inventory of agent findings before finalizing, preventing missed recommendations during synthesis
- **`/lavra-work` knowledge logging requirements** - Added trigger table showing exactly when to log (surprises, choices, errors, patterns, constraints); logging is now mandatory per task with explicit gate before marking task complete
- **`/lavra-parallel` knowledge logging framing** - Fixed ralph prompt which said "only on final success or failure", actively encouraging batching; aligned teams worker prompt with inline-first framing
- **Branching strategy** - `lavra-work` now asks user about branching strategy instead of always creating a feature branch

## [0.6.4] - 2026-02-20

### Added
- **`--teams` mode for `/lavra-parallel`** - Persistent worker teammates that stay active across waves, with swarm registration and idle-check hook. Includes `TeammateIdle` hook that blocks idle when ready beads remain.
- **`--ralph` mode for `/lavra-parallel`** - Autonomous iterative execution with completion promise instead of test-only loop.
- **Bead context injection** - `relates_to` bead context now injected into subagent and lavra-work prompts via `bd swarm/graph` for wave building and relate links.
- **MIT LICENSE file** for GitHub badge detection.
- **Modular CLAUDE.md rules** - Split type-specific content into `.claude/rules/` (shell-scripting, hooks-system, plugin-catalog, conversion-scripts) with glob-based activation. CLAUDE.md reduced from 430 to 157 lines.

### Fixed
- **Knowledge persistence across machines** - `provision-memory.sh` now patches `.gitignore` with negation rules for `.beads/memory/` and uses `git add -f`, fixing silent failure when `.beads/` was gitignored.
- **Swarm registration for `--teams` mode** - Was only enabled for `--ralph`, now works for both modes.
- **Duplicate `PRE_BRANCH_SHA`** in section 9T, already recorded in section 4 for all modes.

### Changed
- README updated with `--teams` mode comparison table, features, and hook documentation.
- Docs clarified: subagent knowledge enforcement is hook-based, section 8 recall vs SessionStart hook distinction, display mode configuration.

## [0.6.2] - 2026-02-16

### Added
- **`/lavra-recall` command** - Mid-session knowledge lookup without restarting. Six search modes: keywords, bead ID, `--recent N`, `--stats`, `--topic`, `--type`. Smart argument parsing detects bead IDs and extracts keywords from titles.
- **Interactive OpenCode model selection** - During OpenCode installation, users can customize which Claude model to use for each performance tier (haiku/sonnet/opus). Standalone script available at `scripts/select-opencode-models.sh`. Configuration persists in `scripts/shared/model-config.json`.
- **File-scope conflict prevention for parallel work** - `lavra-plan` now includes a `## Files` section in child bead templates so each bead declares which files it will touch. `lavra-parallel` adds a conflict detection phase that analyzes file scopes, detects overlaps, and forces sequential ordering via `bd dep add`.
- **File ownership in subagent prompts** - `lavra-parallel` now passes file scope to subagents so they know which files they may modify, with post-wave ownership violation checks and inter-wave knowledge recall.

### Changed
- **DSPy.rb skill updated to v0.34.3 API** - Complete rewrite of SKILL.md and all reference/asset files. New API patterns: `.call()`, `result.field`, `T::Enum`, `Tools::Base`. New references: `toolsets.md` and `observability.md`. Covers 10+ new features: events, lifecycle callbacks, fiber-local LM, GEPA optimization, evaluation framework, BAML/TOON schema formats, storage system, score API, and RubyLLM unified adapter.
- **OpenCode model mapping updated** - Sonnet tier updated from deprecated `claude-sonnet-4-20250514` to `claude-sonnet-4-5-20250929`.
- Model tier mapping now reads from `scripts/shared/model-config.json` configuration file instead of hardcoded values, with fallback to defaults.

## [0.6.1] - 2026-02-15

### Fixed
- **Duplicate knowledge entries** - memory-capture.sh now checks for duplicate keys before appending to JSONL, preventing JSONL/SQLite desync
- **Global installation portability** - Global installer now bundles all 7 hook scripts to ~/.claude/hooks/, eliminating dependency on plugin source repo
- **check-memory.sh hook discovery** - Updated to search 3 locations (global hooks, marketplace install, legacy source) for maximum compatibility
- **OpenCode plugin paths** - Fixed project installation to use correct .opencode/plugins/ directory per OpenCode documentation
- **Build artifact separation** - Created opencode-src/ and gemini-src/ source directories, moved plugin.ts and package.json to prevent installer failures
- **GitHub Actions CI** - Added conversion steps before tests to generate OpenCode/Gemini outputs, updated test expectations for 644 permissions
- **Installer path portability** - Changed hardcoded absolute paths to tilde expansion (~/.claude/hooks/) for dotfiles compatibility
- **Cross-platform shell compatibility** - Fixed find command to use -maxdepth/-mindepth instead of -depth for GNU/BSD compatibility
- **Template syntax test** - Updated to allow $ARGUMENTS in code blocks while verifying {{args}} conversion
- **Skill file permissions** - Changed from 0o444 (read-only) to 0o644 (writable) to allow conversion script re-runs without EACCES errors

### Changed
- OpenCode installer now copies from opencode-src/ instead of gitignored opencode/ directory
- Gemini installer now copies from gemini-src/ instead of gitignored gemini/ directory
- Global installation is now fully self-contained and portable across machines without plugin source
- README updated with comprehensive Troubleshooting section for Claude Code, OpenCode, and Gemini CLI

## [0.6.0] - 2026-02-13

### Added
- **OpenCode support** via native TypeScript plugin (`plugins/lavra/opencode/plugin.ts`)
  - Auto-recall: inject relevant knowledge at session start
  - Memory capture: extract knowledge from `bd comments add`
  - Subagent wrapup: warn when subagents complete without logging knowledge
  - Uses Bun.spawn() for security (prevents shell injection)
  - Pre-fork filtering for performance (avoids subprocess overhead on non-matching bash commands)
- **Gemini CLI support** via extension manifest (`gemini-extension.json`)
  - SessionStart → auto-recall.sh
  - AfterTool (bash) → memory-capture.sh
  - AfterAgent → subagent-wrapup.sh
  - Uses same stdin/stdout JSON protocol as Claude Code
  - Install: `gemini extensions install https://github.com/roberto-mello/lavra`
- **AGENTS.md references** in 10 files (6 commands, 4 agents) where it aids user discovery
  - AGENTS.md is the emerging cross-tool standard (OpenCode, etc.)
  - Recommended: symlink CLAUDE.md → AGENTS.md for dual-tool projects

### Changed
- README Multi-Platform Support section with OpenCode, Gemini CLI, and Codex CLI status
- CLAUDE.md updated with multi-platform support summary and repository structure

## [0.5.0] - 2026-02-10

### Added
- Native plugin system support (`/plugin marketplace add` + `/plugin install`)
- Memory auto-bootstrap in SessionStart hook -- `.beads/memory/` is created automatically on first session in any beads-enabled project, no manual install.sh needed
- `provision-memory.sh` shared library for memory directory setup, used by auto-recall.sh, check-memory.sh, and install.sh

### Fixed
- plugin.json `repository` field changed from object to string per plugin manifest schema
- plugin.json removed unsupported `requirements` field
- marketplace.json `owner.url` changed to `owner.email` per marketplace schema
- SQL injection in `kb_search()` via unvalidated `TOP_N` LIMIT parameter
- Numeric validation for `--recent` parameter in recall.sh
- `git add` in bootstrap now stages specific files instead of entire `.beads/memory/` directory
- `.gitattributes` placement standardized to per-directory (inside `.beads/memory/`) across all installation paths

### Changed
- README Quick Install now presents native plugin system as Option A (recommended) and manual install.sh as Option B
- CLAUDE.md Plugin Installation section split into Native and Manual subsections
- Memory provisioning logic deduplicated from 3 files into single shared function

## [0.4.2] - 2026-02-10

### Added
- `/lavra-parallel` command for working on multiple beads in parallel via subagents
- Memory recall hook (`recall.sh`) deployed to `.beads/memory/` during install

### Changed
- Renamed `/resolve-parallel` to `/lavra-parallel` for naming consistency
- Updated install.sh and uninstall.sh to handle lavra-parallel

## [0.4.1] - 2026-02-09

### Added
- SQLite FTS5 full-text search with BM25 ranking for knowledge recall
- `knowledge-db.sh` shared library for FTS5 operations (create, insert, search, sync)
- Dual-write to both SQLite and JSONL on every knowledge capture
- FTS5-first search in auto-recall.sh with grep fallback
- FTS5 search in recall.sh with grep fallback
- Recall benchmark harness for evaluating grep vs FTS5 search quality
- Git-trackable knowledge: `knowledge.jsonl` committed to git for team sharing
- `.gitattributes` union merge strategy for conflict-free multi-user collaboration
- `check-memory.sh` SessionStart hook for auto-detecting beads projects missing memory setup
- Global install warning when per-project memory hooks are not configured
- Automatic one-time backfill from existing JSONL and beads.db comments on first FTS5 run

### Fixed
- install.sh failing when skill directory already exists
- Only overwrite skills managed by this plugin on reinstall (preserve user customizations)
- Updated `bd comment add` to `bd comments add` to match current beads CLI syntax

### Changed
- Auto-recall search now uses FTS5 with porter stemming and BM25 ranking, falling back to grep
- Installation steps clarified: global first, then per-project
- Knowledge rotation threshold increased from 1000/500 to 5000/2500

## [0.4.0] - 2026-02-08

### Added
- Global installation support (`./install.sh` without target path installs to `~/.claude/`)
- `disable-model-invocation: true` on 17 utility commands and 7 manual skills to reduce context token usage by 94%
- Critical requirement preventing subagent file writes in auto-denied mode

### Changed
- Context budget reduced from ~130K chars to ~8,200 chars (94% reduction) by trimming agent descriptions and disabling auto-invocation on utility components
- Removed OpenCode workaround (upstream PR #160 merged)

## [0.3.0] - 2026-02-08

Initial public release. Fork of [compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) with beads-based persistent memory.

### Added
- 27 specialized agents (14 review, 5 research, 3 design, 4 workflow, 1 docs) with model tier assignments (Haiku/Sonnet/Opus)
- 11 workflow commands for brainstorming, planning, review, and testing
- 5 skills (git-worktree, brainstorming, create-agent-skills, agent-browser, frontend-design)
- 3 hooks: auto-recall (SessionStart), memory-capture (PostToolUse), subagent-wrapup (SubagentStop)
- Context7 MCP server for framework documentation
- Automatic knowledge capture from `bd comments add` with typed prefixes (LEARNED/DECISION/FACT/PATTERN/INVESTIGATION)
- Automatic knowledge recall at session start based on open beads and git branch context
- Marketplace structure with install.sh/uninstall.sh
- OpenCode/Codex installation via `@every-env/compound-plugin` converter
- Agent description optimization reducing startup token cost by 80%

### Changed from compound-engineering
- Replaced markdown-based knowledge storage with beads-based persistent memory
- All workflows create and update beads instead of markdown files
- Rewrote `learnings-researcher` to search `knowledge.jsonl` instead of markdown docs
- Adapted `code-simplicity-reviewer` to protect `.beads/memory/` files
- Renamed `compound-docs` skill to `lavra-knowledge`

[0.6.2]: https://github.com/roberto-mello/lavra/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/roberto-mello/lavra/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/roberto-mello/lavra/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/roberto-mello/lavra/compare/v0.4.2...v0.5.0
[0.4.2]: https://github.com/roberto-mello/lavra/compare/v0.4.0...v0.4.2
[0.4.1]: https://github.com/roberto-mello/lavra/compare/v0.4.0...v0.4.2
[0.4.0]: https://github.com/roberto-mello/lavra/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/roberto-mello/lavra/releases/tag/v0.3.0

# Component Catalog

Full listing of all commands, agents, skills, hooks, and MCP servers included in beads-compound.

[Back to README](../README.md)

## Commands (29)

Commands are organized by use case to help you choose the right tool for the job.

### Planning & Discovery (6 commands)

Explore ideas and create structured plans before writing code.

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/beads-brainstorm` | Explore ideas collaboratively, identify gray areas, file phases as beads | When requirements are unclear or you need to explore approaches |
| `/beads-design` | Orchestrate full planning pipeline per phase: plan → deepen → review | After brainstorm — runs the entire design pipeline automatically |
| `/beads-plan` | Research and create epic with child beads | Start every feature - creates structured plan with research |
| `/beads-deepen` | Enhance plan with parallel research agents | For complex features - adds depth and best practices |
| `/beads-plan-review` | Multi-agent review of epic plan | Before implementation - catch issues early |
| `/beads-quick` | Fast-track small tasks with abbreviated plan | Quick fixes and small features that don't need full pipeline |

### Executing Work (3 commands)

Implement features and fix bugs using beads for tracking.

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/beads-work` | Work on a single bead with full lifecycle | Standard workflow - one bead at a time |
| `/beads-parallel` | Work on multiple beads in parallel (`--ralph` for autonomous retry, `--teams` for persistent workers) | Speed up delivery - multiple independent beads |
| `/beads-triage` | Prioritize and categorize beads | After planning or review - organize work queue |

### Reviewing & Quality (2 commands)

Ensure code quality and capture knowledge before shipping.

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/beads-review` | Multi-agent code review | Before closing beads - comprehensive quality check |
| `/beads-import` | Import markdown plans into beads | When you have external plans to convert |

### Ad-hoc sessions: Recalling Knowledge and Saving Progress (3 commands)

Capture knowledge and save session state.

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/beads-recall` | Search knowledge base and inject context | When you need past learnings mid-session without restarting |
| `/beads-checkpoint` | Save progress, create/update beads, commit | Mid-session - checkpoint your work |
| `/beads-compound` | Deep problem documentation with parallel analysis | After solving hard problems - share learnings |

### Utility Commands (15)

| Command | Description |
|---------|-------------|
| `/lfg` | Full autonomous engineering workflow |
| `/changelog` | Create engaging changelogs for recent merges |
| `/create-agent-skill` | Create or edit Claude Code skills |
| `/generate-command` | Create a new custom slash command |
| `/heal-skill` | Fix incorrect SKILL.md files |
| `/deploy-docs` | Validate and prepare documentation for deployment |
| `/release-docs` | Build and update documentation |
| `/feature-video` | Record a video walkthrough for a PR |
| `/agent-native-audit` | Comprehensive agent-native architecture review |
| `/test-browser` | Run browser tests on affected pages |
| `/xcode-test` | Build and test iOS apps on simulator |
| `/report-bug` | Report a bug in the plugin |
| `/reproduce-bug` | Reproduce and investigate a bug |
| `/resolve-pr-parallel` | Resolve all PR comments in parallel |
| `/resolve-todo-parallel` | Resolve all pending TODOs in parallel |

## Agents (28) -- Cost-Optimized by Model Tier

All agents include model tier assignments for optimal cost/performance balance:

**Haiku Tier (5 agents)** -- Structured tasks, fast and cheap:
- learnings-researcher, repo-research-analyst, framework-docs-researcher, ankane-readme-writer, lint

**Sonnet Tier (14 agents)** -- Moderate judgment, balanced cost:
- code-simplicity-reviewer, kieran-rails-reviewer, kieran-python-reviewer, kieran-typescript-reviewer, dhh-rails-reviewer, security-sentinel, pattern-recognition-specialist, deployment-verification-agent, best-practices-researcher, git-history-analyzer, design-implementation-reviewer, design-iterator, figma-design-sync, bug-reproduction-validator, pr-comment-resolver, every-style-editor

**Opus Tier (9 agents)** -- Deep reasoning, premium quality:
- architecture-strategist, performance-oracle, data-integrity-guardian, data-migration-expert, agent-native-reviewer, julik-frontend-races-reviewer, spec-flow-analyzer

The most frequently invoked agents (learnings-researcher, repo-research-analyst) run on Haiku for maximum efficiency. Review workflows intelligently mix tiers based on complexity.

## Skills (15)

| Skill | Description |
|-------|-------------|
| `git-worktree` | Manage git worktrees for parallel bead work |
| `brainstorming` | Structured brainstorming with bead output |
| `create-agent-skills` | Create new agents and skills |
| `agent-native-architecture` | Design agent-native system architectures |
| `beads-knowledge` | Document solved problems as knowledge entries |
| `agent-browser` | Browser automation for testing and screenshots |
| `andrew-kane-gem-writer` | Write Ruby gems following Andrew Kane's style |
| `dhh-rails-style` | Rails development following DHH's conventions |
| `dspy-ruby` | DSPy integration for Ruby applications |
| `every-style-editor` | Every's house style guide for content editing |
| `file-todos` | Find and manage TODO comments in code |
| `frontend-design` | Frontend design patterns and best practices |
| `gemini-imagegen` | Generate images using Google's Gemini |
| `rclone` | Cloud storage file management with rclone |
| `skill-creator` | Create new skills from templates |

## MCP Servers

- **Context7** -- Framework documentation lookup

## Hooks (5 + shared library)

| Hook | Trigger | Purpose |
|------|---------|---------|
| auto-recall.sh | SessionStart | Inject relevant knowledge at session start (FTS5-first, grep fallback) |
| memory-capture.sh | PostToolUse (Bash) | Extract knowledge from bd comments (dual-write to SQLite + JSONL) |
| subagent-wrapup.sh | SubagentStop | Ensure subagents log learnings (does not fire for teammates) |
| teammate-idle-check.sh | TeammateIdle | Prevent `--teams` workers from idling while ready beads remain |
| check-memory.sh | SessionStart (global) | Auto-detect beads projects missing memory setup |
| knowledge-db.sh | (library) | Shared SQLite FTS5 functions sourced by other hooks |

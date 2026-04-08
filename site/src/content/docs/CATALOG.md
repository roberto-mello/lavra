---
title: Command Catalog
description: Full listing of all commands, agents, skills, hooks, and MCP servers
order: 2
---

# Component Catalog

Full listing of all commands, agents, skills, hooks, and MCP servers included in Lavra.

See the [Command Reference](/docs/commands) for descriptions and direct links, or the [Command Map](/command-map) for a visual overview.

## Commands (23 core + 5 optional)

### Workflow (12)

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/lavra-design` | Orchestrate the full design pipeline, brainstorm, plan, research, revise, review, lock | Runs the entire design pipeline automatically |
| `/lavra-brainstorm` | Explore requirements and approaches through collaborative dialogue before planning | When requirements are unclear or you need to explore approaches. Included in `/lavra-design` |
| `/lavra-plan` | Transform feature descriptions into well-structured beads with parallel research and multi-phase planning | Start every feature, creates a structured plan with research. Included in `/lavra-design` |
| `/lavra-review` | Perform exhaustive code reviews using multi-agent analysis and ultra-thinking | Before closing beads, comprehensive quality check. Included in `/lavra-design` |
| `/lavra-quick` | Fast-track small tasks, abbreviated plan then straight to execution | Quick fixes and small features that don't need the full pipeline |
| `/lavra-work` | Execute work on one or many beads, auto-routes between single-bead and multi-bead paths based on input | Standard workflow, any number of beads |
| `/lavra-work-ralph` | Autonomous retry mode, iterates until completion criteria are met or retry budget is exhausted | Hands-off execution with self-correction |
| `/lavra-work-teams` | Work on multiple beads with persistent worker teammates that self-organize through a ready queue | Speed up delivery with team parallelism |
| `/lavra-qa` | Browser-based QA verification of the running app, systematic testing from the user's perspective | After implementation, verify the feature works end to end |
| `/lavra-ship` | Fully automated ship sequence from code-ready to PR-open with beads closed and knowledge captured | When work is done, opens PR, closes beads, pushes |
| `/lavra-checkpoint` | Save session progress by filing beads, capturing knowledge, and syncing state | Mid-session, checkpoint your work before context runs out |
| `/lavra-retro` | Weekly retrospective with shipping analytics, team performance, and knowledge synthesis | Weekly, review what shipped and surface deferred decisions |

### Planning & Triage (5)

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/lavra-research` | Gather evidence and best practices for a plan using domain-matched research agents | For complex features. Gathers best practices and prior art. Included in `/lavra-design` |
| `/lavra-ceo-review` | CEO/founder-mode plan review, challenge premises, validate business fit, run 10-section structured review | Before committing to a feature, validate scope and business fit. Included in `/lavra-design` |
| `/lavra-eng-review` | Engineering review, parallel agents check architecture, simplicity, security, and performance | Before implementation, catch design issues early. Included in `/lavra-design` |
| `/lavra-triage` | Triage and categorize beads for prioritization | After planning or review, organize the work queue |
| `/lavra-import` | Import a markdown plan into beads as an epic with child tasks | When you have an external plan to convert into beads |

### Knowledge (2)

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/lavra-learn` | Curate raw knowledge comments into structured, well-tagged entries for future auto-recall | After closing beads, clean up terse knowledge captured during work |
| `/lavra-recall` | Search knowledge base mid-session and inject relevant context | When you need past learnings mid-session without restarting |

### Utility (5)

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/lavra-setup` | Configure project stack, review agents, and workflow settings | First time setting up Lavra in a project, or reconfiguring |
| `/changelog` | Create engaging changelogs for recent merges to main branch | Before a release, summarize what shipped |
| `/heal-skill` | Fix incorrect SKILL.md files when a skill has wrong instructions or outdated API references | When a skill is misbehaving or referencing stale APIs |
| `/test-browser` | Run browser tests on pages affected by current PR or branch | After UI changes, verify nothing broke in the browser |
| `/report-bug` | Report a bug in the Lavra plugin | When you hit a bug in Lavra itself |

### Optional (5)

Domain-specific commands in `commands/optional/`. Not installed by default, copy manually to `.claude/commands/` to enable.

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/feature-video` | Record a video walkthrough of a feature and add it to the PR description | When a PR benefits from a visual demo |
| `/agent-native-audit` | Run comprehensive agent-native architecture review with scored principles | When designing systems where agents are first-class users |
| `/xcode-test` | Build and test iOS apps on simulator using XcodeBuildMCP | iOS projects, run tests without leaving the agent |
| `/reproduce-bug` | Reproduce and investigate a bug using logs, console inspection, and browser screenshots | Before filing a bug, confirm the issue is reproducible |
| `/generate-command` | Create a new custom slash command following conventions and best practices | When you want to extend Lavra with a project-specific command |

## Agents (30): Cost-Optimized by Model Tier

### Haiku class model (5): Structured tasks, fast and cheap

`learnings-researcher`, `repo-research-analyst`, `framework-docs-researcher`, `ankane-readme-writer`, `lint`

### Sonnet class model (18): Moderate judgment, balanced cost

`best-practices-researcher`, `bug-reproduction-validator`, `code-simplicity-reviewer`, `deployment-verification-agent`, `design-implementation-reviewer`, `design-iterator`, `dhh-rails-reviewer`, `every-style-editor`, `figma-design-sync`, `git-history-analyzer`, `goal-verifier`, `kieran-python-reviewer`, `kieran-rails-reviewer`, `kieran-typescript-reviewer`, `migration-drift-detector`, `pattern-recognition-specialist`, `pr-comment-resolver`, `security-sentinel`

### Opus class model (7): Deep reasoning, premium quality

`agent-native-reviewer`, `architecture-strategist`, `data-integrity-guardian`, `data-migration-expert`, `julik-frontend-races-reviewer`, `performance-oracle`, `spec-flow-analyzer`

## Skills (15)

### Core (8): Installed by default

| Skill | Description |
|-------|-------------|
| `agent-browser` | Browser automation for testing and screenshots |
| `agent-native-architecture` | Design agent-native system architectures |
| `brainstorming` | Structured brainstorming with bead output |
| `create-agent-skills` | Create new agents and skills |
| `file-todos` | Find and manage TODO comments in code |
| `git-worktree` | Manage git worktrees for parallel bead work |
| `lavra-knowledge` | Document solved problems as knowledge entries |

### Optional (7): Copy from `skills/optional/` to use

| Skill | Description |
|-------|-------------|
| `andrew-kane-gem-writer` | Write Ruby gems following Andrew Kane's style |
| `dhh-rails-style` | Rails development following DHH's conventions |
| `dspy-ruby` | DSPy integration for Ruby applications |
| `every-style-editor` | Every's house style guide for content editing |
| `frontend-design` | Frontend design patterns and best practices |
| `gemini-imagegen` | Generate images using Google's Gemini |
| `rclone` | Cloud storage file management with rclone |

## MCP Servers

- **Context7**: Framework documentation lookup

## Hooks (4)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `auto-recall.sh` | SessionStart | Inject relevant knowledge at session start |
| `memory-capture.sh` | PostToolUse (Bash) | Extract knowledge from `bd comment` calls |
| `subagent-wrapup.sh` | SubagentStop | Ensure subagents log learnings before completing |
| `teammate-idle-check.sh` | TeammateIdle | Prevent `--teams` workers from idling while ready beads remain |

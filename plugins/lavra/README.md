# lavra

A Claude Code plugin that combines beads-based persistent memory with compound-engineering's multi-agent workflows.

## Overview

- **27 specialized agents** (cost-optimized across Haiku/Sonnet/Opus tiers)
- **11 workflow commands** for brainstorming, planning, research, review, and more
- **5 skills** for worktrees, brainstorming, agent creation, and documentation
- **Automatic knowledge capture** from `bd comments add` with knowledge prefixes
- **Automatic knowledge recall** at session start based on current beads
- **Context7 MCP server** for framework documentation
- **60-70% cost reduction** via intelligent model tier assignment

## Installation

This plugin is installed via the marketplace root installer:

```bash
cd /path/to/lavra
./install.sh /path/to/your-project
```

See the [marketplace README](../../README.md) for full details.

## Commands

| Command | Description |
|---------|-------------|
| `/beads-brainstorm` | Explore ideas collaboratively before planning |
| `/beads-plan` | Research and plan using multiple agents |
| `/beads-research` | Gather evidence with domain-matched research agents |
| `/beads-plan-review` | Multi-agent review of epic plan |
| `/beads-triage` | Prioritize and categorize child beads |
| `/beads-work` | Work on one or many beads -- auto-routes single vs. multi-bead |
| `/beads-review` | Multi-agent code review before closing |
| `/beads-research` | Deep research using 5 specialized agents |
| `/beads-checkpoint` | Save progress, capture knowledge, commit |
| `/beads-learn` | Curate knowledge into structured, reusable entries |


## Agents (Model Tier Optimized)

All 27 agents include model tier assignments for optimal cost/performance balance:

### Haiku Tier (5 agents) -- Structured tasks, fast & cheap
- `learnings-researcher` -- Search knowledge.jsonl for past solutions
- `repo-research-analyst` -- Repository structure exploration
- `framework-docs-researcher` -- Framework documentation lookup
- `ankane-readme-writer` -- Template-based README generation
- `lint` -- Run linting tools

### Sonnet Tier (13 agents) -- Moderate judgment, balanced cost
- `code-simplicity-reviewer` -- Unnecessary complexity review
- `kieran-rails-reviewer` -- Rails best practices
- `kieran-python-reviewer` -- Python best practices
- `kieran-typescript-reviewer` -- TypeScript best practices
- `dhh-rails-reviewer` -- Rails conventions (DHH style)
- `security-sentinel` -- Security vulnerabilities (OWASP)
- `pattern-recognition-specialist` -- Code patterns and anti-patterns
- `deployment-verification-agent` -- Deployment readiness checklists
- `best-practices-researcher` -- Industry best practices research
- `git-history-analyzer` -- Git history pattern analysis
- `design-implementation-reviewer` -- Design-to-code accuracy
- `design-iterator` -- Design refinement iterations
- `figma-design-sync` -- Figma design synchronization
- `bug-reproduction-validator` -- Bug reproduction verification
- `pr-comment-resolver` -- PR comment resolution

### Opus Tier (9 agents) -- Deep reasoning, premium quality
- `architecture-strategist` -- System architecture and design patterns
- `performance-oracle` -- Algorithmic complexity and scalability
- `data-integrity-guardian` -- ACID properties, data consistency
- `data-migration-expert` -- Database migration validation
- `agent-native-reviewer` -- Agent-native architecture patterns
- `julik-frontend-races-reviewer` -- Frontend race conditions and timing
- `spec-flow-analyzer` -- User flow and edge case analysis

## Skills

### Core (installed by default)

| Skill | Description |
|-------|-------------|
| `git-worktree` | Manage git worktrees for parallel bead work |
| `brainstorming` | Structured brainstorming with bead output |
| `create-agent-skills` | Create new agents and skills |
| `agent-native-architecture` | Design agent-native system architectures |
| `beads-knowledge` | Document solved problems as knowledge entries |
| `agent-browser` | Browser automation for testing and screenshots |
| `file-todos` | Find and manage TODO comments in code |
| `project-setup` | Project environment setup and onboarding automation |
| `skill-creator` | Create new skills from templates |

### Optional (in `skills/optional/`, copy to install)

| Skill | Description |
|-------|-------------|
| `andrew-kane-gem-writer` | Write Ruby gems following Andrew Kane's style |
| `dhh-rails-style` | Rails development following DHH's conventions |
| `dspy-ruby` | DSPy integration for Ruby applications |
| `every-style-editor` | Every's house style guide for content editing |
| `frontend-design` | Frontend design patterns and best practices |
| `gemini-imagegen` | Generate images using Google's Gemini |
| `rclone` | Cloud storage file management with rclone |

## Memory System

Knowledge prefixes recognized by the memory capture hook:

- `LEARNED:` -- Something you learned while working
- `DECISION:` -- A decision and its rationale
- `FACT:` -- An objective fact about the codebase
- `PATTERN:` -- A reusable pattern discovered
- `INVESTIGATION:` -- Research findings

Usage:
```bash
bd comments add BD-001 "LEARNED: OAuth redirect URI must match exactly"
```

Knowledge is stored in `.beads/memory/knowledge.jsonl` and automatically recalled at the start of each session.

## License

MIT

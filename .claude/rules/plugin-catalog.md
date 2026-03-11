---
description: Full catalog of commands, agents, and skills
globs: "**/plugins/**,**/agents/**,**/commands/**,**/skills/**"
---

# Plugin Catalog

## Commands (29)

Commands are in `plugins/beads-compound/commands/`:

**Beads Workflow (10):**

| Command | File | Description |
|---------|------|-------------|
| `/beads-brainstorm` | beads-brainstorm.md | Explore ideas collaboratively |
| `/beads-design` | beads-design.md | Orchestrate full planning pipeline per phase: plan → deepen → review |
| `/beads-quick` | beads-quick.md | Fast-track small tasks with abbreviated plan |
| `/beads-plan` | beads-plan.md | Research and plan with multiple agents |
| `/beads-work` | beads-work.md | Work on a single bead with full lifecycle |
| `/beads-parallel` | beads-parallel.md | Work on multiple beads in parallel (`--ralph` for autonomous retry, `--teams` for persistent worker teammates) |
| `/beads-review` | beads-review.md | Multi-agent code review |
| `/beads-checkpoint` | beads-checkpoint.md | Save progress and capture knowledge |
| `/beads-compound` | beads-compound.md | Document solved problems |
| `/beads-recall` | beads-recall.md | Search knowledge base mid-session |

**Planning & Triage (4):**

| Command | File | Description |
|---------|------|-------------|
| `/beads-deepen` | beads-deepen.md | Enhance plan with parallel research |
| `/beads-plan-review` | beads-plan-review.md | Multi-agent plan review |
| `/beads-triage` | beads-triage.md | Prioritize and categorize beads |
| `/beads-import` | beads-import.md | Import markdown plans into beads |

**Utility (15):**

| Command | File | Description |
|---------|------|-------------|
| `/lfg` | lfg.md | Full autonomous engineering workflow |
| `/changelog` | changelog.md | Create engaging changelogs |
| `/create-agent-skill` | create-agent-skill.md | Create or edit skills |
| `/generate-command` | generate-command.md | Create new slash commands |
| `/heal-skill` | heal-skill.md | Fix incorrect SKILL.md files |
| `/deploy-docs` | deploy-docs.md | Validate docs for deployment |
| `/release-docs` | release-docs.md | Build and update documentation |
| `/feature-video` | feature-video.md | Record video walkthrough for PR |
| `/agent-native-audit` | agent-native-audit.md | Agent-native architecture review |
| `/test-browser` | test-browser.md | Browser tests on affected pages |
| `/xcode-test` | xcode-test.md | iOS simulator testing |
| `/report-bug` | report-bug.md | Report a plugin bug |
| `/reproduce-bug` | reproduce-bug.md | Reproduce and investigate bugs |
| `/resolve-pr-parallel` | resolve-pr-parallel.md | Resolve PR comments in parallel |
| `/resolve-todo-parallel` | resolve-todo-parallel.md | Resolve TODOs in parallel |

## Agents (28)

Agents are in `plugins/beads-compound/agents/`:

**Review (14)**: agent-native-reviewer, architecture-strategist, code-simplicity-reviewer, data-integrity-guardian, data-migration-expert, deployment-verification-agent, dhh-rails-reviewer, julik-frontend-races-reviewer, kieran-python-reviewer, kieran-rails-reviewer, kieran-typescript-reviewer, pattern-recognition-specialist, performance-oracle, security-sentinel

**Research (5)**: best-practices-researcher, framework-docs-researcher, git-history-analyzer, learnings-researcher, repo-research-analyst

**Design (3)**: design-implementation-reviewer, design-iterator, figma-design-sync

**Workflow (5)**: bug-reproduction-validator, every-style-editor, lint, pr-comment-resolver, spec-flow-analyzer

**Docs (1)**: ankane-readme-writer

## Skills (15)

Skills are in `plugins/beads-compound/skills/`:

- **git-worktree**: Manage git worktrees for parallel bead work
- **brainstorming**: Structured brainstorming with bead output
- **create-agent-skills**: Create new agents and skills
- **agent-native-architecture**: Design agent-native system architectures
- **beads-knowledge**: Document solved problems as knowledge entries
- **agent-browser**: Browser automation for testing and screenshots
- **andrew-kane-gem-writer**: Write Ruby gems following Andrew Kane's style
- **dhh-rails-style**: Rails development following DHH's conventions
- **dspy-ruby**: DSPy integration for Ruby applications
- **every-style-editor**: Every's house style guide for content editing
- **file-todos**: Find and manage TODO comments in code
- **frontend-design**: Frontend design patterns and best practices
- **gemini-imagegen**: Generate images using Google's Gemini
- **rclone**: Cloud storage file management with rclone
- **skill-creator**: Create new skills from templates

## Subagent Integration

When delegating work to subagents, include BEAD_ID in the prompt:

```
Task(subagent_type="general-purpose",
     prompt="Investigate OAuth flow. BEAD_ID: BD-001")
```

The `subagent-wrapup.sh` hook will:
1. Extract BEAD_ID from the subagent transcript
2. Block completion until subagent logs knowledge
3. Prompt with the five knowledge prefixes (LEARNED/DECISION/FACT/PATTERN/INVESTIGATION)

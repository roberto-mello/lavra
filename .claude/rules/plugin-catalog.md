---
description: Full catalog of commands, agents, and skills
globs: "**/plugins/**,**/agents/**,**/commands/**,**/skills/**"
---

# Plugin Catalog

## Commands (24 core + 5 optional)

Commands are in `plugins/lavra/commands/`:

**Beads Workflow (15):**

| Command | File | Description |
|---------|------|-------------|
| `/lavra-brainstorm` | lavra-brainstorm.md | Explore ideas collaboratively |
| `/lavra-design` | lavra-design.md | Orchestrate full planning pipeline per phase: plan -> research -> review |
| `/lavra-quick` | lavra-quick.md | Fast-track small tasks with abbreviated plan |
| `/lavra-plan` | lavra-plan.md | Research and plan with multiple agents |
| `/lavra-work` | lavra-work.md | Work on one or many beads -- auto-routes single vs. multi-bead paths |
| `/lavra-work-ralph` | lavra-work-ralph.md | Autonomous retry mode with completion promises |
| `/lavra-work-teams` | lavra-work-teams.md | Persistent worker teammates with COMPLETED/ACCEPTED protocol |
| `/lavra-review` | lavra-review.md | Multi-agent code review |
| `/lavra-qa` | lavra-qa.md | Browser-based QA verification from the user's perspective |
| `/lavra-ship` | lavra-ship.md | Automated ship sequence from code-ready to PR-open |
| `/lavra-checkpoint` | lavra-checkpoint.md | Save progress and capture knowledge |
| `/lavra-retro` | lavra-retro.md | Weekly retrospective with shipping analytics and knowledge synthesis |
| `/lavra-learn` | lavra-learn.md | Curate knowledge into structured entries |
| `/lavra-recall` | lavra-recall.md | Search knowledge base mid-session |

**Planning & Triage (5):**

| Command | File | Description |
|---------|------|-------------|
| `/lavra-research` | lavra-research.md | Gather evidence with domain-matched agents |
| `/lavra-ceo-review` | lavra-ceo-review.md | CEO/founder-mode plan review -- scope + business fit validation |
| `/lavra-eng-review` | lavra-eng-review.md | Engineering review -- architecture, simplicity, security, performance |
| `/lavra-triage` | lavra-triage.md | Prioritize and categorize beads |
| `/lavra-import` | lavra-import.md | Import markdown plans into beads |

**Utility (5):**

| Command | File | Description |
|---------|------|-------------|
| `/lavra-setup` | lavra-setup.md | Configure project stack, review agents, and workflow |
| `/changelog` | changelog.md | Create engaging changelogs |
| `/heal-skill` | heal-skill.md | Fix incorrect SKILL.md files |
| `/test-browser` | test-browser.md | Browser tests on affected pages |
| `/report-bug` | report-bug.md | Report a plugin bug |

**Optional (5):** Domain-specific commands in `plugins/lavra/commands/optional/`. Not installed by default.

| Command | File | Description |
|---------|------|-------------|
| `/feature-video` | optional/feature-video.md | Record video walkthrough for PR |
| `/agent-native-audit` | optional/agent-native-audit.md | Agent-native architecture review |
| `/xcode-test` | optional/xcode-test.md | iOS simulator testing |
| `/reproduce-bug` | optional/reproduce-bug.md | Reproduce and investigate bugs |
| `/generate-command` | optional/generate-command.md | Create new slash commands |

## Agents (30)

Agents are in `plugins/lavra/agents/`:

**Review (16)**: agent-native-reviewer, architecture-strategist, code-simplicity-reviewer, data-integrity-guardian, data-migration-expert, deployment-verification-agent, dhh-rails-reviewer, goal-verifier, julik-frontend-races-reviewer, kieran-python-reviewer, kieran-rails-reviewer, kieran-typescript-reviewer, migration-drift-detector, pattern-recognition-specialist, performance-oracle, security-sentinel

**Research (5)**: best-practices-researcher, framework-docs-researcher, git-history-analyzer, learnings-researcher, repo-research-analyst

**Design (3)**: design-implementation-reviewer, design-iterator, figma-design-sync

**Workflow (5)**: bug-reproduction-validator, every-style-editor, lint, pr-comment-resolver, spec-flow-analyzer

**Docs (1)**: ankane-readme-writer

## Skills (17: 10 core + 7 optional)

Skills are in `plugins/lavra/skills/` (core) and `plugins/lavra/skills/optional/` (optional):

- **git-worktree**: Manage git worktrees for parallel bead work
- **brainstorming**: Structured brainstorming with bead output
- **create-agent-skills**: Create new agents and skills
- **agent-native-architecture**: Design agent-native system architectures
- **lavra-knowledge**: Document solved problems as knowledge entries
- **agent-browser**: Browser automation for testing and screenshots
- **lavra-work-single**: Single-bead implementation path — invoked by lavra-work router
- **lavra-work-multi**: Multi-bead orchestration path — invoked by lavra-work router
- **andrew-kane-gem-writer**: Write Ruby gems following Andrew Kane's style
- **dhh-rails-style**: Rails development following DHH's conventions
- **dspy-ruby**: DSPy integration for Ruby applications
- **every-style-editor**: Every's house style guide for content editing
- **file-todos**: Find and manage TODO comments in code
- **frontend-design**: Frontend design patterns and best practices
- **gemini-imagegen**: Generate images using Google's Gemini
- **rclone**: Cloud storage file management with rclone

## Subagent Integration

When delegating work to subagents, include BEAD_ID in the prompt:

```
Task(subagent_type="general-purpose",
     prompt="Investigate OAuth flow. BEAD_ID: BD-001")
```

The `subagent-wrapup.sh` hook will:
1. Extract BEAD_ID from the subagent transcript
2. Block completion until subagent logs knowledge
3. Prompt with the seven knowledge prefixes (LEARNED/DECISION/FACT/PATTERN/INVESTIGATION/DEVIATION/SKIP)

---
title: Quick Start
description: Install Lavra and run your first workflow in minutes
order: 1
---

# Quick Start Guide

> **Lavra** (/ˈla.vɾɐ/) — Portuguese for "harvest." Every session plants knowledge that the next one reaps.

## Installation

Run from inside your project directory:

```bash
npx @lavralabs/lavra@latest --claude      # Claude Code
npx @lavralabs/lavra@latest --opencode    # OpenCode
npx @lavralabs/lavra@latest --gemini      # Gemini CLI
npx @lavralabs/lavra@latest --cortex      # Cortex Code
npx @lavralabs/lavra@latest --codex       # Codex
```

If the installer detects a project in the current directory, it will ask whether to install for this project only or globally (`~/.claude`). A global install makes commands available in every project, but you still run [/lavra-setup](#codebase-analysis) per project to configure the memory system and review agents.

Or with Bun:

```bash
bunx @lavralabs/lavra@latest --claude
```

Restart your agent after installing to pick up the new commands and hooks.

> Codex note: current direct install runs Lavra through skills (`$lavra-*`). Slash-command parity (`/lavra-*`) is planned via plugin marketplace packaging.

## Verify Installation

```bash
cd /path/to/your-project

# Check that files were created
ls -la .claude/hooks/        # Should see auto-recall.sh, memory-capture.sh
ls -la .claude/commands/     # Should see lavra-*.md files
ls -la .lavra/memory/        # Should see knowledge.jsonl, recall.sh
```

## Configuration

### Workflow config

The [/lavra-setup](#codebase-analysis) command creates `.lavra/config/lavra.json`, among other things. Once generated, you can edit it to tune Lavra (the example below is in `jsonc` format, with comments):

```jsonc
{
  "workflow": {
    "research": true,             // run research agents in /lavra-design
    "plan_review": true,          // run plan review phase in /lavra-design
    "goal_verification": true,    // verify completion criteria in /lavra-work and /lavra-ship
    "review_scope": "full",       // "full" (all changes) or "targeted" (P0/P1 and arch/security beads only)
    "testing_scope": "targeted"   // "targeted" (hooks, API routes, complex logic only) or "full" (all tests)
  },
  "execution": {
    "max_parallel_agents": 3,     // max subagents running at once
    "commit_granularity": "task"  // "task" (atomic, default) or "wave" (legacy)
  },
  "model_profile": "balanced"     // "balanced" (default) or "quality" (opus for review/verification agents)
}
```

### Codebase analysis

If you're installing Lavra into an existing project, run `/lavra-setup` to generate a codebase profile:

```
/lavra-setup
```

We recommend that you run codebase analysis when prompted. This dispatches 3 parallel agents to analyze your stack, architecture, and conventions, saving the results to `.lavra/config/codebase-profile.md`. This file is used by `/lavra-design` and `/lavra-work` as planning context.

`/lavra-setup` also asks questions to configure the behavior of Lavra's planning, reviewing and implementation agents. See [Workflow config](#workflow-config).

## Your First Workflow

### 1. Design

Describe the feature — Lavra runs the full six-phase design pipeline:

```
/lavra-design "add two-factor authentication with TOTP and QR codes"
```

1. **Brainstorm** — interactive interview to clarify scope, constraints, and success criteria
2. **Plan** — generates a structured multi-phase implementation plan
3. **Research** — dispatches domain-matched agents in parallel (security practices, framework docs, existing codebase patterns)
4. **Revise** — integrates research findings back into the plan
5. **Review** — four adversarial agents (CEO, engineering, security, simplicity) challenge the plan
6. **Lock** — final plan becomes an epic bead with child tasks ready for `/lavra-work`

The output is detailed enough that implementation is mechanical — subagents don't need to ask questions.

### 2. Work

Pick up the epic and Lavra works through the child beads automatically:

```
/lavra-work BD-001
```

For each bead it:
- Recalls relevant knowledge from past sessions automatically
- Implements with parallel subagents where possible
- Runs multi-agent code review and fixes issues
- Commits atomically and closes the bead

### 3. QA (optional)

Verify the feature from a user's perspective in a real browser:

```
/lavra-qa BD-001
```

### 4. Ship

Automated end-to-end: close remaining beads, run security scan, open PR:

```
/lavra-ship BD-001
```

## Next Session

When you start a new session:

1. The `auto-recall` hook runs automatically
2. It sees you have open beads
3. It searches knowledge for relevant entries
4. Injects them as context

You get relevant learnings without manually searching!

## Main Commands

| Command | Use When |
|---------|----------|
| `/lavra-design "description"` | Full design pipeline with interview, research, CEO and engineering reviews, planning |
| `/lavra-work {id}` | Working through a bead or epic |
| `/lavra-qa {id}` | Verifying a feature in a real browser before shipping |
| `/lavra-ship {id}` | Shipping. Closes beads, security scan, opens PR |
| `/lavra-quick` | Fast-track small tasks. Abbreviated plan then straight to execution |
| `/lavra-checkpoint` | When you've been working outside the pipeline (ad-hoc sessions). Save session progress by filing beads, capturing knowledge, and syncing state |

See the full [Command Reference](/docs/commands) or the [Command Map](/command-map) for a visual overview of all commands and how they connect.

### Codex Invocation

In Codex direct installs, run Lavra workflows via skills:

```text
$lavra-plan add OAuth device flow
$lavra-work lavra-7zm.2
```

Slash commands like `/lavra-work` are not exposed in the current Codex direct-install path.
This is also true for current plugin marketplace installs in Codex.

## Manual Knowledge Search

See the [Knowledge System docs](/docs/knowledge) for how capture, storage, and auto-recall work.

Mid-session, use the slash command in your agent to inject learnings into the agent's context:

```
/lavra-recall oauth redirect
/lavra-recall rls postgres
```

Or search directly from the shell:

```bash
# Search by keyword
.lavra/memory/recall.sh "authentication"

# Filter by type
.lavra/memory/recall.sh "jwt" --type learned

# Show recent entries
.lavra/memory/recall.sh --recent 10

# Show stats
.lavra/memory/recall.sh --stats
```

## Example: Full Feature Flow

```bash
# Design the feature -- creates epic BD-050 with child beads
/lavra-design "add two-factor authentication with TOTP and QR codes"
# Runs security and framework research agents in parallel
# Creates:
#   BD-050:   [epic] Two-factor authentication
#   BD-050.1: Database schema for OTP secrets
#   BD-050.2: QR code generation endpoint
#   BD-050.3: Verification endpoint
#   BD-050.4: Settings UI

# Work through the epic
/lavra-work BD-050
# Recalls security knowledge automatically
# Implements each child bead with parallel subagents
# Commits atomically, runs review, closes each bead

# Verify in a real browser
/lavra-qa BD-050

# Ship it
/lavra-ship BD-050
# Closes remaining beads, runs security scan, opens PR
```

## Tips

1. **Log liberally**: Every insight is valuable. Future you will thank you.

2. **Use prefixes consistently**:
   - `LEARNED:` - Technical insights, gotchas, discoveries
   - `DECISION:` - Choices made and why
   - `FACT:` - Constraints, requirements, environment details
   - `PATTERN:` - Coding patterns, conventions, idioms
   - `INVESTIGATION:` - Root cause analysis, how things work
   - `DEVIATION:` - Auto-fixes applied outside bead scope

3. **Review before closing**: `/lavra-review` catches issues early

4. **Plan complex features**: `/lavra-plan` prevents rework by researching upfront

5. **Checkpoint long sessions**: `/lavra-checkpoint` saves progress without losing context

6. **Trust auto-recall**: Knowledge will be injected when relevant, no need to search manually

## Troubleshooting

### Knowledge not appearing at session start

```bash
# Check if knowledge exists
.lavra/memory/recall.sh --stats

# Check if hook is installed
ls -la .claude/hooks/auto-recall.sh

# Check if hook is configured
cat .claude/settings.json | jq '.hooks.SessionStart'
```

### Commands not showing up

```bash
# Check if commands are installed
ls -la .claude/commands/lavra-*.md

# Restart Claude Code (required after installation)
```

### Agents not found

The plugin references compound-engineering agents but doesn't install them. If you don't have compound-engineering installed, the agent dispatches in commands will fail. You can either:

1. Install compound-engineering plugin
2. Or modify the commands to use different agent names
3. Or just use basic beads workflow without the agent commands

## Uninstall

```bash
npx @lavralabs/lavra@latest --uninstall
```

This removes the plugin but **preserves**:
- `.beads/` directory
- All your beads
- `knowledge.jsonl` with all accumulated knowledge

## Next Steps

- Read the [README](https://github.com/roberto-mello/lavra#readme) for the full feature overview
- Browse the [Command Reference](/docs/commands) for all available commands

---
title: Quick Start
description: Install lavra and run your first workflow in minutes
order: 1
---

# Quick Start Guide

## Installation

```bash
npx lavra@latest
```

Or with Bun:

```bash
bunx lavra@latest
```

Or manually from the plugin directory:

```bash
./install.sh /path/to/your-project
```

Restart Claude Code after installing.

## Verify Installation

```bash
cd /path/to/your-project

# Check that files were created
ls -la .claude/hooks/        # Should see auto-recall.sh, memory-capture.sh
ls -la .claude/commands/     # Should see lavra-*.md files
ls -la .beads/memory/        # Should see knowledge.jsonl, recall.sh
```

## Configuration

### Workflow config (automatic)

The installer creates `.beads/config/lavra.json` automatically. Edit to tune the workflow:

```json
{
  "workflow": {
    "research": true,        // run research agents in /lavra-design
    "plan_review": true,     // run plan review phase in /lavra-design
    "goal_verification": true // verify completion criteria in /lavra-work and /lavra-ship
  },
  "execution": {
    "max_parallel_agents": 3, // max subagents running at once
    "commit_granularity": "task" // "task" (atomic, default) or "wave" (legacy)
  },
  "model_profile": "balanced"
}
```

Existing projects get this file automatically on next session start.

### Codebase analysis (optional, for brownfield projects)

If you're installing lavra into an existing project, run `/project-setup` to generate a codebase profile:

```
/project-setup
```

When prompted "Run codebase analysis?", choose Y. This dispatches 3 parallel agents to analyze your stack, architecture, and conventions, saving the results to `.beads/config/codebase-profile.md`. This file is used by `/lavra-design` and `/lavra-work` as planning context.

## Your First Workflow

### 1. Design

Describe the feature — lavra creates the beads, runs research agents, and produces a plan:

```
/lavra-design "add two-factor authentication with TOTP and QR codes"
```

This dispatches domain-matched research agents in parallel, then creates an epic with child beads for each implementation step. Review and adjust the plan before moving on.

### 2. Work

Pick up the epic and lavra works through the child beads automatically:

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

## Available Commands

| Command | Use When |
|---------|----------|
| `/lavra-design "description"` | Starting any feature — creates beads, runs research, builds plan |
| `/lavra-work {id}` | Working through a bead or epic |
| `/lavra-qa {id}` | Verifying a feature in a real browser before shipping |
| `/lavra-ship {id}` | Shipping — closes beads, security scan, opens PR |
| `/lavra-review {id}` | On-demand multi-agent code review |
| `/lavra-checkpoint` | Save progress mid-session |

## Manual Knowledge Search

```bash
# Search by keyword
.beads/memory/recall.sh "authentication"

# Show recent
.beads/memory/recall.sh --recent 10

# Show stats
.beads/memory/recall.sh --stats

# Filter by type
.beads/memory/recall.sh "jwt" --type learned
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
.beads/memory/recall.sh --stats

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
npx lavra@latest --uninstall
```

This removes the plugin but **preserves**:
- `.beads/` directory
- All your beads
- `knowledge.jsonl` with all accumulated knowledge

## Next Steps

Once you're comfortable with the basic workflow:

1. Read the full [README.md](README.md) for all features
2. Check [COMPARISON.md](../COMPARISON.md) to understand vs semantic-beads
3. Customize the commands in `.claude/commands/` for your workflow
4. Add custom tags to `.claude/hooks/memory-capture.sh` for better search

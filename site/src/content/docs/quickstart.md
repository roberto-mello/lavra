---
title: Quick Start
description: Install lavra and run your first workflow in minutes
order: 1
---

# Quick Start Guide

## Installation

```bash
# From the plugin directory
cd ~/Documents/projects/lavra
./install.sh /path/to/your-project

# Restart Claude Code
```

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

The installer creates `.beads/config/lavra.json` with default settings. Edit to toggle:
- `workflow.research` -- skip research phase in `/lavra-design`
- `workflow.plan_review` -- skip plan review phase in `/lavra-design`
- `workflow.goal_verification` -- skip goal verification in `/lavra-work` and `/lavra-ship`
- `execution.max_parallel_agents` -- limit parallel subagents (default: 3)
- `execution.commit_granularity` -- `"task"` (default, atomic) or `"wave"` (legacy)

Existing projects get this file automatically on next session start (version self-heal).

### Codebase analysis (optional, for brownfield projects)

If you're installing lavra into an existing project, run `/project-setup` to generate a codebase profile:

```
/project-setup
```

When prompted "Run codebase analysis?", choose Y. This dispatches 3 parallel agents to analyze your stack, architecture, and conventions, saving the results to `.beads/config/codebase-profile.md`. This file is used by `/lavra-design` and `/lavra-work` as planning context.

## Your First Workflow

### 1. Create a bead

```bash
bd create "Add user profile page" -d "Display user info with edit capability"
# Returns: BD-001
```

### 2. Plan it (optional but recommended)

```
/lavra-plan BD-001
```

This dispatches research agents to gather:
- Best practices for profile pages
- Framework documentation
- Existing patterns in your codebase

Creates child beads for each step.

### 3. Work on it

```
/lavra-work BD-001.1
```

This:
- Shows you relevant knowledge automatically
- Updates status to in_progress
- Offers investigation if you want it

### 4. Implement

Just code normally:
```bash
# Edit files
# Make commits
```

### 5. Log learnings

```bash
bd comments add BD-001.1 "LEARNED: Profile images should be lazy-loaded for performance"
bd comments add BD-001.1 "DECISION: Using Gravatar for default avatars"
bd comments add BD-001.1 "FACT: Max upload size is 5MB (nginx limit)"
```

These get auto-captured to `.beads/memory/knowledge.jsonl`.

### 6. Review

```
/lavra-review BD-001.1
```

This dispatches multiple reviewers:
- Security audit
- Performance check
- Code quality review
- Architecture validation

Creates follow-up beads for any issues found.

### 7. Close

```bash
bd close BD-001.1
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
| `/lavra-plan {id or desc}` | Starting a complex feature, need research |
| `/lavra-work {id}` | Starting work on a bead |
| `/lavra-review {id}` | Before closing a bead, want multi-agent review |
| `/lavra-research {id or question}` | Need deep understanding before implementing |
| `/lavra-checkpoint` | Want to save progress during long session |

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
# Day 1: Research and planning
bd create "Add two-factor authentication" -d "TOTP-based 2FA with QR codes"
# => BD-050

/lavra-plan BD-050
# Researches best practices, security considerations, framework options
# Creates child beads:
#   BD-050.1: Database schema for OTP secrets
#   BD-050.2: QR code generation endpoint
#   BD-050.3: Verification endpoint
#   BD-050.4: Settings UI

# Day 2: Implement first step
/lavra-work BD-050.1
# Auto-recalls security knowledge from yesterday's research

# Edit files, create migration
git add -A
git commit -m "Add OTP secrets table"

bd comments add BD-050.1 "LEARNED: OTP secrets MUST be encrypted at rest"
bd comments add BD-050.1 "DECISION: Using rotp gem for TOTP generation"
bd comments add BD-050.1 "FACT: Backup codes needed for account recovery"

/lavra-review BD-050.1
# Security review catches missing index on user_id
# Creates BD-051: Add index to otp_secrets.user_id

# Fix the issue
git add -A
git commit -m "Add index to otp_secrets.user_id"
bd close BD-051

bd close BD-050.1

# Continue with BD-050.2...
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
cd ~/Documents/projects/lavra
./uninstall.sh /path/to/your-project
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

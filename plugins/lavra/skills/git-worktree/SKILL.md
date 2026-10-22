---
name: git-worktree
description: "Manage Git worktrees for isolated parallel development. Use when creating, switching, or cleaning up worktrees for parallel bead work."
disable-model-invocation: true
metadata:
  source: Lavra
  site: 'https://lavra.dev'
  overwrite-warning: "Edit source at https://github.com/roberto-mello/lavra. Changes will be overwritten on next install."
---

# Git Worktree Manager

This skill provides a unified interface for managing Git worktrees across your development workflow. Whether you're reviewing PRs in isolation or working on features in parallel, this skill handles all the complexity.

## What This Skill Does

- **Create worktrees** from main branch with clear branch names
- **List worktrees** with current status
- **Switch between worktrees** for parallel work
- **Clean up completed worktrees** automatically
- **Interactive confirmations** at each step
- **Automatic .gitignore management** for worktree directory
- **Automatic .env file copying** from main repo to new worktrees

## CRITICAL: Always Use the Manager Script

**NEVER call `git worktree add` directly.** Always use the `worktree-manager.sh` script.

The script handles critical setup that raw git commands don't:
1. Copies `.env`, `.env.local`, `.env.test`, etc. from main repo
2. Ensures `.worktrees` is in `.gitignore`
3. Creates consistent directory structure

```bash
WORKTREE_MANAGER="$(find . -type f -path "*/git-worktree/scripts/worktree-manager.sh" 2>/dev/null | head -1)"

# CORRECT - Always use the script
bash "$WORKTREE_MANAGER" create feature-name

# WRONG - Never do this directly
git worktree add .worktrees/feature-name -b feature-name main
```

## When to Use This Skill

Use this skill in these scenarios:

1. **Code Review (workflow review command)**: If NOT already on the target branch (PR branch or requested branch), offer worktree for isolated review
2. **Feature Work (workflow work command)**: Always ask if user wants parallel worktree or live branch work
3. **Parallel Development**: When working on multiple features simultaneously
4. **Cleanup**: After completing work in a worktree

## How to Use

### In Agent Workflows

The skill is automatically called from workflow review/work commands:

```
# For review: offers worktree if not on PR branch
# For work: always asks - new branch or worktree?
```

### Manual Usage

You can also invoke the skill directly from bash:

```bash
# Create a new worktree (copies .env files automatically)
bash "$WORKTREE_MANAGER" create feature-login

# List all worktrees
bash "$WORKTREE_MANAGER" list

# Switch to a worktree
bash "$WORKTREE_MANAGER" switch feature-login

# Copy .env files to an existing worktree (if they weren't copied)
bash "$WORKTREE_MANAGER" copy-env feature-login

# Clean up completed worktrees
bash "$WORKTREE_MANAGER" cleanup
```

## Commands

### `create <branch-name> [from-branch]`

Creates a new worktree with the given branch name.

**Options:**
- `branch-name` (required): The name for the new branch and worktree
- `from-branch` (optional): Base branch to create from (defaults to `main`)

**Example:**
```bash
bash "$WORKTREE_MANAGER" create feature-login
```

**What happens:**
1. Checks if worktree already exists
2. Updates the base branch from remote
3. Creates new worktree and branch
4. **Copies all .env files from main repo** (.env, .env.local, .env.test, etc.)
5. Shows path for cd-ing to the worktree

### `list` or `ls`

Lists all available worktrees with their branches and current status.

**Example:**
```bash
bash "$WORKTREE_MANAGER" list
```

**Output shows:**
- Worktree name
- Branch name
- Which is current (marked with checkmark)
- Main repo status

### `switch <name>` or `go <name>`

Switches to an existing worktree and cd's into it.

**Example:**
```bash
bash "$WORKTREE_MANAGER" switch feature-login
```

**Optional:**
- If name not provided, lists available worktrees and prompts for selection

### `cleanup` or `clean`

Interactively cleans up inactive worktrees with confirmation.

**Example:**
```bash
bash "$WORKTREE_MANAGER" cleanup
```

**What happens:**
1. Lists all inactive worktrees
2. Asks for confirmation
3. Removes selected worktrees
4. Cleans up empty directories

## Workflow Examples

### Code Review with Worktree

```bash
# Claude Code recognizes you're not on the PR branch
# Offers: "Use worktree for isolated review? (y/n)"

# You respond: yes
# Script runs (copies .env files automatically):
bash "$WORKTREE_MANAGER" create pr-123-feature-name

# You're now in isolated worktree for review with all env vars
cd .worktrees/pr-123-feature-name

# After review, return to main:
cd ../..
bash "$WORKTREE_MANAGER" cleanup
```

### Parallel Feature Development

```bash
# For first feature (copies .env files):
bash "$WORKTREE_MANAGER" create feature-login

# Later, start second feature (also copies .env files):
bash "$WORKTREE_MANAGER" create feature-notifications

# List what you have:
bash "$WORKTREE_MANAGER" list

# Switch between them as needed:
bash "$WORKTREE_MANAGER" switch feature-login

# Return to main and cleanup when done:
cd .
bash "$WORKTREE_MANAGER" cleanup
```

## Key Design Principles

### KISS (Keep It Simple, Stupid)

- **One manager script** handles all worktree operations
- **Simple commands** with sensible defaults
- **Interactive prompts** prevent accidental operations
- **Clear naming** using branch names directly

### Opinionated Defaults

- Worktrees always created from **main** (unless specified)
- Worktrees stored in **.worktrees/** directory
- Branch name becomes worktree name
- **.gitignore** automatically managed

### Safety First

- **Confirms before creating** worktrees
- **Confirms before cleanup** to prevent accidental removal
- **Won't remove current worktree**
- **Clear error messages** for issues

## Integration with Workflows

### `workflow review command`

Instead of always creating a worktree:

```
1. Check current branch
2. If ALREADY on target branch (PR branch or requested branch) -> stay there, no worktree needed
3. If DIFFERENT branch than the review target -> offer worktree:
   "Use worktree for isolated review? (y/n)"
   - yes -> call git-worktree skill
   - no -> proceed with PR diff on current branch
```

### `workflow work command`

Always offer choice:

```
1. Ask: "How do you want to work?
   1. New branch on current worktree (live work)
   2. Worktree (parallel work)"

2. If choice 1 -> create new branch normally
3. If choice 2 -> call git-worktree skill to create from main
```

## Troubleshooting

### "Worktree already exists"

If you see this, the script will ask if you want to switch to it instead.

### "Cannot remove worktree: it is the current worktree"

Switch out of the worktree first (to main repo), then cleanup:

```bash
cd $(git rev-parse --show-toplevel)
bash "$WORKTREE_MANAGER" cleanup
```

### Lost in a worktree?

See where you are:

```bash
bash "$WORKTREE_MANAGER" list
```

### .env files missing in worktree?

If a worktree was created without .env files (e.g., via raw `git worktree add`), copy them:

```bash
bash "$WORKTREE_MANAGER" copy-env feature-name
```

Navigate back to main:

```bash
cd $(git rev-parse --show-toplevel)
```

## Technical Details

### Directory Structure

```
.worktrees/
├── feature-login/          # Worktree 1
│   ├── .git
│   ├── app/
│   └── ...
├── feature-notifications/  # Worktree 2
│   ├── .git
│   ├── app/
│   └── ...
└── ...

.gitignore (updated to include .worktrees)
```

### How It Works

- Uses `git worktree add` for isolated environments
- Each worktree has its own branch
- Changes in one worktree don't affect others
- Share git history with main repo
- Can push from any worktree

### Performance

- Worktrees are lightweight (just file system links)
- No repository duplication
- Shared git objects for efficiency
- Much faster than cloning or stashing/switching

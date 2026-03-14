# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Claude Code plugin marketplace that provides beads-based persistent memory with compound-engineering's multi-agent workflows. The primary plugin is `beads-compound`, located at `plugins/beads-compound/`.

The plugin provides:
- 29 specialized agents (15 review, 5 research, 3 design, 5 workflow, 1 docs)
- 24 core commands + 5 optional domain-specific commands (in commands/optional/)
- 16 skills (git-worktree, brainstorming, create-agent-skills, agent-browser, dhh-rails-style, etc.)
- 3 hooks for automatic knowledge capture, recall, and subagent wrapup
- 1 MCP server (Context7 for framework documentation)
- Automatic knowledge capture from beads comments (LEARNED/DECISION/FACT/PATTERN/INVESTIGATION)
- Automatic knowledge recall at session start based on current beads

## Multi-Platform Support

beads-compound supports OpenCode and Gemini CLI in addition to Claude Code:

**OpenCode:** Core memory system via native TypeScript plugin at `plugins/beads-compound/opencode/plugin.ts`. Commands/agents/skills are Claude Code-specific. OpenCode reads `AGENTS.md`.

**Gemini CLI:** Full hook compatibility via `gemini-extension.json` manifest. Uses same stdin/stdout JSON protocol as Claude Code.

See README.md for detailed setup instructions.

## Repository Structure

```
beads-compound-plugin/              # Marketplace root
├── .claude-plugin/
│   └── marketplace.json            # Marketplace catalog
├── plugins/
│   └── beads-compound/             # Plugin root
│       ├── .claude-plugin/
│       │   └── plugin.json         # Plugin manifest (v0.6.0)
│       ├── agents/                 # 29 agents (review/, research/, design/, workflow/, docs/)
│       ├── commands/               # 24 core commands + optional/
│       ├── skills/                 # 16 skills with supporting files
│       ├── hooks/                  # hooks.json, auto-recall.sh, memory-capture.sh, subagent-wrapup.sh, recall.sh
│       ├── opencode/               # OpenCode TypeScript plugin
│       ├── gemini/                 # Gemini CLI hook configuration
│       ├── gemini-extension.json   # Gemini extension manifest
│       ├── scripts/                # import-plan.sh
│       └── .mcp.json               # Context7 MCP server
├── install.sh                      # Installer (at marketplace root)
├── uninstall.sh                    # Uninstaller (at marketplace root)
├── CLAUDE.md
└── README.md
```

## Plugin Installation

### Native Plugin System (not done yet)

```bash
/plugin marketplace add https://github.com/roberto-mello/beads-compound-plugin
/plugin install beads-compound
```

### Manual Install

```bash
# From marketplace root
./install.sh /path/to/target-project

# Or from target project
bash /path/to/beads-compound-plugin/install.sh
```

**IMPORTANT**: The installer will fail if you try to install into the plugin directory itself. Always install into a separate target project.

The installer copies from `plugins/beads-compound/` into the target's `.claude/` directory:
- `hooks/` -> `.claude/hooks/`
- `commands/` -> `.claude/commands/`
- `agents/` -> `.claude/agents/`
- `skills/` -> `.claude/skills/`
- `.mcp.json` -> `.mcp.json` (merged if exists)
- Configures `settings.json` with hook definitions

### Uninstall

```bash
./uninstall.sh /path/to/target-project
```

## Development Commands

**Test the installer:** (from plugin root)
```bash
mkdir -p /tmp/test-project && cd /tmp/test-project
git init && bd init --no-daemon
bash ~/Documents/projects/beads-compound-plugin/install.sh

# Verify
ls -la .claude/hooks/
ls -la .claude/commands/
ls -la .claude/agents/review/
ls -la .claude/skills/
cat .claude/settings.json | jq .
```

**Test uninstaller:**
```bash
bash ~/Documents/projects/beads-compound-plugin/uninstall.sh /tmp/test-project
```

**Test hook format:**
```bash
cat .claude/settings.json | jq '.hooks'
# Should use string matchers, not object matchers:
# Correct: {"matcher": "Bash", "hooks": [...]}
# Wrong:   {"matcher": {"tools": ["BashTool"]}, "hooks": [...]}
```

## Agent Instructions

This project uses **bd** (beads) for issue tracking.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
```

### Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd backup
   git add .beads/backup/
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
- NEVER add Co-Authored-By lines to commit messages
- Never use emoji in print messages unless explicitly requested

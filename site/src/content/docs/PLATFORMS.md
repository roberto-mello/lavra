---
title: Platform Support
description: Installation and setup for OpenCode, Gemini CLI, Cortex Code, and Codex CLI
order: 4
---

# Multi-Platform Support

Installation and setup instructions for all supported platforms: OpenCode, Gemini CLI, Cortex Code, and Codex CLI.

[Back to README](../README.md)

## OpenCode

**Install:**
```bash
# Global install (to ~/.config/opencode)
./install.sh --opencode

# Interactive model selection during install
# You'll be prompted to choose Claude models for each tier (haiku/sonnet/opus)
# Or use --yes to skip prompts and use defaults

# Or project-specific install
./install.sh --opencode /path/to/your-project
```

The installer copies the TypeScript plugin to `~/.config/opencode/plugins/lavra/` (global) or `.opencode/plugins/lavra/` (project-specific) and installs dependencies with Bun.

### OpenCode Troubleshooting

```bash
# Check if plugin is installed
# Project-specific:
ls -la .opencode/plugins/lavra/plugin.ts

# Global:
ls -la ~/.config/opencode/plugins/lavra/plugin.ts

# Check if commands/agents/skills/hooks are installed
ls -la .opencode/commands/
ls -la .opencode/agents/
ls -la .opencode/skills/
ls -la .opencode/hooks/

# Check if plugin is loading (look for console.log messages in OpenCode output)
# Expected: "[lavra] Plugin loaded successfully"
# Expected: "[lavra] session.created hook triggered"

# Check memory directory
ls -la .beads/memory/

# Test knowledge capture manually
bd comments add <BEAD_ID> "LEARNED: Testing memory capture"
tail -1 .beads/memory/knowledge.jsonl

# Check plugin dependencies are installed
ls -la .opencode/plugins/lavra/node_modules/
# Or for global: ls -la ~/.config/opencode/plugins/lavra/node_modules/
```

## Gemini CLI

**Install:**
```bash
# Global install (to ~/.config/gemini)
./install.sh --gemini

# Or project-specific install
./install.sh --gemini /path/to/your-project
```

The installer copies hooks to `~/.config/gemini/hooks/` (global) or `.gemini/hooks/` (project-specific).

### Gemini CLI Troubleshooting

```bash
# Check if hooks are installed (project-specific)
ls -la .gemini/hooks/

# Or global install
ls -la ~/.config/gemini/hooks/

# Check hook configuration in gemini-extension.json
cat gemini-extension.json | jq '.hooks'

# Check memory directory
ls -la .beads/memory/

# Test knowledge capture manually
bd comments add <BEAD_ID> "LEARNED: Testing memory capture"
tail -1 .beads/memory/knowledge.jsonl
```

## Cortex Code

**Install:**
```bash
# Global install (to ~/.snowflake/cortex)
./install.sh --cortex

# Or project-specific install
./install.sh --cortex /path/to/project
```

The installer copies hooks to `~/.snowflake/cortex/hooks/` (global) or `.cortex/hooks/` (project-specific). Commands, agents, and skills use `.md` format (same as Claude Code). Hooks are configured via `~/.snowflake/cortex/hooks.json`. Context7 MCP is not installed automatically -- to enable framework documentation lookup, add it manually to `~/.snowflake/cortex/mcp.json`:

```json
{
  "mcpServers": {
    "context7": {
      "url": "https://mcp.context7.com/mcp",
      "type": "http"
    }
  }
}
```

> **Note:** Cortex Code also reads `.claude/` directories for compatibility, but native `.cortex/` paths are preferred.

### Cortex Code Troubleshooting

**Hooks not loading:**
- Check `~/.snowflake/cortex/hooks.json` exists and has SessionStart/PostToolUse/SubagentStop entries
- For project-specific installs, check `.cortex/hooks/` directory exists

**Memory not capturing:**
- Ensure `.cortex/hooks/memory-capture.sh` (project) or `~/.snowflake/cortex/hooks/memory-capture.sh` (global) exists and is executable

**Agent model selection:**
- Uses haiku/sonnet/opus in Task tool (same tier names as Claude)

## Codex CLI / Antigravity

**Not yet supported.** Codex CLI hook system is planned but not shipped (PR #11067 closed). Antigravity has no lifecycle event system.

## Model Configuration

For OpenCode, you can customize which Claude models to use for each performance tier. See [MODEL_SELECTION.md](MODEL_SELECTION.md) for details on:
- Interactive model selection during installation
- Manual model configuration via `scripts/select-opencode-models.sh`
- Editing `scripts/shared/model-config.json` directly

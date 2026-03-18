---
title: Platform Support
description: Installation and setup for Claude Code, OpenCode, Gemini CLI, and Cortex Code
order: 4
---

# Multi-Platform Support

Lavra supports four AI coding agents. The core memory system (hooks, knowledge capture, auto-recall) works identically across all platforms. Commands, agents, and skills are available on all platforms.

## What works where

| Feature | Claude Code | OpenCode | Gemini CLI | Cortex Code |
|---------|-------------|----------|------------|-------------|
| Memory capture | ✓ | ✓ | ✓ | ✓ |
| Auto-recall | ✓ | ✓ | ✓ | ✓ |
| Commands | ✓ | ✓ | ✓ | ✓ |
| Agents | ✓ | ✓ | ✓ | ✓ |
| Skills | ✓ | ✓ | ✓ | ✓ |
| Context7 MCP | ✓ | ✓ | ✓ | manual |

## Claude Code

```bash
npx @lavralabs/lavra@latest --claude       # local project
npx @lavralabs/lavra@latest --global       # all projects (~/.claude/)
```

## OpenCode

```bash
npx @lavralabs/lavra@latest --opencode           # local project
npx @lavralabs/lavra@latest --opencode --yes     # skip model selection prompts
```

The installer copies a TypeScript plugin to `.opencode/plugins/lavra/` (local) or `~/.config/opencode/plugins/lavra/` (global) and installs dependencies with Bun. Commands, agents, and skills are converted to OpenCode format automatically.

You'll be prompted to choose which models to map to each tier (haiku/sonnet/opus). See [Model Selection](/docs/model-selection) for details.

**Verify:**
```bash
ls -la .opencode/plugins/lavra/plugin.ts
ls -la .opencode/hooks/
```

Check plugin is loading (look for these in OpenCode output):
```
[lavra] Plugin loaded successfully
[lavra] session.created hook triggered
```

## Gemini CLI

```bash
npx @lavralabs/lavra@latest --gemini       # local project
```

The installer converts commands to `.toml` format and copies commands, agents, skills, and hooks to `.gemini/` (local) or `~/.config/gemini/` (global). Memory capture and auto-recall work via the same stdin/stdout JSON protocol as Claude Code. Context7 MCP is configured automatically in `~/.config/gemini/settings.json`.

**Verify:**
```bash
ls -la .gemini/hooks/
cat gemini-extension.json | jq '.hooks'
```

## Cortex Code

```bash
bash /path/to/lavra/installers/install-cortex.sh
```

The installer copies hooks to `.cortex/hooks/` (local) or `~/.snowflake/cortex/hooks/` (global). Commands, agents, and skills use `.md` format (same as Claude Code). Hooks are configured via `hooks.json`.

Context7 MCP is not installed automatically. To enable framework documentation lookup, add it manually to `~/.snowflake/cortex/mcp.json`:

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

> Cortex Code also reads `.claude/` directories for compatibility, but native `.cortex/` paths are preferred.

## See Also

- [Model Selection](/docs/model-selection) — customize which models map to each tier in OpenCode
- [Cost Optimization](/docs/cost) — how Lavra assigns agents to model tiers

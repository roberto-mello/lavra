---
title: Model Selection
description: Customize which models Lavra uses per performance tier in OpenCode and Gemini CLI
order: 8
---

# Model Selection

Lavra maps its agents to three performance tiers. For OpenCode and Gemini CLI, you can customize which model each tier uses.

## Tiers

| Tier | Default (OpenCode) | Default (Gemini) | Used for |
|------|--------------------|------------------|----------|
| **haiku** | `claude-haiku-4-5-20251001` | `gemini-2.5-flash` | Fast structured tasks |
| **sonnet** | `claude-sonnet-4-5-20250929` | `gemini-2.5-pro` | Standard review and research |
| **opus** | `claude-opus-4-6` | `gemini-2.5-pro` | Deep reasoning (when routed explicitly) |

## OpenCode — Interactive Selection

When installing for OpenCode, you'll be prompted to customize model mappings:

```bash
npx lavra@latest --opencode
# Customize models? (y/N):
```

Select `y` to pick models for each tier from your available OpenCode models.

To skip prompts and use defaults:

```bash
npx lavra@latest --opencode --yes
```

## OpenCode — Manual Configuration

Run the selection script independently:

```bash
bash scripts/select-opencode-models.sh
```

Or edit `scripts/shared/model-config.json` directly:

```json
{
  "opencode": {
    "haiku": "anthropic/claude-haiku-4-5-20251001",
    "sonnet": "anthropic/claude-sonnet-4-5-20250929",
    "opus": "anthropic/claude-opus-4-6"
  },
  "gemini": {
    "haiku": "gemini-2.5-flash",
    "sonnet": "gemini-2.5-pro",
    "opus": "gemini-2.5-pro"
  }
}
```

Re-run the installer after editing to apply changes.

## Troubleshooting

**`opencode` command not found** — model selection requires OpenCode in your PATH. Install it first, then re-run the Lavra installer.

**No Claude models available** — configure your OpenCode API keys with `opencode config`, then re-run.

## See Also

- [Cost Optimization](/docs/cost) — how agents are assigned to tiers
- [Platform Support](/docs/platforms) — platform-specific install instructions

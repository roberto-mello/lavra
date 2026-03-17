---
title: Model Selection
description: Choose which Claude models to use per performance tier in OpenCode
order: 8
---

# Model Selection for OpenCode

The OpenCode installer supports interactive model selection, allowing you to choose which Claude models to use for each performance tier (haiku/sonnet/opus).

## Quick Start

### Interactive Installation

When installing for OpenCode, you'll be prompted to customize model selections:

```bash
./install.sh -opencode

# You'll see:
🎯 Step 1/6: Model selection...

Would you like to customize model selections for each tier?
(haiku/sonnet/opus)

Customize models? (y/N):
```

Select `y` to interactively choose models for each tier.

### Automatic Installation (Use Defaults)

Skip model selection prompts with the `--yes` flag:

```bash
./install.sh -opencode --yes
```

This uses the default model configuration from `scripts/shared/model-config.json`.

## Manual Model Selection

You can also configure models independently before installation:

```bash
cd scripts
./select-opencode-models.sh
```

This will:
1. Query available models via `opencode models`
2. Present an interactive selection menu for each tier
3. Save your selections to `model-config.json`
4. Use these selections during subsequent installations

## Model Configuration File

Model selections are stored in `scripts/shared/model-config.json`:

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

You can edit this file directly if needed.

## Model Tiers Explained

The plugin uses three performance tiers across all agents and commands:

| Tier | Performance | Cost | Use Case |
|------|-------------|------|----------|
| **haiku** | Fast | Low | Quick tasks, simple operations |
| **sonnet** | Balanced | Medium | Standard development work |
| **opus** | Best | High | Complex reasoning, reviews |

During installation, you map each tier to a specific model available in your OpenCode setup.

## How It Works

1. **Query Available Models**: The installer runs `opencode models` to get your model list
2. **Filter Claude Models**: Only Anthropic/Claude models are shown for selection
3. **Interactive Selection**: For each tier, you pick from available models
4. **Save Configuration**: Selections are saved to `model-config.json`
5. **Conversion**: The conversion script reads the config and maps agent models accordingly

## Default Models

If you skip model selection or if `opencode` is not available, these defaults are used:

- **haiku**: `anthropic/claude-haiku-4-5-20251001`
- **sonnet**: `anthropic/claude-sonnet-4-5-20250929`
- **opus**: `anthropic/claude-opus-4-6`

## Troubleshooting

### "opencode command not found"

Model selection requires OpenCode to be installed and accessible in your PATH:

```bash
which opencode
# Should output: /path/to/opencode
```

If not found, install OpenCode first: https://github.com/smallcloudai/refact

### No Claude models available

If `opencode models` doesn't show any Anthropic/Claude models, configure your OpenCode API keys first:

```bash
opencode config
```

### Permission denied

Make sure the selection script is executable:

```bash
chmod +x scripts/select-opencode-models.sh
```

## Examples

### Select Latest Sonnet for All Tiers

```bash
./scripts/select-opencode-models.sh

# When prompted for haiku:
Selection: 5  # (pick latest sonnet)

# When prompted for sonnet:
Selection: 5  # (pick latest sonnet)

# When prompted for opus:
Selection: 2  # (pick opus-4-6)
```

### Use Gemini Models Instead

For Gemini CLI, edit `scripts/shared/model-config.json` directly:

```json
{
  "gemini": {
    "haiku": "gemini-2.0-flash-exp",
    "sonnet": "gemini-2.5-pro",
    "opus": "gemini-2.5-pro-exp"
  }
}
```

## See Also

- [Installation Guide](../README.md#installation)
- [Platform Support](../README.md#multi-platform-support)
- [Agent Configuration](../CLAUDE.md#agents-28)

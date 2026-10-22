---
description: Platform conversion scripts, model mapping, and file permissions
globs: "**/scripts/**,**/opencode/**,**/gemini/**"
---

# Platform Conversion Scripts

OpenCode, Gemini CLI, Cortex Code, and Codex require conversion from Claude Code format:

- `scripts/convert-opencode.ts` - Converts to OpenCode format
- `scripts/convert-gemini.ts` - Converts to Gemini CLI format
- `scripts/convert-cortex.ts` - Converts to Cortex Code format
- `scripts/convert-codex.ts` - Converts Codex output from Cortex output
- Run automatically during platform-specific installation
- Requires Bun runtime (`bun run convert-opencode.ts`)

Generated outputs are checked in for release/install compatibility, but they must always match the canonical source in `plugins/lavra/`. The CI and pre-release gate use `scripts/check-generated-outputs.sh` to fail if the generated trees drift.

## Model Tier Mapping

Claude Code tiers map to platform-specific model IDs via `scripts/shared/model-config.json`:

| Claude Tier | OpenCode Model (default) | Gemini Model (default) |
|-------------|--------------------------|------------------------|
| haiku | anthropic/claude-haiku-4-5-20251001 | gemini-2.5-flash |
| sonnet | anthropic/claude-sonnet-4-5-20250929 | gemini-2.5-pro |
| opus | anthropic/claude-opus-4-6 | gemini-2.5-pro |
| inherit | inherit | inherit |

## Interactive Model Selection

- OpenCode installer prompts to customize models (unless `--yes` flag used)
- Runs `opencode models` to query available models
- Selections saved to `scripts/shared/model-config.json`
- Manual selection: `./scripts/select-opencode-models.sh`
- See `docs/MODEL_SELECTION.md` for details

## Generated File Permissions

Skills use `0o644` (writable) not `0o444` (read-only):
- Allows conversion script to overwrite on subsequent runs
- Prevents `EACCES` errors when re-running conversion
- Read-only permissions cause subsequent runs to fail silently (misleading "no SKILL.md found" warnings)

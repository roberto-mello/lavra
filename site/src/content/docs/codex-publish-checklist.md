---
title: Codex Publish Checklist
description: Preflight and release checklist for Codex plugin marketplace support
order: 29
---

# Codex Publish Checklist

Use this checklist before publishing a Lavra release with Codex support.

## 1) Preflight checks

Run:

```bash
./scripts/pre-release-check.sh
./scripts/test-installation.sh
```

Required Codex pass conditions:
- `plugins/lavra/.codex-plugin/plugin.json` exists and is valid JSON
- `.agents/plugins/marketplace.json` exists and is valid JSON
- marketplace auth policy is `ON_INSTALL` or `ON_USE`
- Codex conversion output is generated (`scripts/convert-codex.ts`)
- Codex installation tests pass in `scripts/test-installation.sh`

## 2) Marketplace metadata

Validate local marketplace add flow from repository root:

```bash
codex plugin marketplace add .
```

Expected behavior today:
- marketplace registers successfully
- Lavra invocation in Codex uses skills (`$lavra-*`)
- `/lavra-*` is not currently a native Codex command path

## 3) Package contents sanity

Confirm npm package includes required Codex files:
- `plugins/lavra/.codex-plugin/plugin.json`
- `plugins/lavra/hooks/check-memory.sh`
- `plugins/lavra/hooks/dispatch-hook.sh`
- `plugins/lavra/hooks/memory-capture.sh`
- `plugins/lavra/hooks/auto-recall.sh`
- `scripts/convert-codex.ts`

Installer preflight should fail fast if these are missing.

## 4) Release notes

Include Codex notes in release summary:
- install channels supported (`--codex`, install.sh, plugin marketplace metadata path)
- current invocation model (`$lavra-*`)
- known limitation (`/lavra-*` parity pending Codex command support)

## 5) Rollout and rollback

Rollout:
1. Publish release with Codex support notes.
2. Validate on a clean machine with:
   - `npx @lavralabs/lavra@latest --codex`
   - `bash install.sh --codex /tmp/test-project`
   - `codex plugin marketplace add .` (from repo root)
3. Confirm memory hooks fire and `scripts/test-installation.sh` remains green.

Rollback:
1. If Codex install regression is found, unpublish/deprecate the affected npm tag.
2. Revert the broken installer/conversion commits.
3. Ship patch release and rerun the full preflight + installation test suite before re-publish.

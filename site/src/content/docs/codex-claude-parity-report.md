---
title: Codex vs Claude Parity Report
description: Feature parity status between Claude Code and Codex for Lavra
order: 30
---

# Codex vs Claude Parity Report

Last verified: **April 30, 2026**

## Installation Parity

| Area | Claude Code | Codex | Status |
|---|---|---|---|
| npx/bunx install | `--claude` | `--codex` | Parity |
| install.sh manual install | Yes | Yes | Parity |
| global install | `~/.claude` | `~/.codex` | Parity |
| project install | `.claude/*` | `.codex/*` | Parity |
| marketplace metadata path | native Claude marketplace model | `codex plugin marketplace add .` | Partial parity |

## Command/Invocation Parity

| Area | Claude Code | Codex | Status |
|---|---|---|---|
| Slash commands (`/lavra-*`) | Supported | Not currently exposed | Gap |
| Skills invocation | Optional | Primary (`$lavra-*`) | Functional parity with UX difference |
| Core workflows (plan/work/review/etc.) | Yes | Yes (via skills) | Parity |

## Hooks + Memory Parity

| Area | Claude Code | Codex | Status |
|---|---|---|---|
| Session start memory behavior | Yes | Matched | Parity |
| Post-tool capture | Yes | Yes (`PostToolUse` + `Bash`) | Parity |
| Hook payload fields used by Lavra | Yes | Validated in live probes | Parity |
| Async hooks | Available in Claude-style setups | Not supported currently | Codex runtime constraint |

## Runtime Functionality Parity

| Area | Claude Code | Codex | Status |
|---|---|---|---|
| Skill chaining (skill references other skills) | Yes | Works via skill invocation model | Near parity |
| Subagent dispatch from workflows | Yes | Works (Task/subagent patterns used) | Near parity |
| AskUserQuestion-style prompts | Native primitive | Adapted for Codex (direct question fallback) | Near parity |

## Known Codex Caveats

- `/lavra-*` slash commands are not currently available in Codex; use `$lavra-*`.
- A small number of optional/secondary skill texts still contain Claude-centric examples (`.claude/*` paths, `CLAUDE_PLUGIN_ROOT`, `/workflows:*` references). These are mostly instructional strings and do not block core Lavra plan/work/review operation.
- `request_user_input` may be unavailable in some Codex modes; Lavra Codex skills use direct-chat fallback guidance.

## Validation Summary

- `./scripts/pre-release-check.sh` passes with Codex artifact/schema checks.
- `./scripts/test-installation.sh` passes with Codex install + marketplace smoke test.
- Current baseline: **52 passed, 0 failed**.

## Practical Guidance

- For Claude Code users: keep using `/lavra-*`.
- For Codex users: use `$lavra-*` for the same workflows.
- Treat Codex as functionally ready for core Lavra workflows, with command-surface UX differences from Claude Code.


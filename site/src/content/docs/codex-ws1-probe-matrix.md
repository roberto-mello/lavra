# Codex WS1 Probe Matrix

Date: 2026-04-30  
Scope: `lavra-7zm.1`

## Goal

Validate assumptions needed to port Lavra memory + command workflows to Codex while keeping existing platform support unchanged.

## Results (Current)

### 1) Hook payload fields used by Lavra parser

Status: `PARTIAL (code-verified, runtime sample pending)`

- Lavra capture script reads:
  - `.tool_name`
  - `.tool_input.command`
  - `.cwd`
- Script path: `plugins/lavra/hooks/memory-capture.sh`
- Risk: if Codex payload keys differ, capture becomes no-op.

### 2) PostToolUse shell-only filtering parity

Status: `PASS (design), runtime matcher check pending`

- Cortex installer writes `PostToolUse` matcher as `bash`.
- Capture script additionally exits unless tool name is `Bash` or `bash`.
- Capture writes only for `bd comments add ...` with known knowledge prefixes.
- Result: high-noise event, low-write behavior matches Claude strategy.

### 3) Command exposure model across install channels

Status: `PARTIAL`

- Existing Cortex path:
  - global install writes commands/agents/skills
  - project install is hooks-focused
- Need Codex marketplace/plugin flow validation for command exposure and namespace behavior.

### 4) Plugin install surfaces (repo/user/marketplace)

Status: `PARTIAL`

- Existing repo has mature install flows for Claude/OpenCode/Gemini/Cortex.
- Codex marketplace-local/user catalog semantics need runtime proof for final installer design.

## Live Probes Required

- LP1: capture real Codex `PostToolUse` payload sample.
- LP2: verify matcher behavior (`bash` vs `Bash`, etc.).
- LP3: verify command exposure and namespacing for plugin install.
- LP4: verify plugin install surfaces for repo/user/marketplace paths.

## Probe Helper Added

Script: `scripts/probe-codex-hook-payload.sh`

Purpose:
- store raw hook payload JSON
- print candidate field mapping for fast parser adaptation

Run (in Codex hook pipeline):

```bash
cat payload.json | scripts/probe-codex-hook-payload.sh
```

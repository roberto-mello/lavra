---
title: Configuration
description: All lavra.json options for tuning workflow, execution, and model behavior
order: 3
---

# Configuration

Lavra's behavior is controlled by `.lavra/config/lavra.json`, created when you run `/lavra-setup`. You can edit it directly at any time — changes take effect on the next command invocation.

```jsonc
{
  "workflow": {
    "research": true,
    "plan_review": true,
    "goal_verification": true,
    "review_scope": "full",
    "testing_scope": "targeted"
  },
  "execution": {
    "max_parallel_agents": 3,
    "commit_granularity": "task"
  },
  "model_profile": "balanced"
}
```

All fields are optional. If a field is missing, Lavra uses the default shown above.

---

## Workflow

### `research`

**Default:** `true`

Controls whether `/lavra-design` dispatches research agents during the planning phase. When enabled, domain-matched agents run in parallel to gather framework docs, security practices, and codebase patterns before the plan is written. Disabling it speeds up planning but produces less-informed plans.

### `plan_review`

**Default:** `true`

Controls whether `/lavra-design` runs the adversarial review phase (CEO, engineering, security, simplicity agents). When enabled, the plan is challenged before being locked as an epic. Disabling it skips that phase entirely.

### `goal_verification`

**Default:** `true`

Controls whether `/lavra-work` and `/lavra-ship` dispatch the `goal-verifier` agent after each bead is implemented. The verifier checks at three levels: the code exists, it's not a stub, and it's connected to the rest of the system. When disabled, beads close without this check.

### `review_scope`

**Default:** `"full"`

Controls when `/lavra-review` runs during `/lavra-work`.

- **`"full"`:** `/lavra-review` runs on every bead and every wave. Nothing ships without multi-agent review.
- **`"targeted"`:** `/lavra-review` runs only when a bead is P0/P1 priority, or its title or description contains architecture or security terms. Everything else gets a self-review only.

`"full"` is the right default for most projects. Use `"targeted"` when review overhead is meaningfully slowing down low-risk work — config changes, copy edits, minor UI tweaks — and you're comfortable with self-review as the gate for those.

### `testing_scope`

**Default:** `"targeted"`

Controls how broadly `/lavra-design` and `/lavra-work` generate test requirements.

- **`"targeted"`:** Tests for risky paths only: hooks, API routes, external service calls, complex business logic. Skips component render tests, static pages, and layout-only changes.
- **`"full"`:** Test cases for everything — unit, integration, edge cases, and structural tests.

`"targeted"` is the default because full coverage requirements significantly increase planning and implementation time. Switch to `"full"` if your project requires comprehensive test coverage by policy.

---

## Execution

### `max_parallel_agents`

**Default:** `3`

Maximum number of subagents running simultaneously in `/lavra-work` multi-bead mode. Higher values can speed up large epics but increase token costs and the chance of merge conflicts between agents working on related files.

### `commit_granularity`

**Default:** `"task"`

Controls how `/lavra-work` creates commits.

- **`"task"`:** One atomic commit per task completed. Makes `git log --grep="BD-001"` useful and allows per-task revert.
- **`"wave"`:** One commit per wave of beads. Fewer commits, coarser history.

---

## Model profile

### `model_profile`

**Default:** `"balanced"`

Controls which model tier is used for review and verification agents.

- **`"balanced"`:** Review and verification agents use the standard model tier (Sonnet). Faster and cheaper.
- **`"quality"`:** Review and verification agents use Opus. More thorough findings, higher cost. Useful for security-sensitive work or when you're releasing something important.

This setting only affects review and verification agents. Implementation agents always use their configured tier regardless of `model_profile`.

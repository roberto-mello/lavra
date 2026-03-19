---
title: Cost Optimization
description: How Lavra assigns agents to model tiers for optimal cost and performance
order: 9
---

# Cost Optimization

How Lavra assigns its 30 agents to model tiers for optimal cost/performance balance.

## Tier Breakdown

| Tier | Count | Agents |
|------|-------|--------|
| **haiku** | 5 | `ankane-readme-writer`, `framework-docs-researcher`, `learnings-researcher`, `repo-research-analyst`, `lint` |
| **sonnet** | 18 | Most reviewers and workflow agents |
| **inherit** | 7 | `agent-native-reviewer`, `architecture-strategist`, `data-integrity-guardian`, `data-migration-expert`, `julik-frontend-races-reviewer`, `performance-oracle`, `spec-flow-analyzer` |

`inherit` means the agent runs at whatever model the calling command uses — typically sonnet.

## Design Rationale

- **Haiku** for structured, template-based tasks: README generation, knowledge search, linting — fast and cheap
- **Sonnet** for the bulk of review and research work — good judgment on well-defined tasks
- **Inherit** for agents whose quality scales with the calling context — if you invoke them on opus, they get opus too

## Cost at Scale

`/lavra-review` dispatches up to 13 agents in parallel. With the default sonnet tier, a full review run costs roughly the same as 2–3 manual code review messages. The haiku agents (linting, knowledge search) add negligible cost.

## Configuring Model Quality

Set `model_profile` in `.lavra/config/lavra.json` to `"quality"` to route critical agents (`security-sentinel`, `architecture-strategist`, `goal-verifier`, `performance-oracle`) to opus automatically. All other agents stay at their default tier. This affects `/lavra-review`, `/lavra-eng-review`, `/lavra-work`, and `/lavra-ship`.

```json
{ "model_profile": "quality" }
```

The default `"balanced"` keeps all agents at their configured tier.

---
title: Cost Optimization
description: How lavra assigns agents to model tiers for optimal cost and performance
order: 9
---

# Cost Optimization

How lavra assigns agents to model tiers for optimal cost/performance balance.

[Back to README](../README.md)

## Tier Breakdown

The plugin's 28 agents are assigned to three model tiers based on reasoning complexity:

| Tier | Agents | Use Case | Cost Impact |
|------|--------|----------|-------------|
| **Haiku** | 5 | Structured information retrieval, template-based output | Lowest cost, fastest response |
| **Sonnet** | 14 | Moderate judgment with established patterns | Balanced cost/quality |
| **Opus** | 9 | Deep architectural reasoning, nuanced security analysis | Premium quality for critical decisions |

## Key Optimizations

- Most frequently invoked agents (`learnings-researcher`, `repo-research-analyst`) use Haiku
- Review workflows like `/lavra-review` fire 13+ agents, mostly Sonnet tier
- Opus reserved for architectural/security decisions requiring deep reasoning
- Commands automatically dispatch agents at their assigned tier via frontmatter `model:` field

This tiering reduces costs by 60-70% compared to running all agents on Opus while maintaining quality where it matters.

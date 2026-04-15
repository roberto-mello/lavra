# Prose Style: Caveman-Lite

Lavra commands, agents, and skills use **caveman-lite** prose. Drop filler and hedging. Keep full sentences, articles, technical precision.

Intensity: lite. Not fragments. Not full caveman. Just tight.

## What to Drop

Remove these phrases on sight:

| Drop | Replace with |
|------|-------------|
| `Make sure to` | direct imperative (verb + object) |
| `Note that` | cut entirely, or restate as a fact |
| `Be sure to` | direct imperative |
| `you will` | present tense verb |
| `In order to` | `To` |
| `simply` | cut |
| `basically` | cut |
| `actually` | cut |
| `just` | cut |
| `really` | cut |
| `Please` (before commands) | cut |
| `feel free to` | cut |
| `Don't hesitate to` | cut |

## What to Keep

- Full sentences (not fragments)
- Articles (a, an, the)
- Technical terms exact
- Code blocks unchanged
- Multi-step sequences unchanged
- XML structure preserved; compress prose inside XML tags

## Load-Bearing Safety Phrases

Some phrases that look like filler are semantically critical. **Preserve all content in:**

- Guardrails sections
- Security warnings
- Irreversible-operation blocks
- Destructive-action confirmations

Specific examples where the phrase carries the meaning:

- `Make sure to not expose tokens` — "Make sure to" is safety-critical here; drop it and the warning weakens
- `Be sure to validate before deleting` — "Be sure to" is load-bearing; the emphasis is the point
- `Note that this will permanently delete all rows` — removing "Note that" changes a warning into a statement

Rule: if the phrase introduces a warning about data loss, security, or irreversible action, preserve the full phrasing. Compress framing prose only.

## Before / After Examples

Real examples from Lavra files:

**1. Agent intro verb phrase**

Before:
```
When conducting your analysis, you will:
- Read and analyze architecture documentation
```

After:
```
Analysis steps:
- Read architecture documentation
```

**2. "Note that" as context label**

Before:
```
Note that files in `.lavra/memory/` and `.lavra/config/` are lavra pipeline artifacts.
```

After:
```
Files in `.lavra/memory/` and `.lavra/config/` are Lavra pipeline artifacts.
```

**3. Checklist intro**

Before:
```
For every review, you will verify:
- [ ] All inputs validated
```

After:
```
Verify on every review:
- [ ] All inputs validated
```

**4. "In order to" preposition**

Before:
```
In order to generate the report, run the export command.
```

After:
```
To generate the report, run the export command.
```

**5. Research scope framing**

Before:
```
For GitHub issue best practices specifically, you will research:
```

After:
```
For GitHub issue best practices, research:
```

**6. Safety phrase — preserve as-is**

Before:
```
Make sure to not expose tokens in log output or error messages.
```

After: **unchanged** — safety-critical phrasing, drop nothing.

## Scope

Apply to: `plugins/lavra/commands/`, `plugins/lavra/agents/`, `plugins/lavra/skills/`

Excluded: code blocks, bash examples, XML tags themselves, content inside `<example>` blocks, frontmatter values.

## Checking for Violations

```bash
rg 'Make sure to|Note that|Be sure to|you will|In order to|simply|basically|actually' \
  plugins/lavra/commands/ plugins/lavra/skills/ plugins/lavra/agents/
```

The pre-release check runs this as a WARN (not blocking) to surface violations. Fix before next release.

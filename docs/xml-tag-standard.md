# XML Tag Standard for lavra

Canonical vocabulary for structuring commands and agents. XML tags improve model instruction-following across platforms (Claude, OpenCode, Gemini) by providing explicit semantic boundaries.

## Rules

1. **YAML frontmatter stays in YAML** — name, description, argument-hint, model unchanged
2. **Markdown allowed inside XML tags** — hybrid approach (headers, lists, code blocks all valid)
3. **Existing input-capture tags preserved** — `<raw_argument>`, `<bead_input>`, `<input_document>`, `<feature_description>`, `<epic_bead_id>` stay as-is
4. **`<thinking>` and `<examples>` tags stay** where they already exist
5. **Tags are semantic wrappers** — they wrap existing content, not replace it
6. **No nesting of standard tags** — `<process>` cannot contain `<guardrails>`
7. **Order matters** — tags should appear in the order listed below

## Command Tags

| Tag | Purpose | Required |
|-----|---------|----------|
| `<objective>` | What this command accomplishes (1-3 sentences) | Yes |
| `<execution_context>` | Runtime variables, file references, bead IDs | Conditional (when command takes input) |
| `<context>` | Background info the model needs (constraints, prior art, year) | No |
| `<process>` | Numbered steps — the core logic | Yes |
| `<success_criteria>` | How to know it worked (checkable conditions) | Yes |
| `<guardrails>` | What NOT to do, scope boundaries | No |
| `<handoff>` | Next-step options for user after completion | No |

### Command conversion pattern

**Before:**
```markdown
---
name: example-command
description: Does something useful
---

# Title

Some intro text explaining what this does.

## Input
<raw_argument> #$ARGUMENTS </raw_argument>

## Phase 1: Do the thing
1. Step one
2. Step two

## Phase 2: Verify
1. Check this
2. Check that

## What NOT to do
- Don't do X
- Don't do Y
```

**After:**
```markdown
---
name: example-command
description: Does something useful
---

<objective>
Does something useful by running two phases of work.
</objective>

<execution_context>
<raw_argument> #$ARGUMENTS </raw_argument>
</execution_context>

<process>

## Phase 1: Do the thing
1. Step one
2. Step two

## Phase 2: Verify
1. Check this
2. Check that

</process>

<guardrails>
- Don't do X
- Don't do Y
</guardrails>
```

### Notes for commands

- The `#` title line and `## Introduction` section fold into `<objective>`
- All phase/step content goes inside a single `<process>` tag
- `<execution_context>` wraps the input-capture tags plus any bead-ID resolution logic
- `<success_criteria>` should be a checklist (use `- [ ]` or bullet points)

## Agent Tags

| Tag | Purpose | Required |
|-----|---------|----------|
| `<role>` | Identity and expertise (1-2 sentences) | Yes |
| `<philosophy>` | Principles guiding decisions | No |
| `<process>` | How to conduct analysis/work (numbered steps) | Yes |
| `<output_format>` | Expected result structure | No |
| `<success_criteria>` | What constitutes thorough work | Yes |
| `<examples>` | Keep existing examples tags | No (keep if present) |

### Agent conversion pattern

**Before:**
```markdown
---
name: example-reviewer
description: Reviews code for X
model: sonnet
---
<examples>...</examples>

You are an expert in X. Your mission is to Y.

When reviewing code, you will:
1. Do A
2. Do B
3. Do C

Your review process:
1. Step one
2. Step two

Output format:
## Review: filename
...
```

**After:**
```markdown
---
name: example-reviewer
description: Reviews code for X
model: sonnet
---
<examples>...</examples>

<role>
You are an expert in X. Your mission is to Y.
</role>

<process>

When reviewing code, you will:
1. Do A
2. Do B
3. Do C

Your review process:
1. Step one
2. Step two

</process>

<output_format>
## Review: filename
...
</output_format>

<success_criteria>
- Every file reviewed has actionable feedback or explicit approval
- No false positives — only flag real issues
</success_criteria>
```

### Notes for agents

- `<examples>` stays first (after frontmatter) — unchanged
- The identity paragraph ("You are...") goes in `<role>`
- "When to call" lists can go in `<role>` or stay outside tags (they're for the dispatcher, not the agent)
- All analysis/review steps go in `<process>`
- If the agent has a specific output template, wrap it in `<output_format>`
- `<philosophy>` is for agents with explicit guiding principles (e.g., DHH reviewer, code-simplicity-reviewer)

## Tag Reference (combined)

All tags used across commands and agents:

| Tag | Used in | Purpose |
|-----|---------|---------|
| `<objective>` | Commands | What this command accomplishes |
| `<execution_context>` | Commands | Runtime input and variable resolution |
| `<context>` | Commands | Background knowledge needed |
| `<process>` | Both | Core logic / analysis steps |
| `<success_criteria>` | Both | Definition of done |
| `<guardrails>` | Commands | Scope boundaries and prohibitions |
| `<handoff>` | Commands | Next-step suggestions |
| `<role>` | Agents | Identity and expertise |
| `<philosophy>` | Agents | Guiding principles |
| `<output_format>` | Agents | Expected output structure |
| `<examples>` | Agents | Example interactions (existing) |
| `<raw_argument>` | Commands | Raw user input capture (existing) |
| `<bead_input>` | Commands | Bead ID input capture (existing) |
| `<input_document>` | Commands | Document input capture (existing) |
| `<feature_description>` | Commands | Feature text capture (existing) |
| `<epic_bead_id>` | Commands | Epic bead reference (existing) |
| `<thinking>` | Both | Reasoning blocks (existing) |

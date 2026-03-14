# Workflow: Get Guidance on Skill Design

<required_reading>
**Read these reference files NOW:**
1. references/core-principles.md
2. references/recommended-structure.md
</required_reading>

<process>
## Step 1: Understand the Problem Space

Ask the user:
- What task or domain are you trying to support?
- Is this something you do repeatedly?
- What makes it complex enough to need a skill?

## Step 2: Determine If a Skill Is Right

**Create a skill when:**
- Task is repeated across multiple sessions
- Domain knowledge doesn't change frequently
- Complex enough to benefit from structure

**Don't create a skill when:**
- One-off task
- Changes constantly
- Too simple
- Better as a slash command

## Step 3: Map the Workflows

Ask: "What are the different things someone might want to do with this skill?"

## Step 4: Identify Domain Knowledge

Ask: "What knowledge is needed regardless of which workflow?"

## Step 5: Draft the Structure

Based on answers, recommend simple or router pattern.

## Step 6: Identify Essential Principles

Ask: "What rules should ALWAYS apply, no matter which workflow?"

## Step 7: Present Recommendation

If yes -> offer to switch to "Create a new skill" workflow.
If no -> clarify and iterate.
</process>

<decision_framework>
## Quick Decision Framework

| Situation | Recommendation |
|-----------|----------------|
| Single task, repeat often | Simple skill |
| Multiple related tasks | Router + workflows |
| Complex domain, many patterns | Router + workflows + references |
| User-triggered, fresh context | Slash command, not skill |
| One-off task | No skill needed |
</decision_framework>

<success_criteria>
Guidance is complete when:
- [ ] User understands if they need a skill
- [ ] Structure is recommended and explained
- [ ] Workflows are identified
- [ ] User is ready to build (or decided not to)
</success_criteria>

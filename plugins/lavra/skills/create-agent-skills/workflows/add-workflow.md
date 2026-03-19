# Workflow: Add a Workflow to Existing Skill

<required_reading>
**Read these reference files NOW:**
1. references/recommended-structure.md
2. references/workflows-and-validation.md
</required_reading>

<process>
## Step 1: Select the Skill

```bash
ls ~/.claude/skills/
```

Present numbered list, ask: "Which skill needs a new workflow?"

## Step 2: Analyze Current Structure

Determine if it's a simple skill or already has workflows/.

## Step 3: Gather Workflow Requirements

Ask what the workflow should do and when it would be used.

## Step 4: Upgrade to Router Pattern (if needed)

If skill is currently simple, ask if it should be restructured first.

## Step 5: Create the Workflow File

Create `workflows/{workflow-name}.md` with required_reading, process, and success_criteria.

## Step 6: Update SKILL.md

Add the new workflow to intake question, routing table, and workflows index.

## Step 7: Create References (if needed)

If the workflow needs domain knowledge that doesn't exist yet.

## Step 8: Test

Invoke the skill and verify the new workflow routes and executes correctly.
</process>

<success_criteria>
Workflow addition is complete when:
- [ ] Skill upgraded to router pattern (if needed)
- [ ] Workflow file created with required_reading, process, success_criteria
- [ ] SKILL.md intake updated with new option
- [ ] SKILL.md routing updated
- [ ] Tested and working
</success_criteria>

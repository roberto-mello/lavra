# Workflow: Upgrade Skill to Router Pattern

<required_reading>
**Read these reference files NOW:**
1. references/recommended-structure.md
2. references/skill-structure.md
</required_reading>

<process>
## Step 1: Select the Skill

Present numbered list, ask: "Which skill should be upgraded to the router pattern?"

## Step 2: Verify It Needs Upgrading

Good candidate for upgrade:
- Over 200 lines
- Multiple distinct use cases
- Essential principles that shouldn't be skipped
- Growing complexity

## Step 3: Identify Components

Analyze the current skill and identify:
1. **Essential principles** - Rules that apply to ALL use cases
2. **Distinct workflows** - Different things a user might want to do
3. **Reusable knowledge** - Patterns, examples, technical details

## Step 4: Create Directory Structure

```bash
mkdir -p ~/.claude/skills/{skill-name}/workflows
mkdir -p ~/.claude/skills/{skill-name}/references
```

## Step 5: Extract Workflows

For each identified workflow, create a workflow file with required_reading, process, and success_criteria.

## Step 6: Extract References

For each identified reference topic, create a reference file.

## Step 7: Rewrite SKILL.md as Router

Replace with router structure including essential_principles, intake, routing, reference_index, workflows_index.

## Step 8: Verify Nothing Was Lost

- [ ] All principles preserved (now inline)
- [ ] All procedures preserved (now in workflows)
- [ ] All knowledge preserved (now in references)
- [ ] No orphaned content

## Step 9: Test

Invoke the upgraded skill and verify routing works correctly.
</process>

<success_criteria>
Upgrade is complete when:
- [ ] workflows/ directory created with workflow files
- [ ] references/ directory created (if needed)
- [ ] SKILL.md rewritten as router
- [ ] Essential principles inline in SKILL.md
- [ ] All original content preserved
- [ ] Tested and working
</success_criteria>

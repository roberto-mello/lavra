# Workflow: Audit a Skill

<required_reading>
**Read these reference files NOW:**
1. references/recommended-structure.md
2. references/skill-structure.md
</required_reading>

<process>
## Step 1: List Available Skills

Enumerate skills in chat as numbered list:
```bash
ls ~/.claude/skills/
```

Ask: "Which skill would you like to audit? (enter number or name)"

## Step 2: Read the Skill

After user selects, read the full skill structure.

## Step 3: Run Audit Checklist

### YAML Frontmatter
- [ ] Has `name:` field (lowercase-with-hyphens)
- [ ] Name matches directory name
- [ ] Has `description:` field
- [ ] Description says what it does AND when to use it
- [ ] Description is third person

### Structure
- [ ] SKILL.md under 500 lines
- [ ] All XML tags properly closed
- [ ] Has required tags
- [ ] Has success_criteria

### Content Quality
- [ ] Principles are actionable (not vague platitudes)
- [ ] Steps are specific (not "do the thing")
- [ ] Success criteria are verifiable
- [ ] No redundant content across files

## Step 4: Generate Report

Present findings with passing items, issues found, and score.

## Step 5: Offer Fixes

If issues found, ask:
"Would you like me to fix these issues?"
1. **Fix all** - Apply all recommended fixes
2. **Fix one by one** - Review each fix before applying
3. **Just the report** - No changes needed
</process>

<success_criteria>
Audit is complete when:
- [ ] Skill fully read and analyzed
- [ ] All checklist items evaluated
- [ ] Report presented to user
- [ ] Fixes applied (if requested)
</success_criteria>

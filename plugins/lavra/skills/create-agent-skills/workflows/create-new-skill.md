# Workflow: Create a New Skill

<required_reading>
**Read these reference files NOW:**
1. references/recommended-structure.md
2. references/skill-structure.md
3. references/core-principles.md
</required_reading>

<process>
## Step 1: Adaptive Requirements Gathering

**If user provided context** (e.g., "build a skill for X"):
-> Analyze what's stated, what can be inferred, what's unclear
-> Skip to asking about genuine gaps only

**If user just invoked skill without context:**
-> Ask what they want to build

## Step 2: Research Trigger (If External API)

**When external service detected**, ask:
"This involves [service name] API. Would you like me to research current endpoints and patterns before building?"

## Step 3: Decide Structure

**Simple skill (single workflow, <200 lines):**
-> Single SKILL.md file with all content

**Complex skill (multiple workflows OR domain knowledge):**
-> Router pattern:
```
skill-name/
├── SKILL.md (router + principles)
├── workflows/ (procedures - FOLLOW)
├── references/ (knowledge - READ)
├── templates/ (output structures - COPY + FILL)
└── scripts/ (reusable code - EXECUTE)
```

## Step 4: Create Directory

```bash
mkdir -p ~/.claude/skills/{skill-name}
# If complex:
mkdir -p ~/.claude/skills/{skill-name}/workflows
mkdir -p ~/.claude/skills/{skill-name}/references
```

## Step 5: Write SKILL.md

**Simple skill:** Write complete skill file with YAML frontmatter, objective, quick_start, content sections, success_criteria.

**Complex skill:** Write router with frontmatter, essential_principles, intake, routing, reference_index, workflows_index.

## Step 6: Write Workflows (if complex)

For each workflow, include required_reading, process, and success_criteria sections.

## Step 7: Write References (if needed)

Domain knowledge that multiple workflows might need.

## Step 8: Validate Structure

Check:
- [ ] YAML frontmatter valid
- [ ] Name matches directory (lowercase-with-hyphens)
- [ ] Description says what it does AND when to use it (third person)
- [ ] Required tags present
- [ ] All referenced files exist
- [ ] SKILL.md under 500 lines

## Step 9: Test

Invoke the skill and observe:
- Does it ask the right intake question?
- Does it load the right workflow?
- Does output match expectations?

Iterate based on real usage, not assumptions.
</process>

<success_criteria>
Skill is complete when:
- [ ] Requirements gathered with appropriate questions
- [ ] Directory structure correct
- [ ] SKILL.md has valid frontmatter
- [ ] All workflows have required_reading + process + success_criteria
- [ ] References contain reusable domain knowledge
- [ ] Tested with real invocation
</success_criteria>

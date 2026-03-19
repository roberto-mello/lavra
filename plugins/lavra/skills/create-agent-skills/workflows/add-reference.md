# Workflow: Add a Reference to Existing Skill

<required_reading>
**Read these reference files NOW:**
1. references/recommended-structure.md
2. references/skill-structure.md
</required_reading>

<process>
## Step 1: Select the Skill

```bash
ls ~/.claude/skills/
```

Present numbered list, ask: "Which skill needs a new reference?"

## Step 2: Analyze Current Structure

Determine if references/ folder exists and what references are already present.

## Step 3: Gather Reference Requirements

Ask:
- What knowledge should this reference contain?
- Which workflows will use it?
- Is this reusable across workflows or specific to one?

## Step 4: Create the Reference File

Create `references/{reference-name}.md` with structured content.

## Step 5: Update SKILL.md

Add the new reference to the reference index.

## Step 6: Update Workflows That Need It

Add to relevant workflows' required_reading sections.

## Step 7: Verify

- [ ] Reference file exists and is well-structured
- [ ] Reference is in SKILL.md reference_index
- [ ] Relevant workflows have it in required_reading
- [ ] No broken references
</process>

<success_criteria>
Reference addition is complete when:
- [ ] Reference file created with useful content
- [ ] Added to reference_index in SKILL.md
- [ ] Relevant workflows updated to read it
- [ ] Content is reusable (not workflow-specific)
</success_criteria>

# Workflow: Add a Template to a Skill

<required_reading>
**Read these reference files NOW:**
1. references/using-templates.md
</required_reading>

<process>
## Step 1: Identify the Skill

Ask (if not already provided):
- Which skill needs a template?
- What output does this template structure?

## Step 2: Analyze Template Need

Confirm this is a good template candidate:
- [ ] Output has consistent structure across uses
- [ ] Structure matters more than creative generation
- [ ] Filling placeholders is more reliable than blank-page generation

## Step 3: Create Templates Directory

```bash
mkdir -p ~/.claude/skills/{skill-name}/templates
```

## Step 4: Design Template Structure

Gather requirements for sections, placeholders, and static content.

## Step 5: Write Template File

Create `templates/{template-name}.md` with clear section markers, `{{PLACEHOLDER}}` syntax, and brief inline guidance.

## Step 6: Update Workflow to Use Template

Add template read and fill instructions to the relevant workflow.

## Step 7: Test

Verify template is used correctly and all placeholders get filled.
</process>

<success_criteria>
Template is complete when:
- [ ] templates/ directory exists
- [ ] Template file has clear structure with placeholders
- [ ] At least one workflow references the template
- [ ] Tested with real invocation
</success_criteria>

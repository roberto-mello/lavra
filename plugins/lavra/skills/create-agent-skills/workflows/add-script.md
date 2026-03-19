# Workflow: Add a Script to a Skill

<required_reading>
**Read these reference files NOW:**
1. references/using-scripts.md
</required_reading>

<process>
## Step 1: Identify the Skill

Ask (if not already provided):
- Which skill needs a script?
- What operation should the script perform?

## Step 2: Analyze Script Need

Confirm this is a good script candidate:
- [ ] Same code runs across multiple invocations
- [ ] Operation is error-prone when rewritten
- [ ] Consistency matters more than flexibility

## Step 3: Create Scripts Directory

```bash
mkdir -p ~/.claude/skills/{skill-name}/scripts
```

## Step 4: Design Script

Gather requirements for inputs, outputs, errors, and idempotency.

## Step 5: Write Script File

Create `scripts/{script-name}.{ext}` with purpose comment, usage instructions, input validation, error handling, and clear output.

## Step 6: Make Executable (if bash)

```bash
chmod +x ~/.claude/skills/{skill-name}/scripts/{script-name}.sh
```

## Step 7: Update Workflow to Use Script

Add the script invocation to the relevant workflow.

## Step 8: Test

Verify the script runs correctly within the workflow.
</process>

<success_criteria>
Script is complete when:
- [ ] scripts/ directory exists
- [ ] Script file has proper structure
- [ ] Script is executable (if bash)
- [ ] At least one workflow references the script
- [ ] No hardcoded secrets or credentials
- [ ] Tested with real invocation
</success_criteria>

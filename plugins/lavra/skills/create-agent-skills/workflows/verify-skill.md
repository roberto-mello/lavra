# Workflow: Verify Skill Content Accuracy

<required_reading>
**Read these reference files NOW:**
1. references/skill-structure.md
</required_reading>

<purpose>
Audit checks structure. **Verify checks truth.**

Skills contain claims about external things: APIs, CLI tools, frameworks, services. These change over time. This workflow checks if a skill's content is still accurate.
</purpose>

<process>
## Step 1: Select the Skill

Present numbered list, ask: "Which skill should I verify for accuracy?"

## Step 2: Read and Categorize

Categorize by primary dependency type:

| Type | Verification Method |
|------|---------------------|
| **API/Service** | WebSearch |
| **CLI Tools** | Run commands |
| **Framework** | Check docs |
| **Pure Process** | No external deps |

## Step 3: Extract Verifiable Claims

Scan skill content and extract CLI tools, API endpoints, framework patterns, file paths.

## Step 4: Verify by Type

Verify each claim using appropriate method for its type.

## Step 5: Generate Freshness Report

Present findings with verified, outdated, broken, and unverifiable items.

## Step 6: Offer Updates

If issues found, offer to update all, review each, or just keep the report.

## Step 7: Suggest Verification Schedule

| Skill Type | Recommended Frequency |
|------------|----------------------|
| API/Service | Every 1-2 months |
| Framework | Every 3-6 months |
| CLI Tools | Every 6 months |
| Pure Process | Annually |
</process>

<success_criteria>
Verification is complete when:
- [ ] Skill categorized by dependency type
- [ ] Verifiable claims extracted
- [ ] Each claim checked with appropriate method
- [ ] Freshness report generated
- [ ] Updates applied (if requested)
</success_criteria>

<overview>
This reference documents common patterns for skill authoring, including templates, examples, terminology consistency, and anti-patterns. All patterns use pure XML structure.
</overview>

<template_pattern>
<description>
Provide templates for output format. Match the level of strictness to your needs.
</description>

<strict_requirements>
Use when output format must be exact and consistent:

```xml
<report_structure>
ALWAYS use this exact template structure:

```markdown
# [Analysis Title]

## Executive summary
[One-paragraph overview of key findings]

## Key findings
- Finding 1 with supporting data
- Finding 2 with supporting data
- Finding 3 with supporting data

## Recommendations
1. Specific actionable recommendation
2. Specific actionable recommendation
```
</report_structure>
```

**When to use**: Compliance reports, standardized formats, automated processing
</strict_requirements>

<flexible_guidance>
Use when Claude should adapt the format based on context:

```xml
<report_structure>
Here is a sensible default format, but use your best judgment:

```markdown
# [Analysis Title]

## Executive summary
[Overview]

## Key findings
[Adapt sections based on what you discover]

## Recommendations
[Tailor to the specific context]
```

Adjust sections as needed for the specific analysis type.
</report_structure>
```

**When to use**: Exploratory analysis, context-dependent formatting, creative tasks
</flexible_guidance>
</template_pattern>

<examples_pattern>
<description>
For skills where output quality depends on seeing examples, provide input/output pairs.
</description>

<when_to_use>
- Output format has nuances that text explanations can't capture
- Pattern recognition is easier than rule following
- Examples demonstrate edge cases
- Multi-shot learning improves quality
</when_to_use>
</examples_pattern>

<consistent_terminology>
<principle>
Choose one term and use it throughout the skill. Inconsistent terminology confuses Claude and reduces execution quality.
</principle>

<implementation>
1. Choose terminology early in skill development
2. Document key terms in `<objective>` or `<context>`
3. Use find/replace to enforce consistency
4. Review reference files for consistent usage
</implementation>
</consistent_terminology>

<provide_default_with_escape_hatch>
<principle>
Provide a default approach with an escape hatch for special cases, not a list of alternatives. Too many options paralyze decision-making.
</principle>

<implementation>
1. Recommend ONE default approach
2. Explain when to use the default (implied: most of the time)
3. Add ONE escape hatch for edge cases
4. Link to advanced reference if multiple alternatives truly needed
</implementation>
</provide_default_with_escape_hatch>

<progressive_disclosure_pattern>
<description>
Keep SKILL.md concise by linking to detailed reference files. Claude loads reference files only when needed.
</description>
</progressive_disclosure_pattern>

<validation_pattern>
<description>
For skills with validation steps, make validation scripts verbose and specific.
</description>
</validation_pattern>

<checklist_pattern>
<description>
For complex multi-step workflows, provide a checklist Claude can copy and track progress.
</description>
</checklist_pattern>

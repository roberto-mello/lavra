<golden_rule>
Show your skill to someone with minimal context and ask them to follow the instructions. If they're confused, Claude will likely be too.
</golden_rule>

<overview>
Clarity and directness are fundamental to effective skill authoring. Clear instructions reduce errors, improve execution quality, and minimize token waste.
</overview>

<guidelines>
<contextual_information>
Give Claude contextual information that frames the task:

- What the task results will be used for
- What audience the output is meant for
- What workflow the task is part of
- The end goal or what successful completion looks like

Context helps Claude make better decisions and produce more appropriate outputs.
</contextual_information>

<specificity>
Be specific about what you want Claude to do. If you want code only and nothing else, say so.

**Vague**: "Help with the report"
**Specific**: "Generate a markdown report with three sections: Executive Summary, Key Findings, Recommendations"

Specificity eliminates ambiguity and reduces iteration cycles.
</specificity>

<sequential_steps>
Provide instructions as sequential steps. Use numbered lists or bullet points.

Sequential steps create clear expectations and reduce the chance Claude skips important operations.
</sequential_steps>
</guidelines>

<avoid_ambiguity>
<principle>
Eliminate words and phrases that create ambiguity or leave decisions open.
</principle>

<ambiguous_phrases>
"Try to..." - Implies optional. Use "Always..." or "Never..." instead.
"Should probably..." - Unclear obligation. Use "Must..." or "May optionally..." instead.
"Generally..." - When are exceptions allowed? Use "Always... except when..." instead.
"Consider..." - Should Claude always do this or only sometimes? Use "If X, then Y" or "Always..." instead.
</ambiguous_phrases>
</avoid_ambiguity>

<define_edge_cases>
<principle>
Anticipate edge cases and define how to handle them. Don't leave Claude guessing.
</principle>
</define_edge_cases>

<output_format_specification>
<principle>
When output format matters, specify it precisely. Show examples.
</principle>
</output_format_specification>

<decision_criteria>
<principle>
When Claude must make decisions, provide clear criteria.
</principle>
</decision_criteria>

<constraints_and_requirements>
<principle>
Clearly separate "must do" from "nice to have" from "must not do".
</principle>
</constraints_and_requirements>

<success_criteria>
<principle>
Define what success looks like. How will Claude know it succeeded?
</principle>
</success_criteria>

<testing_clarity>
<principle>
Test your instructions by asking: "Could I hand these instructions to a junior developer and expect correct results?"
</principle>
</testing_clarity>

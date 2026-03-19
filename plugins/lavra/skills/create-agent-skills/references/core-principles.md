<overview>
Core principles guide skill authoring decisions. These principles ensure skills are efficient, effective, and maintainable across different models and use cases.
</overview>

<conciseness_principle>
<description>
The context window is shared. Your skill shares it with the system prompt, conversation history, other skills' metadata, and the actual request.
</description>

<guidance>
Only add context Claude doesn't already have. Challenge each piece of information:
- "Does Claude really need this explanation?"
- "Can I assume Claude knows this?"
- "Does this paragraph justify its token cost?"

Assume Claude is smart. Don't explain obvious concepts.
</guidance>
</conciseness_principle>

<degrees_of_freedom_principle>
<description>
Match the level of specificity to the task's fragility and variability. Give Claude more freedom for creative tasks, less freedom for fragile operations.
</description>

<matching_specificity>
The key is matching specificity to fragility:

- **Fragile operations** (database migrations, payment processing, security): Low freedom, exact instructions
- **Standard operations** (API calls, file processing, data transformation): Medium freedom, preferred pattern with flexibility
- **Creative operations** (code review, content generation, analysis): High freedom, heuristics and principles

Mismatched specificity causes problems:
- Too much freedom on fragile tasks -> errors and failures
- Too little freedom on creative tasks -> rigid, suboptimal outputs
</matching_specificity>
</degrees_of_freedom_principle>

<model_testing_principle>
<description>
Skills act as additions to models, so effectiveness depends on the underlying model. What works for Opus might need more detail for Haiku.
</description>

<balancing_across_models>
Aim for instructions that work well across all target models. Find the balance that serves your target audience.

See [iteration-and-testing.md](iteration-and-testing.md) for model testing examples.
</balancing_across_models>
</model_testing_principle>

<progressive_disclosure_principle>
<description>
SKILL.md serves as an overview. Reference files contain details. Claude loads reference files only when needed.
</description>

<implementation>
- Keep SKILL.md under 500 lines
- Split detailed content into reference files
- Keep references one level deep from SKILL.md
- Link to references from relevant sections
- Use descriptive reference file names

See [skill-structure.md](skill-structure.md) for progressive disclosure patterns.
</implementation>
</progressive_disclosure_principle>

<validation_principle>
<description>
Validation scripts are force multipliers. They catch errors that Claude might miss and provide actionable feedback.
</description>

<characteristics>
Good validation scripts:
- Provide verbose, specific error messages
- Show available valid options when something is invalid
- Pinpoint exact location of problems
- Suggest actionable fixes
- Are deterministic and reliable

See [workflows-and-validation.md](workflows-and-validation.md) for validation patterns.
</characteristics>
</validation_principle>

<principle_summary>
<conciseness>
Only add context Claude doesn't have. Assume Claude is smart. Challenge every piece of content.
</conciseness>

<degrees_of_freedom>
Match specificity to fragility. High freedom for creative tasks, low freedom for fragile operations, medium for standard work.
</degrees_of_freedom>

<model_testing>
Test with all target models. Balance detail level to work across Haiku, Sonnet, and Opus.
</model_testing>

<progressive_disclosure>
Keep SKILL.md concise. Split details into reference files. Load reference files only when needed.
</progressive_disclosure>

<validation>
Make validation scripts verbose and specific. Catch errors early with actionable feedback.
</validation>
</principle_summary>

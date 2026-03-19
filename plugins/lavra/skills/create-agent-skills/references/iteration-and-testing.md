<overview>
Skills improve through iteration and testing. This reference covers evaluation-driven development, Claude A/B testing patterns, and XML structure validation during testing.
</overview>

<evaluation_driven_development>
<principle>
Create evaluations BEFORE writing extensive documentation. This ensures your skill solves real problems rather than documenting imagined ones.
</principle>

<workflow>
<step_1>
**Identify gaps**: Run Claude on representative tasks without a skill. Document specific failures or missing context.
</step_1>

<step_2>
**Create evaluations**: Build three scenarios that test these gaps.
</step_2>

<step_3>
**Establish baseline**: Measure Claude's performance without the skill.
</step_3>

<step_4>
**Write minimal instructions**: Create just enough content to address the gaps and pass evaluations.
</step_4>

<step_5>
**Iterate**: Execute evaluations, compare against baseline, and refine.
</step_5>
</workflow>
</evaluation_driven_development>

<iterative_development_with_claude>
<principle>
The most effective skill development uses Claude itself. Work with "Claude A" (expert who helps refine) to create skills used by "Claude B" (agent executing tasks).
</principle>

<creating_skills>
<workflow>
<step_1>
**Complete task without skill**: Work through problem with Claude A, noting what context you repeatedly provide.
</step_1>

<step_2>
**Ask Claude A to create skill**: "Create a skill that captures this pattern we just used"
</step_2>

<step_3>
**Review for conciseness**: Remove unnecessary explanations.
</step_3>

<step_4>
**Improve architecture**: Organize content with progressive disclosure.
</step_4>

<step_5>
**Test with Claude B**: Use fresh instance to test on real tasks.
</step_5>

<step_6>
**Iterate based on observation**: Return to Claude A with specific issues observed.
</step_6>
</workflow>
</creating_skills>
</iterative_development_with_claude>

<model_testing>
<principle>
Test with all models you plan to use. Different models have different strengths and need different levels of detail.
</principle>

<haiku_testing>
**Claude Haiku** (fast, economical)

Questions to ask:
- Does the skill provide enough guidance?
- Are examples clear and complete?
- Do implicit assumptions become explicit?
- Does Haiku need more structure?

Haiku benefits from:
- More explicit instructions
- Complete examples (no partial code)
- Clear success criteria
- Step-by-step workflows
</haiku_testing>

<sonnet_testing>
**Claude Sonnet** (balanced)

Questions to ask:
- Is the skill clear and efficient?
- Does it avoid over-explanation?
- Are workflows well-structured?
- Does progressive disclosure work?

Sonnet benefits from:
- Balanced detail level
- XML structure for clarity
- Progressive disclosure
- Concise but complete guidance
</sonnet_testing>

<opus_testing>
**Claude Opus** (powerful reasoning)

Questions to ask:
- Does the skill avoid over-explaining?
- Can Opus infer obvious steps?
- Are constraints clear?
- Is context minimal but sufficient?

Opus benefits from:
- Concise instructions
- Principles over procedures
- High degrees of freedom
- Trust in reasoning capabilities
</opus_testing>
</model_testing>

<observation_based_iteration>
<principle>
Iterate based on what you observe, not what you assume. Real usage reveals issues assumptions miss.
</principle>

<iteration_pattern>
1. **Observe**: Run Claude on real tasks with current skill
2. **Document**: Note specific issues, not general feelings
3. **Hypothesize**: Why did this issue occur?
4. **Fix**: Make targeted changes to address specific issues
5. **Test**: Verify fix works on same scenario
6. **Validate**: Ensure fix doesn't break other scenarios
7. **Repeat**: Continue with next observed issue
</iteration_pattern>
</observation_based_iteration>

<progressive_refinement>
<principle>
Skills don't need to be perfect initially. Start minimal, observe usage, add what's missing.
</principle>

<initial_version>
Start with:
- Valid YAML frontmatter
- Required XML tags: objective, quick_start, success_criteria
- Minimal working example
- Basic success criteria

Skip initially:
- Extensive examples
- Edge case documentation
- Advanced features
- Detailed reference files
</initial_version>

<iteration_additions>
Add through iteration:
- Examples when patterns aren't clear from description
- Edge cases when observed in real usage
- Advanced features when users need them
- Reference files when SKILL.md approaches 500 lines
- Validation scripts when errors are common
</iteration_additions>
</progressive_refinement>

<overview>
This reference covers patterns for complex workflows, validation loops, and feedback cycles in skill authoring. All patterns use pure XML structure.
</overview>

<complex_workflows>
<principle>
Break complex operations into clear, sequential steps. For particularly complex workflows, provide a checklist.
</principle>

<when_to_use>
Use checklist pattern when:
- Workflow has 5+ sequential steps
- Steps must be completed in order
- Progress tracking helps prevent errors
- Easy resumption after interruption is valuable
</when_to_use>
</complex_workflows>

<feedback_loops>
<validate_fix_repeat_pattern>
<principle>
Run validator -> fix errors -> repeat. This pattern greatly improves output quality.
</principle>

<why_it_works>
- Catches errors early before changes are applied
- Machine-verifiable with objective verification
- Plan can be iterated without touching originals
- Reduces total iteration cycles
</why_it_works>
</validate_fix_repeat_pattern>

<plan_validate_execute_pattern>
<principle>
When Claude performs complex, open-ended tasks, create a plan in a structured format, validate it, then execute.

Workflow: analyze -> **create plan file** -> **validate plan** -> execute -> verify
</principle>

<when_to_use>
Use plan-validate-execute when:
- Operations are complex and error-prone
- Changes are irreversible or difficult to undo
- Planning can be validated independently
- Catching errors early saves significant time
</when_to_use>
</plan_validate_execute_pattern>
</feedback_loops>

<conditional_workflows>
<principle>
Guide Claude through decision points with clear branching logic.
</principle>

<when_to_use>
Use conditional workflows when:
- Different task types require different approaches
- Decision points are clear and well-defined
- Workflows are mutually exclusive
- Guiding Claude to correct path improves outcomes
</when_to_use>
</conditional_workflows>

<validation_scripts>
<principles>
Validation scripts are force multipliers. They catch errors that Claude might miss and provide actionable feedback for fixing issues.
</principles>

<characteristics_of_good_validation>
<verbose_errors>
**Good**: "Field 'signature_date' not found. Available fields: customer_name, order_total, signature_date_signed"
**Bad**: "Invalid field"
</verbose_errors>

<specific_feedback>
**Good**: "Line 47: Expected closing tag `</paragraph>` but found `</section>`"
**Bad**: "XML syntax error"
</specific_feedback>

<actionable_suggestions>
**Good**: "Required field 'customer_name' is missing. Add: {\"customer_name\": \"value\"}"
**Bad**: "Missing required field"
</actionable_suggestions>
</characteristics_of_good_validation>

<benefits>
- Catches errors before they propagate
- Reduces iteration cycles
- Provides learning feedback
- Makes debugging deterministic
- Enables confident execution
</benefits>
</validation_scripts>

<checkpoint_pattern>
<principle>
For long workflows, add checkpoints where Claude can pause and verify progress before continuing.
</principle>

<benefits>
- Prevents cascading errors
- Easier to diagnose issues
- Clear progress indicators
- Natural pause points for review
- Reduces wasted work from early errors
</benefits>
</checkpoint_pattern>

<error_recovery>
<principle>
Design workflows with clear error recovery paths. Claude should know what to do when things go wrong.
</principle>

<when_to_use>
Include error recovery when:
- Workflows interact with external systems
- File operations could fail
- Network calls could timeout
- User input could be invalid
- Errors are recoverable
</when_to_use>
</error_recovery>

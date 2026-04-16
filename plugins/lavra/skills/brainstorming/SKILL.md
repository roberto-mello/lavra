---
name: brainstorming
description: "Explore user intent, approaches, and design decisions before planning. Use for ambiguous requests, brainstorming sessions, or feature exploration."
---

# Brainstorming

Process knowledge for brainstorming sessions that clarify **WHAT** to build before **HOW** to build it.

## When to Use This Skill

Brainstorming is valuable when:
- Requirements are unclear or ambiguous
- Multiple approaches could solve the problem
- Trade-offs need to be explored with the user
- The user hasn't fully articulated what they want
- The feature scope needs refinement

Brainstorming can be skipped when:
- Requirements are explicit and detailed
- The user knows exactly what they want
- The task is a straightforward bug fix or well-defined change

## Core Process

### Phase 0: Assess Requirement Clarity

Assess whether brainstorming is needed before asking questions.

**Signals that requirements are clear:**
- User provided specific acceptance criteria
- User referenced existing patterns to follow
- User described exact behavior expected
- Scope is constrained and well-defined

**Signals that brainstorming is needed:**
- User used vague terms ("make it better", "add something like")
- Multiple reasonable interpretations exist
- Trade-offs haven't been discussed
- User seems unsure about the approach

If requirements are clear, suggest: "Your requirements seem clear. Consider proceeding directly to planning or implementation."

### Phase 1: Understand the Idea

Ask questions **one at a time**. Avoid overwhelming with multiple questions.

**Question Techniques:**

1. **Prefer multiple choice when natural options exist**
   - Good: "Should the notification be: (a) email only, (b) in-app only, or (c) both?"
   - Avoid: "How should users be notified?"

2. **Start broad, then narrow**
   - First: What is the core purpose?
   - Then: Who are the users?
   - Finally: What constraints exist?

3. **Validate assumptions explicitly**
   - "I'm assuming users will be logged in. Is that correct?"

4. **Ask about success criteria early**
   - "How will you know this feature is working well?"

**Key Topics to Explore:**

| Topic | Example Questions |
|-------|-------------------|
| Purpose | What problem does this solve? What's the motivation? |
| Users | Who uses this? What's their context? |
| Constraints | Any technical limitations? Timeline? Dependencies? |
| Success | How will you measure success? What's the happy path? |
| Edge Cases | What shouldn't happen? Any error states to consider? |
| Existing Patterns | Are there similar features in the codebase to follow? |

**Exit Condition:** Continue until the idea is clear OR user says "proceed" or "let's move on"

### Phase 2: Explore Approaches

After understanding the idea, propose 2-3 concrete approaches.

**Structure for Each Approach:**

```markdown
### Approach A: [Name]

[2-3 sentence description]

**Pros:**
- [Benefit 1]
- [Benefit 2]

**Cons:**
- [Drawback 1]
- [Drawback 2]

**Best when:** [Circumstances where this approach shines]
```

**Guidelines:**
- Lead with a recommendation and explain why
- Be honest about trade-offs
- Consider YAGNI--simpler is usually better
- Reference codebase patterns when relevant

### Phase 3: Capture the Design

Log key decisions and investigation results as bead comments. For each significant decision or finding:

```bash
# Log the chosen approach
bd comments add {BEAD_ID} "DECISION: Chose [approach name] because [rationale]. Alternatives considered: [list]"

# Log key investigation findings
bd comments add {BEAD_ID} "INVESTIGATION: Explored [topic]. Found that [key finding]. This means [implication]."

# Log important facts discovered during brainstorming
bd comments add {BEAD_ID} "FACT: [Constraint or requirement discovered during brainstorming]"
```

**If no active bead exists**, present a summary in this format:

```markdown
## What We're Building
[Concise description--1-2 paragraphs max]

## Why This Approach
[Brief explanation of approaches considered and why this one was chosen]

## Key Decisions
- [Decision 1]: [Rationale]
- [Decision 2]: [Rationale]

## Open Questions
- [Any unresolved questions for the planning phase]
```

### Phase 4: Handoff

Options for what to do next:

1. **Proceed to planning** -> Run `/lavra-plan`
2. **Refine further** -> Continue exploring the design
3. **Done for now** -> User will return later

## YAGNI Principles

During brainstorming, actively resist complexity:

- **Don't design for hypothetical future requirements**
- **Choose the simplest approach that solves the stated problem**
- **Prefer boring, proven patterns over clever solutions**
- **Ask "Do we really need this?" when complexity emerges**
- **Defer decisions that don't need to be made now**

## Incremental Validation

Keep sections short--200-300 words maximum. After each section, pause to validate understanding:

- "Does this match what you had in mind?"
- "Any adjustments before we continue?"
- "Is this the direction you want to go?"

Prevents wasted effort on misaligned designs.

## Anti-Patterns to Avoid

| Anti-Pattern | Better Approach |
|--------------|-----------------|
| Asking 5 questions at once | Ask one at a time |
| Jumping to implementation details | Stay focused on WHAT, not HOW |
| Proposing overly complex solutions | Start simple, add complexity only if needed |
| Ignoring existing codebase patterns | Research what exists first |
| Making assumptions without validating | State assumptions explicitly and confirm |
| Creating lengthy design documents | Keep it concise--details go in the plan |

## Integration with Planning

Brainstorming answers **WHAT** to build: requirements, chosen approach, key decisions.

Planning answers **HOW** to build it: implementation steps, technical details, testing strategy.

When brainstorm output exists (as bead comments), `/lavra-plan` detects it and uses it as input, skipping its own idea refinement phase.

---
name: lfg
description: Full autonomous engineering workflow
argument-hint: [feature description]
disable-model-invocation: true
---

<objective>
Run the full autonomous engineering workflow end-to-end: plan, deepen, work, review, resolve TODOs, browser test, and record a feature video.
</objective>

<process>

Run these slash commands in order. Do not do anything else.

1. `/beads-plan $ARGUMENTS`
2. `/beads-deepen`
3. `/beads-work`
4. `/beads-review`
5. `/resolve-todo-parallel`
6. `/test-browser`
7. `/feature-video`

Start with step 1 now.

</process>

<success_criteria>
- All 7 steps completed in sequence without being skipped
- Feature is planned, deepened, implemented, reviewed, TODOs resolved, browser-tested, and video recorded
- All beads created during planning are closed
- Code is committed and pushed
</success_criteria>

---
title: Hooks
description: How Lavra's four automatic hooks work — session recall, knowledge capture, subagent wrapup, and teammate idle check.
order: 6
---

# Hooks

Lavra ships four hooks that run automatically during your Claude Code session. You don't invoke them directly — they fire in the background based on what you do.

## auto-recall (SessionStart)

Runs when Claude Code starts. Searches your knowledge base for entries relevant to what you're currently working on, then injects the top matches into the session context.

**How it finds relevant knowledge:**
1. Reads your open and in-progress beads via `bd list`
2. Extracts keywords from bead titles (4+ characters, common words excluded)
3. Adds keywords from the current git branch name
4. Searches `knowledge.jsonl` and returns the top 10 matches
5. Falls back to the 10 most recent entries if no keywords are found

If a `session-state.md` file exists in `.lavra/memory/` (written by `/lavra-work` or `/lavra-checkpoint` at milestones), its content is injected once then deleted. This lets you resume exactly where you left off after context compaction.

## memory-capture (PostToolUse on Bash)

Runs after every Bash tool call. Watches for `bd comments add` commands that include a knowledge prefix, then parses and stores the entry in `.lavra/memory/knowledge.jsonl`.

**Recognized prefixes:**

| Prefix | Use for |
|--------|---------|
| `LEARNED:` | Key technical insight discovered during work |
| `DECISION:` | What was chosen and why |
| `FACT:` | Constraint, gotcha, or environment detail |
| `PATTERN:` | Recurring convention or idiom |
| `INVESTIGATION:` | Root cause analysis |
| `DEVIATION:` | Auto-fix applied outside bead scope |

**Example:**
```bash
bd comments add beads-abc "LEARNED: Astro 5 uses id not slug for glob loader entries"
```

The hook auto-tags entries based on keywords in the content. After 1000 entries, the oldest 500 are archived to `knowledge.archive.jsonl`.

## subagent-wrapup (SubagentStop)

Runs when a subagent finishes. Blocks the subagent from completing until it has logged at least one knowledge comment.

**How it works:**
1. Reads the subagent's transcript to find a `BEAD_ID:` reference
2. If found, checks whether the subagent logged a knowledge comment during its run
3. If no knowledge was captured, blocks with a prompt listing the six prefixes

This ensures knowledge compounds across parallel agent work — every subagent leaves a trail.

> **Note:** This hook does not fire for `/lavra-work-teams` teammates, which use a separate `COMPLETED → ACCEPTED` handoff protocol.

## teammate-idle-check (TeammateIdle)

Runs when a `/lavra-work-teams` teammate goes idle. Checks whether there are still beads in the ready queue and blocks the teammate from stopping if work remains.

**How it works:**
1. Runs `bd ready` to check for remaining beads
2. If beads are available, returns a `decision:block` JSON response that prevents the teammate from idling
3. If no beads remain, allows the teammate to stop gracefully

This keeps persistent worker teammates active as long as there's work to do.

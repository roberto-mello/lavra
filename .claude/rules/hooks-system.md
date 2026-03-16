---
description: Hook architecture, matcher format, and memory system
globs: "**/hooks/**"
---

# Hooks System

Four hooks implement memory, subagent, and teams features:

1. **SessionStart**: `auto-recall.sh` - Searches knowledge based on open/in-progress beads, extracts keywords from bead titles and git branch, injects top 10 relevant entries. Also injects session state from `.beads/memory/session-state.md` if present (survives context compaction, recalled once then deleted).
2. **PostToolUse**: `memory-capture.sh` (matcher: "Bash") - Detects `bd comment add`/`bd comments add` with knowledge prefixes, stores in `knowledge.jsonl`, auto-tags
3. **SubagentStop**: `subagent-wrapup.sh` - Blocks completion until subagent logs at least one knowledge comment. Does NOT fire for teammates (--teams uses COMPLETED->ACCEPTED protocol)
4. **TeammateIdle**: `teammate-idle-check.sh` - Blocks idle if `bd ready` has remaining beads (JSON `decision:block` pattern)

## Hook Matcher Format

Matchers MUST be regex strings, not objects:

```json
{
  "PostToolUse": [{"matcher": "Bash", "hooks": [...]}],
  "PreToolUse": [{"matcher": "Edit|Write", "hooks": [...]}]
}
```

Tool names: `Bash`, `Edit`, `Write`, `Read`, `Task`, `Grep`, `Glob`
- Do NOT use "Tool" suffix (not "BashTool")
- Do NOT use object format like `{"tools": ["BashTool"]}`

## Memory System

Knowledge stored in `.beads/memory/knowledge.jsonl`:

```json
{"key": "learned-oauth-redirect-must-match-exactly", "type": "learned", "content": "OAuth redirect URI must match exactly", "source": "user", "tags": ["oauth", "auth", "security"], "ts": 1706918400, "bead": "BD-001"}
```

- **Auto-tagging**: Keywords detected in content are added as tags
- **Rotation**: After 1000 lines, first 500 archived to `knowledge.archive.jsonl`
- **Search**: `.beads/memory/recall.sh` (use `--all` to include archive)

## Memory Capture Detection

The `memory-capture.sh` hook detects:
```bash
bd comment add {BEAD_ID} "LEARNED|DECISION|FACT|PATTERN|INVESTIGATION|DEVIATION: ..."
```
Regex matches both `bd comment add` (singular) and `bd comments add` (plural).

Knowledge types:
- `LEARNED:` - Key technical insight discovered during work
- `DECISION:` - What was chosen and why
- `FACT:` - Constraint, gotcha, or environment detail
- `PATTERN:` - Recurring convention or idiom
- `INVESTIGATION:` - Root cause analysis
- `DEVIATION:` - Auto-fix applied outside bead scope (from deviation rules)

## Auto-Recall Strategy

1. Gets open/in-progress beads via `bd list --status=open --json`
2. Extracts keywords (4+ chars, excluding common words) from bead titles
3. Adds keywords from git branch name (if not main/master)
4. Searches `knowledge.jsonl`, deduplicates, returns top 10
5. Falls back to recent 10 entries if no search terms
6. If `.beads/memory/session-state.md` exists and is non-empty:
   - Delete if >24 hours old (stale from previous day)
   - Otherwise inject its content into the system message, then delete the file
   - This provides "where was I?" context after context compaction

## Session State Lifecycle

`session-state.md` is an ephemeral file (gitignored) written by `/lavra-work`, `/lavra-design`, and `/lavra-checkpoint` at milestones. It contains current position, last completed task, and next steps.

- **Written during work** at milestones (bead started, task completed, phase transition, wave completed)
- **Survives compaction** because it's a file, not conversation context
- **Recalled once** at next session start by `auto-recall.sh`
- **Deleted after recall** -- it doesn't linger
- **Fresh sessions** (no prior compaction) start clean -- the file won't exist

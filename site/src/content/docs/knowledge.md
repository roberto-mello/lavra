---
title: Knowledge System
description: How lavra captures, stores, and automatically recalls technical knowledge across sessions.
order: 7
---

# Knowledge System

lavra's knowledge system solves a fundamental problem with AI coding assistants: they forget everything between sessions. The knowledge system gives your agent persistent memory that compounds over time.

## How it works

When you or an agent discovers something worth remembering — a gotcha, an architectural decision, a root cause — you log it as a typed knowledge comment on a bead:

```bash
bd comment add beads-abc "LEARNED: OAuth redirect URI must match exactly, including trailing slash"
```

The `memory-capture` hook detects this, parses it, and stores it in `.beads/memory/knowledge.jsonl`. At the start of every future session, the `auto-recall` hook searches that file based on your current work and injects the most relevant entries into Claude's context automatically.

## Knowledge types

| Type | Use for |
|------|---------|
| `LEARNED:` | Insight from debugging, investigation, or surprise behavior |
| `DECISION:` | Architectural or design choice with rationale |
| `FACT:` | Hard constraint, version requirement, or environment detail |
| `PATTERN:` | Recurring convention in this codebase or team |
| `INVESTIGATION:` | Root cause analysis of a bug or incident |
| `DEVIATION:` | Change made outside the current bead's scope |

## Storage

Knowledge is stored in `.beads/memory/knowledge.jsonl` — one JSON object per line:

```json
{"key": "learned-oauth-redirect", "type": "learned", "content": "OAuth redirect URI must match exactly", "tags": ["oauth", "auth"], "ts": 1706918400, "bead": "beads-abc"}
```

The file is committed to git alongside your beads, so knowledge is shared across your team and persists across machines.

**Rotation:** After 1000 entries, the oldest 500 are archived to `knowledge.archive.jsonl` to keep recall fast.

## Searching manually

```bash
# Search current knowledge
.beads/memory/recall.sh <keywords>

# Include archived entries
.beads/memory/recall.sh --all <keywords>
```

Or mid-session:

```
/lavra-recall <keywords>
```

## Curating knowledge

Raw knowledge comments logged during work are functional but often terse. `/lavra-learn` reviews recently closed beads and rewrites knowledge entries to be more searchable, better tagged, and useful to future sessions:

```
/lavra-learn beads-abc beads-xyz
```

Run this after shipping a feature to make sure the insights survive.

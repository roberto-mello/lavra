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

Knowledge is stored in two places that stay in sync:

**`.beads/memory/knowledge.jsonl`** — the source of truth, committed to git so knowledge is shared across your team and persists across machines:

```json
{"key": "learned-oauth-redirect", "type": "learned", "content": "OAuth redirect URI must match exactly", "tags": ["oauth", "auth"], "ts": 1706918400, "bead": "beads-abc"}
```

**`.beads/memory/knowledge.db`** — a local SQLite database (gitignored) built from the JSONL file, used for fast search. It has an FTS5 virtual table with a Porter stemmer, so searching "authenticate" also matches "authentication" and "authenticated". Results are ranked by BM25 relevance — entries that match more of your search terms, and in more important fields (content over tags), rank higher.

The SQLite DB is rebuilt automatically from the JSONL on first use and kept in sync as new entries are added.

**Rotation:** When `knowledge.jsonl` exceeds 5000 lines, the oldest 2500 entries are moved to `knowledge.archive.jsonl`. Both files use `merge=union` in `.gitattributes` so concurrent writes from teammates merge cleanly without conflicts.

## Searching manually

Mid-session, use the slash command to search and inject relevant entries into your agent's context:

```
/lavra-recall authentication
/lavra-recall BD-050
```

Or search directly from the shell:

```bash
# Search by keyword (uses SQLite FTS + BM25 ranking)
.beads/memory/recall.sh "authentication"

# Filter by type
.beads/memory/recall.sh "jwt" --type learned

# Show recent entries
.beads/memory/recall.sh --recent 10

# Show stats
.beads/memory/recall.sh --stats
```

## Curating knowledge

Raw knowledge comments logged during work are functional but often terse. `/lavra-learn` reviews recently closed beads and rewrites knowledge entries to be more searchable, better tagged, and useful to future sessions:

```
/lavra-learn beads-abc beads-xyz
```

Run this after shipping a feature to make sure the insights survive.

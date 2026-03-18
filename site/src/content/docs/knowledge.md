---
title: Knowledge System
description: How Lavra captures, stores, and automatically recalls technical knowledge across sessions.
order: 7
---

# Knowledge System

Lavra's knowledge system solves a fundamental problem with AI coding assistants: they usually have no consistent memory, and forget everything between sessions. Lavra's knowledge system gives your agent persistent memory that compounds over time.

## How it works

When using Lavra's workflow commands, agents are instructed to log things worth remembering - a gotcha, an architectural decision, a pattern, a root cause. They log it as a typed knowledge comment on a bead:

```bash
bd comments add beads-abc "LEARNED: OAuth redirect URI must match exactly, including trailing slash"
```

The `memory-capture` hook detects this, parses it, and stores it in `.beads/memory/knowledge.jsonl`. At the start of every future session, the `auto-recall` hook searches that file based on your current work and injects the most relevant entries into the agent's context automatically.

You can add your own knowledge entries manually using `bd comments add` and they will be retrieved by agents via a hook at session start, or by using the Lavra workflow commands. See also [Searching manually](#searching-manually) and [Curating knowledge](#curating-knowledge).

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

**Security:** Knowledge entries are auto-injected into agent context at session start. In collaborative projects, treat changes to `knowledge.jsonl` with the same scrutiny as CI config — any collaborator can add entries that influence agent behavior. Recalled entries are sanitized (role prefix stripping, bidirectional char removal) and wrapped in `<untrusted-knowledge>` tags. See [Security Model](SECURITY.md#knowledge-system-injection-defense) for the full threat model and team recommendations.

## Searching manually

Knowledge entries are indexed by domain terms — framework names, error codes, API names, gotcha keywords. Search with whatever you'd naturally reach for when debugging:

Mid-session, use the slash command to inject relevant entries into your agent's context:

```
/lavra-recall oauth redirect
/lavra-recall rls context postgres
/lavra-recall nfse E0014
```

Or search directly from the shell:

```bash
# Keyword search (SQLite FTS5 + BM25 ranking, Porter stemming)
.beads/memory/recall.sh "authentication"

# Filter by knowledge type
.beads/memory/recall.sh "postgres" --type investigation

# Include archived entries (older than 5000 lines)
.beads/memory/recall.sh "pydantic" --all

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

`/lavra-work` calls `/lavra-learn` automatically at the end of each bead. `/lavra-checkpoint` prompts you to run it if it detects captured knowledge. If you've been coding outside the pipeline — direct edits, quick fixes, exploratory work, run `/lavra-checkpoint` (to file beads for what was fixed/changed, which will prompt to run `/lavra-learn`) or run `/lavra-learn` directly, before ending the session to curate whatever you captured.

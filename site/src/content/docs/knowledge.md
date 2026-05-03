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

The `memory-capture` hook detects this, parses it, and stores it in `.lavra/memory/knowledge.jsonl`. At the start of every future session, the `auto-recall` hook searches that file based on your current work and injects the most relevant entries into the agent's context automatically.

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

Knowledge is stored as one shared log plus local derived artifacts:

**`.lavra/memory/knowledge.jsonl`** — the source of truth, committed to git so knowledge is shared across your team and persists across machines:

```json
{"key": "learned-oauth-redirect", "type": "learned", "content": "OAuth redirect URI must match exactly", "tags": ["oauth", "auth"], "ts": 1706918400, "bead": "beads-abc"}
```

**`.lavra/memory/knowledge.db`** — a local SQLite database (gitignored) built from the JSONL file, used for fast search. It has an FTS5 virtual table with a Porter stemmer, so searching "authenticate" also matches "authentication" and "authenticated". Results are ranked by BM25 relevance — entries that match more of your search terms, and in more important fields (content over tags), rank higher.

The SQLite DB is rebuilt automatically from the JSONL on first use and kept in sync as new entries are added.

**`.lavra/memory/knowledge.active.jsonl`** — a gitignored local cache built by `memory-sanitize.sh`. The shell wrapper compiles and runs the Go helper in `memorysanitize/` when `go` is available, and falls back to the reduced `jq` path when it is not. The active cache removes exact and normalized duplicates from the append-only knowledge log so auto-recall and manual search can use a smaller, cleaner working set without rewriting shared memory history. Its paired `knowledge.active.db` cache serves the same purpose for local FTS search.

**`.lavra/memory/knowledge.audit.jsonl`** — a gitignored audit artifact from the local sanitizer. In Go-helper mode it records actions like skipped invalid lines, filtered command/log noise, duplicate collapse, symbol/file anchor checks, and stale-memory downgrades so local cleanup stays explainable.

**`.lavra/memory/.memory-sanitize-go`** — a gitignored compiled helper binary built locally from `.lavra/memory/memorysanitize/` the first time advanced sanitization runs on a machine with Go installed.

**Rotation:** When `knowledge.jsonl` exceeds 5000 lines, the oldest 2500 entries are moved to `knowledge.archive.jsonl`. Both files use `merge=union` in `.gitattributes` so concurrent writes from teammates merge cleanly without conflicts.

**Security:** Knowledge entries are auto-injected into agent context at session start. In collaborative projects, treat changes to `knowledge.jsonl` with the same scrutiny as CI config — any collaborator can add entries that influence agent behavior. Recalled entries are sanitized (role prefix stripping, bidirectional char removal) and wrapped in `<untrusted-knowledge>` tags. See [Security Model](SECURITY.md#knowledge-system-injection-defense) for the full threat model and team recommendations.

## Local vs shared memory

Lavra now separates retrieval hygiene from shared history:

- `knowledge.jsonl` is the shared, committed, append-only source of truth
- `knowledge.active.*` and `knowledge.audit.jsonl` are local-only, gitignored working artifacts

This lets Lavra reduce token usage and improve recall quality locally without rewriting team history every time the sanitizer learns something new.

On machines without Go, Lavra still builds `knowledge.active.jsonl` through the shell/`jq` fallback. That keeps recall working, but the richer anchor-validation and audit path is only available through the Go helper.

## Shared Curation

Local refinement improves recall quality without touching the shared log. Shared curation is the later, review-gated step for promoting those refinements back into `.lavra/memory/knowledge.jsonl` without rewriting history.

The rules are simple:

- keep `knowledge.jsonl` append-only
- never promote shared memory from a hook
- use an explicit command, not automatic write-back
- preserve provenance with relationship fields like `supersedes`, `superseded_by`, and `merged_from`

Recommended shared statuses:

- `canonical`
  - reviewed entry that should rank first for its topic cluster
- `superseded`
  - historical entry kept for provenance but replaced by a newer canonical entry
- `needs_review`
  - entry stays visible in history but is flagged as lower-trust for shared recall

`active` remains a local-cache concept for `knowledge.active.jsonl`, not a shared-log status.

The intended UX is a dedicated `/lavra-curate` workflow:

1. `--dry-run` gathers candidates from `knowledge.audit.jsonl`, `knowledge.active.jsonl`, and raw `knowledge.jsonl`, then prints the exact JSONL lines that would be appended.
2. `--apply` requires explicit confirmation and appends only the reviewed lines.

Guardrails:

- no hook path can invoke `--apply`
- `review_reason` is required for each curated append
- `--apply` must fail if the proposal content changed since review generation
- `/lavra-learn` stays focused on capture quality and does not do shared-history cleanup

This keeps local sanitization and shared memory curation separate: local caches can be opinionated, while the committed shared log stays additive and auditable.

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
.lavra/memory/recall.sh "authentication"

# Filter by knowledge type
.lavra/memory/recall.sh "postgres" --type investigation

# Include archived entries (older than 5000 lines)
.lavra/memory/recall.sh "pydantic" --all

# Show recent entries
.lavra/memory/recall.sh --recent 10

# Show stats
.lavra/memory/recall.sh --stats
```

## Curating knowledge

Raw knowledge comments logged during work are functional but often terse. `/lavra-learn` reviews recently closed beads and rewrites knowledge entries to be more searchable, better tagged, and useful to future sessions:

```
/lavra-learn beads-abc beads-xyz
```

`/lavra-work` calls `/lavra-learn` automatically at the end of each bead. `/lavra-checkpoint` prompts you to run it if it detects captured knowledge. If you've been coding outside the pipeline — direct edits, quick fixes, exploratory work, run `/lavra-checkpoint` (to file beads for what was fixed/changed, which will prompt to run `/lavra-learn`) or run `/lavra-learn` directly, before ending the session to curate whatever you captured.

`/lavra-learn` improves the quality of captured entries. It does not currently perform shared-memory cleanup or rewrite older memories. That later layer is tracked separately in the shared-curation design.

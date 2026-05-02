---
title: Shared Memory Curation
description: Design for promoting reviewed local memory refinements back into shared knowledge safely.
order: 8
---

# Shared Memory Curation

Lavra now has a strong local refinement pipeline: `memory-sanitize.sh` deduplicates noisy memories, writes `knowledge.active.jsonl` and `knowledge.active.db`, emits `knowledge.audit.jsonl`, and can hide stale memories from local recall without touching the shared log.

That solves retrieval quality, but not shared cleanup. Teams still collaborate through the append-only `.lavra/memory/knowledge.jsonl` file. This document defines the next layer: an explicit, reviewable workflow for promoting curated memories back into shared history.

## Status

This is a design target, not a shipped workflow yet.

Current state:
- local refinement is automatic and gitignored
- shared memory is append-only and committed
- no hook writes curated results back into `knowledge.jsonl`

Planned state:
- curated shared entries are appended explicitly after review
- older entries stay in history and are linked, not rewritten
- recall prefers canonical shared entries by default

## Goals

- Keep `knowledge.jsonl` append-only and collaboration-friendly
- Let teams converge on canonical memories instead of accumulating conflicting variants forever
- Reuse local audit and drift-validation signals as inputs
- Require an explicit review step before shared-memory writes
- Avoid token-heavy full-corpus LLM passes on the hot path

## Non-goals

- Automatic hook-based write-back to shared memory
- In-place rewriting or deletion of old JSONL lines
- Treating local heuristic output as authoritative without review
- Full semantic clustering on every session start

## Local vs Shared

### Local-only artifacts

These remain gitignored and machine-generated:

- `.lavra/memory/knowledge.active.jsonl`
- `.lavra/memory/knowledge.active.db`
- `.lavra/memory/knowledge.audit.jsonl`
- sanitizer lock/debounce markers

These artifacts can be opinionated. They may hide stale, noisy, or duplicate entries as long as the audit log explains why.

### Shared artifact

This remains the committed collaboration layer:

- `.lavra/memory/knowledge.jsonl`

Shared memory must stay conservative. It is the cross-machine, cross-teammate history. Improvements are additive and reviewed.

## Design Principles

### Append-only

Shared curation appends new canonical or superseding entries. It does not rewrite old ones.

### Review-gated

No hook should promote shared memories automatically. A user-facing command or review workflow must approve the write.

### Provenance-preserving

New curated entries should explain what they supersede or merge. History stays inspectable.

### Merge-tolerant

Two teammates may curate the same topic differently. The system should tolerate competing append-only outcomes and resolve later with a newer canonical entry, not a history edit.

## Proposed Shared Fields

Existing entries stay valid. Shared curation adds optional fields such as:

```json
{
  "status": "canonical",
  "supersedes": ["learned-old-auth-redirect-note"],
  "merged_from": ["decision-auth-retry", "fact-auth-timeout"],
  "review_source": "local-audit",
  "review_reason": "Merged duplicate auth redirect guidance into one canonical entry"
}
```

Candidate fields:

- `status`
  - `active`
  - `canonical`
  - `superseded`
  - `needs_review`
- `supersedes`
  - array of entry keys this curated memory replaces conceptually
- `superseded_by`
  - key of the newer canonical entry
- `merged_from`
  - array of entry keys combined into this entry
- `review_source`
  - `local-audit`, `manual`, or `team-review`
- `review_reason`
  - short free-text explanation

These fields are additive. Legacy entries without them continue to work.

## Workflow

### 1. Gather candidates

Collect possible curation actions from:

- `knowledge.audit.jsonl`
- local `knowledge.active.jsonl`
- raw shared `knowledge.jsonl`

Candidate groups:

- obvious duplicates
- noisy or malformed shared entries that deserve a clean replacement
- stale memories with a better modern replacement
- clusters of overlapping entries that should become one canonical memory

### 2. Present a review set

The workflow should show:

- the candidate entries
- the proposed shared action
- the reason for the proposal
- the exact JSONL lines that would be appended

This can be implemented as:

- a future `/lavra-curate` command, or
- a shared-review mode of `/lavra-learn`

### 3. Append curated shared entries

On approval:

- append one or more new entries to `knowledge.jsonl`
- mark relationships via `supersedes`, `superseded_by`, or `merged_from`
- never delete prior lines

### 4. Update recall behavior later

Once shared curation exists, recall should:

- prefer `canonical` entries over older overlapping ones
- still allow raw/history views for debugging and audit

## Collaboration Model

Different teammates may promote different curated entries for the same area.

That is acceptable if:

- both writes are append-only
- both preserve provenance
- a later review can emit a newer canonical entry that supersedes both

This keeps git merges simple. It also avoids a dangerous pattern where one workstation silently rewrites shared memory based on local heuristics.

## Validation Plan

Any implementation of this design should satisfy:

- old and new schema variants can coexist in `knowledge.jsonl`
- no shared-memory write occurs without an explicit user action
- shared curation never deletes or rewrites old lines
- concurrent teammate writes merge as additive history
- recall can prefer canonical entries without hiding raw history permanently
- projects with no local audit artifacts still function normally

## Testing Plan

- Schema compatibility
  - mixed legacy and curated entries do not break capture or recall
- Append-only behavior
  - curated writes only add lines
- Concurrency
  - two teammates append different canonical entries without corrupting the log
- Review gate
  - no hook path can trigger shared-memory writes
- Ranking behavior
  - canonical entries win by default once ranking support lands
- Fallback behavior
  - legacy projects without curation metadata still behave correctly

## Relationship to `/lavra-learn`

Today `/lavra-learn` curates raw bead comments into better knowledge entries. That is still useful and remains the right place for turning session-local observations into searchable memory.

Shared curation is a separate concern:

- `/lavra-learn` improves capture quality
- shared curation improves the long-lived shared history

They may share UI later, but they should not be conflated in the current implementation.


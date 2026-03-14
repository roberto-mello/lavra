---
name: beads-knowledge
description: "Capture solved problems as knowledge entries in JSONL format for fast recall. Use when a problem has been solved and the solution should be preserved for future sessions."
allowed-tools: "- Read # Parse conversation context
  - Write # Append to knowledge.jsonl
  - Bash # Run bd commands, search knowledge
  - Grep # Search existing knowledge"
preconditions: "- Problem has been solved (not in-progress)
  - Solution has been verified working"
disable-model-invocation: true
---

# beads-knowledge Skill

**Purpose:** Capture solved problems as structured JSONL entries in `.beads/memory/knowledge.jsonl` and as bead comments, building a searchable knowledge base that auto-recall injects into future sessions.

## Overview

This skill captures problem solutions immediately after confirmation, creating structured knowledge entries that:
- Are stored in `.beads/memory/knowledge.jsonl` for auto-recall search
- Are logged as bead comments for traceability back to specific work items
- Use the five knowledge prefixes: LEARNED, DECISION, FACT, PATTERN, INVESTIGATION

**Organization:** Append-only JSONL file. Each solved problem produces one or more knowledge entries. The auto-recall hook (`auto-recall.sh`) searches these entries by keyword and injects relevant ones at session start.

---

<critical_sequence name="knowledge-capture" enforce_order="strict">

## 7-Step Process

<step number="1" required="true">
### Step 1: Detect Confirmation

**Auto-invoke after phrases:**

- "that worked"
- "it's fixed"
- "working now"
- "problem solved"
- "that did it"

**OR manual invocation.**

**Non-trivial problems only:**

- Multiple investigation attempts needed
- Tricky debugging that took time
- Non-obvious solution
- Future sessions would benefit

**Skip for:**

- Simple typos
- Obvious syntax errors
- Trivial fixes immediately corrected
</step>

<step number="2" required="true" depends_on="1">
### Step 2: Gather Context

Extract from conversation history:

**Required information:**

- **Area/module**: Which part of the codebase had the problem
- **Symptom**: Observable error/behavior (exact error messages)
- **Investigation attempts**: What didn't work and why
- **Root cause**: Technical explanation of actual problem
- **Solution**: What fixed it (code/config changes)
- **Prevention**: How to avoid in future

**BLOCKING REQUIREMENT:** If critical context is missing (area, exact error, or resolution steps), ask user and WAIT for response before proceeding to Step 3:

```
I need a few details to document this properly:

1. Which area/module had this issue?
2. What was the exact error message or symptom?
3. What fixed it?

[Continue after user provides details]
```
</step>

<step number="3" required="false" depends_on="2">
### Step 3: Check Existing Knowledge

Search knowledge.jsonl for similar issues:

```bash
# Search by error message keywords
grep "exact error phrase" .beads/memory/knowledge.jsonl

# Search using recall script if available
.beads/memory/recall.sh "keyword1 keyword2"
```

**IF similar knowledge found:**

Present decision options:

```
Found similar knowledge entry:
  [key]: [content summary]

What's next?
1. Create new entries anyway (recommended if different root cause)
2. Skip (this is a duplicate)
3. Create new entries with cross-reference

Choose (1-3): _
```

WAIT for user response.

**ELSE** (no similar knowledge found):

Proceed directly to Step 4.
</step>

<step number="4" required="true" depends_on="2">
### Step 4: Determine Knowledge Type

Classify the solution into one or more knowledge prefixes:

| Prefix | Use When | Example |
|--------|----------|---------|
| LEARNED | Discovered something non-obvious through debugging | "LEARNED: OAuth redirect URI must match exactly including trailing slash" |
| DECISION | Made an architectural or implementation choice | "DECISION: Use connection pooling instead of per-request connections because..." |
| FACT | Confirmed a factual constraint or requirement | "FACT: PostgreSQL JSONB columns require explicit casting for array operations" |
| PATTERN | Identified a recurring pattern (good or bad) | "PATTERN: Always check for nil before accessing nested hash keys in API responses" |
| INVESTIGATION | Documented an investigation path for future reference | "INVESTIGATION: Debugged memory leak - profiler showed retained objects from..." |

Most solved problems produce 1-3 entries. A complex debugging session might produce:
- 1 LEARNED (the key insight)
- 1 PATTERN (the prevention rule)
- 1 INVESTIGATION (the debugging path for future reference)
</step>

<step number="5" required="true" depends_on="4" blocking="true">
### Step 5: Validate JSONL Entry

**CRITICAL:** All knowledge entries must conform to the JSONL schema.

<validation_gate name="jsonl-schema" blocking="true">

**Required fields for each entry:**

```json
{
  "key": "lowercase-hyphen-separated-unique-key",
  "type": "learned|decision|fact|pattern|investigation",
  "content": "Clear, specific description of the knowledge",
  "source": "user|agent|subagent",
  "tags": ["tag1", "tag2"],
  "ts": 1706918400,
  "bead": "BD-001"
}
```

**Validation rules:**

1. **key**: Must be lowercase, hyphen-separated, unique, descriptive (e.g., `learned-oauth-redirect-must-match-exactly`)
2. **type**: Must be one of: `learned`, `decision`, `fact`, `pattern`, `investigation`
3. **content**: Must be specific and searchable (no vague descriptions)
4. **source**: Must be `user`, `agent`, or `subagent`
5. **tags**: Array of lowercase keywords for search (auto-detected from content where possible)
6. **ts**: Unix timestamp (current time)
7. **bead**: Bead ID if working on a specific bead, or empty string if none

**Auto-tagging:** Extract keywords from content matching known domains:
- auth, oauth, jwt, session -> "auth"
- database, postgres, sql, migration -> "database"
- react, component, hook, state -> "react"
- api, endpoint, request, response -> "api"
- test, spec, fixture, mock -> "testing"
- performance, memory, cache, query -> "performance"
- deploy, ci, docker, build -> "devops"
- config, env, settings -> "config"

**BLOCK if validation fails:**

```
JSONL validation failed:

Errors:
- key: must be lowercase-hyphen-separated, got "MyKey"
- type: must be one of [learned, decision, fact, pattern, investigation], got "bug"
- content: too vague - must be specific and searchable

Please provide corrected values.
```

**GATE ENFORCEMENT:** Do NOT proceed to Step 6 until all entries pass validation.

</validation_gate>
</step>

<step number="6" required="true" depends_on="5">
### Step 6: Write Knowledge Entries

**Append entries to knowledge.jsonl:**

```bash
# Append each validated entry as a single JSON line
echo '{"key":"learned-oauth-redirect-must-match","type":"learned","content":"OAuth redirect URI must match exactly including trailing slash","source":"agent","tags":["auth","oauth","security"],"ts":1706918400,"bead":"BD-001"}' >> .beads/memory/knowledge.jsonl
```

**Log as bead comments (if bead ID available):**

For each knowledge entry, also log it as a bead comment using the appropriate prefix:

```bash
bd comments add BD-001 "LEARNED: OAuth redirect URI must match exactly including trailing slash"
bd comments add BD-001 "PATTERN: Always verify OAuth redirect URIs match exactly, including protocol and trailing slash"
```

**Handle rotation:** If knowledge.jsonl exceeds 1000 lines after appending:
1. Move first 500 lines to `knowledge.archive.jsonl`
2. Keep remaining lines as new `knowledge.jsonl`

```bash
LINE_COUNT=$(wc -l < .beads/memory/knowledge.jsonl)
if [ "$LINE_COUNT" -gt 1000 ]; then
  head -500 .beads/memory/knowledge.jsonl >> .beads/memory/knowledge.archive.jsonl
  tail -n +501 .beads/memory/knowledge.jsonl > .beads/memory/knowledge.jsonl.tmp
  mv .beads/memory/knowledge.jsonl.tmp .beads/memory/knowledge.jsonl
fi
```
</step>

<step number="7" required="false" depends_on="6">
### Step 7: Cross-Reference & Pattern Detection

If similar knowledge found in Step 3:

**Add cross-reference tag:**
Include the key of the related entry in the tags array (e.g., `"tags": ["auth", "see-also:learned-oauth-token-expiry"]`).

**Detect recurring patterns:**

If 3+ entries share the same tags or describe similar issues, suggest creating a PATTERN entry that synthesizes the recurring theme:

```
Detected recurring pattern: 3 entries related to "auth" + "redirect"

Suggest creating a PATTERN entry?
1. Yes - create synthesized pattern entry
2. No - entries are distinct enough

Choose (1-2): _
```
</step>

</critical_sequence>

---

<decision_gate name="post-capture" wait_for_user="true">

## Decision Menu After Capture

After successful knowledge capture, present options and WAIT for user response:

```
Knowledge captured successfully.

Entries added:
- [key1]: [content summary]
- [key2]: [content summary]

Bead comments logged: [Yes/No - BD-XXX]

What's next?
1. Continue workflow (recommended)
2. View captured entries
3. Search related knowledge
4. Add more entries for this solution
5. Other
```

**Handle responses:**

**Option 1: Continue workflow**
- Return to calling skill/workflow
- Knowledge capture is complete

**Option 2: View captured entries**
- Display the JSONL entries that were written
- Present decision menu again

**Option 3: Search related knowledge**
- Run recall search with the tags from the new entries
- Display related knowledge
- Present decision menu again

**Option 4: Add more entries**
- Return to Step 4 to classify additional knowledge
- Useful when the solution reveals multiple insights

**Option 5: Other**
- Ask what they'd like to do

</decision_gate>

---

<integration_protocol>

## Integration Points

**Invoked by:**
- Manual invocation in conversation after solution confirmed
- Can be triggered by detecting confirmation phrases like "that worked", "it's fixed", etc.
- Called from `/beads-work` and `/beads-review` workflows

**Works with:**
- `auto-recall.sh` hook reads from knowledge.jsonl at session start
- `memory-capture.sh` hook captures knowledge from `bd comments add` commands
- `recall.sh` script provides manual search

**Data flow:**
1. This skill writes structured entries to `.beads/memory/knowledge.jsonl`
2. This skill also logs comments via `bd comments add` (which triggers `memory-capture.sh`)
3. At next session start, `auto-recall.sh` searches knowledge.jsonl and injects relevant entries

</integration_protocol>

---

<success_criteria>

## Success Criteria

Knowledge capture is successful when ALL of the following are true:

- All JSONL entries have valid schema (required fields, correct types)
- Entries appended to `.beads/memory/knowledge.jsonl`
- Bead comments logged via `bd comments add` (if bead ID available)
- Content is specific and searchable (not vague)
- Tags are appropriate for future recall
- User presented with decision menu and action confirmed

</success_criteria>

---

## Error Handling

**Missing context:**

- Ask user for missing details
- Don't proceed until critical info provided

**JSONL validation failure:**

- Show specific errors
- Present retry with corrected values
- BLOCK until valid

**Missing bead ID:**

- Knowledge can still be captured to knowledge.jsonl
- Skip `bd comments add` step
- Warn: "No active bead - knowledge saved to JSONL only, not linked to a bead"

**Knowledge.jsonl doesn't exist:**

- Create it: `touch .beads/memory/knowledge.jsonl`
- Continue normally

---

## Execution Guidelines

**MUST do:**
- Validate JSONL entries (BLOCK if invalid per Step 5 validation gate)
- Extract exact error messages from conversation
- Include specific, searchable content
- Use `bd comments add` with knowledge prefixes when bead ID is available
- Auto-tag based on content keywords

**MUST NOT do:**
- Skip JSONL validation
- Use vague descriptions (not searchable for auto-recall)
- Create markdown files in docs/solutions/ (this is NOT compound-docs)
- Write entries with missing required fields

---

## Quality Guidelines

**Good knowledge entries have:**

- Specific, searchable content (exact error messages, specific techniques)
- Appropriate type classification (LEARNED vs FACT vs PATTERN etc.)
- Relevant tags for future keyword-based recall
- Clear cause-and-effect (not just "what" but "why")
- Prevention guidance where applicable

**Avoid:**

- Vague content ("something was wrong with auth")
- Missing technical details ("fixed the code")
- Overly broad tags ("code", "bug")
- Duplicate content across entries (each entry should add unique value)

---

## Example Scenario

**User:** "That worked! The N+1 query is fixed."

**Skill activates:**

1. **Detect confirmation:** "That worked!" triggers auto-invoke
2. **Gather context:**
   - Area: Database queries in order processing
   - Symptom: Order listing taking >5 seconds, N+1 query when loading items
   - Failed attempts: Added pagination (didn't help)
   - Solution: Added eager loading with `.includes(:items)` on Order model
   - Root cause: Missing eager loading causing separate query per order item
3. **Check existing:** No similar knowledge found
4. **Determine type:**
   - LEARNED: The key insight about eager loading
   - PATTERN: Prevention rule for future queries
5. **Validate entries:**
   ```json
   {"key":"learned-n-plus-one-order-items-eager-load","type":"learned","content":"Order listing N+1 query fixed by adding .includes(:items) to Order model scope. Missing eager loading caused separate DB query per order item, taking >5 seconds for 100+ orders.","source":"agent","tags":["database","performance","n-plus-one","eager-loading"],"ts":1706918400,"bead":"BD-042"}
   {"key":"pattern-always-check-eager-loading-on-associations","type":"pattern","content":"When listing parent records that display child data, always use .includes() for associations. Check with bullet gem or query logs. Without eager loading, N records = N+1 queries.","source":"agent","tags":["database","performance","n-plus-one","eager-loading","prevention"],"ts":1706918401,"bead":"BD-042"}
   ```
   Valid.
6. **Write entries:**
   - Appended to `.beads/memory/knowledge.jsonl`
   - Logged bead comments:
     ```bash
     bd comments add BD-042 "LEARNED: Order listing N+1 query fixed by adding .includes(:items). Missing eager loading caused separate DB query per order item."
     bd comments add BD-042 "PATTERN: When listing parent records that display child data, always use .includes() for associations. Check with bullet gem or query logs."
     ```
7. **Cross-reference:** None needed (no similar knowledge)

**Output:**

```
Knowledge captured successfully.

Entries added:
- learned-n-plus-one-order-items-eager-load: Order listing N+1 query fixed by adding .includes(:items)...
- pattern-always-check-eager-loading-on-associations: When listing parent records...

Bead comments logged: Yes - BD-042

What's next?
1. Continue workflow (recommended)
2. View captured entries
3. Search related knowledge
4. Add more entries for this solution
5. Other
```

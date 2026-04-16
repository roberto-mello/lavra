---
name: lavra-knowledge
description: "Capture solved problems as knowledge entries for fast recall. Use when a solution should be preserved for future sessions."
allowed-tools: "- Read # Parse conversation context
  - Write # Append to knowledge.jsonl
  - Bash # Run bd commands, search knowledge
  - Grep # Search existing knowledge"
preconditions: "- Problem has been solved (not in-progress)
  - Solution has been verified working"
disable-model-invocation: true
metadata:
  source: Lavra
  site: 'https://lavra.dev'
  overwrite-warning: "Edit source at https://github.com/roberto-mello/lavra. Changes will be overwritten on next install."
---

# lavra-knowledge Skill

**Purpose:** Capture solved problems as structured JSONL entries in `.lavra/memory/knowledge.jsonl` and as bead comments, building a searchable knowledge base that auto-recall injects into future sessions.

## Overview

Captures problem solutions immediately after confirmation, creating structured knowledge entries stored in `.lavra/memory/knowledge.jsonl` for auto-recall search and logged as bead comments for traceability. Uses the five knowledge prefixes: LEARNED, DECISION, FACT, PATTERN, INVESTIGATION.

**Organization:** Append-only JSONL file. Each solved problem produces one or more entries. The auto-recall hook (`auto-recall.sh`) searches by keyword and injects relevant entries at session start.

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

**Non-trivial problems only:** multiple investigation attempts, tricky debugging, non-obvious solution, or future sessions would benefit.

**Skip for:** simple typos, obvious syntax errors, trivial fixes.
</step>

<step number="2" required="true" depends_on="1">
### Step 2: Gather Context

Extract from conversation history:

**Required:**

- **Area/module**: Which part of the codebase had the problem
- **Symptom**: Observable error/behavior (exact error messages)
- **Investigation attempts**: What didn't work and why
- **Root cause**: Technical explanation of actual problem
- **Solution**: What fixed it (code/config changes)
- **Prevention**: How to avoid in future

**BLOCKING REQUIREMENT:** If critical context is missing (area, exact error, or resolution steps), ask and WAIT before proceeding to Step 3:

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

Search `knowledge.jsonl` for similar issues:

```bash
# Search by error message keywords
grep "exact error phrase" .lavra/memory/knowledge.jsonl

# Search using recall script if available
.lavra/memory/recall.sh "keyword1 keyword2"
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

Most solved problems produce 1-3 entries. A complex debugging session might produce 1 LEARNED (key insight), 1 PATTERN (prevention rule), 1 INVESTIGATION (debugging path for future reference).
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

**GATE ENFORCEMENT:** Do not proceed to Step 6 until all entries pass validation.

</validation_gate>
</step>

<step number="6" required="true" depends_on="5">
### Step 6: Write Knowledge Entries

**Append entries to `knowledge.jsonl`:**

```bash
# Append each validated entry as a single JSON line
echo '{"key":"learned-oauth-redirect-must-match","type":"learned","content":"OAuth redirect URI must match exactly including trailing slash","source":"agent","tags":["auth","oauth","security"],"ts":1706918400,"bead":"BD-001"}' >> .lavra/memory/knowledge.jsonl
```

**Log as bead comments (if bead ID available):**

For each entry, log a bead comment using the appropriate prefix:

```bash
bd comments add BD-001 "LEARNED: OAuth redirect URI must match exactly including trailing slash"
bd comments add BD-001 "PATTERN: Always verify OAuth redirect URIs match exactly, including protocol and trailing slash"
```

**Rotation:** If `knowledge.jsonl` exceeds 1000 lines after appending, move first 500 lines to `knowledge.archive.jsonl` and keep remaining lines as new `knowledge.jsonl`.

```bash
LINE_COUNT=$(wc -l < .lavra/memory/knowledge.jsonl)
if [ "$LINE_COUNT" -gt 1000 ]; then
  head -500 .lavra/memory/knowledge.jsonl >> .lavra/memory/knowledge.archive.jsonl
  tail -n +501 .lavra/memory/knowledge.jsonl > .lavra/memory/knowledge.jsonl.tmp
  mv .lavra/memory/knowledge.jsonl.tmp .lavra/memory/knowledge.jsonl
fi
```
</step>

<step number="7" required="false" depends_on="6">
### Step 7: Cross-Reference & Pattern Detection

If similar knowledge found in Step 3:

**Add cross-reference tag:** include the key of the related entry in the tags array (e.g., `"tags": ["auth", "see-also:learned-oauth-token-expiry"]`).

**Detect recurring patterns:** if 3+ entries share the same tags or describe similar issues, suggest creating a PATTERN entry that synthesizes the recurring theme:

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

After successful capture, present options and WAIT for user response:

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

**Option 1:** Return to calling skill/workflow. Capture is complete.

**Option 2:** Display the JSONL entries written. Present menu again.

**Option 3:** Run recall search with the new entry tags. Display related knowledge. Present menu again.

**Option 4:** Return to Step 4 to classify additional knowledge. Useful when the solution reveals multiple insights.

**Option 5:** Ask what they'd like to do.

</decision_gate>

---

<integration_protocol>

## Integration Points

**Invoked by:** manual invocation after solution confirmed, confirmation phrases ("that worked", "it's fixed"), or called from `/lavra-work` and `/lavra-review` workflows.

**Works with:**
- `auto-recall.sh` — reads `knowledge.jsonl` at session start
- `memory-capture.sh` — captures knowledge from `bd comments add` commands
- `recall.sh` — manual search

**Data flow:**
1. Writes structured entries to `.lavra/memory/knowledge.jsonl`
2. Logs comments via `bd comments add` (triggers `memory-capture.sh`)
3. At next session start, `auto-recall.sh` searches and injects relevant entries

</integration_protocol>

---

<success_criteria>

## Success Criteria

Capture is successful when ALL of the following are true:

- All JSONL entries have valid schema (required fields, correct types)
- Entries appended to `.lavra/memory/knowledge.jsonl`
- Bead comments logged via `bd comments add` (if bead ID available)
- Content is specific and searchable
- Tags are appropriate for future recall
- User presented with decision menu and action confirmed

</success_criteria>

---

## Error Handling

**Missing context:** ask for missing details. Do not proceed until critical info is provided.

**JSONL validation failure:** show specific errors, present retry with corrected values. BLOCK until valid.

**Missing bead ID:** knowledge can still be captured to `knowledge.jsonl`. Skip `bd comments add`. Warn: "No active bead - knowledge saved to JSONL only, not linked to a bead."

**`knowledge.jsonl` doesn't exist:** create it with `touch .lavra/memory/knowledge.jsonl` and continue.

---

## Execution Guidelines

**MUST do:**
- Validate JSONL entries (BLOCK if invalid per Step 5 gate)
- Extract exact error messages from conversation
- Include specific, searchable content
- Use `bd comments add` with knowledge prefixes when bead ID is available
- Auto-tag based on content keywords

**MUST NOT do:**
- Skip JSONL validation
- Use vague descriptions
- Create markdown files in `docs/solutions/` (this is not compound-docs)
- Write entries with missing required fields

---

## Quality Guidelines

**Good entries have:** specific, searchable content (exact error messages, specific techniques); appropriate type classification; relevant tags; clear cause-and-effect; prevention guidance where applicable.

**Avoid:** vague content ("something was wrong with auth"), missing technical details ("fixed the code"), overly broad tags ("code", "bug"), duplicate content across entries.

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
   - Appended to `.lavra/memory/knowledge.jsonl`
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

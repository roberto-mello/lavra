# Knowledge JSONL Schema

**Storage location:** `.beads/memory/knowledge.jsonl`

Each line in the JSONL file is a complete, valid JSON object representing one knowledge entry.

## Required Fields

- **key** (string): Unique identifier, lowercase-hyphen-separated. Format: `{type}-{descriptive-slug}` (e.g., `learned-oauth-redirect-must-match-exactly`)
- **type** (enum): One of `learned`, `decision`, `fact`, `pattern`, `investigation`
- **content** (string): Clear, specific description of the knowledge. Must be searchable -- include exact error messages, specific techniques, and cause-effect explanations.
- **source** (enum): One of `user`, `agent`, `subagent`
- **tags** (array of strings): Lowercase keywords for search. Auto-detected from content where possible. Maximum 8 tags.
- **ts** (integer): Unix timestamp of when the knowledge was captured
- **bead** (string): Bead ID (e.g., `BD-001`) if linked to a specific bead, or empty string `""` if not linked

## Knowledge Type Definitions

| Type | Description | Use When |
|------|-------------|----------|
| `learned` | Non-obvious insight discovered through debugging or investigation | You discovered something that would save future sessions time |
| `decision` | Architectural or implementation choice with rationale | A deliberate choice was made between alternatives |
| `fact` | Confirmed factual constraint, requirement, or behavior | A hard truth about the system, API, or framework |
| `pattern` | Recurring pattern (positive or negative) to follow or avoid | A rule that should be applied consistently |
| `investigation` | Investigation path and findings for future reference | The debugging journey itself has value for similar future issues |

## Validation Rules

1. **key** must be lowercase, hyphen-separated, and descriptive
2. **type** must be one of the five allowed values (case-sensitive)
3. **content** must be specific and searchable (no vague descriptions like "fixed a bug")
4. **source** must be one of: `user`, `agent`, `subagent`
5. **tags** must be an array of lowercase strings, max 8 items
6. **ts** must be a valid Unix timestamp (integer)
7. **bead** must be a string (bead ID or empty string)

## Auto-Tag Detection

When writing entries, detect keywords in content and auto-add relevant tags:

| Keywords in Content | Auto-Tag |
|---------------------|----------|
| auth, oauth, jwt, session, login, token | `auth` |
| database, postgres, sql, migration, query, index | `database` |
| react, component, hook, state, render | `react` |
| api, endpoint, request, response, rest, graphql | `api` |
| test, spec, fixture, mock, assert | `testing` |
| performance, memory, cache, n+1, slow, optimize | `performance` |
| deploy, ci, docker, build, pipeline | `devops` |
| config, env, settings, environment | `config` |
| security, xss, csrf, injection, vulnerability | `security` |
| css, style, layout, responsive, tailwind | `frontend` |
| error, exception, crash, timeout, retry | `errors` |
| git, branch, merge, rebase, worktree | `git` |

## Example Valid Entries

```jsonl
{"key":"learned-oauth-redirect-must-match-exactly","type":"learned","content":"OAuth redirect URI must match exactly including trailing slash. Mismatched URI causes silent auth failure with no error message in logs.","source":"agent","tags":["auth","oauth","security"],"ts":1706918400,"bead":"BD-001"}
{"key":"decision-use-connection-pooling","type":"decision","content":"Chose connection pooling over per-request connections for database access. Per-request was causing connection exhaustion under load (>50 concurrent users). PgBouncer in transaction mode solved it.","source":"user","tags":["database","performance","config"],"ts":1706918500,"bead":"BD-002"}
{"key":"fact-postgres-jsonb-array-cast","type":"fact","content":"PostgreSQL JSONB columns require explicit casting for array operations. Use jsonb_array_elements() for iteration, not direct array syntax. Without cast, query returns empty result instead of error.","source":"agent","tags":["database","postgres"],"ts":1706918600,"bead":"BD-003"}
{"key":"pattern-check-nil-before-nested-hash","type":"pattern","content":"Always use dig() or safe navigation (&.) when accessing nested hash keys in API responses. Direct access raises NoMethodError on nil, which crashes background jobs silently.","source":"agent","tags":["api","errors","pattern"],"ts":1706918700,"bead":"BD-004"}
{"key":"investigation-memory-leak-retained-objects","type":"investigation","content":"Debugged memory leak in worker process. Profiler (memory_profiler gem) showed retained String objects from log formatting. Logger was interpolating large request bodies into debug messages even when debug level was disabled. Fix: wrap debug logs in block form logger.debug { expensive_string }.","source":"agent","tags":["performance","memory","investigation"],"ts":1706918800,"bead":"BD-005"}
```

## Rotation Policy

When `knowledge.jsonl` exceeds 1000 lines:
1. First 500 lines are appended to `knowledge.archive.jsonl`
2. Remaining 500 lines become the new `knowledge.jsonl`
3. Use `recall.sh --all` to search both current and archive

## Bead Comment Mapping

Each knowledge entry type maps to a bead comment prefix:

| Entry Type | Bead Comment Prefix |
|------------|---------------------|
| `learned` | `LEARNED:` |
| `decision` | `DECISION:` |
| `fact` | `FACT:` |
| `pattern` | `PATTERN:` |
| `investigation` | `INVESTIGATION:` |

When logging to both knowledge.jsonl AND bead comments:

```bash
# JSONL entry
echo '{"key":"learned-example","type":"learned","content":"...","source":"agent","tags":["tag"],"ts":1706918400,"bead":"BD-001"}' >> .beads/memory/knowledge.jsonl

# Corresponding bead comment
bd comments add BD-001 "LEARNED: [content from entry]"
```

## Search Behavior

The `auto-recall.sh` hook searches knowledge.jsonl using these strategies:

1. Extract keywords (4+ chars) from open/in-progress bead titles
2. Add keywords from git branch name
3. Search knowledge.jsonl for each keyword (case-insensitive grep)
4. Deduplicate results
5. Return top 10 most relevant entries
6. Fall back to 10 most recent entries if no search terms

# Architecture

Memory system design, plugin structure, and changes from the upstream Compound Engineering plugin.

[Back to README](../README.md)

## Memory System

Knowledge is stored in two formats:

- **SQLite FTS5** (`knowledge.db`) -- Primary search backend with full-text search and BM25 ranking
- **JSONL** (`knowledge.jsonl`) -- Portable export format, grep-compatible fallback

Both are written to simultaneously. If `sqlite3` is unavailable, only JSONL is written and grep-based search is used automatically.

```json
{
  "key": "learned-oauth-redirect-must-match-exactly",
  "type": "learned",
  "content": "OAuth redirect URI must match exactly",
  "source": "user",
  "tags": ["oauth", "auth", "security"],
  "ts": 1706918400,
  "bead": "BD-001"
}
```

- **FTS5 Search**: Uses porter stemming and BM25 ranking -- "webhook authentication" finds entries about HMAC signature verification even when those exact words don't appear together
- **Auto-tagging**: Keywords detected and added as tags
- **Git-tracked**: Knowledge files can be committed to git for team sharing and portability
- **Conflict-free collaboration**: Multiple users can capture knowledge simultaneously without merge conflicts
- **Auto-sync**: First session after `git pull` automatically imports new knowledge into local search index
- **Rotation**: After 5000 entries, oldest 2500 archived (JSONL only)
- **Search**: `.beads/memory/recall.sh "keyword"` or automatic at session start

## Plugin Structure

```
beads-compound-plugin/              # Marketplace root
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── beads-compound/             # Plugin root
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── agents/
│       │   ├── review/             # 14 review agents
│       │   ├── research/           # 5 research agents
│       │   ├── design/             # 3 design agents
│       │   ├── workflow/           # 5 workflow agents
│       │   └── docs/               # 1 docs agent
│       ├── commands/               # 26 commands
│       ├── skills/                 # 15 skills
│       ├── hooks/                  # 4 hooks + shared library + hooks.json
│       ├── scripts/
│       └── .mcp.json
├── install.sh
├── uninstall.sh
├── CLAUDE.md
└── README.md
```

## Changes from Compound Engineering

This plugin is a fork of [compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) (MIT license) with the following changes:

### Memory System

- Replaced markdown-based knowledge storage with beads-based persistent memory (`.beads/memory/knowledge.jsonl`)
- SQLite FTS5 full-text search with BM25 ranking for knowledge recall, improving precision by 18%, recall by 17%, and MRR by 24% over grep-based search across 25 benchmark queries
- Automatic knowledge capture from `bd comments add` with typed prefixes (LEARNED/DECISION/FACT/PATTERN/INVESTIGATION), dual-writing to SQLite (for fast searching with fuzzy matching) and JSONL (for committing to git)
- Automatic knowledge recall at session start based on open beads and git branch context
- Subagent knowledge enforcement via `SubagentStop` hook
- All workflows create and update beads instead of markdown files
- Automatic one-time backfill from existing JSONL and beads.db comments on first FTS5 run
- First session (like cloning a beads-compound enabled repo) triggers rebuilding the FTS5 index from the JSONL in git. Everything self-heals on first session.

### Performance Optimizations

- **Context budget optimization (94% reduction)**: Plugin now uses only 8,227 chars of Claude Code's 16,000 char description budget. This prevents components from being silently excluded from Claude's context.
  - Trimmed all 28 agent descriptions to under 250 chars, moving verbose examples into agent bodies wrapped in `<examples>` tags
  - Added `disable-model-invocation: true` to 17 manual utility commands (they remain available when explicitly invoked via `/command-name` but don't clutter Claude's auto-suggestion context)
  - Added `disable-model-invocation: true` to 7 manual utility skills (beads-knowledge, create-agent-skills, file-todos, skill-creator, git-worktree, rclone, gemini-imagegen)
  - Core beads workflow commands (`/beads-brainstorm`, `/beads-plan`, `/beads-work`, `/beads-parallel`, `/beads-review`, `/beads-compound`, `/beads-deepen`, `/beads-plan-review`) remain fully auto-discoverable
- **Model tier assignments**: Each agent specifies a `model:` field (haiku/sonnet/opus) based on reasoning complexity, reducing costs 60-70% compared to running all agents on the default model. High-frequency agents like `learnings-researcher` run on Haiku; deep reasoning agents like `architecture-strategist` run on Opus.

### Structural Changes

- Rewrote `learnings-researcher` to search `knowledge.jsonl` instead of markdown docs
- Adapted `code-simplicity-reviewer` to protect `.beads/memory/` files
- Renamed `compound-docs` skill to `beads-knowledge`
- Added `beads-` prefix to all commands to avoid conflicts

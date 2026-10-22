---
title: Troubleshooting
description: Debugging guides for memory features, common issues, and platform migration
order: 6
---

# Troubleshooting

Debugging guides for memory features, common issues, and migration across all supported platforms.

[Back to README](../README.md)

## Memory Features Not Working

If automatic knowledge capture or recall isn't working, check your setup:

### Claude Code

```bash
# Check if hooks are installed
ls -la .claude/hooks/

# Check hook configuration
cat .claude/settings.json | jq '.hooks'

# Check memory directory
ls -la .lavra/memory/

# Test knowledge capture manually
bd comments add <BEAD_ID> "LEARNED: Testing memory capture"
tail -1 .lavra/memory/knowledge.jsonl

# Test recall manually
bash .lavra/memory/recall.sh
```

**Expected hooks in settings.json:**
- `SessionStart`: `auto-recall.sh`
- `PostToolUse` (Bash matcher): `memory-capture.sh`
- `SubagentStop`: `subagent-wrapup.sh`
- `TeammateIdle`: `teammate-idle-check.sh`

### OpenCode

```bash
# Check if plugin is installed
# Project-specific:
ls -la .opencode/plugins/lavra/plugin.ts

# Global:
ls -la ~/.config/opencode/plugins/lavra/plugin.ts

# Check if commands/agents/skills/hooks are installed
ls -la .opencode/commands/
ls -la .opencode/agents/
ls -la .opencode/skills/
ls -la .opencode/hooks/

# Check if plugin is loading (look for console.log messages in OpenCode output)
# Expected: "[lavra] Plugin loaded successfully"
# Expected: "[lavra] session.created hook triggered"

# Check memory directory
ls -la .lavra/memory/

# Test knowledge capture manually
bd comments add <BEAD_ID> "LEARNED: Testing memory capture"
tail -1 .lavra/memory/knowledge.jsonl

# Check plugin dependencies are installed
ls -la .opencode/plugins/lavra/node_modules/
# Or for global: ls -la ~/.config/opencode/plugins/lavra/node_modules/
```

### Gemini CLI

```bash
# Check if hooks are installed (project-specific)
ls -la .gemini/hooks/

# Or global install
ls -la ~/.config/gemini/hooks/

# Check hook configuration in gemini-extension.json
cat gemini-extension.json | jq '.hooks'

# Check memory directory
ls -la .lavra/memory/

# Test knowledge capture manually
bd comments add <BEAD_ID> "LEARNED: Testing memory capture"
tail -1 .lavra/memory/knowledge.jsonl
```

### Cortex Code

**Hooks not loading:**
- Check `~/.snowflake/cortex/hooks.json` exists and has SessionStart/PostToolUse/SubagentStop entries
- For project-specific installs, check `.cortex/hooks/` directory exists

**Memory not capturing:**
- Ensure `.cortex/hooks/memory-capture.sh` (project) or `~/.snowflake/cortex/hooks/memory-capture.sh` (global) exists and is executable

**Agent model selection:**
- Uses haiku/sonnet/opus in Task tool (same tier names as Claude)

### Codex

**`/lavra-*` not recognized:**
- Expected in the current direct-install path.
- Use skills invocation instead: `$lavra-plan ...`, `$lavra-work ...`.
- Current plugin marketplace install path also invokes as `$lavra-*` in Codex today.
- Slash-command parity is planned via future Codex plugin command support.

**SessionStart invalid JSON errors:**
- Ensure `~/.codex/hooks.json` `SessionStart` runs only:
  - `bash ~/.codex/hooks/check-memory.sh codex`
- Ensure `~/.codex/hooks/` and `.codex/hooks/` both contain:
  - `check-memory.sh`, `auto-recall.sh`, `memory-capture.sh`, `sanitize-content.sh`

**Memory not capturing in Codex:**
- Check PostToolUse matcher is `Bash` in `~/.codex/hooks.json`
- Verify dispatcher command shape:
  - `bash ~/.codex/hooks/dispatch-hook.sh .codex/hooks memory-capture.sh`

## Common Issues

**No knowledge entries being saved:**
- Ensure you're using `bd comments add <BEAD_ID> "LEARNED: ..."` format (not `bd comment`)
- Check that the hook is configured in settings.json with correct matcher (e.g., `"Bash"` for PostToolUse)
- Verify `.lavra/memory/` directory exists
- Test the hook manually using the platform-specific commands above

**Knowledge recall not showing context:**
- Check that `auto-recall.sh` is in SessionStart hooks
- Verify you have open or in_progress beads: `bd list --status=open`
- Run manual recall to test: `bash .lavra/memory/recall.sh`
- Check if `knowledge.jsonl` has entries: `wc -l .lavra/memory/knowledge.jsonl`

**SQLite search not working:**
- Verify `sqlite3` is installed: `which sqlite3`
- Check database exists: `ls -la .lavra/memory/knowledge.db`
- System automatically falls back to grep if SQLite unavailable

**Duplicate entries in knowledge.jsonl:**
- This was fixed in v0.6.0+. Update to latest version.
- To clean up existing duplicates:
  ```bash
  cd .lavra/memory
  cp knowledge.jsonl knowledge.jsonl.backup
  jq -s 'group_by(.key) | map(max_by(.ts)) | .[] | @json' knowledge.jsonl > knowledge.jsonl.tmp
  mv knowledge.jsonl.tmp knowledge.jsonl
  ```

## Migrating Existing Projects

If you already have a project using the plugin with an existing `knowledge.jsonl`, re-running the installer will upgrade it:

```bash
# Re-run the installer (safe to run on existing installs)
bash /path/to/lavra/install.sh /path/to/your-project
```

On the next Claude Code session start, the system will automatically:
1. Create `knowledge.db` with the FTS5 schema
2. Import all entries from your existing `knowledge.jsonl` and `knowledge.archive.jsonl`
3. Import any knowledge-prefixed comments from `beads.db`

After this one-time import, new entries are written to both formats. Your existing JSONL files remain intact and continue to be written to.

**Prerequisite**: `sqlite3` must be available (pre-installed on macOS and most Linux distributions). If missing, the system gracefully falls back to grep-based search with no errors.

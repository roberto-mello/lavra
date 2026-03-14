# Autonomous Execution

How to configure permissions for `/beads-work-ralph` and `/beads-work-teams` modes.

## Why Permissions Matter

`/beads-work-ralph` and `/beads-work-teams` spawn subagents (or persistent worker teammates) that execute code autonomously. These agents need to:

- Run shell commands (`bd`, `git`, test suites)
- Read, write, and edit source files
- Search the codebase with Grep/Glob

By default, Claude Code prompts for human approval on each tool use. In autonomous mode, there is no human at the keyboard -- unapproved tool calls cause workers to stall silently, wasting turns and context.

## Recommended: Granular Permissions

Add an `allow` list to your project's `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(bd *)",
      "Bash(.beads/memory/*)",
      "Bash(npm test)",
      "Bash(bun test)",
      "Read",
      "Write",
      "Edit",
      "Grep",
      "Glob"
    ]
  }
}
```

This pre-approves the specific tools and command patterns that beads workflows use, while leaving everything else gated behind approval.

**Adapt to your project.** If your test command is `pytest` or `cargo test`, add those patterns. If workers need `make build`, add `Bash(make *)`. Only allow what your workflow actually needs.

## Nuclear Option: --dangerously-skip-permissions

Claude Code accepts `--dangerously-skip-permissions` at launch, which bypasses all tool approval prompts globally.

```bash
claude --dangerously-skip-permissions
```

**When to use:**
- Throwaway environments (CI, containers, disposable VMs)
- Fully trusted codebases where the blast radius is acceptable

**When NOT to use:**
- Production machines with credentials, SSH keys, or secrets accessible
- Repos you don't fully control (forks, open-source contributions)
- Any environment where an unexpected `rm -rf` or `curl | bash` would hurt

This flag disables ALL permission checks, not just the ones beads needs. There is no granularity.

## Per-Project vs Global Settings

| Location | Scope | Use when |
|----------|-------|----------|
| `.claude/settings.json` | This project only | You want autonomous execution for one repo |
| `~/.claude/settings.json` | All projects | You always run with the same permission set |

Project settings override global settings. If you set `allow` in both, the project-level list wins.

**Recommendation:** Use per-project settings. Different repos have different risk profiles, and a blanket global allow list is harder to audit.

## Security Trade-offs

Granting autonomous tool access means:

- **Bash commands run without review.** A buggy agent can execute destructive commands. The granular approach limits this to specific patterns (`git *`, `bd *`, test runners), but those patterns are still broad.
- **File writes happen without approval.** Agents can overwrite any file. They follow ownership lists from the orchestrator, but enforcement is advisory, not technical.
- **No human checkpoint.** In default mode, each tool call is a chance to catch mistakes. Autonomous mode removes that safety net.

**Mitigations:**
- Use feature branches -- never run `--ralph`/`--teams` on main
- Review the pre-push diff before pushing
- Keep `--retries` low (default 5) to limit blast radius from a confused agent
- Run in a worktree or container for full isolation
- Use granular permissions instead of `--dangerously-skip-permissions`

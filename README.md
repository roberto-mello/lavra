# Beads Compound

[![License](https://img.shields.io/github/license/roberto-mello/beads-compound-plugin)](LICENSE)
[![Release](https://img.shields.io/github/v/release/roberto-mello/beads-compound-plugin)](https://github.com/roberto-mello/beads-compound-plugin/releases)
[![Beads CLI](https://img.shields.io/badge/requires-beads%20CLI-blue)](https://github.com/steveyegge/beads)

> This README reflects latest developments. [Download a release](https://github.com/roberto-mello/beads-compound-plugin/releases) for stable versions.

**AI agents that actually learn from their work.**

Agents forget everything between sessions. You fix the same OAuth bug twice. You re-explain architecture patterns every day. This plugin gives agents persistent memory -- they capture lessons during work, recall them automatically in future sessions, and compound knowledge over time.

<div align="center">
  <img src="images/beads-compound.jpg" alt="Beads Compound Engineering Infographic" />
</div>

## Getting Started

**Prerequisites:** [beads CLI](https://github.com/steveyegge/beads) (`bd`), `jq`, `sqlite3`

```bash
npx beads-compound@latest
```

Or manual install:

```bash
git clone https://github.com/roberto-mello/beads-compound-plugin.git
cd beads-compound-plugin
./install.sh               # Claude Code (default)
./install.sh --opencode    # OpenCode
./install.sh --gemini      # Gemini CLI
./install.sh --cortex      # Cortex Code
```

Use `--yes` to skip confirmation prompts. See [docs/PLATFORMS.md](docs/PLATFORMS.md) for platform-specific setup details.

## The Problem

**Without plugin:**
```bash
# Monday - you fix OAuth redirect bug
Agent: "How should I handle OAuth redirects?"
You: "They must match exactly, including trailing slash"
Agent: *implements fix*

# Wednesday - similar GitHub OAuth feature
Agent: "How should I handle OAuth redirects?"
You: *explains the same thing again*
```

**With plugin:**
```bash
# Monday
Agent: *implements OAuth fix*
Agent: `LEARNED: OAuth redirect_uri must match exactly, including trailing slash`

# Wednesday
Agent: *automatically recalls: "OAuth redirect_uri must match exactly..."*
Agent: *implements correctly without asking*
```

## Three-Phase Workflow

For features that need thorough planning, `/beads-design` orchestrates the full pipeline as a single command:

```
/beads-design "oauth authentication"
```

### Phase 1: Brainstorm (`/beads-brainstorm`)

Interactive dialogue to explore requirements. Identifies gray areas, captures decisions, surfaces trade-offs before any code is written.

### Phase 2: Design (`/beads-design` orchestrates automatically)

Runs the full planning pipeline -- plan, deepen with parallel research agents, and multi-agent plan review -- for each phase. Single command, zero manual sequencing.

```
  Brainstorm (interactive)
        |
  Plan (/beads-plan) -----> Creates epic with phased child beads
        |
  Deepen (/beads-deepen) -> 20-40 research agents enrich each phase
        |
  Review (/beads-plan-review) -> 4 agents validate the plan
        |
  Ready for implementation
```

### Phase 3: Execute (`/beads-work` or `/beads-parallel`)

Implement phase by phase with full lifecycle tracking, knowledge capture, and quality checks.

```bash
/beads-work BD-001          # One bead at a time
/beads-parallel BD-001      # Multiple beads in parallel
/beads-parallel BD-001 --ralph   # Autonomous with self-correction
/beads-parallel BD-001 --teams   # Persistent worker teammates
```

## Quick Mode

For small tasks that don't need the full pipeline:

```bash
/beads-plan "fix the login bug"    # Creates epic with child beads
/beads-work BD-001                 # Implement, capture knowledge, close
```

## What's Included

- **28 specialized agents** -- review, research, design, workflow, docs
- **27 commands** -- brainstorm, plan, design, execute, review, recall
- **15 skills** -- worktrees, Rails style, DSPy, browser automation
- **Automatic knowledge capture and recall** -- dual SQLite FTS5 + JSONL
- **Multi-platform** -- Claude Code, OpenCode, Gemini CLI, Cortex Code

See [docs/CATALOG.md](docs/CATALOG.md) for the full listing of all agents, commands, and skills.

## How Memory Works

Knowledge is captured automatically from `bd comments add` with typed prefixes (LEARNED, DECISION, FACT, PATTERN, INVESTIGATION) and stored in both SQLite FTS5 (for fast BM25-ranked search) and JSONL (for git-tracked team sharing). At session start, relevant knowledge is recalled based on your current beads and git branch context.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full memory system design.

## Multi-Platform Support

Works with Claude Code (primary), OpenCode, Gemini CLI, and Cortex Code. Each platform gets the memory system; commands, agents, and skills availability varies by platform.

See [docs/PLATFORMS.md](docs/PLATFORMS.md) for setup instructions and platform-specific details.

## Cost Optimization

Agents use tiered models (Haiku/Sonnet/Opus) based on reasoning complexity -- 60-70% cheaper than running all agents on Opus. High-frequency agents like `learnings-researcher` run on Haiku; deep reasoning agents like `architecture-strategist` run on Opus.

See [docs/COST.md](docs/COST.md) for the full tier breakdown.

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues and debugging steps.

## Uninstall

```bash
./uninstall.sh                     # Global uninstall
./uninstall.sh /path/to/project    # Project-specific
```

Removes plugin components but preserves `.beads/` data and accumulated knowledge.

## Acknowledgments

[Every](https://every.to)'s [writing on compound engineering](https://every.to/chain-of-thought/compound-engineering-how-every-codes-with-agents) is well worth reading.

Task tracking is powered by Steve Yegge's [Beads](https://github.com/steveyegge/beads).

Built by Roberto Mello based on [compound-engineering](https://github.com/EveryInc/compound-engineering-plugin) by the team at [Every](https://every.to), extending their philosophy with persistent memory and performance optimizations.

## License

MIT (same as compound-engineering-plugin)

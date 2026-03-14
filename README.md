# Beads Compound

[![License](https://img.shields.io/github/license/roberto-mello/beads-compound-plugin)](LICENSE)
[![Release](https://img.shields.io/github/v/release/roberto-mello/beads-compound-plugin)](https://github.com/roberto-mello/beads-compound-plugin/releases)
[![Beads CLI](https://img.shields.io/badge/requires-beads%20CLI-blue)](https://github.com/steveyegge/beads)

A development orchestrator that makes each unit of work make the next one easier.

## The Pipeline

```
/beads-design  -->  /beads-work  -->  /beads-qa  -->  /beads-ship
```

**Design** orchestrates the full planning pipeline as a single command: interactive brainstorm, structured plan with phased beads, parallel domain-matched research agents, plan revision, and adversarial review by 4 agents. The output is detailed enough that implementation is mechanical.

**Work** implements the plan with built-in quality gates. Auto-routes between single-bead and multi-bead parallel execution. Includes mandatory knowledge capture inline, self-review with fix loop, and knowledge curation before closing.

**QA** runs browser-based verification against the running app using headless Chromium. Maps changed files to routes, tests interactions and console errors, takes screenshots. Skips gracefully when changes are backend-only.

**Ship** goes from "code is ready" to "PR is open" in one command. Rebases on main, runs tests, scans for secrets and debug leftovers, creates the PR, closes beads, and pushes the backup.

## Knowledge Compounding

Every stage both consumes and produces knowledge. This is what separates beads-compound from a command collection.

```
brainstorm  --DECISION-->  design
design      <--LEARNED/PATTERN--  recall from prior work
research    --FACT/INVESTIGATION-->  revise plan
work        --LEARNED (inline)-->  mandatory knowledge gate
review      --LEARNED-->  issues found become future recall
learn       structures raw entries into searchable knowledge
retro       synthesizes patterns across time, surfaces gaps
```

Knowledge is stored in `.beads/memory/knowledge.jsonl` (git-tracked, team-shareable) with SQLite FTS5 for ranked search. At session start, relevant entries are recalled automatically based on your current beads and git branch. When you hit the same OAuth bug next month, the agent already knows the fix.

## Quick Start

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

Then use the three-command workflow:

```bash
/beads-design "I want users to upload photos"   # brainstorm + plan + research + review
/beads-work                                      # implement + review + learn
/beads-ship                                      # rebase, test, PR, close beads, push
```

<details>
<summary><strong>Supporting Commands</strong></summary>

| Command | Purpose |
|---------|---------|
| `/beads-quick` | Fast-track small tasks; escalates to full pipeline if complexity warrants it |
| `/beads-learn` | Targeted knowledge extraction -- structures raw comments into searchable entries |
| `/beads-recall` | Mid-session knowledge search when you need prior context |
| `/beads-checkpoint` | Save progress and sync state without closing beads |
| `/beads-qa` | Browser-based QA verification (when building web apps) |
| `/beads-retro` | Weekly analytics, team breakdown, and knowledge synthesis |
| `/beads-import` | Import markdown plans into beads |
| `/beads-triage` | Prioritize and categorize beads |
| `/changelog` | Generate release changelogs |

</details>

<details>
<summary><strong>Power-User Commands</strong></summary>

| Command | Purpose |
|---------|---------|
| `/beads-plan` | Run the plan phase manually (creates epic with phased child beads) |
| `/beads-research` | Run domain-matched research agents manually |
| `/beads-plan-review` | Run adversarial 4-agent plan review manually |
| `/beads-review` | Full multi-agent code review (15 reviewers across security, performance, architecture, style) |
| `/beads-work-ralph` | Autonomous retry mode with self-correction |
| `/beads-work-teams` | Persistent worker teammates with COMPLETED/ACCEPTED protocol |

</details>

## Agents

29 specialized agents across 5 categories make the system smarter than a generic LLM. Each agent runs at the right model tier (Haiku for high-frequency lookups, Opus for deep reasoning) to keep costs 60-70% lower than running everything on the most expensive model.

- **Review (15):** architecture, security, performance, data integrity, deployment, Rails/Python/TypeScript style, frontend races, migration drift, pattern recognition, simplicity
- **Research (5):** best practices, framework docs (via Context7 MCP), git history, knowledge recall, repo analysis
- **Design (3):** design implementation, design iteration, Figma sync
- **Workflow (5):** bug reproduction, style editing, linting, PR comment resolution, spec flow analysis
- **Docs (1):** Andrew Kane-style README writer

See [docs/CATALOG.md](docs/CATALOG.md) for the full listing.

## Installation

The installer copies agents, commands, skills, and hooks into your project's `.claude/` directory. Memory is stored in `.beads/memory/` and tracked by git for team sharing.

```bash
npx beads-compound@latest              # Recommended
./install.sh                           # Claude Code
./install.sh --opencode                # OpenCode
./install.sh --gemini                  # Gemini CLI
./install.sh --cortex                  # Cortex Code
```

Use `--yes` to skip confirmation prompts. See [docs/PLATFORMS.md](docs/PLATFORMS.md) for platform details.

Uninstall:

```bash
./uninstall.sh                         # Global
./uninstall.sh /path/to/project        # Project-specific
```

Preserves `.beads/` data and accumulated knowledge.

## Multi-Platform

Works with Claude Code (primary), OpenCode, Gemini CLI, and Cortex Code. Every platform gets the memory system. Commands, agents, and skills availability varies by platform. See [docs/PLATFORMS.md](docs/PLATFORMS.md).

## Acknowledgments

[Every](https://every.to)'s [writing on compound engineering](https://every.to/chain-of-thought/compound-engineering-how-every-codes-with-agents) is well worth reading. Task tracking is powered by Steve Yegge's [Beads](https://github.com/steveyegge/beads). Built by Roberto Mello, extending [compound-engineering](https://github.com/EveryInc/compound-engineering-plugin) by the team at [Every](https://every.to) with persistent memory and multi-agent orchestration.

## License

MIT (same as compound-engineering-plugin)

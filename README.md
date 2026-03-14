# beads-compound

**beads-compound turns your AI coding agent into a development team that gets smarter with every task.**

A plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that orchestrates the full development lifecycle -- from brainstorming to shipping -- while automatically capturing and recalling knowledge so each unit of work makes the next one easier.

### Without beads-compound

- The agent forgets everything between sessions -- you re-explain context every time
- Planning is shallow: it jumps to code before thinking through the problem
- Review is inconsistent: sometimes thorough, sometimes a rubber stamp
- Knowledge stays in your head. When a teammate hits the same bug, they start from zero
- Shipping is manual: you run tests, create the PR, close tickets, push -- every time

### With beads-compound

- **Automatic memory.** Knowledge is captured inline during work and recalled automatically at the start of every session. Hit the same OAuth bug next month? The agent already knows the fix.
- **Structured planning.** Brainstorm with scope sharpening, research with domain-matched agents, adversarial plan review -- all before a single line of code is written.
- **Built-in quality gates.** Every implementation runs through a review-fix-learn loop. Knowledge capture is mandatory, not optional.
- **Team-shareable knowledge.** Memory lives in `.beads/memory/knowledge.jsonl`, tracked by git. Your team compounds knowledge together.

## The workflow

Most of the time, you type three commands:

```
/beads-design "I want users to upload photos for listings"
```

This runs the full planning pipeline as a single command: interactive brainstorm with scope sharpening, structured plan with phased beads, domain-matched research agents, plan revision, and adversarial review. The output is detailed enough that implementation is mechanical.

```
/beads-work
```

Picks up the approved plan and implements it. Auto-routes between single and multi-bead parallel execution. Includes mandatory review, fix loop, and knowledge curation -- all automatic.

```
/beads-ship
```

Rebases on main, runs tests, scans for secrets and debug leftovers, creates the PR, closes beads, and pushes the backup. One command to land the plane.

Add `/beads-qa` between work and ship when building web apps -- it maps changed files to routes and runs browser-based verification with screenshots.

## Who this is for

Anyone using Claude Code who wants consistent, high-quality output instead of hoping the agent gets it right this time.

- **Non-technical users:** `/beads-design "build me X"` handles the brainstorming, planning, and research. `/beads-work` handles the implementation with built-in quality gates. You get working software without needing to know how to code.
- **Solo developers:** The memory system acts as a second brain. Past decisions, patterns, and gotchas surface automatically when they're relevant.
- **Teams:** Knowledge compounds across contributors. One person's hard-won insight becomes everyone's starting context.

## Install

**Requires:** [beads CLI](https://github.com/steveyegge/beads), `jq`, `sqlite3`

```bash
npx beads-compound@latest
```

Or manual:

```bash
git clone https://github.com/roberto-mello/beads-compound-plugin.git
cd beads-compound-plugin
./install.sh               # Claude Code (default)
./install.sh --opencode    # OpenCode
./install.sh --gemini      # Gemini CLI
./install.sh --cortex      # Cortex Code
```

<details>
<summary><strong>All commands</strong></summary>

**Pipeline (4):** `/beads-design`, `/beads-work`, `/beads-qa`, `/beads-ship`

**Supporting (9):** `/beads-quick` (fast path with escalation), `/beads-learn` (knowledge curation), `/beads-recall` (mid-session search), `/beads-checkpoint` (save progress), `/beads-retro` (weekly analytics), `/beads-import`, `/beads-triage`, `/changelog`, `/test-browser`

**Power-user (6):** `/beads-plan`, `/beads-research`, `/beads-plan-review`, `/beads-review` (15 specialized review agents), `/beads-work-ralph` (autonomous retry), `/beads-work-teams` (persistent workers)

**29 specialized agents** across review, research, design, workflow, and docs. Each runs at the right model tier to keep costs 60-70% lower than running everything on Opus.

See [docs/CATALOG.md](docs/CATALOG.md) for the full listing.

</details>

## How knowledge compounds

```
brainstorm  --DECISION-->  design
design      <--LEARNED/PATTERN--  auto-recall from prior work
research    --FACT/INVESTIGATION-->  plan revision
work        --LEARNED (inline)-->  mandatory knowledge gate
review      --LEARNED-->  issues become future recall
retro       synthesizes patterns, surfaces gaps
```

Five knowledge types (LEARNED, DECISION, FACT, PATTERN, INVESTIGATION) are captured inline during work and stored in `.beads/memory/knowledge.jsonl`. At session start, relevant entries are recalled automatically based on your current beads and git branch. The system gets smarter over time -- not just for you, but for your whole team.

## Acknowledgments

Built by [Roberto Mello](https://github.com/roberto-mello), extending [compound-engineering](https://github.com/EveryInc/compound-engineering-plugin) by [Every](https://every.to). Task tracking by [Beads](https://github.com/steveyegge/beads). Inspired by Every's writing on [compound engineering](https://every.to/chain-of-thought/compound-engineering-how-every-codes-with-agents).

## License

MIT

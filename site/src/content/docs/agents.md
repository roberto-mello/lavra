---
title: Agent Reference
description: All 30 specialized agents Lavra dispatches for research, review, design, and workflow tasks.
order: 9
---

# Agent Reference

Agents are dispatched automatically by Lavra's workflow commands — you don't invoke them directly. They run as subagents with specialized instructions for a specific domain.

See the [Command Map](/command-map) for a visual overview of how all commands, agents, and skills connect.

## Review (16)

Dispatched by `/lavra-review`, `/lavra-work`, and `/lavra-ship` to catch issues before code ships.

| Agent | Description |
|-------|-------------|
| `architecture-strategist` | Evaluates system design, component boundaries, SOLID compliance, and dependency structure |
| `code-simplicity-reviewer` | Identifies unnecessary complexity, premature abstractions, and YAGNI violations |
| `security-sentinel` | Audits input validation, SQL injection, XSS, auth/authz, hardcoded secrets, and OWASP Top 10 |
| `performance-oracle` | Finds bottlenecks, N+1 queries, memory leaks, and projects impact at 10x/100x scale |
| `goal-verifier` | Three-level check (Exists, Substantive, Wired) that implementation actually delivers the bead's success criteria |
| `kieran-rails-reviewer` | Rails code review for conventions, clarity, and maintainability |
| `kieran-python-reviewer` | Python review enforcing type hints, Pythonic patterns, and module organization |
| `kieran-typescript-reviewer` | TypeScript review enforcing no-any policy, type safety, and modern TS 5+ patterns |
| `dhh-rails-reviewer` | Brutally honest Rails review from DHH's perspective — flags anti-patterns and unnecessary abstractions |
| `data-integrity-guardian` | Reviews migrations, data models, and DB mutations for safety, constraints, and referential integrity |
| `data-migration-expert` | Reviews data backfills and production transformations — validates ID mappings and rollback safety |
| `deployment-verification-agent` | Produces pre/post-deploy checklists, SQL verification queries, and rollback procedures |
| `migration-drift-detector` | Detects schema changes not caused by migrations in the PR (Rails, Alembic, Prisma, Drizzle, Knex) |
| `pattern-recognition-specialist` | Finds design patterns, anti-patterns, naming inconsistencies, and architectural boundary violations |
| `julik-frontend-races-reviewer` | Reviews JS and Stimulus for race conditions, timer issues, and Hotwire/Turbo compatibility |
| `agent-native-reviewer` | Checks that user actions have agent equivalents and agents see what users see |

## Research (5)

Dispatched by `/lavra-design` and `/lavra-research` to gather context before planning.

| Agent | Description |
|-------|-------------|
| `best-practices-researcher` | Researches external best practices, docs, and examples for any technology or framework |
| `framework-docs-researcher` | Fetches framework and library documentation via Context7, checks for API deprecations |
| `git-history-analyzer` | Analyzes git history to trace code origins, identify contributors, and extract development patterns |
| `learnings-researcher` | Searches `knowledge.jsonl` for past solutions, patterns, and gotchas relevant to the current work |
| `repo-research-analyst` | Analyzes repository structure, architecture files, GitHub issues, and contribution patterns |

## Design (3)

Dispatched by `/lavra-qa` and design-related workflows.

| Agent | Description |
|-------|-------------|
| `figma-design-sync` | Detects and fixes visual differences between web implementation and Figma design |
| `design-implementation-reviewer` | Verifies UI implementations match Figma specs after components are created or modified |
| `design-iterator` | Iteratively refines UI design through screenshot-analyze-improve cycles |

## Workflow (5)

Used across various commands for specific task types.

| Agent | Description |
|-------|-------------|
| `bug-reproduction-validator` | Systematically reproduces reported bugs and confirms whether behavior deviates from expected |
| `spec-flow-analyzer` | Maps all possible user flows from a spec, identifies gaps and ambiguities |
| `pr-comment-resolver` | Addresses pull request review comments by implementing the requested changes |
| `lint` | Runs linting and code quality checks on Ruby and ERB files |
| `every-style-editor` | Reviews and edits text content against Every's house style guide |

## Docs (1)

| Agent | Description |
|-------|-------------|
| `ankane-readme-writer` | Creates or updates README files following Ankane-style template for Ruby gems |

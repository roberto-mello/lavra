---
title: Command Reference
description: All Lavra slash commands — what they do and when to use them.
order: 5
---

# Command Reference

See the [Command Map](/command-map) for a visual overview of how all commands, agents, and skills connect.

## Workflow

These commands cover the end-to-end development loop from idea to shipped PR.

### /lavra-brainstorm

Explore requirements and approaches through collaborative dialogue before planning.

### /lavra-design

Orchestrate the full design pipeline — brainstorm, plan, research, revise, review, lock.

### /lavra-plan

Transform feature descriptions into well-structured beads with parallel research and multi-phase planning.

### /lavra-quick

Fast-track small tasks — abbreviated plan then straight to execution.

### /lavra-work

Execute work on one or many beads — auto-routes between single-bead and multi-bead paths based on input.

### /lavra-work-ralph

Autonomous retry mode — iterates until completion criteria are met or retry budget is exhausted.

### /lavra-work-teams

Work on multiple beads with persistent worker teammates that self-organize through a ready queue.

### /lavra-review

Perform exhaustive code reviews using multi-agent analysis and ultra-thinking.

### /lavra-qa

Browser-based QA verification of the running app from the user's perspective.

### /lavra-ship

Fully automated ship sequence from code-ready to PR-open with beads closed and knowledge captured.

### /lavra-checkpoint

Save session progress by filing beads, capturing knowledge, and syncing state.

### /lavra-retro

Weekly retrospective with shipping analytics, team performance, and knowledge synthesis.

## Planning & Triage

### /lavra-research

Gather evidence and best practices for a plan using domain-matched research agents.

### /lavra-ceo-review

CEO/founder-mode plan review — challenge premises, validate business fit, run 10-section structured review.

### /lavra-eng-review

Engineering review — parallel agents check architecture, simplicity, security, and performance.

### /lavra-triage

Triage and categorize beads for prioritization.

### /lavra-import

Import a markdown plan into beads as an epic with child tasks.

## Knowledge

### /lavra-learn

Curate raw knowledge comments into structured, well-tagged entries for future auto-recall.

### /lavra-recall

Search knowledge base mid-session and inject relevant context.

## Utility

### /changelog

Create engaging changelogs for recent merges to main branch.

### /heal-skill

Fix incorrect SKILL.md files when a skill has wrong instructions or outdated API references.

### /test-browser

Run browser tests on pages affected by current PR or branch.

### /report-bug

Report a bug in the Lavra plugin.

## Optional Commands

These commands are not installed by default. Copy from `commands/optional/` to `.claude/commands/` to enable them.

### /feature-video

Record a video walkthrough of a feature and add it to the PR description.

### /agent-native-audit

Run comprehensive agent-native architecture review with scored principles.

### /xcode-test

Build and test iOS apps on simulator using XcodeBuildMCP.

### /reproduce-bug

Reproduce and investigate a bug using logs, console inspection, and browser screenshots.

### /generate-command

Create a new custom slash command following conventions and best practices.

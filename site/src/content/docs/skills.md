---
title: Skills Reference
description: The 15 skills Lavra ships — 8 core skills installed by default, plus 7 optional domain-specific skills.
order: 10
---

# Skills Reference

Skills are reusable instruction sets installed into `.claude/skills/`. Your agent loads them automatically when the task matches. You can also invoke them explicitly with `/skill-name`.

See the [Command Map](/command-map) for a visual overview of how all commands, agents, and skills connect.

## Core skills

Installed by default with every Lavra installation.

### agent-browser

Browser automation using Vercel's agent-browser CLI — fill forms, click buttons, take screenshots, scrape pages.

### agent-native-architecture

Design patterns for building applications where agents are first-class citizens — MCP tools, autonomous agents, self-modifying systems.

### brainstorming

Structured brainstorming before implementing features — explores intent, approaches, and design decisions.

### create-agent-skills

Expert guidance for authoring and refining SKILL.md files.

### file-todos

Workflows for creating and managing file-based todos in a `todos/` directory.

### git-worktree

Manages git worktrees for isolated parallel development — create, switch, list, and clean up.

### lavra-knowledge

Captures solved problems as structured knowledge entries for fast future recall.

### lavra-work (internal)

Internal reference files for subagent prompts, single-bead and multi-bead work paths. Not user-invokable -- used by `/lavra-work`, `/lavra-work-ralph`, and `/lavra-work-teams`.

> **Note:** Project setup is now a command: `/lavra-setup`. See [commands](/docs/commands).

## Optional skills

Domain-specific skills in `skills/optional/`. Copy individual skill directories to `.claude/skills/` to use them.

### andrew-kane-gem-writer

Write Ruby gems following Andrew Kane's proven patterns and philosophy.

### dhh-rails-style

Rails development following DHH's 37signals conventions — REST purity, fat models, Hotwire.

### dspy-ruby

Build type-safe LLM applications with DSPy.rb — signatures, modules, agents, optimization.

### every-style-editor

Review and edit text content to conform to Every's house style guide.

### frontend-design

Create distinctive, production-grade frontend interfaces with high design quality.

### gemini-imagegen

Generate and edit images using Google's Gemini image generation API.

### rclone

Cloud storage file management with rclone — sync, copy, mount across 40+ providers.

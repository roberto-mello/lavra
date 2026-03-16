#!/usr/bin/env python3
"""
Apply context optimizations from compound-engineering-plugin PR #161.
Phase 1: Trim agent descriptions and move examples to body.
Phase 2: Add disable-model-invocation to manual commands.
Phase 3: Add disable-model-invocation to manual skills.
"""
import re
from pathlib import Path
from typing import Dict, Tuple

BASE = Path("/Users/rbm/Documents/projects/lavra/plugins/lavra")

# Phase 1: Agent descriptions (based on compound-engineering patterns)
AGENT_DESCRIPTIONS = {
    # Review agents (14)
    "kieran-rails-reviewer": "Reviews Rails code with an extremely high quality bar for conventions, clarity, and maintainability. Use after implementing features, modifying code, or creating new Rails components.",
    "agent-native-reviewer": "Reviews code for agent-native compliance - ensuring user actions have agent equivalents and agents see what users see. Checks action parity, context parity, and shared workspace design.",
    "architecture-strategist": "Analyzes code changes from an architectural perspective - evaluating system design, component boundaries, SOLID compliance, and dependency analysis. Use for structural changes, new services, or refactorings.",
    "code-simplicity-reviewer": "Final review ensuring code is as simple and minimal as possible. Identifies unnecessary complexity, challenges premature abstractions, applies YAGNI rigorously. Use after implementation.",
    "data-integrity-guardian": "Reviews database migrations, data models, and persistent data manipulation. Checks migration safety, validates constraints, verifies referential integrity, audits privacy compliance.",
    "data-migration-expert": "Reviews PRs touching database migrations, data backfills, or production data transformations. Validates ID mappings, checks for swapped values, verifies rollback safety.",
    "deployment-verification-agent": "Produces pre/post-deploy checklists with SQL verification queries, rollback procedures, and monitoring plans. Use when PRs touch production data, migrations, or behavior that could silently fail.",
    "dhh-rails-reviewer": "Brutally honest Rails code review from DHH's perspective. Identifies anti-patterns, JavaScript framework contamination, unnecessary abstractions, and Rails convention violations.",
    "julik-frontend-races-reviewer": "Reviews JavaScript and Stimulus code for race conditions, timing issues, and DOM irregularities. Checks Hotwire/Turbo compatibility, event handler cleanup, timer cancellation. Use after JavaScript changes.",
    "kieran-python-reviewer": "Python code review enforcing strict conventions: mandatory type hints (modern 3.10+ syntax), Pythonic patterns, proper module organization, testability, naming clarity. Use after Python changes.",
    "kieran-typescript-reviewer": "TypeScript code review enforcing strict conventions: no-any policy, proper type safety, modern TS 5+ patterns, import organization, testability, naming clarity. Use after TypeScript changes.",
    "pattern-recognition-specialist": "Analyzes code for design patterns, anti-patterns, naming conventions, code duplication, and architectural boundary violations. Produces structured reports with actionable refactoring recommendations.",
    "performance-oracle": "Analyzes code for performance bottlenecks, algorithmic complexity, N+1 queries, memory leaks, caching opportunities, and scalability concerns. Projects performance at 10x/100x/1000x volumes.",
    "security-sentinel": "Performs security audits covering input validation, SQL injection, XSS, authentication/authorization, hardcoded secrets, and OWASP Top 10 compliance. Use for code handling user input, auth, payments, or sensitive data.",

    # Research agents (5)
    "best-practices-researcher": "Researches external best practices, documentation, and examples for any technology, framework, or development practice. Checks available skills first, then official docs and community standards.",
    "framework-docs-researcher": "Gathers comprehensive documentation and best practices for frameworks, libraries, or project dependencies. Fetches official docs via Context7, explores source code, checks for API deprecations.",
    "git-history-analyzer": "Analyzes git history to understand code evolution, trace origins of specific code patterns, identify key contributors and their expertise areas, and extract development patterns from commit history.",
    "learnings-researcher": "Searches institutional learnings in .beads/memory/knowledge.jsonl for relevant past solutions. Finds applicable patterns, gotchas, and lessons learned to prevent repeated mistakes.",
    "repo-research-analyst": "Conducts thorough research on repository structure, documentation, and patterns. Analyzes architecture files, examines GitHub issues, reviews contribution guidelines, discovers templates.",

    # Design agents (3)
    "design-implementation-reviewer": "Verifies UI implementations match Figma design specifications. Use after HTML/CSS/React components are created or modified to compare implementation against Figma and identify discrepancies.",
    "design-iterator": "Iteratively refines UI design through N screenshot-analyze-improve cycles. Use PROACTIVELY when design changes aren't coming together after 1-2 attempts, or when user requests iterative refinement.",
    "figma-design-sync": "Detects and fixes visual differences between web implementation and Figma design. Use iteratively when syncing implementation to match Figma specs.",

    # Workflow agents (5)
    "bug-reproduction-validator": "Systematically attempts to reproduce reported bugs, validates steps to reproduce, and confirms whether behavior deviates from expected functionality. Classifies issues appropriately.",
    "every-style-editor": "Reviews and edits text content to conform to Every's house style guide - checking headline casing, company usage, adverbs, active voice, number formatting, and punctuation rules.",
    "lint": "Runs linting and code quality checks on Ruby and ERB files. Use before pushing to origin to catch style violations, syntax errors, and code quality issues.",
    "pr-comment-resolver": "Addresses pull request review comments by implementing requested changes and reporting back. Handles understanding the comment, implementing fixes, verifying correctness, and providing resolution summary.",
    "spec-flow-analyzer": "Analyzes specifications, plans, and feature descriptions to map all possible user flows, identify gaps and ambiguities, and surface critical questions. Use when reviewing feature specs or validating implementation plans.",

    # Docs agents (1)
    "ankane-readme-writer": "Creates or updates README files following Ankane-style template for Ruby gems. Enforces imperative voice, sentences under 15 words, proper section ordering, and single-purpose code fences.",
}

# Phase 2: Commands that should have disable-model-invocation: true
# (Manual commands with side effects that shouldn't be auto-suggested)
DISABLE_COMMANDS = [
    "lfg",
    "lavra-checkpoint",
    "deploy-docs",
    "release-docs",
    "changelog",
    "lavra-triage",
    "test-browser",
    "xcode-test",
    "report-bug",
    "reproduce-bug",
    "resolve-pr-parallel",
    "resolve-todo-parallel",
    "generate-command",
    "heal-skill",
    "feature-video",
    "agent-native-audit",
    "create-agent-skill",
    "session-start",
    "session-end",
    "cleanproject",
    "cleanup-types",
    "context-cache",
    "find-todos",
]

# Phase 3: Skills that should have disable-model-invocation: true
DISABLE_SKILLS = [
    "lavra-knowledge",      # compound-docs equivalent
    "create-agent-skills",  # matches their pattern
    "file-todos",           # matches their pattern
    "skill-creator",        # matches their pattern
]

def extract_frontmatter_and_body(content: str) -> Tuple[str, str]:
    """Extract YAML frontmatter and body from markdown file."""
    match = re.match(r'^---\n(.*?)\n---\n(.*)$', content, re.DOTALL)
    if not match:
        raise ValueError("Could not parse frontmatter")
    return match.group(1), match.group(2)

def parse_frontmatter(frontmatter: str) -> Dict[str, str]:
    """Parse YAML frontmatter into dict, handling quoted multiline strings."""
    fields = {}
    current_key = None
    current_value = []
    in_quotes = False

    for line in frontmatter.split('\n'):
        # Check if this is a new key
        if ':' in line and not line.startswith(' ') and not in_quotes:
            # Save previous key if exists
            if current_key:
                value = '\n'.join(current_value).strip()
                # Remove surrounding quotes if present
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                fields[current_key] = value

            # Start new key
            key, value = line.split(':', 1)
            current_key = key.strip()
            value = value.strip()

            # Check if value starts with a quote
            if value.startswith('"'):
                in_quotes = True
                if value.endswith('"') and len(value) > 1:
                    # Single-line quoted value
                    in_quotes = False
                    current_value = [value]
                else:
                    current_value = [value]
            else:
                current_value = [value] if value else []
        elif current_key:
            # Continuation of current value
            current_value.append(line)
            if in_quotes and line.rstrip().endswith('"'):
                in_quotes = False

    # Save last key
    if current_key:
        value = '\n'.join(current_value).strip()
        if value.startswith('"') and value.endswith('"'):
            value = value[1:-1]
        fields[current_key] = value

    return fields

def build_frontmatter(fields: Dict[str, str]) -> str:
    """Build YAML frontmatter from dict."""
    lines = ['---']
    for key, value in fields.items():
        if not value:
            lines.append(f'{key}:')
        elif '\n' in value or len(value) > 80 or '"' in value:
            # Multiline or long string - use quoted format
            escaped = value.replace('"', '\\"')
            lines.append(f'{key}: "{escaped}"')
        else:
            lines.append(f'{key}: {value}')
    lines.append('---')
    return '\n'.join(lines)

def remove_delegation_examples_section(body: str) -> str:
    """Remove ## Delegation Examples section from body."""
    # Remove the section header and all examples under it until next ## or end
    pattern = r'## Delegation Examples\s*\n\n(?:<example>.*?</example>\s*\n*)*'
    return re.sub(pattern, '', body, flags=re.DOTALL)

def extract_examples_from_body(body: str) -> list:
    """Extract all <example> blocks from body."""
    pattern = r'<example>.*?</example>'
    return re.findall(pattern, body, re.DOTALL)

def process_agent(file_path: Path, new_description: str) -> None:
    """Process a single agent file."""
    print(f"  Processing {file_path.relative_to(BASE)}...")

    content = file_path.read_text()
    frontmatter, body = extract_frontmatter_and_body(content)
    fields = parse_frontmatter(frontmatter)

    # Extract examples from body if they exist
    examples = extract_examples_from_body(body)

    # Update description
    old_desc_len = len(fields.get('description', ''))
    fields['description'] = new_description

    # Remove ## Delegation Examples section from body
    body = remove_delegation_examples_section(body)

    # Add examples section to body if examples exist
    if examples:
        examples_section = '<examples>\n' + '\n\n'.join(examples) + '\n</examples>\n\n'
        body = examples_section + body

    # Rebuild file
    new_frontmatter = build_frontmatter(fields)
    new_content = f"{new_frontmatter}\n{body}"

    file_path.write_text(new_content)
    print(f"    ✓ {old_desc_len} chars → {len(new_description)} chars")

def add_disable_to_command(file_path: Path) -> None:
    """Add disable-model-invocation: true to a command file."""
    print(f"  Processing {file_path.relative_to(BASE)}...")

    content = file_path.read_text()
    frontmatter, body = extract_frontmatter_and_body(content)
    fields = parse_frontmatter(frontmatter)

    # Add disable-model-invocation if not present
    if 'disable-model-invocation' not in fields:
        fields['disable-model-invocation'] = 'true'

        # Rebuild file
        new_frontmatter = build_frontmatter(fields)
        new_content = f"{new_frontmatter}\n{body}"

        file_path.write_text(new_content)
        print(f"    ✓ Added disable-model-invocation: true")
    else:
        print(f"    - Already has disable-model-invocation")

def add_disable_to_skill(file_path: Path) -> None:
    """Add disable-model-invocation: true to a skill SKILL.md file."""
    print(f"  Processing {file_path.relative_to(BASE)}...")

    content = file_path.read_text()
    frontmatter, body = extract_frontmatter_and_body(content)
    fields = parse_frontmatter(frontmatter)

    # Add disable-model-invocation if not present
    if 'disable-model-invocation' not in fields:
        fields['disable-model-invocation'] = 'true'

        # Rebuild file
        new_frontmatter = build_frontmatter(fields)
        new_content = f"{new_frontmatter}\n{body}"

        file_path.write_text(new_content)
        print(f"    ✓ Added disable-model-invocation: true")
    else:
        print(f"    - Already has disable-model-invocation")

def main():
    print("=" * 80)
    print("PHASE 1: Trimming agent descriptions")
    print("=" * 80)

    agents_processed = 0
    agents_errors = 0
    old_total = 0
    new_total = 0

    for agent_name, description in AGENT_DESCRIPTIONS.items():
        matches = list(BASE.glob(f"agents/**/{agent_name}.md"))
        if not matches:
            print(f"  ERROR: Could not find {agent_name}.md")
            agents_errors += 1
            continue

        if len(matches) > 1:
            print(f"  ERROR: Found multiple files for {agent_name}")
            agents_errors += 1
            continue

        try:
            # Calculate old length
            content = matches[0].read_text()
            fm, _ = extract_frontmatter_and_body(content)
            fields = parse_frontmatter(fm)
            old_total += len(fields.get('description', ''))
            new_total += len(description)

            process_agent(matches[0], description)
            agents_processed += 1
        except Exception as e:
            print(f"  ERROR processing {agent_name}: {e}")
            agents_errors += 1

    print(f"\n✓ Processed {agents_processed} agents")
    print(f"  Total: {old_total:,} chars → {new_total:,} chars ({100*(old_total-new_total)/old_total:.1f}% reduction)")
    if agents_errors:
        print(f"✗ {agents_errors} errors")

    print("\n" + "=" * 80)
    print("PHASE 2: Adding disable-model-invocation to manual commands")
    print("=" * 80)

    commands_processed = 0
    commands_errors = 0

    for command_name in DISABLE_COMMANDS:
        matches = list(BASE.glob(f"commands/{command_name}.md"))
        if not matches:
            print(f"  WARNING: Could not find commands/{command_name}.md")
            continue

        try:
            add_disable_to_command(matches[0])
            commands_processed += 1
        except Exception as e:
            print(f"  ERROR processing {command_name}: {e}")
            commands_errors += 1

    print(f"\n✓ Processed {commands_processed} commands")
    if commands_errors:
        print(f"✗ {commands_errors} errors")

    print("\n" + "=" * 80)
    print("PHASE 3: Adding disable-model-invocation to manual skills")
    print("=" * 80)

    skills_processed = 0
    skills_errors = 0

    for skill_name in DISABLE_SKILLS:
        matches = list(BASE.glob(f"skills/{skill_name}/SKILL.md"))
        if not matches:
            print(f"  WARNING: Could not find skills/{skill_name}/SKILL.md")
            continue

        try:
            add_disable_to_skill(matches[0])
            skills_processed += 1
        except Exception as e:
            print(f"  ERROR processing {skill_name}: {e}")
            skills_errors += 1

    print(f"\n✓ Processed {skills_processed} skills")
    if skills_errors:
        print(f"✗ {skills_errors} errors")

    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"Agents: {agents_processed} processed, {agents_errors} errors")
    print(f"Commands: {commands_processed} processed, {commands_errors} errors")
    print(f"Skills: {skills_processed} processed, {skills_errors} errors")
    print(f"\nAgent descriptions: {old_total:,} → {new_total:,} chars ({100*(old_total-new_total)/old_total:.1f}% reduction)")

    return 0 if (agents_errors + commands_errors + skills_errors) == 0 else 1

if __name__ == "__main__":
    exit(main())

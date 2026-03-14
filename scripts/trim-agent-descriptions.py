#!/usr/bin/env python3
"""
Trim agent descriptions to under 250 chars and move examples to body.
"""
import re
from pathlib import Path

# Agent descriptions to use (1-2 sentences, under 250 chars)
DESCRIPTIONS = {
    # Review agents (14)
    "kieran-rails-reviewer": "Rails code review enforcing strict conventions: inline turbo streams, proper namespacing, service extraction signals, testability, naming clarity, and duplication over complexity. Use after implementing or modifying Rails code.",
    "agent-native-reviewer": "Reviews code for agent-native compliance - ensuring any user action has an agent equivalent, and agents see what users see. Checks action parity, context parity, and shared workspace design.",
    "architecture-strategist": "Analyzes code changes from an architectural perspective - evaluating system design, component boundaries, SOLID compliance, and dependency analysis. Use for structural changes, new services, or refactorings.",
    "code-simplicity-reviewer": "Final review pass ensuring code is as simple and minimal as possible. Identifies unnecessary complexity, challenges premature abstractions, applies YAGNI rigorously. Use after implementation is complete.",
    "data-integrity-guardian": "Reviews database migrations, data models, and code that manipulates persistent data. Checks migration safety, validates constraints, verifies referential integrity, and audits privacy compliance.",
    "data-migration-expert": "Reviews PRs touching database migrations, data backfills, or production data transformations. Validates ID mappings, checks for swapped values, verifies rollback safety, ensures data integrity.",
    "deployment-verification-agent": "Produces concrete pre/post-deploy checklists with SQL verification queries, rollback procedures, and monitoring plans. Use when PRs touch production data, migrations, or behavior that could silently fail.",
    "dhh-rails-reviewer": "Brutally honest Rails code review from DHH's perspective. Identifies anti-patterns, JavaScript framework contamination, unnecessary abstractions, and Rails convention violations. Flags JWT over sessions, microservices over monoliths.",
    "julik-frontend-races-reviewer": "Reviews JavaScript and Stimulus code for race conditions, timing issues, and DOM irregularities. Checks Hotwire/Turbo compatibility, event handler cleanup, timer cancellation, CSS animation races. Use after implementing or modifying JavaScript.",
    "kieran-python-reviewer": "Python code review enforcing strict conventions: mandatory type hints (modern 3.10+ syntax), Pythonic patterns, proper module organization, testability, naming clarity, and duplication over complexity. Use after implementing or modifying Python code.",
    "kieran-typescript-reviewer": "TypeScript code review enforcing strict conventions: no-any policy, proper type safety, modern TS 5+ patterns, import organization, testability, naming clarity, and duplication over complexity. Use after implementing or modifying TypeScript code.",
    "pattern-recognition-specialist": "Analyzes code for design patterns, anti-patterns, naming conventions, code duplication, and architectural boundary violations. Produces structured reports with actionable refactoring recommendations.",
    "performance-oracle": "Analyzes code for performance bottlenecks, algorithmic complexity, N+1 queries, memory leaks, caching opportunities, and scalability concerns. Projects performance at 10x/100x/1000x data volumes.",
    "security-sentinel": "Performs security audits covering input validation, SQL injection, XSS, authentication/authorization, hardcoded secrets, and OWASP Top 10 compliance. Use when reviewing code that handles user input, authentication, payments, or sensitive data.",

    # Research agents (5)
    "best-practices-researcher": "Researches external best practices, documentation, and examples for any technology, framework, or development practice. Checks available skills first, then official docs and community standards. Includes mandatory deprecation checks.",
    "framework-docs-researcher": "Gathers comprehensive documentation and best practices for frameworks, libraries, or project dependencies. Fetches official docs via Context7, explores source code, identifies version-specific constraints, and checks for API deprecations.",
    "git-history-analyzer": "Analyzes git history to understand code evolution, trace origins of specific code patterns, identify key contributors and their expertise areas, and extract development patterns from commit history.",
    "learnings-researcher": "Searches institutional learnings in .beads/memory/knowledge.jsonl for relevant past solutions. Finds applicable patterns, gotchas, and lessons learned by type, tags, content, and bead references to prevent repeated mistakes.",
    "repo-research-analyst": "Conducts thorough research on repository structure, documentation, and patterns. Analyzes architecture files, examines GitHub issues for conventions, reviews contribution guidelines, discovers templates, and searches for implementation patterns.",

    # Design agents (3)
    "design-implementation-reviewer": "Verifies UI implementations match Figma design specifications. Use after HTML/CSS/React components are created or modified to compare live implementation against Figma and identify visual discrepancies.",
    "design-iterator": "Iteratively refines UI design through N screenshot-analyze-improve cycles. Use PROACTIVELY when design changes aren't coming together after 1-2 attempts, or when user requests iterative refinement.",
    "figma-design-sync": "Detects and fixes visual differences between web implementation and Figma design. Use iteratively when syncing implementation to match Figma specs - captures screenshots, compares, and makes precise CSS/Tailwind corrections.",

    # Workflow agents (5)
    "bug-reproduction-validator": "Systematically attempts to reproduce reported bugs, validates steps to reproduce, and confirms whether behavior deviates from expected functionality. Classifies issues as confirmed bugs, cannot-reproduce, not-a-bug, environmental, data, or user error.",
    "every-style-editor": "Reviews and edits text content to conform to Every's house style guide - checking headline casing, company usage, adverbs, active voice, number formatting, and punctuation rules.",
    "lint": "Runs linting and code quality checks on Ruby and ERB files. Use before pushing to origin to catch style violations, syntax errors, and code quality issues.",
    "pr-comment-resolver": "Addresses pull request review comments by implementing requested changes and reporting back. Handles the full workflow: understanding the comment, implementing the fix, verifying correctness, and providing a structured resolution summary.",
    "spec-flow-analyzer": "Analyzes specifications, plans, and feature descriptions to map all possible user flows, identify gaps and ambiguities, and surface critical questions. Use when reviewing feature specs, planning new features, or validating implementation plans.",

    # Docs agents (1)
    "ankane-readme-writer": "Creates or updates README files following Ankane-style template for Ruby gems. Enforces imperative voice, sentences under 15 words, proper section ordering, and single-purpose code fences.",
}

def extract_frontmatter_and_body(content):
    """Extract frontmatter and body from markdown file."""
    # Match YAML frontmatter between --- delimiters
    match = re.match(r'^---\n(.*?)\n---\n(.*)$', content, re.DOTALL)
    if not match:
        raise ValueError("Could not parse frontmatter")
    return match.group(1), match.group(2)

def parse_frontmatter(frontmatter):
    """Parse YAML frontmatter into dict."""
    fields = {}
    current_key = None
    current_value = []

    for line in frontmatter.split('\n'):
        # Check if this is a new key
        if ':' in line and not line.startswith(' '):
            # Save previous key if exists
            if current_key:
                fields[current_key] = '\n'.join(current_value).strip()

            # Start new key
            key, value = line.split(':', 1)
            current_key = key.strip()
            current_value = [value.strip()] if value.strip() else []
        elif current_key:
            # Continuation of current value
            current_value.append(line)

    # Save last key
    if current_key:
        fields[current_key] = '\n'.join(current_value).strip()

    return fields

def build_frontmatter(fields):
    """Build YAML frontmatter from dict."""
    lines = ['---']
    for key, value in fields.items():
        if '\n' in value or len(value) > 80:
            # Multiline string - use quoted format
            lines.append(f'{key}: "{value}"')
        else:
            lines.append(f'{key}: {value}')
    lines.append('---')
    return '\n'.join(lines)

def extract_examples(body):
    """Extract <example> blocks from body."""
    examples = []
    # Find all <example>...</example> blocks
    pattern = r'<example>.*?</example>'
    matches = re.finditer(pattern, body, re.DOTALL)
    for match in matches:
        examples.append(match.group(0))
    return examples

def remove_delegation_examples_section(body):
    """Remove ## Delegation Examples section from body."""
    # Remove the section header and all examples under it until next ## or end
    pattern = r'## Delegation Examples\s*\n\n(?:<example>.*?</example>\s*\n*)*'
    return re.sub(pattern, '', body, flags=re.DOTALL)

def process_agent(file_path, new_description):
    """Process a single agent file."""
    print(f"Processing {file_path.name}...")

    content = file_path.read_text()

    # Extract frontmatter and body
    frontmatter, body = extract_frontmatter_and_body(content)
    fields = parse_frontmatter(frontmatter)

    # Extract examples from body if they exist
    examples = extract_examples(body)

    # Update description in frontmatter
    fields['description'] = new_description

    # Remove ## Delegation Examples section from body
    body = remove_delegation_examples_section(body)

    # Add examples section to body if examples exist
    if examples:
        examples_section = '\n<examples>\n' + '\n\n'.join(examples) + '\n</examples>\n\n'
        body = examples_section + body

    # Rebuild file
    new_frontmatter = build_frontmatter(fields)
    new_content = f"{new_frontmatter}\n{body}"

    # Write back
    file_path.write_text(new_content)
    print(f"  ✓ Description: {len(new_description)} chars")

def main():
    base = Path("/Users/rbm/Documents/projects/lavra/plugins/lavra/agents")

    processed = 0
    errors = 0

    for agent_name, description in DESCRIPTIONS.items():
        # Find the agent file
        matches = list(base.rglob(f"{agent_name}.md"))
        if not matches:
            print(f"ERROR: Could not find {agent_name}.md")
            errors += 1
            continue

        if len(matches) > 1:
            print(f"ERROR: Found multiple files for {agent_name}")
            errors += 1
            continue

        try:
            process_agent(matches[0], description)
            processed += 1
        except Exception as e:
            print(f"ERROR processing {agent_name}: {e}")
            errors += 1

    print(f"\n✓ Processed {processed} agents")
    if errors:
        print(f"✗ {errors} errors")
        return 1
    return 0

if __name__ == "__main__":
    exit(main())

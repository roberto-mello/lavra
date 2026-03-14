# Workflow: Create Exhaustive Domain Expertise Skill

<objective>
Build a comprehensive execution skill that does real work in a specific domain. Domain expertise skills are full-featured build skills with exhaustive domain knowledge in references, complete workflows for the full lifecycle (build -> debug -> optimize -> ship), and can be both invoked directly by users AND loaded by other skills for domain knowledge.
</objective>

<required_reading>
**Read these reference files NOW:**
1. references/recommended-structure.md
2. references/core-principles.md
</required_reading>

<process>
## Step 1: Identify Domain

Ask user what domain expertise to build. Get specific about the scope.

## Step 2: Confirm Target Location

Domain expertise skills go in: `~/.claude/skills/expertise/{domain-name}/`

## Step 3: Identify Workflows

Cover the FULL lifecycle: build-new, add-feature, debug, write-tests, optimize-performance, ship.

## Step 4: Exhaustive Research Phase

Run multiple web searches to ensure coverage of current ecosystem, architecture patterns, lifecycle tooling, common pitfalls, and real-world usage.

## Step 5: Organize Knowledge Into Domain Areas

Structure references by domain concerns, NOT by arbitrary categories.

## Step 6: Create SKILL.md

Use router pattern with essential principles, intake, routing, reference_index, workflows_index.

## Step 7: Write Workflows

Each workflow includes required_reading, implementation steps, verification steps, and success criteria.

## Step 8: Write Comprehensive References

Each reference includes decision guidance, comparisons, code examples, and anti-patterns.

## Step 9: Validate Completeness

Ask: "Could a user build a professional {domain thing} from scratch through shipping using just this skill?"

## Step 10: Create Directory and Files

Write all SKILL.md, workflow files, and reference files.

## Step 11: Final Quality Check

Review entire skill for completeness and accuracy.
</process>

<success_criteria>
Domain expertise skill is complete when:
- [ ] Comprehensive research completed
- [ ] Knowledge organized by domain areas
- [ ] Essential principles in SKILL.md
- [ ] Full lifecycle covered (build -> debug -> test -> optimize -> ship)
- [ ] Each workflow has required_reading + implementation steps + verification
- [ ] Each reference has decision trees and comparisons
- [ ] User can build something professional from scratch through shipping
</success_criteria>

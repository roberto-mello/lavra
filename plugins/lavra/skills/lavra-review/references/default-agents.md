# Default Review Agents

Agents Lavra ships for code review. All are discovered automatically when installed. Use this list to configure `review_agents` in `.lavra/config/project-setup.md` when you want an explicit subset.

## Always-run (general purpose)

| Agent | What it checks |
|-------|---------------|
| `architecture-strategist` | System design, component boundaries, SOLID compliance, dependency structure |
| `security-sentinel` | Input validation, SQL injection, XSS, auth/authz, hardcoded secrets, OWASP Top 10 |
| `performance-oracle` | Algorithmic complexity, N+1 queries, memory leaks, caching, scalability at 10x/100x/1000x |
| `pattern-recognition-specialist` | Design patterns, anti-patterns, naming conventions, code duplication, boundary violations |
| `data-integrity-guardian` | Migration safety, constraint validation, referential integrity, privacy compliance |
| `agent-native-reviewer` | Agent-native compliance — action parity, context parity, shared workspace design |
| `git-history-analyzer` | Code evolution, origin of patterns, contributor expertise, development trends |
| `code-simplicity-reviewer` | Unnecessary complexity, premature abstractions, YAGNI violations |

## Language / framework specific

| Agent | What it checks |
|-------|---------------|
| `kieran-rails-reviewer` | Rails conventions, clarity, maintainability |
| `dhh-rails-reviewer` | Rails anti-patterns, JS framework contamination, unnecessary abstractions (DHH perspective) |
| `kieran-typescript-reviewer` | No-any policy, type safety, modern TS 5+ patterns, import organization |
| `kieran-python-reviewer` | Type hints, Pythonic patterns, module organization, testability |
| `julik-frontend-races-reviewer` | JS/Stimulus race conditions, Hotwire/Turbo compatibility, event handler cleanup |

## Conditional (migration PRs only)

Run automatically when the PR touches migration files or schema artifacts.

| Agent | What it checks |
|-------|---------------|
| `data-migration-expert` | Migration code correctness — ID mappings, swapped values, rollback safety |
| `deployment-verification-agent` | Pre/post-deploy checklists, SQL verification queries, rollback procedures |
| `migration-drift-detector` | Schema/migration sync across Rails, Alembic, Prisma, Drizzle, Knex |

## Configuring a custom subset

In `.lavra/config/project-setup.md` YAML frontmatter:

```yaml
review_agents:
  - architecture-strategist
  - security-sentinel
  - performance-oracle
  - rust-reviewer        # your custom agent
```

Named agents are validated against discovered agents on disk. Unknown names are skipped.

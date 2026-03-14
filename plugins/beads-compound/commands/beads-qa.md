---
name: beads-qa
description: Browser-based QA verification of the running app -- systematic testing from the user's perspective
argument-hint: "[bead ID or --quick for smoke test]"
---

<objective>
Verify that implemented changes work correctly from the user's perspective by running systematic browser-based tests against the running application. Sits between /beads-work (implementation) and shipping, catching visual regressions, broken interactions, console errors, and workflow breakages that unit tests miss.
</objective>

<execution_context>
<qa_target> $ARGUMENTS </qa_target>
</execution_context>

<guardrails>

**DO NOT use Chrome MCP tools (mcp__claude-in-chrome__*).**

This command uses the `agent-browser` CLI exclusively. The agent-browser CLI is a Bash-based tool from Vercel that runs headless Chromium. It is NOT the same as Chrome browser automation via MCP.

If you find yourself calling `mcp__claude-in-chrome__*` tools, STOP. Use `agent-browser` Bash commands instead.

**DO NOT force browser QA on non-UI work.** If the diff shows only backend/CLI/library/infra changes with no web UI impact, say so and suggest skipping. Do not waste time opening a browser when there is nothing visual to test.

</guardrails>

<process>

### Phase 0: Mode Detection

Parse arguments:

- `--quick` flag: smoke test mode (load pages, check for errors, done)
- No flag: full mode (all test scenarios, interactive elements, edge cases)
- Bead ID: use bead description to understand what was implemented and what to verify

If a bead ID is provided:
```bash
bd show {BEAD_ID} --json
```

Read the bead description to understand acceptance criteria and what the implementation should do. This informs what to test.

### Phase 1: Scope Detection

**Identify changed files:**

```bash
# If on a feature branch
git diff --name-only $(git merge-base HEAD main)..HEAD

# Fallback: unstaged + staged changes
git diff --name-only HEAD
```

**Detect framework and map files to routes:**

| Framework | Detection | Route Mapping |
|-----------|-----------|---------------|
| Next.js | `next.config.*` or `src/app/` | `src/app/**/page.tsx` -> URL path |
| Rails | `Gemfile` with `rails` | `config/routes.rb` + changed controllers/views |
| Django | `manage.py` or `urls.py` | `urls.py` patterns + changed views/templates |
| Laravel | `artisan` | `routes/web.php` + changed controllers/views |
| Remix | `remix.config.*` | `app/routes/` directory structure |
| SvelteKit | `svelte.config.*` | `src/routes/` directory structure |
| Nuxt | `nuxt.config.*` | `pages/` directory structure |
| Generic SPA | `index.html` + router config | Router config file |

Read the relevant routing file to map changed files to URLs:

```bash
# Rails example
cat config/routes.rb
# Next.js example
find src/app -name "page.tsx" -o -name "page.js" | head -20
# Django example
cat */urls.py
```

**Check for non-UI changes:**

If ALL changed files match these patterns, suggest skipping QA:
- `*.rb` models/services/jobs with no view/controller changes
- `*.py` without template/view changes
- API-only endpoints (serializers, API controllers)
- Database migrations only
- CLI tools, libraries, gems, packages
- Infrastructure (Dockerfile, CI configs, terraform)
- Documentation only

If non-UI detected, present:

> "Changes appear to be backend/infrastructure only with no UI impact. Browser QA would not add value here. Skip QA?"

Proceed only if user confirms there IS a UI to test.

**Build the test URL list** from the file-to-route mapping. Present it to the user:

```markdown
## QA Test Plan

**Framework detected:** [framework]
**Changed routes:**

| Route | Changed Files | What to Verify |
|-------|--------------|----------------|
| /users | users_controller.rb, index.html.erb | User listing renders correctly |
| /settings | settings.js, settings.css | Settings page layout and interactions |
```

Use **AskUserQuestion tool**:

**Question:** "Here is the QA test plan. What is the base URL for the running app?"

**Options:**
1. **http://localhost:3000** (default)
2. **http://localhost:5173** (Vite default)
3. **http://localhost:8000** (Django/Laravel default)
4. **Custom URL** - I will provide it

Also ask if they want to add or remove any routes from the test plan.

### Phase 2: Server Verification

**Verify agent-browser is installed:**

```bash
command -v agent-browser >/dev/null 2>&1 && echo "Ready" || (echo "Installing..." && npm install -g agent-browser && agent-browser install)
```

If installation fails, inform the user and stop.

**Ask browser mode:**

Use **AskUserQuestion tool**:

**Question:** "Do you want to watch the browser tests run?"

**Options:**
1. **Headed (watch)** - Opens visible browser window so you can see tests run
2. **Headless (faster)** - Runs in background, faster but invisible

Store the choice and use `--headed` flag when user selects "Headed".

**Verify server is reachable:**

```bash
agent-browser open {BASE_URL}
agent-browser snapshot -i
```

If server is not running:

> "Server is not reachable at {BASE_URL}. Please start your development server and confirm, or provide the correct URL."

Do not proceed until the server responds.

### Phase 3: Test Plan Generation

For each affected route, generate test scenarios based on mode:

**--quick mode (smoke test):**
- Page loads without errors
- No console errors/warnings
- Key heading/content is present
- Screenshot for evidence

**Full mode (default):**
- Page loads without errors
- Console has no errors/warnings
- Key headings and content render correctly
- Navigation elements work (links, tabs, breadcrumbs)
- Forms: fields present, validation fires, submission works
- Buttons and interactive elements respond to clicks
- Changed functionality behaves as specified in the bead
- Data displays correctly (tables, lists, cards)
- Responsive check: viewport resize if layout changes were made
- Authentication-gated pages accessible when logged in

Present the test plan for user approval before executing.

### Phase 4: Execution

For each route in the test plan:

**Step 1: Navigate and assess**
```bash
agent-browser open "{BASE_URL}{route}"
agent-browser snapshot -i
agent-browser get title
```

**Step 2: Check for errors**
```bash
agent-browser snapshot -i --json
```

Look for error messages, 404/500 pages, missing content, broken layouts in the snapshot output.

**Step 3: Test interactive elements (full mode only)**

For forms:
```bash
agent-browser snapshot -i
# Identify form fields from snapshot refs
agent-browser fill @e1 "test input"
agent-browser click @submit_ref
agent-browser snapshot -i  # Check result
```

For navigation:
```bash
agent-browser click @nav_ref
agent-browser snapshot -i  # Verify navigation worked
agent-browser back
```

For dynamic content:
```bash
agent-browser click @trigger_ref
agent-browser wait 1000
agent-browser snapshot -i  # Check updated state
```

**Step 4: Take screenshots**
```bash
agent-browser screenshot qa-{route-slug}.png
agent-browser screenshot --full qa-{route-slug}-full.png
```

**Step 5: Record result**

Assign each page a health score:
- **PASS** - Page loads, no errors, interactions work as expected
- **WARN** - Page loads but has minor issues (non-critical console warnings, minor visual issues)
- **FAIL** - Page broken, console errors, interactions fail, content missing

### Phase 5: Handle Failures

When a test fails:

1. **Document the failure:**
   ```bash
   agent-browser screenshot qa-fail-{route-slug}.png
   ```

2. **Ask user how to proceed:**

   Use **AskUserQuestion tool**:

   **Question:** "QA failure on {route}: {description}. How to proceed?"

   **Options:**
   1. **Fix now** - Investigate and fix the issue
   2. **Create bead** - Track as a bug for later
   3. **Skip** - Accept and continue testing

3. **If "Fix now":**
   - Investigate the root cause
   - Propose and apply a fix
   - Re-run the failing test to verify

4. **If "Create bead":**
   ```bash
   bd create "QA failure: {description} on {route}" --type bug --priority 1
   ```
   Continue testing remaining routes.

5. **If "Skip":**
   - Log as skipped with reason
   - Continue testing

### Phase 6: Results

After all routes tested, present the summary:

```markdown
## QA Results

**Mode:** [quick/full]
**Base URL:** {BASE_URL}
**Bead:** {BEAD_ID} (if provided)

### Pages Tested: [count]

| Route | Health | Notes |
|-------|--------|-------|
| /users | PASS | |
| /settings | WARN | Minor layout shift on mobile viewport |
| /dashboard | FAIL | Console error: TypeError in chart.js |

### Console Errors: [count]
- [List errors with route where found]

### Failures: [count]
- {route} - {issue description}

### Beads Created: [count]
- {BEAD_ID}: {title}

### Screenshots
- qa-users.png
- qa-settings.png
- qa-fail-dashboard.png

### Result: [PASS / WARN / FAIL]
```

**Log knowledge for unexpected findings:**

```bash
bd comments add {BEAD_ID} "LEARNED: {unexpected behavior discovered during QA}"
```

**Close the browser:**
```bash
agent-browser close
```

### Phase 7: Next Steps

Use **AskUserQuestion tool**:

**Question:** "QA complete. Result: {PASS/WARN/FAIL}. What next?"

**Options (if PASS):**
1. **Run `/beads-review`** - Code review before shipping
2. **Close bead** - Mark as complete: `bd close {BEAD_ID}`
3. **Ship it** - Push and create PR

**Options (if WARN or FAIL):**
1. **Fix issues** - Address failures before shipping
2. **Run `/beads-review`** - Code review (issues noted but accepted)
3. **Create beads for failures** - Track issues separately and ship
4. **Re-run QA** - Test again after fixes

</process>

<success_criteria>
- [ ] Changed files identified and mapped to routes
- [ ] Non-UI changes correctly detected (skip suggested when appropriate)
- [ ] Dev server verified as running
- [ ] All affected pages tested with agent-browser CLI
- [ ] Each page has a PASS/WARN/FAIL health score
- [ ] Console errors captured and reported
- [ ] Screenshots taken as evidence
- [ ] Failures documented with reproduction steps
- [ ] Fix beads created for unresolved failures
- [ ] Knowledge logged for unexpected behaviors
</success_criteria>

<handoff>
After QA completes:
1. **Run `/beads-review`** - Multi-agent code review
2. **Fix failures** - Address any FAIL results
3. **Ship** - Push changes and create PR
</handoff>

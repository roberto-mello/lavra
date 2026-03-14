<overview>
A structured discipline for ensuring agents can do everything users can do. Every UI action should have an equivalent agent tool. This isn't a one-time check—it's an ongoing practice integrated into your development workflow.

**Core principle:** When adding a UI feature, add the corresponding tool in the same PR.
</overview>

<why_parity>
## Why Action Parity Matters

**The failure case:**
```
User: "Write something about Catherine the Great in my reading feed"
Agent: "What system are you referring to? I'm not sure what reading feed means."
```

The user could publish to their feed through the UI. But the agent had no `publish_to_feed` tool. The fix was simple—add the tool. But the insight is profound:

**Every action a user can take through the UI must have an equivalent tool the agent can call.**

Without this parity:
- Users ask agents to do things they can't do
- Agents ask clarifying questions about features they should understand
- The agent feels limited compared to direct app usage
- Users lose trust in the agent's capabilities
</why_parity>

<capability_mapping>
## The Capability Map

Maintain a structured map of UI actions to agent tools:

| UI Action | UI Location | Agent Tool | System Prompt Reference |
|-----------|-------------|------------|-------------------------|
| View library | Library tab | `read_library` | "View books and highlights" |
| Add book | Library → Add | `add_book` | "Add books to library" |
| Publish insight | Analysis view | `publish_to_feed` | "Create insights for Feed tab" |
| Start research | Book detail | `start_research` | "Research books via web search" |
| Edit profile | Settings | `write_file(profile.md)` | "Update reading profile" |
| Take screenshot | Camera | N/A (user action) | -- |
| Search web | Chat | `web_search` | "Search the internet" |

**Update this table whenever adding features.**

### Template for Your App

```markdown
# Capability Map - [Your App Name]

| UI Action | UI Location | Agent Tool | System Prompt | Status |
|-----------|-------------|------------|---------------|--------|
| | | | | Missing |
| | | | | Done |
| | | | | N/A |
```

Status meanings:
- Done: Tool exists and is documented in system prompt
- Missing: UI action exists but no agent equivalent
- N/A: User-only action (e.g., biometric auth, camera capture)
</capability_mapping>

<parity_workflow>
## The Action Parity Workflow

### When Adding a New Feature

Before merging any PR that adds UI functionality:

```
1. What action is this?
   → "User can publish an insight to their reading feed"

2. Does an agent tool exist for this?
   → Check tool definitions
   → If NO: Create the tool

3. Is it documented in the system prompt?
   → Check system prompt capabilities section
   → If NO: Add documentation

4. Is the context available?
   → Does agent know what "feed" means?
   → Does agent see available books?
   → If NO: Add to context injection

5. Update the capability map
   → Add row to tracking document
```

### PR Checklist

Add to your PR template:

```markdown
## Agent-Native Checklist

- [ ] Every new UI action has a corresponding agent tool
- [ ] System prompt updated to mention new capability
- [ ] Agent has access to same data UI uses
- [ ] Capability map updated
- [ ] Tested with natural language request
```
</parity_workflow>

<parity_audit>
## The Parity Audit

Periodically audit your app for action parity gaps:

### Step 1: List All UI Actions

Walk through every screen and list what users can do:

```
Library Screen:
- View list of books
- Search books
- Filter by category
- Add new book
- Delete book
- Open book detail

Book Detail Screen:
- View book info
- Start research
- View highlights
- Add highlight
- Share book
- Remove from library

Feed Screen:
- View insights
- Create new insight
- Edit insight
- Delete insight
- Share insight

Settings:
- Edit profile
- Change theme
- Export data
- Delete account
```

### Step 2: Check Tool Coverage

For each action, verify:

```
View list of books      → read_library
Search books            → read_library (with query param)
Filter by category      → MISSING (add filter param to read_library)
Add new book            → MISSING (need add_book tool)
Delete book             → delete_book
Open book detail        → read_library (single book)

Start research          → start_research
View highlights         → read_library (includes highlights)
Add highlight           → MISSING (need add_highlight tool)
Share book              → MISSING (or N/A if sharing is UI-only)

View insights           → read_library (includes feed)
Create new insight      → publish_to_feed
Edit insight            → MISSING (need update_feed_item tool)
Delete insight          → MISSING (need delete_feed_item tool)
```

### Step 3: Prioritize Gaps

Not all gaps are equal:

**High priority (users will ask for this):**
- Add new book
- Create/edit/delete content
- Core workflow actions

**Medium priority (occasional requests):**
- Filter/search variations
- Export functionality
- Sharing features

**Low priority (rarely requested via agent):**
- Theme changes
- Account deletion
- Settings that are UI-preference
</parity_audit>

<tool_design_for_parity>
## Designing Tools for Parity

### Match Tool Granularity to UI Granularity

If the UI has separate buttons for "Edit" and "Delete", consider separate tools:

```typescript
// Matches UI granularity
tool("update_feed_item", { id, content, headline }, ...);
tool("delete_feed_item", { id }, ...);

// vs. combined (harder for agent to discover)
tool("modify_feed_item", { id, action: "update" | "delete", ... }, ...);
```

### Use User Vocabulary in Tool Names

```typescript
// Good: Matches what users say
tool("publish_to_feed", ...);  // "publish to my feed"
tool("add_book", ...);         // "add this book"
tool("start_research", ...);   // "research this"

// Bad: Technical jargon
tool("create_analysis_record", ...);
tool("insert_library_item", ...);
tool("initiate_web_scrape_workflow", ...);
```

### Return What the UI Shows

If the UI shows a confirmation with details, the tool should too:

```typescript
// UI shows: "Added 'Moby Dick' to your library"
// Tool should return the same:
tool("add_book", async ({ title, author }) => {
  const book = await library.add({ title, author });
  return {
    text: `Added "${book.title}" by ${book.author} to your library (id: ${book.id})`
  };
});
```
</tool_design_for_parity>

<context_parity>
## Context Parity

Whatever the user sees, the agent should be able to access.

### The Problem

```swift
// UI shows recent analyses in a list
ForEach(analysisRecords) { record in
    AnalysisRow(record: record)
}

// But system prompt only mentions books, not analyses
let systemPrompt = """
## Available Books
\(books.map { $0.title })
// Missing: recent analyses!
"""
```

The user sees their reading journal. The agent doesn't. This creates a disconnect.

### The Fix

```swift
// System prompt includes what UI shows
let systemPrompt = """
## Available Books
\(books.map { "- \($0.title)" }.joined(separator: "\n"))

## Recent Reading Journal
\(analysisRecords.prefix(10).map { "- \($0.summary)" }.joined(separator: "\n"))
"""
```

### Context Parity Checklist

For each screen in your app:
- [ ] What data does this screen display?
- [ ] Is that data available to the agent?
- [ ] Can the agent access the same level of detail?
</context_parity>

<continuous_parity>
## Maintaining Parity Over Time

### Git Hooks / CI Checks

```bash
#!/bin/bash
# pre-commit hook: check for new UI actions without tools

# Find new SwiftUI Button/onTapGesture additions
NEW_ACTIONS=$(git diff --cached --name-only | xargs grep -l "Button\|onTapGesture")

if [ -n "$NEW_ACTIONS" ]; then
    echo "New UI actions detected. Did you add corresponding agent tools?"
    echo "Files: $NEW_ACTIONS"
    echo ""
    echo "Checklist:"
    echo "  [ ] Agent tool exists for new action"
    echo "  [ ] System prompt documents new capability"
    echo "  [ ] Capability map updated"
fi
```

### Automated Parity Testing

```typescript
// parity.test.ts
describe('Action Parity', () => {
  const capabilityMap = loadCapabilityMap();

  for (const [action, toolName] of Object.entries(capabilityMap)) {
    if (toolName === 'N/A') continue;

    test(`${action} has agent tool: ${toolName}`, () => {
      expect(agentTools.map(t => t.name)).toContain(toolName);
    });

    test(`${toolName} is documented in system prompt`, () => {
      expect(systemPrompt).toContain(toolName);
    });
  }
});
```

### Regular Audits

Schedule periodic reviews:

```markdown
## Monthly Parity Audit

1. Review all PRs merged this month
2. Check each for new UI actions
3. Verify tool coverage
4. Update capability map
5. Test with natural language requests
```
</continuous_parity>

<checklist>
## Action Parity Checklist

For every PR with UI changes:
- [ ] Listed all new UI actions
- [ ] Verified agent tool exists for each action
- [ ] Updated system prompt with new capabilities
- [ ] Added to capability map
- [ ] Tested with natural language request

For periodic audits:
- [ ] Walked through every screen
- [ ] Listed all possible user actions
- [ ] Checked tool coverage for each
- [ ] Prioritized gaps by likelihood of user request
- [ ] Created issues for high-priority gaps
</checklist>

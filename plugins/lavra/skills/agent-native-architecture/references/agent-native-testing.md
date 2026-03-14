<overview>
Testing agent-native apps requires different approaches than traditional unit testing. You're testing whether the agent achieves outcomes, not whether it calls specific functions. This guide provides concrete testing patterns for verifying your app is truly agent-native.
</overview>

<testing_philosophy>
## Testing Philosophy

### Test Outcomes, Not Procedures

**Traditional (procedure-focused):**
```typescript
// Testing that a specific function was called with specific args
expect(mockProcessFeedback).toHaveBeenCalledWith({
  message: "Great app!",
  category: "praise",
  priority: 2
});
```

**Agent-native (outcome-focused):**
```typescript
// Testing that the outcome was achieved
const result = await agent.process("Great app!");
const storedFeedback = await db.feedback.getLatest();

expect(storedFeedback.content).toContain("Great app");
expect(storedFeedback.importance).toBeGreaterThanOrEqual(1);
expect(storedFeedback.importance).toBeLessThanOrEqual(5);
// We don't care exactly how it categorized—just that it's reasonable
```

### Accept Variability

Agents may solve problems differently each time. Your tests should:
- Verify the end state, not the path
- Accept reasonable ranges, not exact values
- Check for presence of required elements, not exact format
</testing_philosophy>

<can_agent_do_it_test>
## The "Can Agent Do It?" Test

For each UI feature, write a test prompt and verify the agent can accomplish it.

### Template

```typescript
describe('Agent Capability Tests', () => {
  test('Agent can add a book to library', async () => {
    const result = await agent.chat("Add 'Moby Dick' by Herman Melville to my library");

    const library = await libraryService.getBooks();
    const mobyDick = library.find(b => b.title.includes("Moby Dick"));

    expect(mobyDick).toBeDefined();
    expect(mobyDick.author).toContain("Melville");
  });

  test('Agent can publish to feed', async () => {
    await libraryService.addBook({ id: "book_123", title: "1984" });

    const result = await agent.chat("Write something about surveillance themes in my feed");

    const feed = await feedService.getItems();
    const newItem = feed.find(item => item.bookId === "book_123");

    expect(newItem).toBeDefined();
    expect(newItem.content.toLowerCase()).toMatch(/surveillance|watching|control/);
  });
});
```

### The "Write to Location" Test

A key litmus test: can the agent create content in specific app locations?

```typescript
describe('Location Awareness Tests', () => {
  const locations = [
    { userPhrase: "my reading feed", expectedTool: "publish_to_feed" },
    { userPhrase: "my library", expectedTool: "add_book" },
    { userPhrase: "my research folder", expectedTool: "write_file" },
    { userPhrase: "my profile", expectedTool: "write_file" },
  ];

  for (const { userPhrase, expectedTool } of locations) {
    test(`Agent knows how to write to "${userPhrase}"`, async () => {
      const prompt = `Write a test note to ${userPhrase}`;
      const result = await agent.chat(prompt);

      expect(result.toolCalls).toContainEqual(
        expect.objectContaining({ name: expectedTool })
      );
    });
  }
});
```
</can_agent_do_it_test>

<surprise_test>
## The "Surprise Test"

A well-designed agent-native app lets the agent figure out creative approaches. Test this by giving open-ended requests.

### The Test

```typescript
describe('Agent Creativity Tests', () => {
  test('Agent can handle open-ended requests', async () => {
    await libraryService.addBook({ id: "1", title: "1984", author: "Orwell" });
    await libraryService.addBook({ id: "2", title: "Brave New World", author: "Huxley" });

    const result = await agent.chat("Help me organize my reading for next month");

    expect(result.toolCalls.length).toBeGreaterThan(0);

    const libraryTools = ["read_library", "write_file", "publish_to_feed"];
    const usedLibraryTool = result.toolCalls.some(
      call => libraryTools.includes(call.name)
    );
    expect(usedLibraryTool).toBe(true);
  });

  test('Agent finds creative solutions', async () => {
    const result = await agent.chat(
      "I want to understand the dystopian themes across my sci-fi books"
    );

    // We just verify it did something substantive
    expect(result.response.length).toBeGreaterThan(100);
    expect(result.toolCalls.length).toBeGreaterThan(0);
  });
});
```

### What Failure Looks Like

```typescript
// FAILURE: Agent can only say it can't do that
const result = await agent.chat("Help me prepare for a book club discussion");

// Bad outcome:
expect(result.response).not.toContain("I can't");
expect(result.response).not.toContain("I don't have a tool");
expect(result.response).not.toContain("Could you clarify");

// If the agent asks for clarification on something it should understand,
// you have a context injection or capability gap
```
</surprise_test>

<parity_testing>
## Automated Parity Testing

Ensure every UI action has an agent equivalent.

### Capability Map Testing

```typescript
// capability-map.ts
export const capabilityMap = {
  "View library": "read_library",
  "Add book": "add_book",
  "Delete book": "delete_book",
  "Publish insight": "publish_to_feed",
  "Start research": "start_research",
  "View highlights": "read_library",
  "Edit profile": "write_file",
  "Search web": "web_search",
  "Export data": "N/A",
};

// parity.test.ts
import { capabilityMap } from './capability-map';
import { getAgentTools } from './agent-config';
import { getSystemPrompt } from './system-prompt';

describe('Action Parity', () => {
  const agentTools = getAgentTools();
  const systemPrompt = getSystemPrompt();

  for (const [uiAction, toolName] of Object.entries(capabilityMap)) {
    if (toolName === 'N/A') continue;

    test(`"${uiAction}" has agent tool: ${toolName}`, () => {
      const toolNames = agentTools.map(t => t.name);
      expect(toolNames).toContain(toolName);
    });

    test(`${toolName} is documented in system prompt`, () => {
      expect(systemPrompt).toContain(toolName);
    });
  }
});
```

### Context Parity Testing

```typescript
describe('Context Parity', () => {
  test('Agent sees all data that UI shows', async () => {
    await libraryService.addBook({ id: "1", title: "Test Book" });
    await feedService.addItem({ id: "f1", content: "Test insight" });

    const systemPrompt = await buildSystemPrompt();

    expect(systemPrompt).toContain("Test Book");
    expect(systemPrompt).toContain("Test insight");
  });
});
```
</parity_testing>

<integration_testing>
## Integration Testing

Test the full flow from user request to outcome.

### End-to-End Flow Tests

```typescript
describe('End-to-End Flows', () => {
  test('Research flow: request → web search → file creation', async () => {
    const bookId = "book_123";
    await libraryService.addBook({ id: bookId, title: "Moby Dick" });

    await agent.chat("Research the historical context of whaling in Moby Dick");

    const searchCalls = mockWebSearch.mock.calls;
    expect(searchCalls.length).toBeGreaterThan(0);

    const researchFiles = await fileService.listFiles(`Research/${bookId}/`);
    expect(researchFiles.length).toBeGreaterThan(0);

    const content = await fileService.readFile(researchFiles[0]);
    expect(content.toLowerCase()).toMatch(/whale|whaling|nantucket|melville/);
  });

  test('Publish flow: request → tool call → feed update', async () => {
    await libraryService.addBook({ id: "book_1", title: "1984" });

    const feedBefore = await feedService.getItems();

    await agent.chat("Write something about Big Brother for my reading feed");

    const feedAfter = await feedService.getItems();
    expect(feedAfter.length).toBe(feedBefore.length + 1);

    const newItem = feedAfter.find(item =>
      !feedBefore.some(old => old.id === item.id)
    );
    expect(newItem).toBeDefined();
    expect(newItem.content.toLowerCase()).toMatch(/big brother|surveillance|watching/);
  });
});
```

### Failure Recovery Tests

```typescript
describe('Failure Recovery', () => {
  test('Agent handles missing book gracefully', async () => {
    const result = await agent.chat("Tell me about 'Nonexistent Book'");

    expect(result.error).toBeUndefined();
    expect(result.response.toLowerCase()).toMatch(
      /not found|don't see|can't find|library/
    );
  });

  test('Agent recovers from API failure', async () => {
    mockWebSearch.mockRejectedValueOnce(new Error("Network error"));

    const result = await agent.chat("Research this topic");

    expect(result.error).toBeUndefined();
    expect(result.response).not.toContain("unhandled exception");
  });
});
```
</integration_testing>

<snapshot_testing>
## Snapshot Testing for System Prompts

Track changes to system prompts and context injection over time.

```typescript
describe('System Prompt Stability', () => {
  test('System prompt structure matches snapshot', async () => {
    const systemPrompt = await buildSystemPrompt();

    const structure = systemPrompt
      .replace(/id: \w+/g, 'id: [ID]')
      .replace(/"[^"]+"/g, '"[TITLE]"')
      .replace(/\d{4}-\d{2}-\d{2}/g, '[DATE]');

    expect(structure).toMatchSnapshot();
  });

  test('All capability sections are present', async () => {
    const systemPrompt = await buildSystemPrompt();

    const requiredSections = [
      "Your Capabilities",
      "Available Books",
      "Recent Activity",
    ];

    for (const section of requiredSections) {
      expect(systemPrompt).toContain(section);
    }
  });
});
```
</snapshot_testing>

<manual_testing>
## Manual Testing Checklist

Some things are best tested manually during development:

### Natural Language Variation Test

Try multiple phrasings for the same request:

```
"Add this to my feed"
"Write something in my reading feed"
"Publish an insight about this"
"Put this in the feed"
"I want this in my feed"
```

All should work if context injection is correct.

### Edge Case Prompts

```
"What can you do?"
→ Agent should describe capabilities

"Help me with my books"
→ Agent should engage with library, not ask what "books" means

"Write something"
→ Agent should ask WHERE (feed, file, etc.) if not clear

"Delete everything"
→ Agent should confirm before destructive actions
```

### Confusion Test

Ask about things that should exist but might not be properly connected:

```
"What's in my research folder?"
→ Should list files, not ask "what research folder?"

"Show me my recent reading"
→ Should show activity, not ask "what do you mean?"

"Continue where I left off"
→ Should reference recent activity if available
```
</manual_testing>

<ci_integration>
## CI/CD Integration

Add agent-native tests to your CI pipeline:

```yaml
# .github/workflows/test.yml
name: Agent-Native Tests

on: [push, pull_request]

jobs:
  agent-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup
        run: npm install

      - name: Run Parity Tests
        run: npm run test:parity

      - name: Run Capability Tests
        run: npm run test:capabilities
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

      - name: Check System Prompt Completeness
        run: npm run test:system-prompt

      - name: Verify Capability Map
        run: |
          npm run generate:capability-map
          git diff --exit-code capability-map.ts
```

### Cost-Aware Testing

Agent tests cost API tokens. Strategies to manage:

```typescript
// Use smaller models for basic tests
const testConfig = {
  model: process.env.CI ? "claude-3-haiku" : "claude-3-opus",
  maxTokens: 500,
};

// Cache responses for deterministic tests
const cachedAgent = new CachedAgent({
  cacheDir: ".test-cache",
  ttl: 24 * 60 * 60 * 1000,  // 24 hours
});

// Run expensive tests only on main branch
if (process.env.GITHUB_REF === 'refs/heads/main') {
  describe('Full Integration Tests', () => { ... });
}
```
</ci_integration>

<test_utilities>
## Test Utilities

### Agent Test Harness

```typescript
class AgentTestHarness {
  private agent: Agent;
  private mockServices: MockServices;

  async setup() {
    this.mockServices = createMockServices();
    this.agent = await createAgent({
      services: this.mockServices,
      model: "claude-3-haiku",
    });
  }

  async chat(message: string): Promise<AgentResponse> {
    return this.agent.chat(message);
  }

  async expectToolCall(toolName: string) {
    const lastResponse = this.agent.getLastResponse();
    expect(lastResponse.toolCalls.map(t => t.name)).toContain(toolName);
  }

  async expectOutcome(check: () => Promise<boolean>) {
    const result = await check();
    expect(result).toBe(true);
  }

  getState() {
    return {
      library: this.mockServices.library.getBooks(),
      feed: this.mockServices.feed.getItems(),
      files: this.mockServices.files.listAll(),
    };
  }
}

// Usage
test('full flow', async () => {
  const harness = new AgentTestHarness();
  await harness.setup();

  await harness.chat("Add 'Moby Dick' to my library");
  await harness.expectToolCall("add_book");
  await harness.expectOutcome(async () => {
    const state = harness.getState();
    return state.library.some(b => b.title.includes("Moby"));
  });
});
```
</test_utilities>

<checklist>
## Testing Checklist

Automated Tests:
- [ ] "Can Agent Do It?" tests for each UI action
- [ ] Location awareness tests ("write to my feed")
- [ ] Parity tests (tool exists, documented in prompt)
- [ ] Context parity tests (agent sees what UI shows)
- [ ] End-to-end flow tests
- [ ] Failure recovery tests

Manual Tests:
- [ ] Natural language variation (multiple phrasings work)
- [ ] Edge case prompts (open-ended requests)
- [ ] Confusion test (agent knows app vocabulary)
- [ ] Surprise test (agent can be creative)

CI Integration:
- [ ] Parity tests run on every PR
- [ ] Capability tests run with API key
- [ ] System prompt completeness check
- [ ] Capability map drift detection
</checklist>

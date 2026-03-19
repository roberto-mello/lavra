<overview>
Start with pure primitives: bash, file operations, basic storage. This proves the architecture works and reveals what the agent actually needs. As patterns emerge, add domain-specific tools deliberately. This document covers when and how to evolve from primitives to domain tools, and when to graduate to optimized code.
</overview>

<start_with_primitives>
## Start with Pure Primitives

Begin every agent-native system with the most atomic tools possible:

- `read_file` / `write_file` / `list_files`
- `bash` (for everything else)
- Basic storage (`store_item` / `get_item`)
- HTTP requests (`fetch_url`)

**Why start here:**

1. **Proves the architecture** - If it works with primitives, your prompts are doing their job
2. **Reveals actual needs** - You'll discover what domain concepts matter
3. **Maximum flexibility** - Agent can do anything, not just what you anticipated
4. **Forces good prompts** - You can't lean on tool logic as a crutch
</start_with_primitives>

<when_to_add_domain_tools>
## When to Add Domain Tools

As patterns emerge, you'll want to add domain-specific tools. This is good—but do it deliberately.

### Vocabulary Anchoring

**Add a domain tool when:** The agent needs to understand domain concepts.

A `create_note` tool teaches the agent what "note" means in your system better than "write a file to the notes directory with this format."

### Guardrails

**Add a domain tool when:** Some operations need validation or constraints that shouldn't be left to agent judgment.

```typescript
// publish_to_feed might enforce format requirements or content policies
tool("publish_to_feed", {
  bookId: z.string(),
  content: z.string(),
  headline: z.string().max(100),  // Enforce headline length
}, async ({ bookId, content, headline }) => {
  // Validate content meets guidelines
  if (containsProhibitedContent(content)) {
    return { text: "Content doesn't meet guidelines", isError: true };
  }
  await feedService.publish({ bookId, content, headline, publishedAt: new Date() });
});
```

### Efficiency

**Add a domain tool when:** Common operations would take many primitive calls.

```typescript
// Primitive approach: multiple calls
// Agent: read library.json, parse, find book, read full_text.txt, read introduction.md...

// Domain tool: one call for common operation
tool("get_book_with_content", { bookId: z.string() }, async ({ bookId }) => {
  const book = await library.getBook(bookId);
  const fullText = await readFile(`Research/${bookId}/full_text.txt`);
  const intro = await readFile(`Research/${bookId}/introduction.md`);
  return { text: JSON.stringify({ book, fullText, intro }) };
});
```
</when_to_add_domain_tools>

<the_rule>
## The Rule for Domain Tools

**Domain tools should represent one conceptual action from the user's perspective.**

They can include mechanical validation, but **judgment about what to do or whether to do it belongs in the prompt**.

### Wrong: Bundles Judgment

```typescript
// WRONG - analyze_and_publish bundles judgment into the tool
tool("analyze_and_publish", async ({ input }) => {
  const analysis = analyzeContent(input);      // Tool decides how to analyze
  const shouldPublish = analysis.score > 0.7;  // Tool decides whether to publish
  if (shouldPublish) {
    await publish(analysis.summary);            // Tool decides what to publish
  }
});
```

### Right: One Action, Agent Decides

```typescript
// RIGHT - separate tools, agent decides
tool("analyze_content", { content: z.string() }, ...);  // Returns analysis
tool("publish", { content: z.string() }, ...);          // Publishes what agent provides

// Prompt: "Analyze the content. If it's high quality, publish a summary."
// Agent decides what "high quality" means and what summary to write.
```

### The Test

Ask: "Who is making the decision here?"

- If the answer is "the tool code" → you've encoded judgment, refactor
- If the answer is "the agent based on the prompt" → good
</the_rule>

<keep_primitives_available>
## Keep Primitives Available

**Domain tools are shortcuts, not gates.**

Unless there's a specific reason to restrict access (security, data integrity), the agent should still be able to use underlying primitives for edge cases.

```typescript
// Domain tool for common case
tool("create_note", { title, content }, ...);

// But primitives still available for edge cases
tool("read_file", { path }, ...);
tool("write_file", { path, content }, ...);

// Agent can use create_note normally, but for weird edge case:
// "Create a note in a non-standard location with custom metadata"
// → Agent uses write_file directly
```

### When to Gate

Gating (making domain tool the only way) is appropriate for:

- **Security:** User authentication, payment processing
- **Data integrity:** Operations that must maintain invariants
- **Audit requirements:** Actions that must be logged in specific ways

**The default is open.** When you do gate something, make it a conscious decision with a clear reason.
</keep_primitives_available>

<graduating_to_code>
## Graduating to Code

Some operations will need to move from agent-orchestrated to optimized code for performance or reliability.

### The Progression

```
Stage 1: Agent uses primitives in a loop
         → Flexible, proves the concept
         → Slow, potentially expensive

Stage 2: Add domain tools for common operations
         → Faster, still agent-orchestrated
         → Agent still decides when/whether to use

Stage 3: For hot paths, implement in optimized code
         → Fast, deterministic
         → Agent can still trigger, but execution is code
```

### The Caveat

**Even when an operation graduates to code, the agent should be able to:**

1. Trigger the optimized operation itself
2. Fall back to primitives for edge cases the optimized path doesn't handle

Graduation is about efficiency. **Parity still holds.** The agent doesn't lose capability when you optimize.
</graduating_to_code>

<decision_framework>
## Decision Framework

### Should I Add a Domain Tool?

| Question | If Yes |
|----------|--------|
| Is the agent confused about what this concept means? | Add for vocabulary anchoring |
| Does this operation need validation the agent shouldn't decide? | Add with guardrails |
| Is this a common multi-step operation? | Add for efficiency |
| Would changing behavior require code changes? | Keep as prompt instead |

### Should I Graduate to Code?

| Question | If Yes |
|----------|--------|
| Is this operation called very frequently? | Consider graduating |
| Does latency matter significantly? | Consider graduating |
| Are token costs problematic? | Consider graduating |
| Do you need deterministic behavior? | Graduate to code |
| Does the operation need complex state management? | Graduate to code |

### Should I Gate Access?

| Question | If Yes |
|----------|--------|
| Is there a security requirement? | Gate appropriately |
| Must this operation maintain data integrity? | Gate appropriately |
| Is there an audit/compliance requirement? | Gate appropriately |
| Is it just "safer" with no specific risk? | Keep primitives available |
</decision_framework>

<checklist>
## Checklist: Primitives to Domain Tools

### Starting Out
- [ ] Begin with pure primitives (read, write, list, bash)
- [ ] Write behavior in prompts, not tool logic
- [ ] Let patterns emerge from actual usage

### Adding Domain Tools
- [ ] Clear reason: vocabulary anchoring, guardrails, or efficiency
- [ ] Tool represents one conceptual action
- [ ] Judgment stays in prompts, not tool code
- [ ] Primitives remain available alongside domain tools

### Graduating to Code
- [ ] Hot path identified (frequent, latency-sensitive, or expensive)
- [ ] Optimized version doesn't remove agent capability
- [ ] Fallback to primitives for edge cases still works

### Gating Decisions
- [ ] Specific reason for each gate (security, integrity, audit)
- [ ] Default is open access
- [ ] Gates are conscious decisions, not defaults
</checklist>

# MCP Server Configuration for OpenCode

The beads-compound plugin uses the Context7 MCP server for framework documentation.

## Manual Configuration Required

OpenCode does not support automatic MCP server installation. You need to manually add the server to your OpenCode configuration.

### Configuration File

Add to `~/.config/opencode/config.json` or your project's `opencode.json`:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upwithcrowd/context7-mcp@latest"],
      "env": {}
    }
  }
}
```

### What Context7 Provides

- Semantic search across PostgreSQL and TimescaleDB documentation
- Framework-specific best practices and patterns
- API reference lookups

### Usage in OpenCode

Once configured, agents can use the Context7 tools to search documentation:

```typescript
// Example: Search PostgreSQL docs
await mcp.call("context7", "search_docs", {
  source: "postgres",
  search_type: "semantic",
  query: "create hypertable with compression",
  version: "latest",
  limit: 5
});
```

## Security Note

The Context7 MCP server runs as a subprocess with access to your environment. Only install if you trust the source.

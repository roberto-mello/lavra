# MCP Server Configuration for Gemini CLI

The beads-compound plugin uses the Context7 MCP server for framework documentation.

## Manual Configuration Required

Gemini CLI does not support automatic MCP server installation. You need to manually add the server to your Gemini configuration.

### Configuration File

Add to `~/.config/gemini/settings.json`:

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

### Usage in Gemini CLI

Once configured, use the `@context7` MCP tool to search documentation:

```
@context7 search_docs source=postgres query="create hypertable" search_type=semantic
```

## Security Note

The Context7 MCP server runs as a subprocess with access to your environment. Only install if you trust the source.

# MCP Server Configuration for Gemini CLI

The beads-compound plugin uses the Context7 MCP server for framework documentation.

The installer automatically configures Context7 in `~/.config/gemini/settings.json`. If you need to add it manually:

### Configuration File

Add to `~/.config/gemini/settings.json`:

```json
{
  "mcpServers": {
    "context7": {
      "url": "https://mcp.context7.com/mcp",
      "type": "http"
    }
  }
}
```

### What Context7 Provides

- Framework documentation lookup
- API reference lookups
- Best practices and patterns for popular libraries

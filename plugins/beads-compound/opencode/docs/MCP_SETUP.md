# MCP Server Configuration for OpenCode

The beads-compound plugin uses the Context7 MCP server for framework documentation.

The installer automatically configures Context7 in `~/.config/opencode/opencode.json`. If you need to add it manually:

### Configuration File

Add to `~/.config/opencode/opencode.json` or your project's `opencode.json`:

```json
{
  "mcp": {
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp"
    }
  }
}
```

Note: OpenCode uses the `mcp` key (not `mcpServers`) and `type: "remote"` for HTTP servers.

### What Context7 Provides

- Framework documentation lookup
- API reference lookups
- Best practices and patterns for popular libraries

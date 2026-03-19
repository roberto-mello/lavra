<when_to_use_scripts>
Even if Claude could write a script, pre-made scripts offer advantages:
- More reliable than generated code
- Save tokens (no need to include code in context)
- Save time (no code generation required)
- Ensure consistency across uses

<execution_vs_reference>
Make clear whether Claude should:
- **Execute the script** (most common): "Run `analyze_form.py` to extract fields"
- **Read it as reference** (for complex logic): "See `analyze_form.py` for the extraction algorithm"

For most utility scripts, execution is preferred.
</execution_vs_reference>

<how_scripts_work>
When Claude executes a script via bash:
1. Script code never enters context window
2. Only script output consumes tokens
3. Far more efficient than having Claude generate equivalent code
</how_scripts_work>
</when_to_use_scripts>

<file_organization>
<scripts_directory>
**Best practice**: Place all executable scripts in a `scripts/` subdirectory within the skill folder.

```
skill-name/
├── SKILL.md
├── scripts/
│   ├── main_utility.py
│   ├── helper_script.py
│   └── validator.py
└── references/
    └── api-docs.md
```

**Benefits**:
- Keeps skill root clean and organized
- Clear separation between documentation and executable code
- Consistent pattern across all skills
- Easy to reference: `python scripts/script_name.py`

**Reference pattern**: In SKILL.md, reference scripts using the `scripts/` path:

```bash
python ~/.claude/skills/skill-name/scripts/analyze.py input.har
```
</scripts_directory>
</file_organization>

<solve_dont_punt>
Handle error conditions rather than punting to Claude.

<configuration_values>
Document configuration parameters to avoid "voodoo constants":

```python
# HTTP requests typically complete within 30 seconds
REQUEST_TIMEOUT = 30

# Three retries balances reliability vs speed
MAX_RETRIES = 3
```
</configuration_values>
</solve_dont_punt>

<package_dependencies>
<runtime_constraints>
Skills run in code execution environment with platform-specific limitations:
- **claude.ai**: Can install packages from npm and PyPI
- **Anthropic API**: No network access and no runtime package installation
</runtime_constraints>

<guidance>
List required packages in your SKILL.md and verify they're available.
</guidance>
</package_dependencies>

<mcp_tool_references>
If your Skill uses MCP (Model Context Protocol) tools, always use fully qualified tool names.

<format>ServerName:tool_name</format>

<examples>
- Use the BigQuery:bigquery_schema tool to retrieve table schemas.
- Use the GitHub:create_issue tool to create issues.
</examples>

Without the server prefix, Claude may fail to locate the tool, especially when multiple MCP servers are available.
</mcp_tool_references>

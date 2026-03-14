<overview>
When building skills that make API calls requiring credentials (API keys, tokens, secrets), follow this protocol to prevent credentials from appearing in chat.
</overview>

<the_problem>
Raw curl commands with environment variables expose credentials:

```bash
# BAD - API key visible in chat
curl -H "Authorization: Bearer $API_KEY" https://api.example.com/data
```

When Claude executes this, the full command with expanded `$API_KEY` appears in the conversation.
</the_problem>

<the_solution>
Use `~/.claude/scripts/secure-api.sh` - a wrapper that loads credentials internally.

<for_supported_services>
```bash
# GOOD - No credentials visible
~/.claude/scripts/secure-api.sh <service> <operation> [args]

# Examples:
~/.claude/scripts/secure-api.sh facebook list-campaigns
~/.claude/scripts/secure-api.sh ghl search-contact "email@example.com"
```
</for_supported_services>
</the_solution>

<credential_storage>
**Location:** `~/.claude/.env` (global for all skills, accessible from any directory)

**Format:**
```bash
# Service credentials
SERVICE_API_KEY=your-key-here
SERVICE_ACCOUNT_ID=account-id-here

# Another service
OTHER_API_TOKEN=token-here
OTHER_BASE_URL=https://api.other.com
```

**Loading in script:**
```bash
set -a
source ~/.claude/.env 2>/dev/null || { echo "Error: ~/.claude/.env not found" >&2; exit 1; }
set +a
```
</credential_storage>

<best_practices>
1. **Never use raw curl with `$VARIABLE` in skill examples** - always use the wrapper
2. **Add all operations to the wrapper** - don't make users figure out curl syntax
3. **Auto-create credential placeholders** - add empty fields to `~/.claude/.env` immediately when creating the skill
4. **Keep credentials in `~/.claude/.env`** - one central location, works everywhere
5. **Document each operation** - show examples in SKILL.md
6. **Handle errors gracefully** - check for missing env vars, show helpful error messages
</best_practices>

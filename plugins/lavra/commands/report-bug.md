---
name: report-bug
description: "Report a bug in the Lavra plugin"
argument-hint: [optional: brief description of the bug]
disable-model-invocation: true
---

<objective>
Report bugs encountered while using the Lavra plugin by gathering structured information and generating a pre-filled GitHub issue link.
</objective>

<process>

## Step 1: Gather Bug Information

Use the AskUserQuestion tool to collect the following information:

**Question 1: Bug Category**
- What type of issue are you experiencing?
- Options: Agent not working, Command not working, Skill not working, MCP server issue, Installation problem, Other

**Question 2: Specific Component**
- Which specific component is affected?
- Ask for the name of the agent, command, skill, or MCP server

**Question 3: What Happened (Actual Behavior)**
- Ask: "What happened when you used this component?"
- Get a clear description of the actual behavior

**Question 4: What Should Have Happened (Expected Behavior)**
- Ask: "What did you expect to happen instead?"
- Get a clear description of expected behavior

**Question 5: Steps to Reproduce**
- Ask: "What steps did you take before the bug occurred?"
- Get reproduction steps

**Question 6: Error Messages**
- Ask: "Did you see any error messages? If so, please share them."
- Capture any error output

## Step 2: Collect Environment Information

Automatically gather:
```bash
# Get plugin version
cat ~/.claude/plugins/installed_plugins.json 2>/dev/null | grep -A5 "lavra" | head -10 || echo "Plugin info not found"

# Get Claude Code version
claude --version 2>/dev/null || echo "Claude CLI version unknown"

# Get OS info
uname -a
```

## Step 3: Format the Bug Report

Create a well-structured bug report with:

```markdown
## Bug Description

**Component:** [Type] - [Name]
**Summary:** [Brief description from argument or collected info]

## Environment

- **Plugin Version:** [from installed_plugins.json]
- **Claude Code Version:** [from claude --version]
- **OS:** [from uname]

## What Happened

[Actual behavior description]

## Expected Behavior

[Expected behavior description]

## Steps to Reproduce

1. [Step 1]
2. [Step 2]
3. [Step 3]

## Error Messages

```
[Any error output]
```

## Additional Context

[Any other relevant information]

---
*Reported via `/report-bug` command*
```

## Step 4: Generate Issue Link

URL-encode the title and body, then construct a pre-filled GitHub issue URL:

```
https://github.com/roberto-mello/lavra/issues/new?title=<url-encoded-title>&body=<url-encoded-body>&labels=bug
```

Title: `[Lavra] Bug: [Brief description]`
Body: the formatted report from Step 3

Use Python to build the URL:

```bash
python3 -c "
import urllib.parse
title = '[Lavra] Bug: <brief description>'
body = '''<formatted report>'''
base = 'https://github.com/roberto-mello/lavra/issues/new'
print(base + '?title=' + urllib.parse.quote(title) + '&body=' + urllib.parse.quote(body) + '&labels=bug')
"
```

## Step 5: Present the Link

Display the URL and instruct the user to open it in a browser:

```
Open this link to submit the bug report (pre-filled):
<generated URL>
```

The link works on any platform — no `gh` CLI required.

</process>

<success_criteria>
- [ ] All six bug information questions answered
- [ ] Environment information collected automatically
- [ ] Bug report formatted with all sections
- [ ] Pre-filled GitHub issue URL generated
- [ ] URL displayed to user with instructions to open in browser
</success_criteria>

<guardrails>

## Error Handling

- If Python is unavailable: display the formatted report and direct user to https://github.com/roberto-mello/lavra/issues/new to paste it manually
- If required information is missing: Re-prompt for that specific field

## Privacy Notice

This command does NOT collect:
- Personal information
- API keys or credentials
- Private code from your projects
- File paths beyond basic OS info

Only technical information about the bug is included in the report.

</guardrails>

# Codex Hook Probe Snippets

Date: 2026-04-30

Use these snippets for live Codex validation of Lavra hook assumptions.

## LP1: Capture raw PostToolUse payload

Hook command target:

```bash
bash -lc 'cat | /ABS/PATH/TO/lavra/scripts/probe-codex-hook-payload.sh'
```

Then run one shell command in Codex. Inspect:

- `/tmp/lavra-codex-probes/payload-*.json`
- `/tmp/lavra-codex-probes/field-map-*.txt`

## LP2: Matcher semantics test

Temporary logger command:

```bash
bash -lc 'mkdir -p /tmp/lavra-codex-probes; echo "$(date +%s) fired" >> /tmp/lavra-codex-probes/matcher.log'
```

Run three variants for `PostToolUse.matcher`:

1. `bash`
2. `Bash`
3. broad fallback (or no matcher)

For each variant:

1. trigger one shell tool call
2. trigger one non-shell tool call
3. compare log entries and determine false positives

## Evidence Capture Template

Record this in bead comments:

```text
variant=<value>
shell_fired=<yes|no>
nonshell_fired=<yes|no>
verdict=<pass|fail>
notes=<payload keys/case sensitivity>
```

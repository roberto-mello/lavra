# GitHub Release Checklist

When asked to create a GitHub release, run ALL steps in order. Do not tag or push until pre-release checks pass.

## 1. Sync

```bash
git pull --rebase
```

## 2. Verify versions are set correctly

These four locations must all have the target version:

- `plugins/lavra/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json` — must match `plugin.json` exactly
- `LAVRA_VERSION` constant in `plugins/lavra/hooks/auto-recall.sh`
- Version string in `plugins/lavra/hooks/provision-memory.sh` (the `echo "X.Y.Z"` line)

Also verify that `site/public/command-map.html` reflects current nodes/connections (new commands, agents, or skills should be added).

Verify that the five reference docs match current plugin contents:

- `site/src/content/docs/commands.md` — check against command frontmatter descriptions:
  ```bash
  grep '^description:' plugins/lavra/commands/*.md plugins/lavra/commands/optional/*.md
  ```
- `site/src/content/docs/agents.md` — check against agent frontmatter descriptions:
  ```bash
  grep '^description:' plugins/lavra/agents/**/*.md
  ```
- `site/src/content/docs/skills.md` — check against skill SKILL.md descriptions:
  ```bash
  grep '^description:' plugins/lavra/skills/*/SKILL.md
  ```
- `site/src/content/docs/CATALOG.md` — command ghost/missing checks are automated (pre-release-check.sh catches them). Still verify manually: agent/skill counts and listings match plugin contents, hook count matches `plugins/lavra/hooks/hooks.json`, and agent model tiers match frontmatter:
  ```bash
  grep '^model:' plugins/lavra/agents/**/*.md | sort | uniq -c
  for f in plugins/lavra/commands/*.md plugins/lavra/commands/optional/*.md; do basename "$f" .md; done | sort
  ```
- `site/src/content/docs/PLATFORMS.md` — verify the feature support table matches what each installer actually installs. Check `installers/install-gemini.sh`, `installers/install-opencode.sh`, and `installers/install-cortex.sh` for what they copy.

If any command, agent, or skill was added, renamed, or had its description changed since the last release, update the corresponding doc before proceeding.

The pre-release check (step 3) will catch any mismatch, but fix them before running it.

## 3. Run pre-release checks (MUST PASS before tagging)

```bash
bash scripts/pre-release-check.sh
```

This replicates the CI `verify-release` job locally:
- Version consistency between `plugin.json` and `marketplace.json`
- Conversion outputs generated (OpenCode + Gemini)
- Component counts (23+ commands, 30+ agents, 15+ skills)
- Source files present
- Catalog accuracy: ghost commands (in CATALOG.md, no file) and missing entries (file exists, not in catalog) both fail
- Compatibility tests pass

**Do not proceed if any check fails.**

## 4. Run installer smoke tests (MUST PASS before tagging)

### Claude installer

Create a fresh test project, run the installer, and verify the memory system:

```bash
mkdir -p /tmp/test-beads-install && cd /tmp/test-beads-install
git init -q && bd init --quiet 2>/dev/null
bash ~/Documents/projects/lavra/install.sh /tmp/test-beads-install
```

Verify the memory directory:

```bash
ls /tmp/test-beads-install/.beads/memory/
# Must contain: knowledge.jsonl, recall.sh, knowledge-db.sh, .gitattributes, .gitignore

cat /tmp/test-beads-install/.beads/memory/.gitignore
# Must contain: knowledge.db (and journal/wal/shm variants)

cat /tmp/test-beads-install/.beads/memory/.gitattributes
# Must contain: knowledge.jsonl merge=union

cat /tmp/test-beads-install/.gitignore 2>/dev/null || echo "(no project .gitignore -- correct)"
# Must NOT contain .beads/
```

Verify the .beads/ warning prompt fires when .gitignore already has .beads/:

```bash
echo ".beads/" >> /tmp/test-beads-install/.gitignore
bash ~/Documents/projects/lavra/install.sh /tmp/test-beads-install 2>&1 | grep -A5 '\[!\] Warning'
# Must show the data loss warning and [non-interactive] message
```

### OpenCode installer

Tests conversion + file installation. Does not require OpenCode to be installed.

```bash
mkdir -p /tmp/test-opencode-install && cd /tmp/test-opencode-install
git init -q && bd init --quiet 2>/dev/null
bash ~/Documents/projects/lavra/install.sh -opencode --yes /tmp/test-opencode-install
```

Verify:

```bash
ls /tmp/test-opencode-install/.opencode/hooks/
# Must contain: auto-recall.sh, memory-capture.sh, subagent-wrapup.sh

ls /tmp/test-opencode-install/.beads/memory/
# Must contain: knowledge.jsonl, recall.sh, knowledge-db.sh, .gitattributes, .gitignore
```

### Gemini installer

Tests conversion + file installation. Does not require Gemini CLI to be installed.

```bash
mkdir -p /tmp/test-gemini-install && cd /tmp/test-gemini-install
git init -q && bd init --quiet 2>/dev/null
bash ~/Documents/projects/lavra/install.sh -gemini --yes /tmp/test-gemini-install
```

Verify:

```bash
ls /tmp/test-gemini-install/hooks/
# Must contain: auto-recall.sh, memory-capture.sh, subagent-wrapup.sh

ls /tmp/test-gemini-install/.beads/memory/
# Must contain: knowledge.jsonl, recall.sh, knowledge-db.sh, .gitattributes, .gitignore
```

### Clean up

```bash
rm -rf /tmp/test-beads-install /tmp/test-opencode-install /tmp/test-gemini-install
cd ~/Documents/projects/lavra
```

**Do not proceed if any verification fails.**

## 5. Push commits

```bash
git push
```

## 6. Tag and release

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
gh release create vX.Y.Z --title "vX.Y.Z" --generate-notes
```

## 7. Verify CI passes

```bash
gh run list --limit 5
# If failed: gh run view <run-id> --log-failed
```

## If CI fails post-release

Do NOT delete and recreate the tag. Bump to a patch version, fix, and release that instead.

## Keeping pre-release checks in sync with CI

`scripts/pre-release-check.sh` mirrors the `verify-release` job in `.github/workflows/test-installation.yml`.

**When modifying either file, always update the other.** Both files have a `SYNC:` comment pointing to each other as a reminder. If CI adds a new check, add it to the script. If the script adds a new check, add it to CI.

The catalog accuracy check (`=== Catalog accuracy ===`) also appears in the `test-compatibility` job, which runs on every PR to `main`. If you change the catalog check logic in pre-release-check.sh, update both CI locations.

## Key facts

- `marketplace.json` uses `"name"` field (not `"id"`) per the Claude Code plugin spec
- CI query: `.plugins[] | select(.name == "lavra") | .version`
- Both `plugin.json` and `marketplace.json` versions must match or CI fails

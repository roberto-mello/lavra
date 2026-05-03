# GitHub Release Checklist

When asked to create a GitHub release, run ALL steps in order. Do not tag or push until pre-release checks pass.

## 1. Sync

```bash
git pull --rebase
```

## 2. Verify versions are set correctly

These six locations must all have the target version:

- `package.json` — npm package version (required for `bunx lavra@latest`)
- `plugins/lavra/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json` — must match `plugin.json` exactly
- `LAVRA_VERSION` constant in `plugins/lavra/hooks/auto-recall.sh`
- Version string in `plugins/lavra/hooks/provision-memory.sh` (the `echo "X.Y.Z"` line)
- Release notes link in `README.md` line 16 — update both version number and URL slug (e.g. `v0.7.4 Release Notes` → `https://lavra.dev/docs/releases/v0.7.4`)

Also verify that `site/public/command-map.html` reflects current nodes/connections (new commands, agents, or skills should have nodes; updated handoff flows should have edges). To spot missing nodes:

```bash
# Nodes in the map
grep -oE "id:'[a-z][a-z0-9-]+'" site/public/command-map.html | sort -u

# Commands on disk
ls plugins/lavra/commands/*.md plugins/lavra/commands/optional/*.md | xargs -I{} basename {} .md | sort

# Agents on disk
find plugins/lavra/agents -name "*.md" | xargs -I{} basename {} .md | sort
```

Compare the outputs — any command or agent on disk but absent from the map needs a node added. Edges (command → command suggestions) must be updated manually when handoff sections change.

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

## 2b. Release notes

Release notes live at `site/src/content/docs/releases/vX.Y.Z.md`.

**When drafting notes** (as changes land, not at release time):
- Create the file with `draft: true` in the frontmatter so it's excluded from production builds
- Load the `/humanizer` skill before writing — run it as the first step, not as a cleanup pass at the end
- Follow the tone and structure of prior releases in `site/src/content/docs/releases/`

**Before tagging** (step 6 below):
- Run a final `/humanizer` pass on the release notes file
- Set the release date in the frontmatter
- Remove `draft: true`
- If the release touches `plugins/lavra/hooks/memorysanitize/`, update the draft notes to mention the Go helper and fallback behavior explicitly

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

Verify the .lavra/ structure:

```bash
ls /tmp/test-beads-install/.lavra/
# Must contain: .gitignore, .gitattributes, .lavra-version, memory/, config/, retros/

cat /tmp/test-beads-install/.lavra/.gitignore
# Must contain: memory/knowledge.db (paths use memory/ prefix)

cat /tmp/test-beads-install/.lavra/.gitattributes
# Must contain: memory/knowledge.jsonl merge=union

cat /tmp/test-beads-install/.lavra/.lavra-version
# Must contain: the target release version (e.g. 0.7.5)

ls /tmp/test-beads-install/.lavra/memory/
# Must contain: knowledge.jsonl, recall.sh, knowledge-db.sh
# Must NOT contain: .db, .db-wal files (gitignored)

cat /tmp/test-beads-install/.gitignore 2>/dev/null || echo "(no project .gitignore -- correct)"
# Must NOT contain .lavra/
```

Verify git merge=union attribute is registered:

```bash
cd /tmp/test-beads-install
git check-attr merge .lavra/memory/knowledge.jsonl
# Expected: .lavra/memory/knowledge.jsonl: merge: union
```

Verify the .lavra/ warning prompt fires when .gitignore already has .lavra/:

```bash
echo ".lavra/" >> /tmp/test-beads-install/.gitignore
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

ls /tmp/test-opencode-install/.lavra/memory/
# Must contain: knowledge.jsonl, recall.sh, knowledge-db.sh

ls /tmp/test-opencode-install/.lavra/
# Must contain: .gitignore, .gitattributes, .lavra-version
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

ls /tmp/test-gemini-install/.lavra/memory/
# Must contain: knowledge.jsonl, recall.sh, knowledge-db.sh

ls /tmp/test-gemini-install/.lavra/
# Must contain: .gitignore, .gitattributes, .lavra-version
```

### npx/bunx installer smoke test

This tests the exact code path users hit with `npx @lavralabs/lavra@latest` — the `bin/install.js` entrypoint. Run this for each platform before tagging.

```bash
mkdir -p /tmp/test-npx-install && cd /tmp/test-npx-install
git init -q && bd init -q 2>/dev/null || true

# Claude
node ~/Documents/projects/lavra/bin/install.js --claude --yes /tmp/test-npx-install
# Verify
ls .claude/commands/ | wc -l   # expect 18+
ls .claude/agents/review/      # expect agent files

# Cortex
node ~/Documents/projects/lavra/bin/install.js --cortex --yes /tmp/test-npx-install
# Verify
ls .cortex/commands/ | wc -l   # expect 18+
ls .cortex/hooks/              # expect hook scripts
```

Verify the output ends with the workflow block (not "0 commands, 0 agents"):
```
Main workflow:
  /lavra-design <feature description>   ...
  /lavra-work <bead id>                 ...
  /lavra-qa                             ...
  /lavra-ship                           ...
```

### Clean up

```bash
rm -rf /tmp/test-beads-install /tmp/test-opencode-install /tmp/test-gemini-install /tmp/test-npx-install
cd ~/Documents/projects/lavra
```

**Do not proceed if any verification fails.**

## 4b. Build helper artifacts for macOS and Linux

If the release touches `plugins/lavra/hooks/memorysanitize/`, build the helper binaries that should be attached to the GitHub release:

```bash
bash scripts/build-memory-sanitize-helper.sh
ls dist/memorysanitize/
# Must contain:
#   memory-sanitize-darwin-amd64
#   memory-sanitize-darwin-arm64
#   memory-sanitize-linux-amd64
#   memory-sanitize-linux-arm64
#   SHA256SUMS.txt
```

These assets are cross-compiled from the single Go helper source. They are not consumed by the installer today, but they are the release artifacts we keep for manual distribution, validation, and future binary-first installs.

## 5. Push commits

```bash
git push
```

## 6. Tag and release

Before tagging: finalize release notes at `site/src/content/docs/releases/vX.Y.Z.md` — run a final `/humanizer` pass, set the release date, and remove `draft: true`.

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
gh release create vX.Y.Z --title "vX.Y.Z" --generate-notes
```

If helper artifacts were built in step 4b, upload them to the GitHub release:

```bash
gh release upload vX.Y.Z dist/memorysanitize/memory-sanitize-* dist/memorysanitize/SHA256SUMS.txt
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

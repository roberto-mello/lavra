# Writing Style

## Brand name capitalization

**Lavra** is always capitalized in prose — headlines, sentences, descriptions, frontmatter.

Lowercase `lavra` is only correct when it appears as:
- A command name: `/lavra-design`, `/lavra-work`
- A package name: `npx lavra@latest`, `lavra.json`
- A file or directory path: `plugins/lavra/`, `.opencode/plugins/lavra/`
- A code block token or inline code: `` `lavra` ``
- A URL segment: `github.com/roberto-mello/lavra`

When editing docs, run this to spot prose violations:

```bash
grep -rn "\blavra\b" site/src/content/docs/ | \
  grep -v "lavra@\|lavra\.json\|/lavra-\|lavra-\*\|lavra#\|\.lavra\|plugins/lavra\|opencode/lavra\|\[lavra\]"
```

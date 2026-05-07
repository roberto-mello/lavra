---
description: Go helper for memory sanitization
globs: "plugins/lavra/hooks/memorysanitize/**,scripts/build-memory-sanitize-helper.sh"
---

# Go Memory Helper

When changing the Go memory sanitizer helper or its release build script:

- Load the `golang-pro` skill first.
- Keep `plugins/lavra/hooks/memory-sanitize.sh` as a thin shell orchestrator.
- Put parsing, dedupe, drift validation, and audit logic in the Go helper, not back into shell.
- Preserve the fallback contract: if `go` is unavailable, the shell wrapper may fall back to the reduced `jq` sanitizer path.

Required validation before finishing:

- `gofmt -w plugins/lavra/hooks/memorysanitize/*.go`
- `go test -race ./...` from `plugins/lavra/hooks/memorysanitize/`
- `go vet ./...` from `plugins/lavra/hooks/memorysanitize/`
- `golangci-lint run` from `plugins/lavra/hooks/memorysanitize/`

Distribution rules:

- The helper is source-distributed today. Installers must copy the `memorysanitize/` directory anywhere they copy `memory-sanitize.sh`.
- Keep release asset generation in `scripts/build-memory-sanitize-helper.sh`.
- If the release procedure changes for helper binaries, update `.agents/rules/github-release.md`, `scripts/pre-release-check.sh`, and `.github/workflows/test-installation.yml` together.

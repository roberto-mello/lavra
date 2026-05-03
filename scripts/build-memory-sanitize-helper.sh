#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_DIR="$REPO_ROOT/plugins/lavra/hooks/memorysanitize"
OUT_DIR="${1:-$REPO_ROOT/dist/memorysanitize}"
GOCACHE_DIR="${GOCACHE:-$OUT_DIR/.gocache}"

mkdir -p "$OUT_DIR"
mkdir -p "$GOCACHE_DIR"
rm -f "$OUT_DIR"/memory-sanitize-* "$OUT_DIR"/SHA256SUMS.txt

TARGETS=(
  "darwin amd64"
  "darwin arm64"
  "linux amd64"
  "linux arm64"
)

for target in "${TARGETS[@]}"; do
  read -r GOOS GOARCH <<<"$target"
  OUTPUT="$OUT_DIR/memory-sanitize-${GOOS}-${GOARCH}"

  echo "Building ${GOOS}/${GOARCH} -> ${OUTPUT}"
  (
    cd "$HELPER_DIR"
    GOCACHE="$GOCACHE_DIR" CGO_ENABLED=0 GOOS="$GOOS" GOARCH="$GOARCH" go build -trimpath -ldflags="-s -w" -o "$OUTPUT" .
  )
done

(
  cd "$OUT_DIR"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 memory-sanitize-* > SHA256SUMS.txt
  else
    sha256sum memory-sanitize-* > SHA256SUMS.txt
  fi
)

echo "Built helper artifacts in $OUT_DIR"

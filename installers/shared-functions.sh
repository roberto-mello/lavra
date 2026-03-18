#!/bin/bash
#
# Shared installer functions for lavra
#
# This file is sourced by platform-specific installers to provide
# common functionality across all platforms.
#

# Print lavra ASCII art banner
print_banner() {
  local platform="${1:-}"
  local version="${2:-0.7.0}"

  # #10b981 → closest 256-color: 35 (medium spring green)
  local GREEN='\033[38;5;35m'
  local DIM='\033[2m'
  local RESET='\033[0m'

  printf "${GREEN}"
  printf '  ██╗      █████╗ ██╗   ██╗██████╗  █████╗ \n'
  printf '  ██║     ██╔══██╗██║   ██║██╔══██╗██╔══██╗\n'
  printf '  ██║     ███████║██║   ██║██████╔╝███████║\n'
  printf '  ██║     ██╔══██║╚██╗ ██╔╝██╔══██╗██╔══██║\n'
  printf '  ███████╗██║  ██║ ╚████╔╝ ██║  ██║██║  ██║\n'
  printf '  ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═╝\n'
  printf "${RESET}"
  if [ -n "$platform" ]; then
    printf "  ${DIM}v${version} · ${platform}${RESET}\n"
  else
    printf "  ${DIM}v${version}${RESET}\n"
  fi
  printf "\n"
}

# Create directory with symlink handling
# Handles dotfiles repos where config directories are symlinks
create_dir_with_symlink_handling() {
  local dir="$1"
  local parent=$(dirname "$dir")
  local basename=$(basename "$dir")

  # Check if parent contains a symlink to this directory
  if [[ -L "$parent/$basename" ]]; then
    local real_path=$(readlink "$parent/$basename")
    echo "  [!] Note: $basename is a symlink to: $real_path"

    if [[ ! -d "$real_path" ]]; then
      mkdir -p "$real_path" || {
        echo "[!] Error: Could not create symlink target: $real_path"
        echo "    Please create this directory manually or adjust your symlink setup"
        return 1
      }
      echo "  ✓ Created symlink target directory"
    fi
  fi

  mkdir -p "$dir" || {
    echo "[!] Error: Could not create directory: $dir"
    return 1
  }
}

# Migrate existing .beads/ Lavra data to .lavra/
# Called BEFORE provision_memory_dir in all installers (order is load-bearing).
# If provision runs first, it creates an empty knowledge.jsonl; the idempotency
# guard (-s: non-empty) would then skip migration, leaving data in .beads/ silently.
migrate_beads_to_lavra() {
  local TARGET="$1"
  local migrated=0

  # Idempotent: skip if .lavra/memory/knowledge.jsonl is non-empty (has data)
  # NOTE: check non-empty (-s) not just present (-f) — provision creates an empty file
  if [[ -s "$TARGET/.lavra/memory/knowledge.jsonl" ]]; then
    echo "  [i] .lavra/ already has knowledge data -- skipping migration"
    return 0
  fi

  if [ -d "$TARGET/.beads/memory" ] && [ -f "$TARGET/.beads/memory/knowledge.jsonl" ]; then
    # Copy memory files, excluding SQLite cache, gitconfig files, and scripts
    # already written by provision. Skip symlinks to avoid dereference outside .beads/.
    mkdir -p "$TARGET/.lavra/memory"
    for f in "$TARGET/.beads/memory/"*; do
      [ -L "$f" ] && continue  # skip symlinks
      fname=$(basename "$f")
      case "$fname" in
        *.db|*.db-wal|*.db-shm|*.db-journal|.gitattributes|.gitignore) continue ;;
        recall.sh|knowledge-db.sh) continue ;;  # new versions written by provision
        *) cp -n "$f" "$TARGET/.lavra/memory/" 2>/dev/null || true ;;
      esac
    done
    migrated=1
  fi

  if [ -d "$TARGET/.beads/config" ] && [ -f "$TARGET/.beads/config/lavra.json" ]; then
    mkdir -p "$TARGET/.lavra/config"
    cp -rn "$TARGET/.beads/config/." "$TARGET/.lavra/config/" 2>/dev/null || true
    migrated=1
  fi

  if [ -d "$TARGET/.beads/retros" ]; then
    mkdir -p "$TARGET/.lavra/retros"
    cp -rn "$TARGET/.beads/retros/." "$TARGET/.lavra/retros/" 2>/dev/null || true
    migrated=1
  fi

  if [ "$migrated" -eq 1 ]; then
    echo ""
    echo "[!] Old Lavra data found in .beads/ — copied to .lavra/"
    echo "    .beads/ data preserved. Safe to delete after verifying .lavra/ data is intact."
    echo "    To remove: rm -rf .beads/memory .beads/config/lavra.json .beads/retros"
    echo ""
  fi
}

# Resolve target directory to absolute path with error handling
resolve_target_dir() {
  local target="$1"

  mkdir -p "$target" || {
    echo "[!] Error: Could not create target directory: $target"
    return 1
  }

  local resolved
  resolved="$(cd "$target" && pwd)" || {
    echo "[!] Error: Could not access target directory: $target"
    return 1
  }

  echo "$resolved"
}

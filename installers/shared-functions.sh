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

# Parse common installer flags and resolve TARGET + GLOBAL_INSTALL.
#
# Reads from caller's environment:
#   LAVRA_GLOBAL_DEFAULT  — platform-specific global install path (required)
#   LAVRA_HOOKS_ARE_GLOBAL — set to "true" for platforms (e.g. Cortex) where
#                            hooks are always installed globally and per-project
#                            install is not meaningful. Suppresses the project-
#                            detection question since the user can't actually
#                            scope hooks to a single project on those platforms.
#
# Sets in caller's scope (use eval):
#   AUTO_YES, QUIET, GLOBAL_INSTALL, TARGET
#
# Usage:
#   LAVRA_GLOBAL_DEFAULT="$HOME/.claude"
#   LAVRA_HOOKS_ARE_GLOBAL=false
#   eval "$(parse_installer_args "$@")"
parse_installer_args() {
  local auto_yes=false
  local quiet=false
  local positional=()

  local force_global=false
  local no_banner=false
  for arg in "$@"; do
    case "$arg" in
      --yes|-y) auto_yes=true ;;
      --quiet|-q) quiet=true ;;
      --global) force_global=true ;;
      --no-banner) no_banner=true ;;
      *) positional+=("$arg") ;;
    esac
  done

  local global_install=true
  local target="${LAVRA_GLOBAL_DEFAULT}"

  if [ "$force_global" = true ]; then
    global_install=true
    target="${LAVRA_GLOBAL_DEFAULT}"
  elif [ ${#positional[@]} -gt 0 ]; then
    target="${positional[0]}"
    global_install=false
  elif [ "${LAVRA_HOOKS_ARE_GLOBAL:-false}" != "true" ] \
    && [ "$auto_yes" = false ] && [ "$quiet" = false ] && [ -t 0 ]; then
    # No explicit path given, running interactively, and per-project install
    # is supported on this platform. Check if the user is standing in a project
    # directory — if so, global is probably not what they intended.
    if [ -d "$PWD/.beads" ] || [ -d "$PWD/.git" ]; then
      echo "  Detected a project in the current directory: $PWD" >&2
      echo "" >&2
      echo "  Install for this project only, or globally (all projects)?" >&2
      echo "    1) This project only  ($PWD)" >&2
      echo "    2) Globally           (${LAVRA_GLOBAL_DEFAULT}, then run /lavra-setup per project)" >&2
      echo "" >&2
      read -r -p "  Choose [1/2, default: 1]: " scope_choice </dev/tty
      echo "" >&2
      case "$scope_choice" in
        2)
          # Confirmed global — keep defaults
          ;;
        *)
          target="$PWD"
          global_install=false
          ;;
      esac
    fi
  fi

  # Emit variable assignments for eval in caller
  printf 'AUTO_YES=%s\n' "$auto_yes"
  printf 'QUIET=%s\n' "$quiet"
  printf 'GLOBAL_INSTALL=%s\n' "$global_install"
  printf 'NO_BANNER=%s\n' "$no_banner"
  printf 'TARGET=%s\n' "$(cd "$target" 2>/dev/null && pwd || echo "$target")"
}

# Sync a flat directory of files from source to target.
# Copies new/changed files, removes files present in target but not source.
# Only removes files that were previously installed by Lavra (tracked in manifest).
#
# Usage: sync_flat_dir SOURCE_DIR TARGET_DIR MANIFEST_FILE MANIFEST_KEY [PATTERN]
#
# MANIFEST_FILE: path to .lavra-manifest (one "KEY:relative/path" per line)
# MANIFEST_KEY:  prefix in manifest lines for this directory (e.g. "commands")
# PATTERN:       glob pattern, defaults to "*.md"
#
# Returns: number of files installed (stdout)
sync_flat_dir() {
  local SOURCE_DIR="$1"
  local TARGET_DIR="$2"
  local MANIFEST_FILE="$3"
  local MANIFEST_KEY="$4"
  local PATTERN="${5:-*.md}"
  local count=0
  local new_manifest="${MANIFEST_FILE}.new"
  local src_list

  # Build sorted list of source filenames (newline-separated, for grep lookup)
  src_list=""
  for src in "$SOURCE_DIR"/$PATTERN; do
    [ -f "$src" ] || continue
    local fname
    fname=$(basename "$src")
    src_list="${src_list}${fname}"$'\n'
    cp "$src" "$TARGET_DIR/$fname"
    count=$((count + 1))
    printf '%s:%s\n' "$MANIFEST_KEY" "$fname" >> "$new_manifest"
  done

  # Remove stale files: in old manifest but no longer in source
  if [ -f "$MANIFEST_FILE" ]; then
    while IFS= read -r line; do
      [[ "$line" == "$MANIFEST_KEY:"* ]] || continue
      local fname="${line#$MANIFEST_KEY:}"
      # Check if fname is in src_list
      if ! printf '%s' "$src_list" | grep -qxF "$fname" && [ -f "$TARGET_DIR/$fname" ]; then
        rm -f "$TARGET_DIR/$fname"
        echo "  - Removed stale: $fname" >&2
      fi
    done < "$MANIFEST_FILE"
  fi

  echo "$count"
}

# Sync a nested directory (one level of subdirs) from source to target.
# Each subdir is treated as a unit. Removes files that no longer exist in source.
# Only removes files tracked in manifest.
#
# Usage: sync_nested_dir SOURCE_DIR TARGET_DIR MANIFEST_FILE MANIFEST_KEY [PATTERN]
sync_nested_dir() {
  local SOURCE_DIR="$1"
  local TARGET_DIR="$2"
  local MANIFEST_FILE="$3"
  local MANIFEST_KEY="$4"
  local PATTERN="${5:-*.md}"
  local count=0
  local new_manifest="${MANIFEST_FILE}.new"
  local src_rel_list

  # Build sorted list of "category/fname" entries from source (for grep lookup)
  src_rel_list=""
  for category_path in "$SOURCE_DIR"/*/; do
    [ -d "$category_path" ] || continue
    local category
    category=$(basename "$category_path")
    mkdir -p "$TARGET_DIR/$category"

    for src in "$category_path"/$PATTERN; do
      [ -f "$src" ] || continue
      local fname
      fname=$(basename "$src")
      src_rel_list="${src_rel_list}${category}/${fname}"$'\n'
      cp "$src" "$TARGET_DIR/$category/$fname"
      count=$((count + 1))
      printf '%s:%s/%s\n' "$MANIFEST_KEY" "$category" "$fname" >> "$new_manifest"
    done
  done

  # Remove stale files: in old manifest but no longer in source
  if [ -f "$MANIFEST_FILE" ]; then
    while IFS= read -r line; do
      [[ "$line" == "$MANIFEST_KEY:"* ]] || continue
      local rel="${line#$MANIFEST_KEY:}"
      if ! printf '%s' "$src_rel_list" | grep -qxF "$rel" && [ -f "$TARGET_DIR/$rel" ]; then
        rm -f "$TARGET_DIR/$rel"
        echo "  - Removed stale: $rel" >&2
      fi
    done < "$MANIFEST_FILE"
  fi

  echo "$count"
}

# Begin a new manifest write cycle. Call before installing files.
# Creates a .new manifest file. Finalize with commit_manifest.
begin_manifest() {
  local MANIFEST_FILE="$1"
  mkdir -p "$(dirname "$MANIFEST_FILE")"
  : > "${MANIFEST_FILE}.new"
}

# Commit the new manifest, replacing the old one.
commit_manifest() {
  local MANIFEST_FILE="$1"
  mv "${MANIFEST_FILE}.new" "$MANIFEST_FILE"
}

# Read lavra version from plugin manifest
get_lavra_version() {
  local plugin_dir="${1:-}"
  if [ -z "$plugin_dir" ]; then
    plugin_dir="$SCRIPT_DIR/plugins/lavra"
  fi
  local manifest="$plugin_dir/.claude-plugin/plugin.json"
  if [ -f "$manifest" ] && command -v jq &>/dev/null; then
    jq -r '.version // "0.0.0"' "$manifest"
  else
    echo "0.0.0"
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

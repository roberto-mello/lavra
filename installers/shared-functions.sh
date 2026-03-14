#!/bin/bash
#
# Shared installer functions for lavra
#
# This file is sourced by platform-specific installers to provide
# common functionality across all platforms.
#

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

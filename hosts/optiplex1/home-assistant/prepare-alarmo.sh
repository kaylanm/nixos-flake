#!/usr/bin/env bash
set -euo pipefail

config_dir=$1
target="$config_dir/custom_components/alarmo"
if [ -L "$config_dir/custom_components" ] || [ -L "$target" ]; then
  printf 'Refusing symlinked Alarmo mountpoint or custom_components directory: %s\n' "$target" >&2
  exit 1
fi
if [ -d "$target" ] && [ -n "$(find "$target" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  printf 'Refusing to hide existing Alarmo files at %s; back up and relocate them first.\n' "$target" >&2
  exit 1
fi
mkdir -p "$target"

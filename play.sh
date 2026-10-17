#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ -x builds/linux/SnowPals.x86_64 ]]; then
  exec ./builds/linux/SnowPals.x86_64 "$@"
elif command -v godot >/dev/null 2>&1; then
  exec godot --path . "$@"
elif command -v godot4 >/dev/null 2>&1; then
  exec godot4 --path . "$@"
elif command -v flatpak >/dev/null 2>&1 && flatpak info org.godotengine.Godot >/dev/null 2>&1; then
  exec flatpak run org.godotengine.Godot --path "$PWD" "$@"
else
  echo 'Open project.godot in Godot 4.5 or later, then press F6/F5 to play.' >&2
  exit 1
fi

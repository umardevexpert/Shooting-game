#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
export XDG_DATA_HOME="$project_root/.runtime/data"
export XDG_CONFIG_HOME="$project_root/.runtime/config"
export XDG_CACHE_HOME="$project_root/.runtime/cache"
mkdir -p "$project_root/build" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
godot --headless --path "$project_root" --editor --import --quit
godot --headless --path "$project_root" --export-debug Android "$project_root/build/ironfall-debug.apk"
echo "Built $project_root/build/ironfall-debug.apk"

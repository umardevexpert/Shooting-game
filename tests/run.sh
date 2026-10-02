#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
export XDG_DATA_HOME="$project_root/.runtime/test-data"
export XDG_CONFIG_HOME="$project_root/.runtime/config"
export XDG_CACHE_HOME="$project_root/.runtime/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
godot --headless --path "$project_root" --editor --import --quit
run_scene() {
  local scene_log="$project_root/.runtime/scene-tests.log"
  timeout 180s godot --headless --path "$project_root" --fixed-fps 60 "$@" 2>&1 | tee "$scene_log"
  if rg -n 'SCRIPT ERROR:|Parse Error:|Failed loading resource|Resource file not found' "$scene_log"; then
    echo "Runtime script or asset errors invalidate this test run." >&2
    return 1
  fi
}
run_scene res://tests/runner.tscn
run_scene res://tests/playthrough.tscn -- --campaign

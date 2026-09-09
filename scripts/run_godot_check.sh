#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/scripts/verify_project.py"
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot executable not found. Set GODOT_BIN=/path/to/Godot_v4.7.2-stable_* and run again."
  exit 2
fi
"$GODOT_BIN" --headless --path "$ROOT" --editor --quit
"$GODOT_BIN" --headless --path "$ROOT" --quit-after 5
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/prop_clearance_check.gd
"$ROOT/scripts/run_scene_check.sh" res://tests/tap_radius_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/save_recovery_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/analytics_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/audio_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/item_pool_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/localisation_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/accessibility_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/screen_shake_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/particles_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/palette_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/game_flow_check.tscn 45

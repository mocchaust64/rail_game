#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/scripts/verify_project.py"

GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot executable not found. Set GODOT_BIN=/path/to/Godot_v4.7.2-stable_* and run again."
  exit 2
fi

# Godot may return 0 from an editor import even when a GDScript failed to parse.
# Capture the log and make script compilation a hard CI gate before any scene test.
IMPORT_LOG="$(mktemp)"
trap 'rm -f "$IMPORT_LOG"' EXIT
set +e
"$GODOT_BIN" --headless --path "$ROOT" --import 2>&1 | tee "$IMPORT_LOG"
IMPORT_STATUS=${PIPESTATUS[0]}
set -e
if [[ "$IMPORT_STATUS" -ne 0 ]] || grep -Eq 'SCRIPT ERROR:|Failed to load script|Parse Error:|Compile Error:' "$IMPORT_LOG"; then
  echo "Godot import/compile gate failed."
  exit 1
fi

"$GODOT_BIN" --headless --path "$ROOT" --quit-after 5

"$ROOT/scripts/run_scene_check.sh" res://tests/prop_clearance_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/track_geometry_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/track_visuals_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/sorter_actor_check.tscn
"$ROOT/scripts/run_scene_check.sh" res://tests/camera_frame_check.tscn
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

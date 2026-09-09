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

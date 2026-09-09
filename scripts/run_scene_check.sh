#!/usr/bin/env bash
# Runs a Godot test scene with a hard timeout. A scene whose script fails to
# load never quits on its own, so without this the whole check hangs.
#
# Two traps this has to avoid:
#   - `godot` is often a shell wrapper, so killing the job leaves the real
#     engine process alive holding stdout open. Job control puts the job in its
#     own process group and the whole group is signalled.
#   - a watchdog that inherits stdout keeps a downstream pipeline waiting for
#     end of input, so its stdio is detached.
set -uo pipefail
set -m
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
SCENE="$1"
LIMIT="${2:-30}"

"$GODOT_BIN" --headless --path "$ROOT" "$SCENE" &
PID=$!
( sleep "$LIMIT"; kill -9 -"$PID" 2>/dev/null; kill -9 "$PID" 2>/dev/null ) >/dev/null 2>&1 </dev/null &
WATCHER=$!

wait "$PID"; CODE=$?
kill -9 "$WATCHER" 2>/dev/null
pkill -9 -P "$WATCHER" 2>/dev/null

if [ "$CODE" -ge 128 ]; then
  echo "TIMEOUT or crash after ${LIMIT}s: $SCENE" >&2
  exit 1
fi
exit "$CODE"

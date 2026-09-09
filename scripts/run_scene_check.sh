#!/usr/bin/env bash
# Runs a Godot test scene with a hard timeout. A scene whose script fails to
# load never quits on its own, so without this the whole check hangs.
#
# The watchdog runs with its own stdio detached: if it inherits the caller's
# stdout, a pipeline downstream of this script waits for the watchdog to exit
# before it sees end of input.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
SCENE="$1"
LIMIT="${2:-30}"

"$GODOT_BIN" --headless --path "$ROOT" "$SCENE" &
PID=$!
( sleep "$LIMIT"; kill -9 "$PID" 2>/dev/null ) >/dev/null 2>&1 </dev/null &
WATCHER=$!

wait "$PID"; CODE=$?
kill -- "-$WATCHER" 2>/dev/null || kill "$WATCHER" 2>/dev/null
pkill -P "$WATCHER" 2>/dev/null

if [ "$CODE" -ge 128 ]; then
  echo "TIMEOUT or crash after ${LIMIT}s: $SCENE" >&2
  exit 1
fi
exit "$CODE"

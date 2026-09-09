extends Node
# Append-only local analytics log.
#
# One JSON object per line. The previous implementation kept every event of the
# session in memory and rewrote the whole array to disk every eight events, so
# the bytes written grew with the square of the session length, and because it
# opened the file with WRITE, which truncates, each session also erased the
# events recorded by every session before it.

const LOG_PATH := "user://analytics_v3.jsonl"

# Events are written out at this interval and never accumulate beyond it, so a
# long session costs the same per event as a short one.
const FLUSH_EVERY := 8
const MAX_BUFFERED := 64

var _pending: Array[Dictionary] = []


func track(event_name: String, params: Dictionary = {}) -> void:
    _pending.append({
        "event": event_name,
        "unix_time": Time.get_unix_time_from_system(),
        "time_ms": Time.get_ticks_msec(),
        "params": params.duplicate(true),
    })
    if OS.is_debug_build():
        print("[analytics] ", event_name, " ", params)
    if _pending.size() >= FLUSH_EVERY:
        flush()


func flush() -> void:
    if _pending.is_empty():
        return
    var file := _open_for_append()
    if file == null:
        # Never let the buffer grow without bound just because the disk is
        # unavailable; drop the oldest events instead of leaking memory.
        if _pending.size() > MAX_BUFFERED:
            _pending = _pending.slice(_pending.size() - MAX_BUFFERED)
        return
    for event in _pending:
        file.store_line(JSON.stringify(event))
    file.close()
    _pending.clear()


func buffered_count() -> int:
    return _pending.size()


func _open_for_append() -> FileAccess:
    if not FileAccess.file_exists(LOG_PATH):
        return FileAccess.open(LOG_PATH, FileAccess.WRITE)
    var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
    if file != null:
        file.seek_end()
    return file


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        flush()

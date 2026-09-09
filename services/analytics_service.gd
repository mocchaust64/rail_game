extends Node

const LOG_PATH := "user://analytics_v2.json"
var events: Array[Dictionary] = []

func track(event_name: String, params: Dictionary = {}) -> void:
    var item: Dictionary = {
        "event": event_name,
        "unix_time": Time.get_unix_time_from_system(),
        "time_ms": Time.get_ticks_msec(),
        "params": params.duplicate(true),
    }
    events.append(item)
    print("[analytics] ", event_name, " ", params)
    if events.size() % 8 == 0:
        flush()

func flush() -> void:
    var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(events))

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        flush()

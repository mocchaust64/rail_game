extends Node

const SAVE_PATH := "user://flow_factory_save_v2.json"
const TEMP_PATH := "user://flow_factory_save_v2.tmp"
const SAVE_VERSION := 2

var highest_unlocked_level: int = 1
var audio_enabled: bool = true
var haptic_enabled: bool = true
var tutorial_seen: bool = false

func _ready() -> void:
    load_save()

func load_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var data: Dictionary = parsed
    highest_unlocked_level = max(1, int(data.get("highest_unlocked_level", 1)))
    audio_enabled = bool(data.get("audio_enabled", true))
    haptic_enabled = bool(data.get("haptic_enabled", true))
    tutorial_seen = bool(data.get("tutorial_seen", false))

func unlock_level(level_number: int) -> void:
    highest_unlocked_level = max(highest_unlocked_level, level_number)
    save()

func mark_tutorial_seen() -> void:
    if tutorial_seen:
        return
    tutorial_seen = true
    save()

func set_audio_enabled(value: bool) -> void:
    audio_enabled = value
    save()

func set_haptic_enabled(value: bool) -> void:
    haptic_enabled = value
    save()

func reset_progress() -> void:
    highest_unlocked_level = 1
    tutorial_seen = false
    save()

func save() -> void:
    var data := {
        "version": SAVE_VERSION,
        "highest_unlocked_level": highest_unlocked_level,
        "audio_enabled": audio_enabled,
        "haptic_enabled": haptic_enabled,
        "tutorial_seen": tutorial_seen,
    }
    var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify(data))
    file.flush()
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))

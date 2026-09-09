extends Node

const SAVE_PATH := "user://flow_factory_save_v2.json"
const TEMP_PATH := "user://flow_factory_save_v2.tmp"
const BACKUP_PATH := "user://flow_factory_save_v2.bak"
const SAVE_VERSION := 3

# Player-facing accessibility bounds.
const SPEED_OPTIONS := [0.75, 1.0]
const LARGE_TEXT_SCALE := 1.25

var highest_unlocked_level: int = 1
var audio_enabled: bool = true
var haptic_enabled: bool = true
var tutorial_seen: bool = false
var reduced_motion: bool = false
var large_text: bool = false
var game_speed: float = 1.0

func _ready() -> void:
    load_save()

func load_save() -> void:
    var data := _read_save(SAVE_PATH)
    if data.is_empty():
        # The live file is missing or was left half-written. The backup is the
        # previous complete save, so recovering from it costs at most one level
        # of progress instead of all of it.
        data = _read_save(BACKUP_PATH)
        if data.is_empty():
            return
        _apply(data)
        # Repair the live file so the next launch does not depend on the backup.
        save()
        return
    _apply(data)


func _read_save(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var text := file.get_as_text()
    file.close()
    var json := JSON.new()
    if json.parse(text) != OK:
        return {}
    var parsed: Variant = json.data
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    return parsed as Dictionary


func _apply(data: Dictionary) -> void:
    highest_unlocked_level = maxi(1, int(data.get("highest_unlocked_level", 1)))
    audio_enabled = bool(data.get("audio_enabled", true))
    haptic_enabled = bool(data.get("haptic_enabled", true))
    tutorial_seen = bool(data.get("tutorial_seen", false))
    reduced_motion = bool(data.get("reduced_motion", false))
    large_text = bool(data.get("large_text", false))
    game_speed = clampf(float(data.get("game_speed", 1.0)), 0.5, 1.0)

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

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value
    save()


func set_large_text(value: bool) -> void:
    large_text = value
    save()


func set_game_speed(value: float) -> void:
    game_speed = clampf(value, 0.5, 1.0)
    save()


# UI font multiplier for the large-text setting.
func text_scale() -> float:
    return LARGE_TEXT_SCALE if large_text else 1.0


# Cargo speed after the player's speed preference is applied.
func scaled_speed(base_speed: float) -> float:
    return base_speed * game_speed


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
        "reduced_motion": reduced_motion,
        "large_text": large_text,
        "game_speed": game_speed,
    }
    var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify(data))
    file.flush()
    file.close()

    # Refuse to replace a good save with a bad one.
    if _read_save(TEMP_PATH).is_empty():
        push_error("save aborted: the temporary file did not read back as valid JSON")
        return

    # Keep the previous save as a backup before touching the live file, so there
    # is never a moment with no complete save on disk. Deleting the live file
    # first without a backup, as this used to, loses everything if the process
    # dies before the rename lands.
    if FileAccess.file_exists(SAVE_PATH):
        var backup := ProjectSettings.globalize_path(BACKUP_PATH)
        if FileAccess.file_exists(BACKUP_PATH):
            DirAccess.remove_absolute(backup)
        DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), backup)
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

    DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))

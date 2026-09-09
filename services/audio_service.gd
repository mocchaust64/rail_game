extends Node
# Pooled sound effects on a dedicated bus.
#
# The previous version created an AudioStreamPlayer for every sound and freed it
# on finish, so a busy moment allocated and destroyed dozens of nodes, nothing
# capped simultaneous voices, and everything routed to Master, which left no way
# to mix or duck music against effects.

const MAX_VOICES := 12
const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

# Small random detune so a sound repeated in quick succession does not phase
# into an obvious machine-gun artefact.
const PITCH_JITTER := 0.06

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _ambient_player: AudioStreamPlayer
var _music_base_db := -27.0
var _duck_tween: Tween


func _ready() -> void:
    _streams = {
        "tap": preload("res://assets/audio/tap.wav"),
        "correct": preload("res://assets/audio/correct.wav"),
        "wrong": preload("res://assets/audio/wrong.wav"),
        "win": preload("res://assets/audio/win.wav"),
        "fail": preload("res://assets/audio/fail.wav"),
        "spawn": preload("res://assets/audio/spawn.wav"),
        "buffer_return": preload("res://assets/audio/buffer_return.wav"),
        "ui": preload("res://assets/audio/ui.wav"),
    }

    for i in range(MAX_VOICES):
        var voice := AudioStreamPlayer.new()
        voice.name = "Voice%02d" % i
        voice.bus = SFX_BUS
        add_child(voice)
        _voices.append(voice)

    _ambient_player = AudioStreamPlayer.new()
    _ambient_player.name = "Ambient"
    _ambient_player.bus = MUSIC_BUS
    var ambient_stream: AudioStream = preload("res://assets/audio/ambient.wav")
    if ambient_stream is AudioStreamWAV:
        var wav := ambient_stream as AudioStreamWAV
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
    _ambient_player.stream = ambient_stream
    _ambient_player.volume_db = _music_base_db
    add_child(_ambient_player)
    if SaveService.audio_enabled and DisplayServer.get_name() != "headless":
        _ambient_player.play()


func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
    if not SaveService.audio_enabled or not _streams.has(name):
        return
    var voice := _take_voice()
    if voice == null:
        return
    voice.stream = _streams[name]
    voice.pitch_scale = pitch + randf_range(-PITCH_JITTER, PITCH_JITTER)
    voice.volume_db = volume_db
    if DisplayServer.get_name() != "headless":
        voice.play()


func voice_count() -> int:
    return _voices.size()


# Pulls the music down briefly so a decisive sound cuts through it.
func duck_music(amount_db: float = 9.0, hold: float = 0.35) -> void:
    if _ambient_player == null:
        return
    if _duck_tween != null and _duck_tween.is_valid():
        _duck_tween.kill()
    _duck_tween = create_tween()
    _duck_tween.tween_property(_ambient_player, "volume_db", _music_base_db - amount_db, 0.06)
    _duck_tween.tween_interval(hold)
    _duck_tween.tween_property(_ambient_player, "volume_db", _music_base_db, 0.45)


func set_enabled(value: bool) -> void:
    SaveService.set_audio_enabled(value)
    if value:
        if not _ambient_player.playing:
            _ambient_player.play()
    else:
        _ambient_player.stop()
        for voice in _voices:
            voice.stop()


# Prefers an idle voice; when every voice is busy the oldest is reused, which
# caps simultaneous sounds instead of letting them pile up without limit.
func _take_voice() -> AudioStreamPlayer:
    for voice in _voices:
        if not voice.playing:
            return voice
    if _voices.is_empty():
        return null
    var stolen := _voices[_next_voice]
    _next_voice = (_next_voice + 1) % _voices.size()
    return stolen

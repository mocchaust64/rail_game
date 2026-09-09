extends Node

var _streams: Dictionary = {}
var _ambient_player: AudioStreamPlayer

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
    _ambient_player = AudioStreamPlayer.new()
    _ambient_player.name = "Ambient"
    var ambient_stream: AudioStream = preload("res://assets/audio/ambient.wav")
    if ambient_stream is AudioStreamWAV:
        var wav := ambient_stream as AudioStreamWAV
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
    _ambient_player.stream = ambient_stream
    _ambient_player.volume_db = -27.0
    add_child(_ambient_player)
    if SaveService.audio_enabled:
        _ambient_player.play()

func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
    if not SaveService.audio_enabled or not _streams.has(name):
        return
    var player := AudioStreamPlayer.new()
    player.stream = _streams[name]
    player.pitch_scale = pitch
    player.volume_db = volume_db
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()

func set_enabled(value: bool) -> void:
    SaveService.set_audio_enabled(value)
    if value:
        if not _ambient_player.playing:
            _ambient_player.play()
    else:
        _ambient_player.stop()

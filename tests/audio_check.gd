extends Node
# Sound effects must play from a pool on a dedicated bus. The old service
# allocated a fresh AudioStreamPlayer for every single sound and freed it on
# finish, and everything routed to Master, so music and effects could not be
# mixed or ducked separately and there was no cap on simultaneous voices.

const PLAYS := 60


func _ready() -> void:
	var failures: Array[String] = []
	SaveService.audio_enabled = true

	for bus in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus) < 0:
			failures.append("no '%s' audio bus, everything routes to Master" % bus)

	var before := AudioService.get_child_count()
	for i in range(PLAYS):
		AudioService.play("tap")
	var after := AudioService.get_child_count()

	if after > before:
		failures.append(
			"%d plays allocated %d new nodes; sound effects should come from a pool"
			% [PLAYS, after - before]
		)

	if not AudioService.has_method("voice_count"):
		failures.append("no way to inspect the voice pool size")
	elif AudioService.voice_count() > AudioService.MAX_VOICES:
		failures.append(
			"pool grew to %d voices, cap is %d"
			% [AudioService.voice_count(), AudioService.MAX_VOICES]
		)

	if failures.is_empty():
		print("audio: PASS (%d plays, %d pooled voices, SFX and Music buses present)"
			% [PLAYS, AudioService.voice_count()])
		get_tree().quit(0)
		return
	for line in failures:
		printerr(line)
	printerr("audio: FAIL (%d)" % failures.size())
	get_tree().quit(1)

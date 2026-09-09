extends Node
# The state machine had no test at all, which is what made game_controller.gd
# risky to change. This drives it through every transition a player can cause,
# and loads all ten levels, before the file is split apart.

const LEVEL_COUNT := 10


func _ready() -> void:
	var failures: Array[String] = []
	var controller := preload("res://app/main.tscn").instantiate() as GameController
	add_child(controller)
	await get_tree().process_frame
	await get_tree().physics_frame

	# Every shipped level must load and reach a playable state.
	for level_number in range(1, LEVEL_COUNT + 1):
		controller.load_level(level_number)
		await get_tree().physics_frame
		if controller.current_level_number != level_number:
			failures.append("load_level(%d) ended on level %d" % [level_number, controller.current_level_number])
		if controller.state != GameController.GameState.PLAYING:
			failures.append("level %d did not reach PLAYING, state is %d" % [level_number, controller.state])

	# Pause and resume.
	controller.load_level(1)
	await get_tree().physics_frame
	controller._on_pause_requested()
	if controller.state != GameController.GameState.PAUSED:
		failures.append("pause did not reach PAUSED")
	controller._on_resume_requested()
	if controller.state != GameController.GameState.PLAYING:
		failures.append("resume did not return to PLAYING")

	# A paused game must not keep spawning cargo.
	controller._on_pause_requested()
	var during_pause := controller.active_items.size()
	for i in range(30):
		await get_tree().physics_frame
	if controller.active_items.size() != during_pause:
		failures.append("cargo kept moving while paused")
	controller._on_resume_requested()

	# Failure, then restart.
	controller._fail("test")
	if controller.state != GameController.GameState.FAILED:
		failures.append("_fail did not reach FAILED")
	controller._on_restart_requested()
	await get_tree().physics_frame
	if controller.state != GameController.GameState.PLAYING:
		failures.append("restart did not return to PLAYING")

	# A hitstop must never survive a level change, or the game is left slow.
	controller._hitstop(5.0)
	controller.load_level(2)
	await get_tree().physics_frame
	if absf(Engine.time_scale - 1.0) > 0.001:
		failures.append("time scale stranded at %.2f after a level change" % Engine.time_scale)

	# Finishing a level must unlock the next one.
	SaveService.highest_unlocked_level = 1
	controller.load_level(1)
	await get_tree().physics_frame
	controller._on_next_requested()
	await get_tree().physics_frame
	if controller.current_level_number != 2:
		failures.append("next level did not advance, on %d" % controller.current_level_number)

	controller.queue_free()

	if failures.is_empty():
		print("game flow: PASS (%d levels, pause, fail, restart, advance)" % LEVEL_COUNT)
		get_tree().quit(0)
		return
	for line in failures:
		printerr(line)
	printerr("game flow: FAIL (%d)" % failures.size())
	get_tree().quit(1)

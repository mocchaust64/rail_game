extends Node
# Colour plus shape was the only accessibility affordance. A player who needs
# less motion, larger text, or a slower line had nothing to change.


func _ready() -> void:
	var failures: Array[String] = []

	# The three settings must exist, persist, and come back after a reload.
	SaveService.set_reduced_motion(true)
	SaveService.set_large_text(true)
	SaveService.set_game_speed(0.75)

	SaveService.reduced_motion = false
	SaveService.large_text = false
	SaveService.game_speed = 1.0
	SaveService.load_save()

	if not SaveService.reduced_motion:
		failures.append("reduced motion did not persist")
	if not SaveService.large_text:
		failures.append("large text did not persist")
	if absf(SaveService.game_speed - 0.75) > 0.001:
		failures.append("game speed did not persist, got %.2f" % SaveService.game_speed)

	# Reduced motion must actually shorten animation, not just be recorded.
	# Measured with the setting explicitly off: load_save() above restored it to
	# on, and reading the baseline in that state compares like with like.
	SaveService.reduced_motion = false
	var full := Motion.duration(0.40)
	SaveService.reduced_motion = true
	var reduced := Motion.duration(0.40)
	if reduced >= full * 0.25:
		failures.append("reduced motion barely changed duration: %.3f vs %.3f" % [reduced, full])
	if reduced <= 0.0:
		failures.append("reduced duration must stay positive, tweens reject zero: %.3f" % reduced)

	SaveService.reduced_motion = false
	if absf(Motion.duration(0.40) - 0.40) > 0.001:
		failures.append("duration must be untouched when motion is not reduced")

	# Every gameplay and UI tween is created through Motion.tween so the setting
	# cannot be forgotten at a call site. Reduced motion speeds the tween up
	# rather than shortening each duration by hand.
	SaveService.reduced_motion = true
	var fast := Motion.tween(self)
	if not is_instance_valid(fast):
		failures.append("Motion.tween did not return a tween")
	else:
		fast.kill()
	if Motion.REDUCED_FACTOR <= 0.0 or Motion.REDUCED_FACTOR >= 1.0:
		failures.append("reduced factor must sit between 0 and 1, got %.3f" % Motion.REDUCED_FACTOR)
	SaveService.reduced_motion = false

	# Large text must scale the UI, and game speed must reach the cargo.
	SaveService.large_text = true
	if SaveService.text_scale() <= 1.0:
		failures.append("large text does not scale the UI, got %.2f" % SaveService.text_scale())
	SaveService.large_text = false
	if absf(SaveService.text_scale() - 1.0) > 0.001:
		failures.append("text scale must be 1.0 when large text is off")

	SaveService.game_speed = 0.5
	var scaled := SaveService.scaled_speed(2.0)
	if absf(scaled - 1.0) > 0.001:
		failures.append("game speed did not scale cargo speed, got %.2f" % scaled)

	# Reset so the check leaves no state behind.
	SaveService.set_reduced_motion(false)
	SaveService.set_large_text(false)
	SaveService.set_game_speed(1.0)

	if failures.is_empty():
		print("accessibility: PASS")
		get_tree().quit(0)
		return
	for line in failures:
		printerr(line)
	printerr("accessibility: FAIL (%d)" % failures.size())
	get_tree().quit(1)

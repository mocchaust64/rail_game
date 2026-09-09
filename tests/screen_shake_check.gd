extends Node
# Screen shake has to build on impact, decay on its own, and disappear entirely
# for a player who asked for reduced motion.


func _ready() -> void:
	var failures: Array[String] = []
	SaveService.reduced_motion = false

	var shake := ScreenShake.new()

	if shake.offset().length() > 0.0001:
		failures.append("shake should be still before any impact")

	shake.add_trauma(1.0)
	shake.advance(0.016)
	var kicked := shake.offset().length()
	if kicked <= 0.0:
		failures.append("shake produced no offset after an impact")
	if kicked > ScreenShake.MAX_OFFSET * 1.01:
		failures.append("shake offset %.3f exceeded the %.3f cap" % [kicked, ScreenShake.MAX_OFFSET])

	# Trauma must not stack past the cap, or a burst of impacts would throw the
	# camera across the screen.
	for i in range(20):
		shake.add_trauma(1.0)
	shake.advance(0.016)
	if shake.offset().length() > ScreenShake.MAX_OFFSET * 1.01:
		failures.append("stacked impacts broke the offset cap")

	# It must settle without anything telling it to stop.
	for i in range(200):
		shake.advance(0.016)
	if shake.offset().length() > 0.0001:
		failures.append("shake never settled, offset still %.4f" % shake.offset().length())

	# Reduced motion suppresses it completely.
	SaveService.reduced_motion = true
	var quiet := ScreenShake.new()
	quiet.add_trauma(1.0)
	quiet.advance(0.016)
	if quiet.offset().length() > 0.0001:
		failures.append("reduced motion did not suppress shake")
	SaveService.reduced_motion = false

	if failures.is_empty():
		print("screen shake: PASS")
		get_tree().quit(0)
		return
	for line in failures:
		printerr(line)
	printerr("screen shake: FAIL (%d)" % failures.size())
	get_tree().quit(1)

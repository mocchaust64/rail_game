extends Node
# Colours are data now, not constants in a script. This proves the resource is
# actually the source of truth: edit the .tres and the game changes.


func _ready() -> void:
	var failures: Array[String] = []

	var palette := VisualFactory.palette
	if palette == null:
		failures.append("no palette resource loaded")
		_report(failures)
		return

	if VisualFactory.kind_color("red") != palette.cargo_red:
		failures.append("red cargo colour does not come from the palette")
	if VisualFactory.kind_color("blue") != palette.cargo_blue:
		failures.append("blue cargo colour does not come from the palette")
	if VisualFactory.kind_color("yellow") != palette.cargo_yellow:
		failures.append("yellow cargo colour does not come from the palette")

	# The three cargo colours must stay far enough apart to be told apart.
	var pairs := [
		[palette.cargo_red, palette.cargo_blue, "red/blue"],
		[palette.cargo_red, palette.cargo_yellow, "red/yellow"],
		[palette.cargo_blue, palette.cargo_yellow, "blue/yellow"],
	]
	for pair in pairs:
		var a: Color = pair[0]
		var b: Color = pair[1]
		var distance := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
		if distance < 0.35:
			failures.append("%s cargo colours are too close: %.2f" % [pair[2], distance])

	# Machines must stand out from the board, which is what a flat palette lost.
	var contrast := absf(palette.machine_body.get_luminance() - palette.floor_colour.get_luminance())
	if contrast < 0.05:
		failures.append("machine and floor luminance differ by only %.3f" % contrast)

	_report(failures)


func _report(failures: Array) -> void:
	if failures.is_empty():
		print("palette: PASS (resource drives cargo colour, colours separable)")
		get_tree().quit(0)
		return
	for line in failures:
		printerr(line)
	printerr("palette: FAIL (%d)" % failures.size())
	get_tree().quit(1)

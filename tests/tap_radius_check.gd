extends Node
# The tap tolerance is defined in board units and converted to pixels per
# junction. A fixed pixel radius was correct only under the orthographic camera
# the project used to have: under perspective it drifts with depth, and it is
# also tied to one viewport size.
#
# Runs as a scene rather than via --script because GameController depends on the
# SaveService autoload, and autoloads are not loaded for SceneTree scripts.


func _ready() -> void:
	var failures: Array[String] = []

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = GameController.CAMERA_FOV
	camera.position = GameController.CAMERA_POSITION
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0.25), Vector3.UP)
	camera.current = true

	var units := GameController.TAP_RADIUS_UNITS
	# Real junction depths: level data puts junctions between z -1.7 and z 1.5.
	var near_anchor := Vector3(0.0, 0.38, 1.5)
	var far_anchor := Vector3(0.0, 0.38, -1.7)

	var near_radius := GameController.screen_radius(camera, near_anchor, units)
	var far_radius := GameController.screen_radius(camera, far_anchor, units)

	if near_radius <= 0.0 or far_radius <= 0.0:
		failures.append("radius must be positive, got near=%.2f far=%.2f" % [near_radius, far_radius])

	# Perspective: the nearer junction must claim more pixels than the far one.
	if near_radius <= far_radius:
		failures.append(
			"near junction radius %.2fpx should exceed far junction radius %.2fpx"
			% [near_radius, far_radius]
		)

	var centre := camera.unproject_position(near_anchor)

	# A point exactly one tap radius away in world space sits on the boundary.
	var edge := near_anchor + camera.global_transform.basis.x * units
	var edge_score := centre.distance_to(camera.unproject_position(edge)) / near_radius
	if absf(edge_score - 1.0) > 0.001:
		failures.append("point at exactly one radius should score 1.0, scored %.4f" % edge_score)

	# Half a radius away is inside; one and a half radii away is outside.
	var half := near_anchor + camera.global_transform.basis.x * (units * 0.5)
	var outside := near_anchor + camera.global_transform.basis.x * (units * 1.5)
	var half_score := centre.distance_to(camera.unproject_position(half)) / near_radius
	var outside_score := centre.distance_to(camera.unproject_position(outside)) / near_radius
	if half_score >= 1.0:
		failures.append("half a radius should be inside, scored %.3f" % half_score)
	if outside_score <= 1.0:
		failures.append("one and a half radii should be outside, scored %.3f" % outside_score)

	remove_child(camera)
	camera.free()

	if failures.is_empty():
		print("tap radius: PASS (near %.1fpx, far %.1fpx)" % [near_radius, far_radius])
		get_tree().quit(0)
		return
	for line in failures:
		printerr(line)
	printerr("tap radius: FAIL (%d)" % failures.size())
	get_tree().quit(1)

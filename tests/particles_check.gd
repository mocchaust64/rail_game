extends Node
# Feedback bursts must actually spawn, emit, and clean themselves up. A burst
# that leaks a node every delivery would accumulate for the whole session.


func _ready() -> void:
	var failures: Array[String] = []
	var world := Node3D.new()
	add_child(world)

	var before := world.get_child_count()
	VisualFactory.burst(world, Vector3(0, 1, 0), Color("#F45B69"), 20)
	var spawned := world.get_child_count() - before
	if spawned != 1:
		failures.append("expected one burst node, got %d" % spawned)

	var particles := world.get_child(world.get_child_count() - 1) as CPUParticles3D
	if particles == null:
		failures.append("burst did not create a CPUParticles3D")
	else:
		if not particles.emitting:
			failures.append("burst node is not emitting")
		if not particles.one_shot:
			failures.append("burst must be one shot, otherwise it never stops")
		if particles.amount <= 0:
			failures.append("burst emits no particles")

	# It must free itself rather than rely on the caller remembering.
	await get_tree().create_timer(1.2).timeout
	if world.get_child_count() != before:
		failures.append("burst leaked %d node(s)" % (world.get_child_count() - before))

	if failures.is_empty():
		print("particles: PASS (burst spawns, emits, and frees itself)")
		get_tree().quit(0)
		return
	for line in failures:
		printerr(line)
	printerr("particles: FAIL (%d)" % failures.size())
	get_tree().quit(1)

extends Node
# Headless regression check for decoration/gameplay overlap.
#
# Decoration props are placed from a fixed layout while receivers and sources
# come from per-level JSON, so a prop can land on top of a gameplay actor.
# This walks the real scene VisualFactory builds and measures it.

const CLEARANCE_RADIUS := 1.8
const BLOCKING_TYPES := ["receiver", "source"]
# 8 vendor props, 4 tank parts, 6 barrier parts, 4 beacon parts.
const EXPECTED_DECOR_NODES := 22


func _ready() -> void:
	var failures: Array[String] = []
	var dir := DirAccess.open("res://levels")
	var level_files: Array[String] = []
	for name in dir.get_files():
		if name.begins_with("level_") and name.ends_with(".json"):
			level_files.append(name)
	level_files.sort()

	for name in level_files:
		failures.append_array(_check_level("res://levels/%s" % name))
	failures.append_array(_check_layout_is_not_stripped(level_files))
	failures.append_array(_check_filter_actually_drops())

	if failures.is_empty():
		print("prop clearance: PASS (%d levels)" % level_files.size())
		get_tree().quit(0)
		return
	for line in failures:
		printerr(line)
	printerr("prop clearance: FAIL (%d violations)" % failures.size())
	get_tree().quit(1)


func _check_level(path: String) -> Array[String]:
	var file := FileAccess.open(path, FileAccess.READ)
	var level: Dictionary = JSON.parse_string(file.get_as_text())
	var level_id := int(level["id"])

	var occupied: Array[Vector2] = []
	for raw in level["nodes"]:
		var node: Dictionary = raw
		if String(node.get("type", "normal")) in BLOCKING_TYPES:
			var p: Array = node["pos"]
			occupied.append(Vector2(float(p[0]), float(p[1])))

	var world := Node3D.new()
	add_child(world)
	VisualFactory.create_floor(world, occupied)

	var violations: Array[String] = []
	for prop in _collect_props(world):
		var flat := Vector2(prop.position.x, prop.position.z)
		for point in occupied:
			var d := flat.distance_to(point)
			if d < CLEARANCE_RADIUS:
				violations.append(
					"level %02d: prop at (%.2f, %.2f) is %.2f from actor at (%.2f, %.2f), needs %.2f"
					% [level_id, flat.x, flat.y, d, point.x, point.y, CLEARANCE_RADIUS]
				)
	remove_child(world)
	world.free()
	return violations


# Decoration is identified by group membership, not by node name: Godot drops
# duplicate node names on add_child, so name matching silently misses most props.
func _collect_props(node: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if node is Node3D and node.is_in_group(VisualFactory.DECOR_GROUP):
		found.append(node as Node3D)
	for child in node.get_children():
		found.append_array(_collect_props(child))
	return found


# A clearance check passes trivially if the filter removes everything, so the
# layout must survive intact on every shipped level. It was chosen to do so.
func _check_layout_is_not_stripped(level_files: Array[String]) -> Array[String]:
	var problems: Array[String] = []
	for name in level_files:
		var file := FileAccess.open("res://levels/%s" % name, FileAccess.READ)
		var level: Dictionary = JSON.parse_string(file.get_as_text())
		var occupied: Array[Vector2] = []
		for raw in level["nodes"]:
			var node: Dictionary = raw
			if String(node.get("type", "normal")) in BLOCKING_TYPES:
				var p: Array = node["pos"]
				occupied.append(Vector2(float(p[0]), float(p[1])))
		var world := Node3D.new()
		add_child(world)
		VisualFactory.create_floor(world, occupied)
		var kept := _collect_props(world).size()
		if kept < EXPECTED_DECOR_NODES:
			problems.append(
				"level %02d: only %d of %d decoration nodes survived the clearance filter"
				% [int(level["id"]), kept, EXPECTED_DECOR_NODES]
			)
		remove_child(world)
		world.free()
	return problems


# The guard itself must work: drop an actor onto a known prop and that prop goes.
func _check_filter_actually_drops() -> Array[String]:
	var world := Node3D.new()
	add_child(world)
	var on_top_of_a_barrel: Array[Vector2] = [Vector2(-4.12, -1.95)]
	VisualFactory.create_floor(world, on_top_of_a_barrel)
	var kept := _collect_props(world).size()
	remove_child(world)
	world.free()
	if kept >= EXPECTED_DECOR_NODES:
		return ["clearance filter is a no-op: %d nodes kept with an actor placed on a prop" % kept]
	return []

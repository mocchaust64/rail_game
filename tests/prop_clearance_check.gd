extends Node
# Headless regression check for decoration/gameplay overlap. The reference yard
# uses our own sparse trees/crates/barriers/flowers and may intentionally filter
# an edge prop on a wider level, so the test protects clearance and minimum
# visual density rather than an old vendor-asset count.

const CLEARANCE_RADIUS := 1.55
const BLOCKING_TYPES := ["receiver", "source"]
const MIN_DECOR_NODES := 14


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


func _collect_props(node: Node) -> Array[Node3D]:
    var found: Array[Node3D] = []
    if node is Node3D and node.is_in_group(VisualFactory.DECOR_GROUP):
        found.append(node as Node3D)
    for child in node.get_children():
        found.append_array(_collect_props(child))
    return found


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
        if kept < MIN_DECOR_NODES:
            problems.append(
                "level %02d: only %d decoration roots survived; expected at least %d"
                % [int(level["id"]), kept, MIN_DECOR_NODES]
            )
        remove_child(world)
        world.free()
    return problems


func _check_filter_actually_drops() -> Array[String]:
    var baseline_world := Node3D.new()
    add_child(baseline_world)
    VisualFactory.create_floor(baseline_world, [])
    var baseline := _collect_props(baseline_world).size()
    remove_child(baseline_world)
    baseline_world.free()

    var filtered_world := Node3D.new()
    add_child(filtered_world)
    # Known custom tree root in the current yard layout.
    VisualFactory.create_floor(filtered_world, [Vector2(-5.65, -7.55)])
    var filtered := _collect_props(filtered_world).size()
    remove_child(filtered_world)
    filtered_world.free()

    if filtered >= baseline:
        return ["clearance filter is a no-op: %d roots kept from baseline %d" % [filtered, baseline]]
    return []

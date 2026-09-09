class_name LevelBuilder
extends RefCounted
# Turns level data into world nodes.
#
# Split out of GameController so that reading a level from disk and populating
# the scene is one job with one entry point, separate from the rules that run
# once the board exists.

const LEVEL_PATH := "res://levels/level_%02d.json"
const BLOCKING_TYPES := ["receiver", "source"]


# Reads and validates a level. Returns an empty dictionary on any failure, with
# the reason already pushed as an error.
static func load_data(level_number: int) -> Dictionary:
    var path := LEVEL_PATH % level_number
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Unable to load %s" % path)
        return {}
    var text := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Invalid JSON in %s" % path)
        return {}
    var level: Dictionary = parsed
    var errors := LevelValidator.validate(level)
    if not errors.is_empty():
        for error in errors:
            push_error("Level validation: %s" % error)
        return {}
    return level


# Populates `world` and returns everything the controller needs to run the
# level. Keys: nodes_by_id, positions, sources, receivers, junctions,
# buffer_chute, item_pool.
static func build(level: Dictionary, world: Node3D, pool_size: int) -> Dictionary:
    var nodes_by_id: Dictionary = {}
    var positions: Dictionary = {}

    # Positions are read first because the floor decoration needs them: props
    # are filtered away from wherever this level puts its receivers and sources.
    var occupied: Array[Vector2] = []
    for raw_node in level["nodes"]:
        var node: Dictionary = raw_node
        var id := String(node["id"])
        nodes_by_id[id] = node
        var p: Array = node["pos"]
        positions[id] = Vector3(float(p[0]), 0.0, float(p[1]))
        if String(node.get("type", "normal")) in BLOCKING_TYPES:
            occupied.append(Vector2(float(p[0]), float(p[1])))

    var item_pool := ItemPool.new(world, pool_size)
    VisualFactory.create_floor(world, occupied)
    var buffer_chute := VisualFactory.create_buffer_chute(world)

    _draw_tracks(nodes_by_id, positions, world)

    var sources: Dictionary = {}
    var receivers: Dictionary = {}
    var junctions: Dictionary = {}
    for id in nodes_by_id:
        var node: Dictionary = nodes_by_id[id]
        match String(node.get("type", "normal")):
            "source":
                var source := SourceActor.new()
                source.position = positions[id]
                world.add_child(source)
                source.configure(String(id))
                sources[id] = source
            "receiver":
                var receiver := ReceiverActor.new()
                receiver.position = positions[id]
                world.add_child(receiver)
                receiver.configure(String(id), String(node["kind"]))
                receivers[id] = receiver
            "junction":
                var junction := JunctionActor.new()
                junction.position = positions[id]
                world.add_child(junction)
                junction.configure(node, positions)
                junctions[id] = junction

    return {
        "nodes_by_id": nodes_by_id,
        "positions": positions,
        "sources": sources,
        "receivers": receivers,
        "junctions": junctions,
        "buffer_chute": buffer_chute,
        "item_pool": item_pool,
    }


# One track per connection, drawn once even when two nodes route to the same
# target from different branches.
static func _draw_tracks(nodes_by_id: Dictionary, positions: Dictionary, world: Node3D) -> void:
    var drawn: Dictionary = {}
    for id in nodes_by_id:
        var node: Dictionary = nodes_by_id[id]
        var node_type := String(node.get("type", "normal"))
        var targets: Array[String] = []
        if node_type == "junction":
            targets.append(String(node["out_a"]))
            targets.append(String(node["out_b"]))
        elif node_type != "receiver":
            targets.append(String(node.get("next", "")))
        for target in targets:
            if target.is_empty():
                continue
            var key := "%s>%s" % [id, target]
            if drawn.has(key):
                continue
            VisualFactory.create_track(world, positions[id], positions[target])
            drawn[key] = true

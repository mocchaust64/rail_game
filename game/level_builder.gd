class_name LevelBuilder
extends RefCounted
# Turns level data into world nodes. Gameplay topology stays in JSON; presentation
# paths are rebuilt from that topology so visuals can curve without changing rules.

const LEVEL_PATH := "res://levels/level_%02d.json"
const BLOCKING_TYPES := ["receiver", "source"]


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


static func build(level: Dictionary, world: Node3D, pool_size: int) -> Dictionary:
    var nodes_by_id: Dictionary = {}
    var positions: Dictionary = {}

    var occupied: Array[Vector2] = []
    for raw_node in level["nodes"]:
        var node: Dictionary = raw_node
        var id := String(node["id"])
        nodes_by_id[id] = node
        var p: Array = node["pos"]
        positions[id] = Vector3(float(p[0]), 0.0, float(p[1]))
        if String(node.get("type", "normal")) in BLOCKING_TYPES:
            occupied.append(Vector2(float(p[0]), float(p[1])))

    # One source of truth for every edge curve. TrackVisuals draws it and
    # ItemActor samples the same path while moving.
    TrackGeometry.rebuild(nodes_by_id, positions)

    # Camera framing follows only the graph, never the decorative floor/props.
    var rig_parent := world.get_parent()
    if rig_parent is SceneRig:
        (rig_parent as SceneRig).frame_positions(positions)

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


static func _draw_tracks(nodes_by_id: Dictionary, positions: Dictionary, world: Node3D) -> void:
    var drawn: Dictionary = {}
    for raw_id in nodes_by_id:
        var id := String(raw_id)
        var node: Dictionary = nodes_by_id[id]
        var targets := _targets(node)
        for raw_target in targets:
            var target := String(raw_target)
            if target.is_empty() or not positions.has(target):
                continue
            var key := "%s>%s" % [id, target]
            if drawn.has(key):
                continue
            var start: Vector3 = positions[id]
            var finish: Vector3 = positions[target]
            var points := TrackGeometry.path_for(id, target, start, finish)
            TrackVisuals.create_path(world, points)
            drawn[key] = true


static func _targets(node: Dictionary) -> Array:
    var targets: Array = []
    var node_type := String(node.get("type", "normal"))
    if node_type == "junction":
        targets.append(String(node["out_a"]))
        targets.append(String(node["out_b"]))
    elif node_type != "receiver":
        var next_id := String(node.get("next", ""))
        if not next_id.is_empty():
            targets.append(next_id)
    return targets

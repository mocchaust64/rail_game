class_name LevelBuilder
extends RefCounted

const LEVEL_PATH := "res://levels/level_%02d.json"
const BLOCKING_TYPES := ["receiver", "source", "sorter_site"]


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
        if String(node.get("type", "normal")) in BLOCKING_TYPES or not String(node.get("visual", "")).is_empty():
            occupied.append(Vector2(float(p[0]), float(p[1])))

    TrackGeometry.rebuild(nodes_by_id, positions)

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
    var sorters: Dictionary = {}
    var default_sorter_cost := int(level.get("sorter_cost", 3))

    for id in nodes_by_id:
        var node: Dictionary = nodes_by_id[id]
        match String(node.get("type", "normal")):
            "source":
                var source := SourceActor.new()
                source.position = positions[id]
                source.rotation.y = deg_to_rad(float(node.get("rotation_y", 0.0)))
                world.add_child(source)
                source.configure(String(id), String(node.get("source_style", "compact")))
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
            "sorter_site":
                var sorter := SorterActor.new()
                sorter.position = positions[id]
                world.add_child(sorter)
                sorter.configure(node, positions, default_sorter_cost)
                sorters[id] = sorter
            "normal":
                if String(node.get("visual", "")) == "processor":
                    var processor := ProcessorVisual.create(world)
                    processor.position = positions[id]
                    var next_id := String(node.get("next", ""))
                    if not next_id.is_empty() and positions.has(next_id):
                        var path := TrackGeometry.path_for(String(id), next_id, positions[id], positions[next_id])
                        if path.size() >= 2:
                            var tangent := path[1] - path[0]
                            if tangent.length_squared() > 0.0001:
                                processor.rotation.y = atan2(tangent.x, tangent.z)

    return {
        "nodes_by_id": nodes_by_id,
        "positions": positions,
        "sources": sources,
        "receivers": receivers,
        "junctions": junctions,
        "sorters": sorters,
        "buffer_chute": buffer_chute,
        "item_pool": item_pool,
    }


static func _draw_tracks(nodes_by_id: Dictionary, positions: Dictionary, world: Node3D) -> void:
    var drawn: Dictionary = {}
    for raw_id in nodes_by_id:
        var id := String(raw_id)
        var node: Dictionary = nodes_by_id[id]
        var targets := _targets(node)
        var node_type := String(node.get("type", "normal"))

        # Sorter outputs are possible routes. Before a sorter is built they stay
        # as pale guide rails only. SorterActor adds the continuous black belt
        # after construction, which makes the player's plan readable at a glance.
        var default_belt := node_type not in ["junction", "sorter_site"]
        var show_belt := bool(node.get("belt", default_belt))
        var show_guides := bool(node.get("guides", true))

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
            TrackVisuals.create_path(world, points, 0.0, 0.0, show_belt, show_guides)
            drawn[key] = true


static func _targets(node: Dictionary) -> Array:
    var targets: Array = []
    var node_type := String(node.get("type", "normal"))
    if node_type == "junction":
        targets.append(String(node["out_a"]))
        targets.append(String(node["out_b"]))
    elif node_type == "sorter_site":
        for key in ["out_1", "out_2", "out_3"]:
            targets.append(String(node[key]))
    elif node_type != "receiver":
        var next_id := String(node.get("next", ""))
        if not next_id.is_empty():
            targets.append(next_id)
    return targets

class_name LevelValidator
extends RefCounted

const SUPPORTED_KINDS := ["red", "blue", "yellow"]


static func validate(level: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    if not level.has("id"):
        errors.append("Missing level id")
    if not level.has("nodes") or typeof(level["nodes"]) != TYPE_ARRAY:
        errors.append("Missing nodes array")
        return errors
    if not level.has("spawns") or typeof(level["spawns"]) != TYPE_ARRAY:
        errors.append("Missing spawns array")
        return errors
    if level["spawns"].is_empty():
        errors.append("spawns must not be empty")
    if float(level.get("item_speed", 0.0)) <= 0.0:
        errors.append("item_speed must be > 0")
    if float(level.get("spawn_interval", 0.0)) <= 0.0:
        errors.append("spawn_interval must be > 0")
    if int(level.get("buffer_capacity", 0)) <= 0:
        errors.append("buffer_capacity must be > 0")
    if float(level.get("buffer_return_delay", 0.0)) <= 0.0:
        errors.append("buffer_return_delay must be > 0")

    var nodes_by_id: Dictionary = {}
    var has_sorters := false
    for raw_node in level["nodes"]:
        if typeof(raw_node) != TYPE_DICTIONARY:
            errors.append("Every node must be an object")
            continue
        var node: Dictionary = raw_node
        var id := String(node.get("id", ""))
        if id.is_empty():
            errors.append("Node missing id")
            continue
        if nodes_by_id.has(id):
            errors.append("Duplicate node id: %s" % id)
            continue
        nodes_by_id[id] = node
        var pos: Variant = node.get("pos", [])
        if typeof(pos) != TYPE_ARRAY or pos.size() != 2:
            errors.append("Node %s must have pos [x,z]" % id)
        if String(node.get("type", "normal")) == "sorter_site":
            has_sorters = true

    if has_sorters:
        _validate_economy(level, errors)

    var receiver_kinds: Dictionary = {}
    var source_ids: Dictionary = {}
    for id in nodes_by_id:
        var node: Dictionary = nodes_by_id[id]
        var node_type := String(node.get("type", "normal"))
        match node_type:
            "junction":
                for key in ["out_a", "out_b"]:
                    _validate_target(id, key, node, nodes_by_id, errors)
                if String(node.get("out_a", "")) == String(node.get("out_b", "")):
                    errors.append("Junction %s must have two distinct outputs" % id)
            "sorter_site":
                var targets: Dictionary = {}
                for key in ["out_1", "out_2", "out_3"]:
                    _validate_target(id, key, node, nodes_by_id, errors)
                    targets[String(node.get(key, ""))] = true
                if targets.size() != 3:
                    errors.append("Sorter %s must have three distinct outputs" % id)
                var mapping: Variant = node.get("mapping", [])
                if typeof(mapping) != TYPE_ARRAY or mapping.size() != 3:
                    errors.append("Sorter %s mapping must contain three colours" % id)
                else:
                    var unique: Dictionary = {}
                    for raw_kind in mapping:
                        var kind := String(raw_kind)
                        if kind not in SUPPORTED_KINDS:
                            errors.append("Sorter %s has unsupported mapping colour %s" % [id, kind])
                        unique[kind] = true
                    if unique.size() != 3:
                        errors.append("Sorter %s mapping must use red, blue and yellow exactly once" % id)
                if int(node.get("build_cost", level.get("sorter_cost", 0))) <= 0:
                    errors.append("Sorter %s build cost must be > 0" % id)
            "receiver":
                var receiver_kind := String(node.get("kind", ""))
                if receiver_kind not in SUPPORTED_KINDS:
                    errors.append("Receiver %s has unsupported kind: %s" % [id, receiver_kind])
                else:
                    receiver_kinds[receiver_kind] = true
            "source":
                source_ids[id] = true
                _validate_next(id, node, nodes_by_id, errors)
            "normal":
                _validate_next(id, node, nodes_by_id, errors)
            _:
                errors.append("Node %s has unsupported type: %s" % [id, node_type])

    for raw_spawn in level["spawns"]:
        if typeof(raw_spawn) != TYPE_DICTIONARY:
            errors.append("Spawn entry must be an object")
            continue
        var spawn: Dictionary = raw_spawn
        var source := String(spawn.get("source", ""))
        var item_kind := String(spawn.get("kind", ""))
        if not source_ids.has(source):
            errors.append("Spawn source is not a valid source node: %s" % source)
        if item_kind not in SUPPORTED_KINDS:
            errors.append("Unsupported spawn kind: %s" % item_kind)
        elif not receiver_kinds.has(item_kind):
            errors.append("No receiver for spawn kind: %s" % item_kind)
        elif source_ids.has(source) and not _can_reach_kind(source, item_kind, nodes_by_id):
            errors.append("Source %s cannot reach receiver kind %s" % [source, item_kind])

    if _graph_has_cycle(nodes_by_id):
        errors.append("Track graph contains a cycle; current levels must terminate at receivers")

    return errors


static func _validate_economy(level: Dictionary, errors: PackedStringArray) -> void:
    var budget := int(level.get("gold_budget", 0))
    var sorter_cost := int(level.get("sorter_cost", 0))
    var optimal := int(level.get("optimal_cost", 0))
    var two_star := int(level.get("two_star_cost", 0))
    if budget <= 0:
        errors.append("gold_budget must be > 0")
    if sorter_cost <= 0:
        errors.append("sorter_cost must be > 0")
    if optimal <= 0 or optimal > budget:
        errors.append("optimal_cost must be > 0 and <= gold_budget")
    if two_star < optimal or two_star > budget:
        errors.append("two_star_cost must be between optimal_cost and gold_budget")


static func _validate_target(id: String, key: String, node: Dictionary, nodes_by_id: Dictionary, errors: PackedStringArray) -> void:
    var target := String(node.get(key, ""))
    if target.is_empty() or not nodes_by_id.has(target):
        errors.append("Node %s has invalid %s=%s" % [id, key, target])


static func _validate_next(id: String, node: Dictionary, nodes_by_id: Dictionary, errors: PackedStringArray) -> void:
    var next_id := String(node.get("next", ""))
    if next_id.is_empty():
        errors.append("Node %s missing next" % id)
    elif not nodes_by_id.has(next_id):
        errors.append("Node %s has invalid next=%s" % [id, next_id])


static func _outputs(node: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var node_type := String(node.get("type", "normal"))
    if node_type == "junction":
        result.append(String(node.get("out_a", "")))
        result.append(String(node.get("out_b", "")))
    elif node_type == "sorter_site":
        for key in ["out_1", "out_2", "out_3"]:
            var target := String(node.get(key, ""))
            if not target.is_empty():
                result.append(target)
    elif node_type != "receiver":
        var next_id := String(node.get("next", ""))
        if not next_id.is_empty():
            result.append(next_id)
    return result


static func _can_reach_kind(start_id: String, target_kind: String, nodes_by_id: Dictionary) -> bool:
    var stack: Array[String] = [start_id]
    var visited: Dictionary = {}
    while not stack.is_empty():
        var id: String = stack.pop_back()
        if visited.has(id) or not nodes_by_id.has(id):
            continue
        visited[id] = true
        var node: Dictionary = nodes_by_id[id]
        if String(node.get("type", "normal")) == "receiver":
            if String(node.get("kind", "")) == target_kind:
                return true
            continue
        for target in _outputs(node):
            if not target.is_empty():
                stack.append(target)
    return false


static func _graph_has_cycle(nodes_by_id: Dictionary) -> bool:
    var colors: Dictionary = {}
    for id in nodes_by_id:
        colors[id] = 0
    for id in nodes_by_id:
        if int(colors[id]) == 0 and _visit_cycle(String(id), nodes_by_id, colors):
            return true
    return false


static func _visit_cycle(id: String, nodes_by_id: Dictionary, colors: Dictionary) -> bool:
    colors[id] = 1
    for target in _outputs(nodes_by_id[id]):
        if target.is_empty() or not nodes_by_id.has(target):
            continue
        if int(colors.get(target, 0)) == 1:
            return true
        if int(colors.get(target, 0)) == 0 and _visit_cycle(target, nodes_by_id, colors):
            return true
    colors[id] = 2
    return false

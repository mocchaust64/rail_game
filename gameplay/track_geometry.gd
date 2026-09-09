class_name TrackGeometry
extends RefCounted
# One deterministic presentation path per graph edge. Rendering and cargo both
# consume these sampled curves so the ball can never cut across a curved belt.
# Routing still commits by node id exactly as before.

const HANDLE_FACTOR := 0.30
const MAX_HANDLE := 1.25
const SAMPLE_SPACING := 0.30
const MIN_SAMPLES := 6
const MAX_SAMPLES := 28

static var _paths: Dictionary = {}


static func rebuild(nodes_by_id: Dictionary, positions: Dictionary) -> void:
    _paths.clear()
    var incoming: Dictionary = {}
    var outgoing: Dictionary = {}

    for raw_id in nodes_by_id:
        var id := String(raw_id)
        var node: Dictionary = nodes_by_id[id]
        incoming[id] = []
        outgoing[id] = _targets(node)

    for raw_id in nodes_by_id:
        var id := String(raw_id)
        var targets: Array = outgoing[id]
        for raw_target in targets:
            var target := String(raw_target)
            if incoming.has(target):
                var predecessors: Array = incoming[target]
                predecessors.append(id)
                incoming[target] = predecessors

    var tangents: Dictionary = {}
    for raw_id in nodes_by_id:
        var id := String(raw_id)
        var incoming_ids: Array = incoming.get(id, [])
        var outgoing_ids: Array = outgoing.get(id, [])
        tangents[id] = _node_tangent(id, incoming_ids, outgoing_ids, positions)

    for raw_id in nodes_by_id:
        var id := String(raw_id)
        var targets: Array = outgoing[id]
        for raw_target in targets:
            var target := String(raw_target)
            if not positions.has(id) or not positions.has(target):
                continue
            var start: Vector3 = positions[id]
            var finish: Vector3 = positions[target]
            var fallback := (finish - start).normalized()
            var start_tangent: Vector3 = tangents.get(id, fallback)
            var end_tangent: Vector3 = tangents.get(target, fallback)
            _paths[_edge_key(id, target)] = _sample_edge(start, finish, start_tangent, end_tangent)


static func clear() -> void:
    _paths.clear()


static func path_for(from_id: String, to_id: String, fallback_start: Vector3, fallback_end: Vector3) -> PackedVector3Array:
    var key := _edge_key(from_id, to_id)
    if _paths.has(key):
        var stored: PackedVector3Array = _paths[key]
        return stored
    return PackedVector3Array([fallback_start, fallback_end])


static func length(points: PackedVector3Array) -> float:
    var total := 0.0
    for i in range(1, points.size()):
        total += points[i - 1].distance_to(points[i])
    return total


static func sample_distance(points: PackedVector3Array, distance: float) -> Dictionary:
    if points.size() < 2:
        var p := points[0] if points.size() == 1 else Vector3.ZERO
        return {"position": p, "tangent": Vector3.FORWARD}

    var remaining := maxf(0.0, distance)
    for i in range(1, points.size()):
        var a := points[i - 1]
        var b := points[i]
        var segment := a.distance_to(b)
        if remaining <= segment or i == points.size() - 1:
            var t := clampf(remaining / maxf(segment, 0.0001), 0.0, 1.0)
            return {
                "position": a.lerp(b, t),
                "tangent": (b - a).normalized(),
            }
        remaining -= segment

    return {
        "position": points[points.size() - 1],
        "tangent": (points[points.size() - 1] - points[points.size() - 2]).normalized(),
    }


static func _targets(node: Dictionary) -> Array:
    var result: Array = []
    var node_type := String(node.get("type", "normal"))
    if node_type == "junction":
        result.append(String(node.get("out_a", "")))
        result.append(String(node.get("out_b", "")))
    elif node_type != "receiver":
        var next_id := String(node.get("next", ""))
        if not next_id.is_empty():
            result.append(next_id)
    return result


static func _node_tangent(id: String, incoming_ids: Array, outgoing_ids: Array, positions: Dictionary) -> Vector3:
    if not positions.has(id):
        return Vector3.FORWARD
    var p: Vector3 = positions[id]
    var incoming_forward := Vector3.ZERO
    var outgoing_forward := Vector3.ZERO

    for raw_prev in incoming_ids:
        var prev := String(raw_prev)
        if positions.has(prev):
            var prev_pos: Vector3 = positions[prev]
            incoming_forward += (p - prev_pos).normalized()

    for raw_next in outgoing_ids:
        var next_id := String(raw_next)
        if positions.has(next_id):
            var next_pos: Vector3 = positions[next_id]
            outgoing_forward += (next_pos - p).normalized()

    if incoming_forward.length_squared() > 0.0001:
        incoming_forward = incoming_forward.normalized()
    if outgoing_forward.length_squared() > 0.0001:
        outgoing_forward = outgoing_forward.normalized()

    var tangent := incoming_forward + outgoing_forward
    if tangent.length_squared() < 0.0001:
        tangent = outgoing_forward if outgoing_forward.length_squared() > 0.0001 else incoming_forward
    if tangent.length_squared() < 0.0001:
        return Vector3.FORWARD
    tangent.y = 0.0
    return tangent.normalized()


static func _sample_edge(start: Vector3, finish: Vector3, start_tangent: Vector3, end_tangent: Vector3) -> PackedVector3Array:
    var direct := finish - start
    var distance := direct.length()
    if distance < 0.001:
        return PackedVector3Array([start, finish])
    var forward := direct / distance

    if start_tangent.dot(forward) < 0.12:
        start_tangent = forward
    if end_tangent.dot(forward) < 0.12:
        end_tangent = forward

    var handle := minf(MAX_HANDLE, distance * HANDLE_FACTOR)
    var p1 := start + start_tangent * handle
    var p2 := finish - end_tangent * handle
    var sample_count := clampi(int(ceil(distance / SAMPLE_SPACING)), MIN_SAMPLES, MAX_SAMPLES)

    var points := PackedVector3Array()
    for i in range(sample_count + 1):
        var t := float(i) / float(sample_count)
        var omt := 1.0 - t
        var p := start * (omt * omt * omt)
        p += p1 * (3.0 * omt * omt * t)
        p += p2 * (3.0 * omt * t * t)
        p += finish * (t * t * t)
        points.append(p)
    return points


static func _edge_key(from_id: String, to_id: String) -> String:
    return "%s>%s" % [from_id, to_id]

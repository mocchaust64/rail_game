extends Node
# Curved tracks are presentation only, but renderer and cargo must agree on the
# exact same path. These checks catch endpoint drift, looping handles and broken
# arc-length sampling before a visual tweak can corrupt gameplay readability.


func _ready() -> void:
    var failures: Array[String] = []

    var nodes := {
        "S": {"id": "S", "type": "source", "next": "J"},
        "J": {"id": "J", "type": "junction", "out_a": "L", "out_b": "R"},
        "L": {"id": "L", "type": "receiver", "kind": "red"},
        "R": {"id": "R", "type": "receiver", "kind": "blue"},
    }
    var positions := {
        "S": Vector3(0, 0, -4),
        "J": Vector3(0, 0, 0),
        "L": Vector3(-2.5, 0, 4),
        "R": Vector3(2.5, 0, 4),
    }

    TrackGeometry.rebuild(nodes, positions)
    var incoming := TrackGeometry.path_for("S", "J", positions["S"], positions["J"])
    var left := TrackGeometry.path_for("J", "L", positions["J"], positions["L"])
    var right := TrackGeometry.path_for("J", "R", positions["J"], positions["R"])

    _check_endpoints(failures, incoming, positions["S"], positions["J"], "S>J")
    _check_endpoints(failures, left, positions["J"], positions["L"], "J>L")
    _check_endpoints(failures, right, positions["J"], positions["R"], "J>R")

    if incoming.size() <= 2 or left.size() <= 2 or right.size() <= 2:
        failures.append("curved edges must be sampled, not returned as two-point lines")

    # Both branches should leave the junction in nearly the same forward
    # direction as the incoming belt, creating a clean Y instead of a hard V.
    var incoming_tangent := (incoming[incoming.size() - 1] - incoming[incoming.size() - 2]).normalized()
    var left_tangent := (left[1] - left[0]).normalized()
    var right_tangent := (right[1] - right[0]).normalized()
    if incoming_tangent.dot(left_tangent) < 0.88:
        failures.append("left branch does not share the junction tangent")
    if incoming_tangent.dot(right_tangent) < 0.88:
        failures.append("right branch does not share the junction tangent")

    for edge in [left, right]:
        var curve_length := TrackGeometry.length(edge)
        var straight := edge[0].distance_to(edge[edge.size() - 1])
        if curve_length + 0.001 < straight:
            failures.append("curve length cannot be shorter than its chord")
        if curve_length > straight * 1.30:
            failures.append("curve handle produced an excessive detour")

        var sampled := TrackGeometry.sample_distance(edge, curve_length * 0.5)
        var tangent: Vector3 = sampled["tangent"]
        if tangent.length() < 0.98:
            failures.append("arc-length sample returned an invalid tangent")

    var fallback_start := Vector3(1, 0, 1)
    var fallback_end := Vector3(2, 0, 2)
    var fallback := TrackGeometry.path_for("missing", "edge", fallback_start, fallback_end)
    if fallback.size() != 2 or fallback[0] != fallback_start or fallback[1] != fallback_end:
        failures.append("unknown edge did not fall back to the straight segment")

    if failures.is_empty():
        print("track geometry: PASS (shared bezier paths and arc-length sampling)")
        get_tree().quit(0)
        return
    for line in failures:
        printerr(line)
    printerr("track geometry: FAIL (%d)" % failures.size())
    get_tree().quit(1)


func _check_endpoints(failures: Array[String], points: PackedVector3Array, expected_start: Vector3, expected_end: Vector3, label: String) -> void:
    if points.is_empty():
        failures.append("%s has no points" % label)
        return
    if not points[0].is_equal_approx(expected_start):
        failures.append("%s start drifted from graph node" % label)
    if not points[points.size() - 1].is_equal_approx(expected_end):
        failures.append("%s end drifted from graph node" % label)

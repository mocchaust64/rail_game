extends Node3D


func _ready() -> void:
    var failures: Array[String] = []
    var points := PackedVector3Array([
        Vector3(0.0, 0.0, -3.0),
        Vector3(0.0, 0.0, -1.5),
        Vector3(0.35, 0.0, 0.0),
        Vector3(1.2, 0.0, 1.4),
        Vector3(2.4, 0.0, 2.5),
    ])
    var path := TrackVisuals.create_path(self, points)

    for layer_name in ["GuideRails", "BeltBase", "MovingBelt"]:
        var layer := path.get_node_or_null(NodePath(layer_name))
        if not layer is MeshInstance3D:
            failures.append("%s must be one continuous mesh" % layer_name)
            continue
        var mesh := (layer as MeshInstance3D).mesh
        if mesh == null or mesh.get_surface_count() != 1:
            failures.append("%s has no renderable surface" % layer_name)
            continue
        var arrays := mesh.surface_get_arrays(0)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        if vertices.is_empty():
            failures.append("%s has no vertices" % layer_name)

    var motion := path.get_node_or_null(NodePath("BeltMotion")) as TrackMotion
    if motion == null:
        failures.append("track must include moving conveyor seams")

    var junction_nodes := {
        "S": {"id": "S", "type": "source", "next": "J"},
        "J": {
            "id": "J", "type": "junction", "out_a": "L", "out_b": "R",
            "filter_kind": "blue", "filter_options": ["red", "blue"]
        },
        "L": {"id": "L", "type": "receiver", "kind": "red"},
        "R": {"id": "R", "type": "receiver", "kind": "blue"},
    }
    var junction_positions := {
        "S": Vector3(0, 0, -4),
        "J": Vector3(0, 0, 0),
        "L": Vector3(-2.5, 0, 4),
        "R": Vector3(2.5, 0, 4),
    }
    TrackGeometry.rebuild(junction_nodes, junction_positions)
    var junction := JunctionActor.new()
    add_child(junction)
    junction.configure(junction_nodes["J"], junction_positions)

    var physical_rail := junction.get_node_or_null(NodePath("PhysicalSwitchRail")) as Node3D
    if physical_rail == null:
        failures.append("junction must expose the long moving conveyor")
    var markers := junction.get_node_or_null(NodePath("RoutingRuleMarkers")) as Node3D
    if markers == null:
        failures.append("junction must show its programmed colour rule")

    # Setup tap changes the filter, not the live route.
    if junction.filter_kind != "blue":
        failures.append("junction did not load initial filter")
    if not junction.cycle_filter() or junction.filter_kind != "red":
        failures.append("planning tap did not cycle the filter rule")

    # Once RUN starts, manual reprogramming must be impossible.
    junction.set_planning_mode(false)
    if junction.cycle_filter():
        failures.append("junction accepted manual filter change during RUN")
    if junction.filter_kind != "red":
        failures.append("runtime tap changed programmed filter")

    # The programmed colour goes to A; all other colours go to B.
    if junction.route_for_kind("red") != "L":
        failures.append("programmed colour did not map to out_a")
    if junction.route_for_kind("blue") != "R":
        failures.append("other colour did not map to out_b")

    # Cargo waits for the physical switch before callback/route commit.
    junction.state = 0
    var routed: Array[String] = []
    junction.request_route_for_kind("blue", func(output: String) -> void: routed.append(output))
    if junction.state != 0:
        failures.append("route changed before physical conveyor finished")
    if not routed.is_empty():
        failures.append("cargo continued before physical conveyor finished")
    junction._on_route_animation_finished()
    if junction.state != 1 or routed != ["R"]:
        failures.append("cargo did not resume on programmed route after switch")

    remove_child(junction)
    junction.free()
    remove_child(path)
    path.free()
    VisualFactory._material_cache.clear()

    if failures.is_empty():
        print("track visuals: PASS (moving conveyor + pre-programmed colour routing)")
        get_tree().quit(0)
        return
    for failure in failures:
        printerr(failure)
    printerr("track visuals: FAIL (%d issues)" % failures.size())
    get_tree().quit(1)

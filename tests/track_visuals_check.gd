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
        for vertex in vertices:
            if not vertex.is_finite():
                failures.append("%s contains a non-finite vertex" % layer_name)
                break

    var motion := path.get_node_or_null(NodePath("BeltMotion")) as TrackMotion
    if motion == null:
        failures.append("track must include moving conveyor seams")
    elif motion.get_node_or_null(NodePath("MovingBeltSeams")) == null:
        failures.append("moving conveyor seams are missing")

    var junction_nodes := {
        "S": {"id": "S", "type": "source", "next": "J"},
        "J": {"id": "J", "type": "junction", "out_a": "L", "out_b": "R"},
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

    var angle_a := junction._angle_for_state(0)
    var angle_b := junction._angle_for_state(1)
    var switch_arc := absf(wrapf(angle_a - angle_b, -PI, PI))
    if switch_arc < deg_to_rad(14.0):
        failures.append("switch rail states differ by only %.1f degrees" % rad_to_deg(switch_arc))

    var physical_rail := junction.get_node_or_null(NodePath("PhysicalSwitchRail")) as Node3D
    if physical_rail == null:
        failures.append("junction must expose the long moving conveyor")
    var switch_pivot := junction.get_node_or_null(NodePath("SwitchPivot")) as MeshInstance3D
    if switch_pivot == null or not switch_pivot.mesh is CylinderMesh:
        failures.append("junction needs a small mechanical pivot")
    elif (switch_pivot.mesh as CylinderMesh).top_radius > 0.30:
        failures.append("junction pivot is too large and reads like a UI button")

    # Route must stay old until the physical conveyor finishes moving.
    junction.state = 0
    junction._perform_toggle(1)
    if junction.state != 0:
        failures.append("junction route changed before the conveyor connected")
    if junction.selected_state() != 1:
        failures.append("junction did not remember the requested target")

    # A duplicated mouse/touch event during the same click must be ignored, not
    # queued. This is the regression that made the user's rail rotate back.
    junction.request_toggle()
    junction._on_toggle_finished()
    if junction.state != 1:
        failures.append("duplicate input made the switch return to its old route")

    remove_child(junction)
    junction.free()
    remove_child(path)
    path.free()
    VisualFactory._material_cache.clear()

    if failures.is_empty():
        print("track visuals: PASS (smooth guide rails + long moving conveyor + stable tap)")
        get_tree().quit(0)
        return
    for failure in failures:
        printerr(failure)
    printerr("track visuals: FAIL (%d issues)" % failures.size())
    get_tree().quit(1)

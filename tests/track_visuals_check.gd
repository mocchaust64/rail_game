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

    for layer_name in ["Base", "Belt", "Rails"]:
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

    var slats := path.get_node_or_null(NodePath("Slats"))
    if not slats is MultiMeshInstance3D:
        failures.append("slats must remain MultiMesh-batched")
    var authored_detail := path.get_node_or_null(NodePath("KenneyConveyorDetail")) as MultiMeshInstance3D
    if authored_detail == null:
        failures.append("Kenney conveyor detail is missing")
    elif authored_detail.material_override is StandardMaterial3D:
        var detail_material := authored_detail.material_override as StandardMaterial3D
        if detail_material.albedo_color.get_luminance() >= 0.40:
            failures.append("authored conveyor detail must stay darker than the metal rails")

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
    junction.state = 0
    var angle_a := junction._target_angle()
    junction.state = 1
    var angle_b := junction._target_angle()
    var switch_arc := absf(wrapf(angle_a - angle_b, -PI, PI))
    if switch_arc < deg_to_rad(14.0):
        failures.append("switch rail states differ by only %.1f degrees" % rad_to_deg(switch_arc))
    var switch_base := junction.get_node_or_null(NodePath("SwitchBase")) as MeshInstance3D
    if switch_base == null or not switch_base.mesh is CylinderMesh:
        failures.append("junction needs a named mechanical switch base")
    elif (switch_base.mesh as CylinderMesh).top_radius < TrackVisuals.BASE_WIDTH * 0.5:
        failures.append("switch base does not cover the conveyor-width junction gap")
    remove_child(junction)
    junction.free()

    remove_child(path)
    path.free()
    VisualFactory._material_cache.clear()
    if failures.is_empty():
        print("track visuals: PASS (continuous body and rails, batched slats)")
        get_tree().quit(0)
        return
    for failure in failures:
        printerr(failure)
    printerr("track visuals: FAIL (%d issues)" % failures.size())
    get_tree().quit(1)

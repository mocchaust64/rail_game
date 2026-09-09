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

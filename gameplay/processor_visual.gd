class_name ProcessorVisual
extends RefCounted
# Custom mid-track machine with a real open tunnel. Cargo passes through the
# empty centre instead of visually clipping through a solid body.


static func create(parent: Node3D, colour: Color = Color("#4D97DF")) -> Node3D:
    var root := Node3D.new()
    root.name = "MidTrackProcessor"
    parent.add_child(root)

    # Two feet keep the rail channel physically open.
    for x in [-0.60, 0.60]:
        var foot := _chamfered_box(Vector3(0.46, 0.18, 1.30), 0.10, Color("#55585A"), 0.60)
        foot.position = Vector3(float(x), 0.09, 0)
        root.add_child(foot)

        var pillar := _chamfered_box(Vector3(0.46, 0.98, 1.22), 0.13, colour, 0.32)
        pillar.position = Vector3(float(x), 0.66, 0)
        root.add_child(pillar)

    # Bridge above the ball path: this gives the machine its chunky silhouette
    # while preserving a 0.78-unit wide open passage underneath.
    var bridge := _chamfered_box(Vector3(1.66, 0.34, 1.28), 0.16, colour, 0.31)
    bridge.position = Vector3(0, 1.20, 0)
    root.add_child(bridge)

    var front_lintel := _chamfered_box(Vector3(0.92, 0.20, 0.12), 0.06, colour.darkened(0.18), 0.40)
    front_lintel.position = Vector3(0, 0.96, 0.65)
    root.add_child(front_lintel)
    var back_lintel := _chamfered_box(Vector3(0.92, 0.18, 0.10), 0.05, colour.darkened(0.20), 0.42)
    back_lintel.position = Vector3(0, 0.94, -0.64)
    root.add_child(back_lintel)

    # Dark tunnel cheeks frame the moving ball without closing the opening.
    for x in [-0.405, 0.405]:
        var cheek := _chamfered_box(Vector3(0.07, 0.64, 0.82), 0.025, Color("#303438"), 0.46)
        cheek.position = Vector3(float(x), 0.53, 0.10)
        root.add_child(cheek)

    var ring := _cylinder(0.31, 0.07, Color("#E3E1DB"), 0.24, 0.16)
    ring.position = Vector3(0, 1.42, -0.03)
    root.add_child(ring)
    var dome := _sphere(0.22, colour.lightened(0.08), 0.18)
    dome.scale.y = 0.52
    dome.position = Vector3(0, 1.48, -0.03)
    root.add_child(dome)

    var stem := _cylinder(0.045, 0.42, Color("#73777A"), 0.32, 0.18)
    stem.position = Vector3(0.83, 0.80, 0.03)
    root.add_child(stem)
    var knob := _sphere(0.095, colour, 0.20)
    knob.position = Vector3(0.83, 1.04, 0.03)
    root.add_child(knob)

    return root


static func _chamfered_box(size: Vector3, bevel: float, colour: Color, roughness: float) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    tool.set_material(VisualFactory.material(colour, roughness))

    var hx := size.x * 0.5
    var hy := size.y * 0.5
    var hz := size.z * 0.5
    var b := clampf(bevel, 0.01, minf(hx, hz) * 0.48)
    var bottom: Array[Vector3] = [
        Vector3(-hx + b, -hy, -hz),
        Vector3(hx - b, -hy, -hz),
        Vector3(hx, -hy, -hz + b),
        Vector3(hx, -hy, hz - b),
        Vector3(hx - b, -hy, hz),
        Vector3(-hx + b, -hy, hz),
        Vector3(-hx, -hy, hz - b),
        Vector3(-hx, -hy, -hz + b),
    ]
    var top: Array[Vector3] = []
    for p in bottom:
        top.append(Vector3(p.x, hy, p.z))

    for i in range(8):
        var j := (i + 1) % 8
        _quad(tool, bottom[i], bottom[j], top[j], top[i])

    var top_center := Vector3(0, hy, 0)
    var bottom_center := Vector3(0, -hy, 0)
    for i in range(8):
        var j := (i + 1) % 8
        tool.add_vertex(top_center)
        tool.add_vertex(top[j])
        tool.add_vertex(top[i])
        tool.add_vertex(bottom_center)
        tool.add_vertex(bottom[i])
        tool.add_vertex(bottom[j])

    tool.generate_normals()
    node.mesh = tool.commit()
    return node


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    for vertex in [a, b, c, a, c, d]:
        tool.add_vertex(vertex)


static func _sphere(radius: float, colour: Color, roughness: float) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 20
    mesh.rings = 10
    node.mesh = mesh
    node.material_override = VisualFactory.material(colour, roughness)
    return node


static func _cylinder(radius: float, height: float, colour: Color, roughness: float, metallic: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 20
    node.mesh = mesh
    node.material_override = VisualFactory.material(colour, roughness, 0.0, metallic)
    return node

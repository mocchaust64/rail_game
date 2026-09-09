class_name MachineVisuals
extends RefCounted
# Custom reference-video machines. The body is a generated chamfered toy mesh,
# shared by source and destinations so the gameplay scene has one visual language
# without depending on external model packs.


static func create_source_shell(parent: Node3D) -> Node3D:
    var root := Node3D.new()
    root.name = "SourceShell"
    parent.add_child(root)

    var shadow_base := _chamfered_box(Vector3(1.52, 0.16, 1.42), 0.16, Color("#55585A"), 0.60)
    shadow_base.position.y = 0.08
    root.add_child(shadow_base)

    var body := _chamfered_box(Vector3(1.40, 1.06, 1.30), 0.18, VisualFactory.BLUE, 0.34)
    body.position.y = 0.62
    root.add_child(body)

    var face := _chamfered_box(Vector3(0.92, 0.54, 0.10), 0.10, Color("#286FB7"), 0.38)
    face.position = Vector3(0, 0.54, 0.66)
    root.add_child(face)

    var mouth := _chamfered_box(Vector3(0.74, 0.36, 0.12), 0.07, Color("#2F3235"), 0.48)
    mouth.position = Vector3(0, 0.42, 0.73)
    root.add_child(mouth)

    var ring := _cylinder(0.36, 0.075, Color("#DDE1E0"), 0.25, 0.20)
    ring.name = "LaunchRing"
    ring.position = Vector3(0, 1.21, -0.02)
    root.add_child(ring)

    var top_button := _cylinder(0.25, 0.07, VisualFactory.BLUE, 0.20)
    top_button.position = Vector3(0, 1.265, -0.02)
    root.add_child(top_button)

    _add_lever(root, VisualFactory.BLUE)
    return root


static func create_receiver_shell(parent: Node3D, kind: String) -> Dictionary:
    var root := Node3D.new()
    root.name = "ReceiverShell_%s" % kind
    parent.add_child(root)

    var colour := VisualFactory.kind_color(kind)
    var dark_colour := colour.darkened(0.16)

    var shadow_base := _chamfered_box(Vector3(1.62, 0.16, 1.48), 0.16, Color("#55585A"), 0.60)
    shadow_base.position.y = 0.08
    root.add_child(shadow_base)

    var body := _chamfered_box(Vector3(1.48, 1.14, 1.34), 0.18, colour, 0.33)
    body.position.y = 0.66
    root.add_child(body)

    var face := _chamfered_box(Vector3(1.02, 0.68, 0.11), 0.10, dark_colour, 0.38)
    face.position = Vector3(0, 0.58, 0.69)
    root.add_child(face)

    var mouth := _chamfered_box(Vector3(0.84, 0.42, 0.13), 0.07, Color("#303236"), 0.46)
    mouth.position = Vector3(0, 0.40, 0.765)
    root.add_child(mouth)

    # Coloured ramp with the same double chevron used by the target video.
    var tongue := _chamfered_box(Vector3(0.78, 0.085, 0.92), 0.10, colour, 0.42)
    tongue.position = Vector3(0, 0.095, 1.08)
    root.add_child(tongue)
    _chevron(root, 0.96)
    _chevron(root, 1.18)

    var sign := _chamfered_box(Vector3(0.82, 0.24, 0.055), 0.06, dark_colour, 0.42)
    sign.position = Vector3(0, 0.91, 0.755)
    root.add_child(sign)

    var label := Label3D.new()
    label.text = kind.to_upper()
    label.font_size = 88
    label.pixel_size = 0.00355
    label.modulate = Color.WHITE
    label.outline_size = 4
    label.outline_modulate = Color(0, 0, 0, 0.12)
    label.position = Vector3(0, 0.91, 0.79)
    root.add_child(label)

    var badge_anchor := Node3D.new()
    badge_anchor.name = "TopBadge"
    badge_anchor.position = Vector3(0, 1.31, -0.03)
    root.add_child(badge_anchor)

    var top_ring := _cylinder(0.24, 0.055, Color("#E4E2DC"), 0.24, 0.16)
    badge_anchor.add_child(top_ring)
    var top_button := _cylinder(0.16, 0.075, colour, 0.20)
    top_button.position.y = 0.055
    badge_anchor.add_child(top_button)

    _add_lever(root, colour)
    var lamp := _sphere(0.095, colour, 0.18, 0.16)
    lamp.position = Vector3(0.70, 1.02, 0.10)
    root.add_child(lamp)

    return {
        "root": root,
        "mouth": mouth,
        "badge_anchor": badge_anchor,
        "lamp": lamp,
    }


static func _add_lever(parent: Node3D, colour: Color) -> void:
    var stem := _cylinder(0.045, 0.42, Color("#73777A"), 0.32, 0.18)
    stem.position = Vector3(0.70, 0.76, 0.04)
    parent.add_child(stem)
    var knob := _sphere(0.095, colour, 0.20)
    knob.position = Vector3(0.70, 1.00, 0.04)
    parent.add_child(knob)


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
        var next := (i + 1) % 8
        _quad(tool, bottom[i], bottom[next], top[next], top[i])

    var top_center := Vector3(0, hy, 0)
    var bottom_center := Vector3(0, -hy, 0)
    for i in range(8):
        var next := (i + 1) % 8
        tool.add_vertex(top_center)
        tool.add_vertex(top[next])
        tool.add_vertex(top[i])
        tool.add_vertex(bottom_center)
        tool.add_vertex(bottom[i])
        tool.add_vertex(bottom[next])

    tool.generate_normals()
    node.mesh = tool.commit()
    return node


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    for vertex in [a, b, c, a, c, d]:
        tool.add_vertex(vertex)


static func _chevron(parent: Node3D, z_value: float) -> void:
    var left := _box(Vector3(0.10, 0.035, 0.30), Color.WHITE, 0.44)
    left.position = Vector3(-0.10, 0.16, z_value)
    left.rotation.y = -PI * 0.25
    parent.add_child(left)
    var right := _box(Vector3(0.10, 0.035, 0.30), Color.WHITE, 0.44)
    right.position = Vector3(0.10, 0.16, z_value)
    right.rotation.y = PI * 0.25
    parent.add_child(right)


static func _box(size: Vector3, colour: Color, roughness: float) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = VisualFactory.material(colour, roughness)
    return node


static func _sphere(radius: float, colour: Color, roughness: float, emission: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 20
    mesh.rings = 10
    node.mesh = mesh
    node.material_override = VisualFactory.material(colour, roughness, emission)
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

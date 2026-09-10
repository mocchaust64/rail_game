class_name MachineVisuals
extends RefCounted
# Cohesive toy-factory machines generated from primitives. The visual target is
# the AI reference: chunky rounded silhouettes, one strong dark mouth, a simple
# top control, and colour used as identity rather than decoration noise.


static func create_source_shell(parent: Node3D) -> Node3D:
    var root := Node3D.new()
    root.name = "SourceShell"
    parent.add_child(root)

    _add_shadow_plinth(root, Vector3(1.48, 0.14, 1.32))

    var shell := _chamfered_box(Vector3(1.34, 1.02, 1.20), 0.24, Color("#6DA7D1"), 0.42)
    shell.position.y = 0.60
    root.add_child(shell)

    var cap := _chamfered_box(Vector3(1.18, 0.18, 1.02), 0.20, Color("#8BC0E0"), 0.36)
    cap.position.y = 1.08
    root.add_child(cap)

    var face := _chamfered_box(Vector3(0.92, 0.50, 0.10), 0.10, Color("#3D79A4"), 0.48)
    face.position = Vector3(0, 0.53, 0.615)
    root.add_child(face)

    var mouth := _chamfered_box(Vector3(0.72, 0.31, 0.13), 0.07, Color("#252A2D"), 0.72)
    mouth.position = Vector3(0, 0.40, 0.685)
    root.add_child(mouth)

    _add_top_control(root, Color("#5B9BC8"))
    _add_side_button(root, Color("#5B9BC8"))
    return root


static func create_receiver_shell(parent: Node3D, kind: String) -> Dictionary:
    var root := Node3D.new()
    root.name = "ReceiverShell_%s" % kind
    parent.add_child(root)

    var colour := VisualFactory.kind_color(kind)
    var shell_colour := colour.lightened(0.06)
    var face_colour := colour.darkened(0.18)

    _add_shadow_plinth(root, Vector3(1.58, 0.14, 1.40))

    # Slightly tapered/chamfered body with a distinct cap gives the same toy
    # appliance read as the reference instead of a raw coloured cube.
    var body := _chamfered_box(Vector3(1.42, 1.10, 1.26), 0.27, shell_colour, 0.40)
    body.position.y = 0.64
    root.add_child(body)

    var cap := _chamfered_box(Vector3(1.24, 0.20, 1.08), 0.23, colour.lightened(0.13), 0.34)
    cap.position.y = 1.14
    root.add_child(cap)

    var face := _chamfered_box(Vector3(1.00, 0.60, 0.105), 0.12, face_colour, 0.50)
    face.position = Vector3(0, 0.58, 0.65)
    root.add_child(face)

    var mouth := _chamfered_box(Vector3(0.82, 0.35, 0.14), 0.08, Color("#24282B"), 0.72)
    mouth.position = Vector3(0, 0.39, 0.725)
    root.add_child(mouth)

    # One clean destination label above the mouth. No duplicate symbols.
    var label := Label3D.new()
    label.text = kind.to_upper()
    label.font_size = 84
    label.pixel_size = 0.00345
    label.modulate = Color("#FFF9F0")
    label.outline_size = 4
    label.outline_modulate = Color(0, 0, 0, 0.12)
    label.position = Vector3(0, 0.84, 0.72)
    root.add_child(label)

    # The receiving tongue is wide, short and visually welded to the machine.
    var tongue := _chamfered_box(Vector3(0.76, 0.075, 0.86), 0.12, colour, 0.46)
    tongue.position = Vector3(0, 0.09, 1.00)
    root.add_child(tongue)
    _chevron(root, 0.91)
    _chevron(root, 1.11)

    var badge_anchor := Node3D.new()
    badge_anchor.name = "TopBadge"
    badge_anchor.position = Vector3(0, 1.33, -0.02)
    root.add_child(badge_anchor)
    var top_ring := _cylinder(0.255, 0.055, Color("#EEE9DF"), 0.44, 0.08)
    badge_anchor.add_child(top_ring)
    var top_button := _sphere(0.155, colour.lightened(0.04), 0.28, 0.08)
    top_button.scale.y = 0.55
    top_button.position.y = 0.07
    badge_anchor.add_child(top_button)

    _add_side_button(root, colour)
    var lamp := _sphere(0.078, colour.lightened(0.08), 0.24, 0.10)
    lamp.position = Vector3(0.66, 0.96, 0.08)
    root.add_child(lamp)

    return {
        "root": root,
        "mouth": mouth,
        "badge_anchor": badge_anchor,
        "lamp": lamp,
    }


static func populate_sorter_shell(parent: Node3D, mapping: Array, directions: Array) -> Dictionary:
    # Blue is deliberately reserved for the routing appliance itself, matching
    # the reference processor while the cargo colours remain decision signals.
    var body_blue := Color("#5C9FD0")
    var dark_blue := Color("#315F7F")
    var lights: Array[MeshInstance3D] = []
    var roof_lights: Array[MeshInstance3D] = []

    _add_shadow_plinth(parent, Vector3(1.72, 0.14, 1.48))

    var body := _chamfered_box(Vector3(1.56, 1.14, 1.34), 0.28, body_blue, 0.40)
    body.position.y = 0.66
    parent.add_child(body)

    var cap := _chamfered_box(Vector3(1.34, 0.20, 1.14), 0.24, Color("#79B5DB"), 0.34)
    cap.position.y = 1.17
    parent.add_child(cap)

    var face := _chamfered_box(Vector3(1.04, 0.58, 0.11), 0.12, dark_blue, 0.50)
    face.position = Vector3(0, 0.58, -0.69)
    parent.add_child(face)

    var mouth := _chamfered_box(Vector3(0.78, 0.34, 0.14), 0.08, Color("#24282B"), 0.72)
    mouth.position = Vector3(0, 0.40, -0.765)
    parent.add_child(mouth)

    _add_top_control(parent, body_blue)
    _add_side_button(parent, body_blue)

    # Three roof dots echo the three exits without forcing the player to decode
    # tiny text on the appliance itself.
    for i in range(3):
        var kind := String(mapping[i]) if i < mapping.size() else "red"
        var lamp := _sphere(0.095, VisualFactory.kind_color(kind), 0.24, 0.14)
        lamp.position = Vector3((float(i) - 1.0) * 0.29, 1.37, 0.02)
        parent.add_child(lamp)
        roof_lights.append(lamp)

    # Coloured port lamps sit exactly where the three physical conveyors leave
    # the sorter, so the colour->lane relationship is spatial rather than verbal.
    for i in range(mini(3, directions.size())):
        var dir: Vector3 = directions[i]
        var kind := String(mapping[i]) if i < mapping.size() else "red"

        var housing := _cylinder(0.20, 0.10, Color("#41484C"), 0.64, 0.06)
        housing.position = dir * 0.71 + Vector3(0, 0.26, 0)
        parent.add_child(housing)

        var light := _sphere(0.145, VisualFactory.kind_color(kind), 0.22, 0.14)
        light.position = dir * 0.75 + Vector3(0, 0.36, 0)
        parent.add_child(light)
        lights.append(light)

    return {
        "port_lights": lights,
        "roof_lights": roof_lights,
    }


static func create_processor_shell(parent: Node3D, colour: Color = Color("#5C9FD0")) -> Node3D:
    var root := Node3D.new()
    root.name = "MidTrackProcessor"
    parent.add_child(root)

    _add_shadow_plinth(root, Vector3(1.62, 0.14, 1.46))

    var body := _chamfered_box(Vector3(1.48, 1.12, 1.34), 0.28, colour, 0.40)
    body.position.y = 0.65
    root.add_child(body)

    var cap := _chamfered_box(Vector3(1.26, 0.19, 1.12), 0.23, colour.lightened(0.12), 0.34)
    cap.position.y = 1.16
    root.add_child(cap)

    var face_front := _chamfered_box(Vector3(0.96, 0.54, 0.11), 0.11, colour.darkened(0.20), 0.50)
    face_front.position = Vector3(0, 0.55, 0.70)
    root.add_child(face_front)
    var mouth_front := _chamfered_box(Vector3(0.76, 0.33, 0.14), 0.08, Color("#252A2D"), 0.72)
    mouth_front.position = Vector3(0, 0.40, 0.775)
    root.add_child(mouth_front)

    var mouth_back := _chamfered_box(Vector3(0.72, 0.29, 0.11), 0.07, Color("#30363A"), 0.68)
    mouth_back.position = Vector3(0, 0.40, -0.72)
    root.add_child(mouth_back)

    _add_top_control(root, colour)
    _add_side_button(root, colour)
    return root


static func _add_shadow_plinth(parent: Node3D, size: Vector3) -> void:
    var plinth := _chamfered_box(size, 0.18, Color("#55595B"), 0.68)
    plinth.position.y = 0.07
    parent.add_child(plinth)


static func _add_top_control(parent: Node3D, colour: Color) -> void:
    var ring := _cylinder(0.27, 0.055, Color("#ECE8DF"), 0.42, 0.08)
    ring.position = Vector3(0, 1.32, -0.02)
    parent.add_child(ring)
    var dome := _sphere(0.17, colour.lightened(0.05), 0.25, 0.08)
    dome.scale.y = 0.52
    dome.position = Vector3(0, 1.39, -0.02)
    parent.add_child(dome)


static func _add_side_button(parent: Node3D, colour: Color) -> void:
    var stem := _cylinder(0.040, 0.28, Color("#73787A"), 0.42, 0.08)
    stem.position = Vector3(0.70, 0.79, 0.02)
    parent.add_child(stem)
    var knob := _sphere(0.085, colour.lightened(0.04), 0.26)
    knob.position = Vector3(0.70, 0.96, 0.02)
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
    var left := _box(Vector3(0.10, 0.035, 0.28), Color("#FFF9F0"), 0.50)
    left.position = Vector3(-0.10, 0.15, z_value)
    left.rotation.y = -PI * 0.25
    parent.add_child(left)
    var right := _box(Vector3(0.10, 0.035, 0.28), Color("#FFF9F0"), 0.50)
    right.position = Vector3(0.10, 0.15, z_value)
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

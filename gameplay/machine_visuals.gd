class_name MachineVisuals
extends RefCounted
# Receiver/source shells share one authored Kenney Factory Kit body so the
# machines read as a coherent product asset instead of boxes assembled in code.

const KENNEY_HOPPER: Mesh = preload("res://assets/vendor/kenney_factory_kit/hopper_square_body_cc0.obj")


static func create_source_shell(parent: Node3D) -> Node3D:
    var root := Node3D.new()
    root.name = "SourceShell"
    parent.add_child(root)

    var base := _box(Vector3(1.48, 0.14, 1.42), Color("#555A5D"), 0.58)
    base.position.y = 0.06
    root.add_child(base)

    var body := _authored_body(VisualFactory.BLUE)
    body.position = Vector3(0, 0.10, -0.05)
    root.add_child(body)

    var mouth := _box(Vector3(0.76, 0.34, 0.16), VisualFactory.MACHINE_DARK, 0.46)
    mouth.position = Vector3(0, 0.46, 0.64)
    root.add_child(mouth)

    var ring := _cylinder(0.39, 0.09, Color("#DADBD5"), 0.28, 0.16)
    ring.name = "LaunchRing"
    ring.position = Vector3(0, 1.18, -0.02)
    root.add_child(ring)

    var well := _cylinder(0.27, 0.06, VisualFactory.MACHINE_DARK, 0.45)
    well.position = Vector3(0, 1.22, -0.02)
    root.add_child(well)

    var lever := _cylinder(0.045, 0.42, Color("#727A7D"), 0.34, 0.14)
    lever.position = Vector3(0.62, 0.72, 0.03)
    root.add_child(lever)
    var knob := _sphere(0.10, VisualFactory.BLUE, 0.22)
    knob.position = Vector3(0.62, 0.96, 0.03)
    root.add_child(knob)
    return root


static func create_receiver_shell(parent: Node3D, kind: String) -> Dictionary:
    var root := Node3D.new()
    root.name = "ReceiverShell_%s" % kind
    parent.add_child(root)

    var colour := VisualFactory.kind_color(kind)
    var base := _box(Vector3(1.58, 0.15, 1.48), Color("#555A5D"), 0.58)
    base.position.y = 0.06
    root.add_child(base)

    var body := _authored_body(colour)
    body.position = Vector3(0, 0.10, -0.05)
    root.add_child(body)

    # Deep front mouth makes the destination obvious before the label is read.
    var mouth := _box(Vector3(0.82, 0.42, 0.18), Color("#303437"), 0.44)
    mouth.position = Vector3(0, 0.48, 0.65)
    root.add_child(mouth)

    var tongue := _box(Vector3(0.76, 0.07, 0.78), colour, 0.48)
    tongue.position = Vector3(0, 0.10, 1.00)
    root.add_child(tongue)
    _chevron(root, 0.91)
    _chevron(root, 1.12)

    # A fixed face sign reads like part of the machine rather than floating UI.
    var sign := _box(Vector3(0.82, 0.23, 0.045), Color("#414548"), 0.50)
    sign.position = Vector3(0, 0.91, 0.61)
    root.add_child(sign)

    var label := Label3D.new()
    label.text = kind.to_upper()
    label.font_size = 86
    label.pixel_size = 0.0036
    label.modulate = Color.WHITE
    label.outline_size = 5
    label.outline_modulate = Color(0, 0, 0, 0.15)
    label.position = Vector3(0, 0.91, 0.64)
    root.add_child(label)

    var badge_anchor := Node3D.new()
    badge_anchor.position = Vector3(0, 1.30, 0)
    root.add_child(badge_anchor)
    var cap := _cylinder(0.18, 0.055, Color("#E5E2DA"), 0.28, 0.10)
    badge_anchor.add_child(cap)
    var cap_dot := _sphere(0.105, colour, 0.22)
    cap_dot.position.y = 0.055
    badge_anchor.add_child(cap_dot)

    var lamp := _sphere(0.10, colour, 0.22, 0.20)
    lamp.position = Vector3(0.62, 1.02, 0.06)
    root.add_child(lamp)

    return {
        "root": root,
        "mouth": mouth,
        "badge_anchor": badge_anchor,
        "lamp": lamp,
    }


static func _authored_body(colour: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = "KenneyFactoryBody"
    node.mesh = KENNEY_HOPPER
    node.scale = Vector3(1.20, 0.72, 1.20)
    node.material_override = VisualFactory.material(colour, 0.38, 0.0, 0.06)
    return node


static func _chevron(parent: Node3D, z_value: float) -> void:
    var left := _box(Vector3(0.10, 0.032, 0.30), Color.WHITE, 0.46)
    left.position = Vector3(-0.10, 0.145, z_value)
    left.rotation.y = -PI * 0.25
    parent.add_child(left)
    var right := _box(Vector3(0.10, 0.032, 0.30), Color.WHITE, 0.46)
    right.position = Vector3(0.10, 0.145, z_value)
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
    mesh.radial_segments = 18
    mesh.rings = 9
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

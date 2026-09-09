class_name VisualFactory
extends RefCounted

const PALETTE_PATH := "res://assets/palette/toy_factory.tres"
static var palette: ToyFactoryPalette = load(PALETTE_PATH)

static var FLOOR_COLOR: Color = palette.floor_colour
static var FLOOR_EDGE: Color = palette.floor_edge
static var FLOOR_INSET: Color = palette.floor_inset
static var BELT_COLOR: Color = palette.belt
static var BELT_INNER: Color = palette.belt_inner
static var BELT_SLAT: Color = palette.belt_slat
static var RAIL_COLOR: Color = palette.rail
static var MACHINE_BODY: Color = palette.machine_body
static var MACHINE_DARK: Color = palette.machine_dark
static var RED: Color = palette.cargo_red
static var BLUE: Color = palette.cargo_blue
static var YELLOW: Color = palette.cargo_yellow
static var GREEN_ACCENT: Color = palette.accent_green
static var ORANGE_ACCENT: Color = palette.accent_orange

const DECOR_GROUP := "decoration"
const DECOR_CLEARANCE := 1.55

static var _material_cache: Dictionary = {}


static func material(color: Color, roughness: float = 0.72, emission: float = 0.0, metallic: float = 0.0) -> StandardMaterial3D:
    var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, emission, metallic]
    if _material_cache.has(key):
        return _material_cache[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    mat.metallic = metallic
    if color.a < 0.999:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = Color(color.r, color.g, color.b, 1.0)
        mat.emission_energy_multiplier = emission
    _material_cache[key] = mat
    return mat


static func kind_color(kind: String) -> Color:
    return palette.cargo_colour(kind)


static func create_floor(parent: Node3D, occupied: Array = []) -> Node3D:
    var root := Node3D.new()
    root.name = "ReferenceToyYard"
    parent.add_child(root)

    # One uninterrupted cream play surface. There is deliberately no inset
    # rectangle or board edge: the reference reads as one continuous toy yard.
    var ground := _box(Vector3(14.0, 0.24, 19.0), Color("#F1E4D3"), 0.94)
    ground.position = Vector3(0, -0.27, 0.25)
    ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(ground)

    _create_reference_decor(root, occupied)
    return root


static func create_kind_visual(kind: String, scale_value: float = 0.38) -> Node3D:
    var root := Node3D.new()
    root.name = "CargoBall_%s" % kind

    var ball := _sphere(scale_value, kind_color(kind), 0.22)
    ball.position.y = 0.02
    root.add_child(ball)

    # A small specular bead gives the same glossy toy read as the target video
    # without drawing a large accessibility icon over the ball surface.
    var shine := _sphere(scale_value * 0.095, Color(1, 1, 1, 0.76), 0.12)
    shine.position = Vector3(-scale_value * 0.25, scale_value * 0.28, -scale_value * 0.19)
    root.add_child(shine)
    return root


# Compatibility entry points. Active gameplay actors call MachineVisuals
# directly, but keeping these avoids breaking older test scenes.
static func create_source_shell(parent: Node3D) -> Node3D:
    return MachineVisuals.create_source_shell(parent)


static func create_receiver_shell(parent: Node3D, kind: String) -> Dictionary:
    return MachineVisuals.create_receiver_shell(parent, kind)


static func create_buffer_chute(parent: Node3D) -> Node3D:
    # The reference presents the buffer as a quiet row of circular sockets at
    # the bottom of the world rather than a separate industrial chute.
    var root := Node3D.new()
    root.name = "BufferSocketTray"
    root.position = Vector3(0.0, 0.0, 6.35)
    parent.add_child(root)

    var back := _box(Vector3(4.65, 0.08, 0.86), Color("#E4D5C3"), 0.92)
    back.position.y = -0.01
    root.add_child(back)

    for x in [-1.72, -0.86, 0.0, 0.86, 1.72]:
        var rim := _cylinder(0.34, 0.045, Color("#D4C3B0"), 0.88)
        rim.position = Vector3(float(x), 0.055, 0)
        root.add_child(rim)
        var socket := _cylinder(0.285, 0.025, Color("#EEDFCF"), 0.96)
        socket.position = Vector3(float(x), 0.085, 0)
        root.add_child(socket)
    return root


static func create_spark_burst(parent: Node3D, origin: Vector3, color: Color) -> void:
    var root := Node3D.new()
    root.name = "SparkBurst"
    parent.add_child(root)
    root.global_position = origin
    for i in range(9):
        var spark := _sphere(0.055, color, 0.25, 0.24)
        root.add_child(spark)
        var angle := TAU * float(i) / 9.0
        var target := Vector3(cos(angle) * 0.68, 0.24 + float(i % 3) * 0.12, sin(angle) * 0.68)
        var tween := Motion.tween(spark)
        tween.set_parallel(true)
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(spark, "position", target, 0.32)
        tween.tween_property(spark, "scale", Vector3.ONE * 0.10, 0.34)
    root.get_tree().create_timer(0.44).timeout.connect(root.queue_free)


static func create_win_confetti(parent: Node3D, origin: Vector3 = Vector3(0, 0.6, 0)) -> void:
    var root := Node3D.new()
    root.name = "WinConfetti"
    parent.add_child(root)
    root.position = origin
    var colors: Array[Color] = [RED, BLUE, YELLOW, GREEN_ACCENT, ORANGE_ACCENT]
    for i in range(28):
        var piece := _box(Vector3(0.10, 0.04, 0.18), colors[i % colors.size()], 0.35)
        root.add_child(piece)
        var angle := TAU * float(i) / 28.0
        var radius := 1.6 + float(i % 4) * 0.24
        var target := Vector3(cos(angle) * radius, 1.1 + float(i % 5) * 0.22, sin(angle) * radius)
        var tween := Motion.tween(piece)
        tween.set_parallel(true)
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(piece, "position", target, 0.46)
        tween.tween_property(piece, "rotation", Vector3(angle * 1.3, angle * 0.7, angle * 1.8), 0.46)
        tween.chain().tween_property(piece, "position:y", 0.15, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.parallel().tween_property(piece, "scale", Vector3.ONE * 0.05, 0.40)
    root.get_tree().create_timer(1.05).timeout.connect(root.queue_free)


static func burst(parent: Node3D, world_position: Vector3, colour: Color, amount: int = 18, upward: float = 2.6) -> void:
    if parent == null or not is_instance_valid(parent):
        return
    var particles := CPUParticles3D.new()
    particles.name = "Burst"
    particles.emitting = false
    particles.one_shot = true
    particles.amount = amount
    particles.lifetime = 0.7
    particles.explosiveness = 1.0
    particles.position = world_position
    particles.direction = Vector3.UP
    particles.spread = 62.0
    particles.initial_velocity_min = upward * 0.6
    particles.initial_velocity_max = upward
    particles.gravity = Vector3(0, -7.0, 0)
    particles.scale_amount_min = 0.13
    particles.scale_amount_max = 0.26
    particles.color = colour

    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 6
    mesh.rings = 3
    particles.mesh = mesh
    particles.material_override = material(colour, 0.26, 0.42)

    parent.add_child(particles)
    particles.emitting = true
    parent.get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)


static func _create_reference_decor(parent: Node3D, occupied: Array) -> void:
    # Keep the middle clean like the reference. These 22 roots also preserve the
    # existing decoration-clearance test contract while using only our own forms.
    var tree_positions := [
        Vector3(-5.65, -0.12, -7.55), Vector3(5.55, -0.12, -7.15),
        Vector3(-5.55, -0.12, 7.45), Vector3(5.55, -0.12, 7.15),
    ]
    for p in tree_positions:
        if _clears(p, occupied):
            _add_decor(parent, _make_tree(p))

    var crate_positions := [
        Vector3(-5.15, -0.10, -4.55), Vector3(5.10, -0.10, -3.70),
        Vector3(-5.25, -0.10, 3.15), Vector3(5.05, -0.10, 4.10),
    ]
    for p in crate_positions:
        if _clears(p, occupied):
            _add_decor(parent, _make_crate(p))

    var barrier_positions := [Vector3(-4.75, -0.08, 1.00), Vector3(4.75, -0.08, 0.20)]
    for i in range(barrier_positions.size()):
        var p: Vector3 = barrier_positions[i]
        if _clears(p, occupied):
            var barrier := _make_barrier(p)
            barrier.rotation.y = -0.18 if i == 0 else 0.16
            _add_decor(parent, barrier)

    var flower_positions := [
        Vector3(-5.8, -0.10, -1.8), Vector3(-5.4, -0.10, -0.8),
        Vector3(-5.7, -0.10, 2.0), Vector3(-5.1, -0.10, 5.3),
        Vector3(5.7, -0.10, -2.1), Vector3(5.35, -0.10, -0.9),
        Vector3(5.75, -0.10, 2.4), Vector3(5.25, -0.10, 5.4),
        Vector3(-4.6, -0.10, -6.8), Vector3(4.6, -0.10, -6.5),
        Vector3(-4.7, -0.10, 6.8), Vector3(4.7, -0.10, 6.6),
    ]
    for i in range(flower_positions.size()):
        var p: Vector3 = flower_positions[i]
        if _clears(p, occupied):
            _add_decor(parent, _make_flower(p, i))


static func _make_tree(pos: Vector3) -> Node3D:
    var root := Node3D.new()
    root.position = pos
    var island := _cylinder(0.82, 0.045, Color("#B5CF8A"), 0.94)
    island.position.y = 0.03
    root.add_child(island)
    var trunk := _cylinder(0.10, 0.78, Color("#A77A58"), 0.82)
    trunk.position = Vector3(0.08, 0.41, 0)
    root.add_child(trunk)
    var crown_low := _sphere(0.42, Color("#7EAE69"), 0.86)
    crown_low.scale = Vector3(1.0, 0.86, 1.0)
    crown_low.position = Vector3(0.08, 0.82, 0)
    root.add_child(crown_low)
    var crown_top := _sphere(0.32, Color("#70A15F"), 0.84)
    crown_top.position = Vector3(0.02, 1.14, -0.03)
    root.add_child(crown_top)
    return root


static func _make_crate(pos: Vector3) -> Node3D:
    var root := Node3D.new()
    root.position = pos
    root.rotation.y = pos.x * 0.035
    var cube := _box(Vector3(0.72, 0.62, 0.72), Color("#D79C6A"), 0.78)
    cube.position.y = 0.31
    root.add_child(cube)
    var plank_color := Color("#BC7D4F")
    for y in [0.14, 0.48]:
        var plank := _box(Vector3(0.78, 0.07, 0.08), plank_color, 0.74)
        plank.position = Vector3(0, float(y), 0.38)
        root.add_child(plank)
    return root


static func _make_barrier(pos: Vector3) -> Node3D:
    var root := Node3D.new()
    root.position = pos
    for x in [-0.43, 0.43]:
        var post := _cylinder(0.055, 0.62, Color("#72787A"), 0.48, 0.14)
        post.position = Vector3(float(x), 0.31, 0)
        root.add_child(post)
    var beam := _box(Vector3(0.98, 0.16, 0.08), Color("#E5B445"), 0.46)
    beam.position.y = 0.48
    root.add_child(beam)
    for x in [-0.28, 0.0, 0.28]:
        var stripe := _box(Vector3(0.10, 0.17, 0.085), Color("#55595B"), 0.46)
        stripe.position = Vector3(float(x), 0.48, 0.005)
        stripe.rotation.z = -0.45
        root.add_child(stripe)
    return root


static func _make_flower(pos: Vector3, index: int) -> Node3D:
    var root := Node3D.new()
    root.position = pos
    var stem := _cylinder(0.018, 0.14, Color("#79A964"), 0.78)
    stem.position.y = 0.07
    root.add_child(stem)
    var colors: Array[Color] = [Color("#F18A96"), Color("#F4C85A"), Color("#8DB6E8")]
    var head := _sphere(0.055, colors[index % colors.size()], 0.58)
    head.position.y = 0.16
    root.add_child(head)
    return root


static func _clears(pos: Vector3, occupied: Array) -> bool:
    var flat := Vector2(pos.x, pos.z)
    for point in occupied:
        if flat.distance_to(point as Vector2) < DECOR_CLEARANCE:
            return false
    return true


static func _add_decor(parent: Node3D, node: Node3D) -> void:
    node.add_to_group(DECOR_GROUP)
    parent.add_child(node)


static func _box(size: Vector3, color: Color, roughness: float = 0.72, emission: float = 0.0, metallic: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = material(color, roughness, emission, metallic)
    return node


static func _sphere(radius: float, color: Color, roughness: float = 0.72, emission: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 20
    mesh.rings = 10
    node.mesh = mesh
    node.material_override = material(color, roughness, emission)
    return node


static func _cylinder(radius: float, height: float, color: Color, roughness: float = 0.72, emission: float = 0.0, metallic: float = 0.0, segments: int = 20) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = segments
    node.mesh = mesh
    node.material_override = material(color, roughness, emission, metallic)
    return node

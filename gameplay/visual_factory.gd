class_name VisualFactory
extends RefCounted

# Reference-video visual pass: warm full-bleed toy yard, dark chunky conveyors,
# glossy ball cargo and colour-coded destination machines. Gameplay remains
# deterministic; this file only changes what those rules look like.
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

# Environment-only CC0 props kept from the audited KayKit integration.
const KAYKIT_PALLET = preload("res://assets/vendor/kaykit_prototype_bits/Pallet_Large_CC0_Derived.obj")
const KAYKIT_BARREL = preload("res://assets/vendor/kaykit_prototype_bits/Barrel_A_CC0_Derived.obj")
const KAYKIT_LOADED_PALLET = preload("res://assets/vendor/kaykit_prototype_bits/Pallet_Loaded_CC0_Derived.obj")

const DECOR_GROUP := "decoration"
const DECOR_CLEARANCE := 1.8

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

    # The reference does not read as a white board floating in space. The play
    # surface and background are the same warm material, so the level fills the
    # phone instead of looking like a prototype table.
    var ground := _box(Vector3(11.6, 0.22, 16.8), FLOOR_COLOR, 0.92)
    ground.position = Vector3(0, -0.26, 0)
    ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(ground)

    # A faint inset gives contact shadows something to sit on without drawing a
    # visible rectangular frame around the level.
    var inset := _box(Vector3(10.9, 0.035, 16.1), FLOOR_INSET, 0.98)
    inset.position = Vector3(0, -0.135, 0)
    inset.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(inset)

    _create_corner_scenery(root)
    _create_decor(root, occupied)
    return root


static func create_track(parent: Node3D, from_pos: Vector3, to_pos: Vector3) -> Node3D:
    var root := Node3D.new()
    root.name = "Conveyor"
    parent.add_child(root)

    var midpoint := (from_pos + to_pos) * 0.5
    var length := from_pos.distance_to(to_pos)
    var angle := atan2(to_pos.x - from_pos.x, to_pos.z - from_pos.z)

    # Dark rubber belt with a lighter inset and metal side rails, matching the
    # reference's chunky toy-conveyor silhouette.
    var base := _box(Vector3(0.90, 0.16, length + 0.10), MACHINE_DARK, 0.64)
    base.position = midpoint + Vector3(0, 0.025, 0)
    base.rotation.y = angle
    root.add_child(base)

    var belt := _box(Vector3(0.66, 0.105, maxf(0.12, length - 0.03)), BELT_COLOR, 0.66)
    belt.position = midpoint + Vector3(0, 0.145, 0)
    belt.rotation.y = angle
    root.add_child(belt)

    for side in [-0.43, 0.43]:
        var rail := _box(Vector3(0.075, 0.15, maxf(0.12, length + 0.06)), RAIL_COLOR, 0.32, 0.0, 0.18)
        rail.position = midpoint + Vector3(0, 0.235, 0)
        rail.rotation.y = angle
        rail.position += Vector3(float(side), 0, 0).rotated(Vector3.UP, angle)
        root.add_child(rail)

    var slat_count := maxi(2, int(floor(length / 0.44)))
    for i in range(1, slat_count):
        var t := float(i) / float(slat_count)
        var p := from_pos.lerp(to_pos, t)
        var slat := _box(Vector3(0.56, 0.025, 0.045), BELT_SLAT, 0.62)
        slat.position = p + Vector3(0, 0.205, 0)
        slat.rotation.y = angle
        root.add_child(slat)

    return root


static func create_kind_visual(kind: String, scale_value: float = 0.38) -> Node3D:
    var root := Node3D.new()
    root.name = "CargoBall_%s" % kind

    # The reference uses one instantly readable toy: glossy coloured balls.
    var ball := _sphere(scale_value, kind_color(kind), 0.26)
    ball.position.y = 0.02
    root.add_child(ball)

    # Small white top glyph keeps the original colour+shape accessibility
    # contract without changing the ball silhouette at gameplay distance.
    var glyph: MeshInstance3D
    match kind:
        "blue":
            glyph = _box(Vector3(scale_value * 0.34, scale_value * 0.045, scale_value * 0.34), Color(1, 1, 1, 0.88), 0.35)
        "yellow":
            glyph = _cylinder(scale_value * 0.22, scale_value * 0.05, Color(1, 1, 1, 0.88), 0.35, 0.0, 0.0, 3)
        _:
            glyph = _cylinder(scale_value * 0.18, scale_value * 0.05, Color(1, 1, 1, 0.88), 0.35)
    glyph.position = Vector3(0, scale_value * 0.93, 0)
    root.add_child(glyph)

    var shine := _sphere(scale_value * 0.105, Color(1, 1, 1, 0.72), 0.18)
    shine.position = Vector3(-scale_value * 0.24, scale_value * 0.26, -scale_value * 0.20)
    root.add_child(shine)
    return root


static func create_source_shell(parent: Node3D) -> Node3D:
    var root := Node3D.new()
    root.name = "SourceShell"
    parent.add_child(root)

    var body := _rounded_machine_body(Vector3(1.45, 0.92, 1.36), BLUE, 0.52)
    body.position.y = 0.43
    root.add_child(body)

    # Keep this as child index 1: SourceActor intentionally reads the launch
    # ring from the second child for its idle pulse.
    var ring := _cylinder(0.43, 0.10, Color("#D9DEE0"), 0.30, 0.0, 0.18)
    ring.position.y = 0.98
    root.add_child(ring)

    var well := _cylinder(0.29, 0.07, MACHINE_DARK, 0.48)
    well.position.y = 1.04
    root.add_child(well)

    var mouth := _box(Vector3(0.72, 0.40, 0.13), MACHINE_DARK, 0.50)
    mouth.position = Vector3(0, 0.42, 0.68)
    root.add_child(mouth)

    var lever := _cylinder(0.055, 0.50, Color("#66727A"), 0.36, 0.0, 0.20)
    lever.position = Vector3(0.70, 0.72, 0.0)
    root.add_child(lever)
    var knob := _sphere(0.11, BLUE, 0.24)
    knob.position = Vector3(0.70, 1.00, 0.0)
    root.add_child(knob)
    return root


static func create_receiver_shell(parent: Node3D, kind: String) -> Dictionary:
    var root := Node3D.new()
    root.name = "ReceiverShell_%s" % kind
    parent.add_child(root)

    var colour := kind_color(kind)
    var base := _box(Vector3(1.62, 0.16, 1.52), Color("#565C60"), 0.62)
    base.position.y = 0.04
    root.add_child(base)

    var body := _rounded_machine_body(Vector3(1.46, 0.94, 1.34), colour, 0.48)
    body.position.y = 0.52
    root.add_child(body)

    var mouth := _box(Vector3(0.80, 0.42, 0.14), Color("#34373A"), 0.48)
    mouth.position = Vector3(0, 0.43, 0.72)
    root.add_child(mouth)

    # Coloured output tongue and white chevrons are one of the strongest visual
    # anchors in the reference video.
    var tongue := _box(Vector3(0.74, 0.075, 0.78), colour, 0.50)
    tongue.position = Vector3(0, 0.09, 1.03)
    root.add_child(tongue)
    _create_chevron(root, 0.92)
    _create_chevron(root, 1.13)

    var label := Label3D.new()
    label.text = kind.to_upper()
    label.font_size = 72
    label.pixel_size = 0.0042
    label.modulate = Color.WHITE
    label.outline_size = 8
    label.outline_modulate = Color(0, 0, 0, 0.14)
    label.position = Vector3(0, 0.94, 0.70)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    root.add_child(label)

    var badge_anchor := Node3D.new()
    badge_anchor.position = Vector3(0, 1.13, 0)
    root.add_child(badge_anchor)
    var cap := _cylinder(0.23, 0.07, Color("#E4E1D7"), 0.28, 0.0, 0.12)
    badge_anchor.add_child(cap)
    var cap_dot := _sphere(0.13, colour, 0.24)
    cap_dot.position.y = 0.075
    badge_anchor.add_child(cap_dot)

    var lever := _cylinder(0.05, 0.50, Color("#6C7276"), 0.38, 0.0, 0.18)
    lever.position = Vector3(0.72, 0.72, 0.10)
    root.add_child(lever)
    var lamp := _sphere(0.11, colour, 0.24, 0.22)
    lamp.position = Vector3(0.72, 1.00, 0.10)
    root.add_child(lamp)

    return {
        "root": root,
        "mouth": mouth,
        "badge_anchor": badge_anchor,
        "lamp": lamp,
    }


static func create_buffer_chute(parent: Node3D) -> Node3D:
    var root := Node3D.new()
    root.name = "BufferChute"
    root.position = Vector3(4.25, 0.0, -3.9)
    parent.add_child(root)

    var tray := _box(Vector3(1.10, 0.14, 1.55), Color("#A9A9A3"), 0.62)
    tray.position.y = 0.06
    root.add_child(tray)
    var inner := _box(Vector3(0.82, 0.08, 1.30), Color("#5A5A57"), 0.68)
    inner.position.y = 0.16
    root.add_child(inner)
    return root


static func create_spark_burst(parent: Node3D, origin: Vector3, color: Color) -> void:
    var root := Node3D.new()
    root.name = "SparkBurst"
    parent.add_child(root)
    root.global_position = origin
    for i in range(9):
        var spark := _sphere(0.055, color, 0.28, 0.30)
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
    for i in range(24):
        var piece := _box(Vector3(0.10, 0.04, 0.18), colors[i % colors.size()], 0.38)
        root.add_child(piece)
        var angle := TAU * float(i) / 24.0
        var radius := 1.5 + float(i % 4) * 0.24
        var target := Vector3(cos(angle) * radius, 1.0 + float(i % 5) * 0.22, sin(angle) * radius)
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
    particles.material_override = material(colour, 0.28, 0.48)

    parent.add_child(particles)
    particles.emitting = true
    parent.get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)


static func _create_chevron(parent: Node3D, z_value: float) -> void:
    var left := _box(Vector3(0.10, 0.035, 0.32), Color.WHITE, 0.48)
    left.position = Vector3(-0.10, 0.145, z_value)
    left.rotation.y = -PI * 0.25
    parent.add_child(left)
    var right := _box(Vector3(0.10, 0.035, 0.32), Color.WHITE, 0.48)
    right.position = Vector3(0.10, 0.145, z_value)
    right.rotation.y = PI * 0.25
    parent.add_child(right)


# A rounded-looking toy block made from a central box and four vertical corner
# cylinders. It stays cheap on mobile but removes the hard prototype-box read.
static func _rounded_machine_body(size: Vector3, colour: Color, roughness: float) -> Node3D:
    var root := Node3D.new()
    var radius := minf(size.x, size.z) * 0.16

    var centre := _box(Vector3(size.x - radius * 1.35, size.y, size.z), colour, roughness)
    root.add_child(centre)
    var cross := _box(Vector3(size.x, size.y, size.z - radius * 1.35), colour, roughness)
    root.add_child(cross)

    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var corner := _cylinder(radius, size.y, colour, roughness)
            corner.position = Vector3(
                float(sx) * (size.x * 0.5 - radius),
                0,
                float(sz) * (size.z * 0.5 - radius)
            )
            root.add_child(corner)
    return root


static func _create_corner_scenery(parent: Node3D) -> void:
    var green := Color("#91B970")
    var trunk := Color("#9C7556")
    var foliage := Color("#6E9D63")
    var corners := [
        Vector3(-5.15, -0.12, -7.35), Vector3(5.15, -0.12, -7.35),
        Vector3(-5.15, -0.12, 7.35), Vector3(5.15, -0.12, 7.35),
    ]
    for p in corners:
        var island := _cylinder(1.35, 0.06, green, 0.92)
        island.position = p
        parent.add_child(island)
        var stem := _cylinder(0.11, 0.82, trunk, 0.82)
        stem.position = p + Vector3(0.22 if p.x < 0 else -0.22, 0.42, 0.0)
        parent.add_child(stem)
        var crown := _sphere(0.48, foliage, 0.84)
        crown.scale = Vector3(0.92, 1.18, 0.92)
        crown.position = stem.position + Vector3(0, 0.58, 0)
        parent.add_child(crown)


# The decor layout keeps the existing clearance contract: 22 grouped nodes are
# present on every shipped level and a runtime filter drops any future overlap.
const DECOR_VENDOR: Array = [
    {"mesh": "loaded", "pos": Vector3(-4.12, -0.12, -3.25), "rot": 0.12, "scale": 0.215},
    {"mesh": "loaded", "pos": Vector3(4.12, -0.12, 0.55), "rot": 3.2216, "scale": 0.195},
    {"mesh": "pallet", "pos": Vector3(4.12, -0.12, -3.25), "rot": -0.08, "scale": 0.205},
    {"mesh": "pallet", "pos": Vector3(-4.12, -0.12, 0.55), "rot": 3.2416, "scale": 0.205},
    {"mesh": "barrel", "pos": Vector3(-4.12, 0.33, -1.95), "rot": 0.0, "scale": 0.82},
    {"mesh": "barrel", "pos": Vector3(-4.12, 0.33, -1.20), "rot": 0.4, "scale": 0.82},
    {"mesh": "barrel", "pos": Vector3(4.12, 0.33, -1.95), "rot": 0.0, "scale": 0.82},
    {"mesh": "barrel", "pos": Vector3(4.12, 0.33, -1.20), "rot": 0.4, "scale": 0.82},
]


static func _create_decor(parent: Node3D, occupied: Array) -> void:
    var pallet_tint := Color("#C99B72")
    var cargo_tint := Color("#D3B18C")
    var barrel_tint := Color("#8EA9A9")

    for entry in DECOR_VENDOR:
        var spec: Dictionary = entry
        var pos: Vector3 = spec["pos"]
        if not _clears(pos, occupied):
            continue
        var resource: Resource = KAYKIT_BARREL
        var tint := barrel_tint
        match String(spec["mesh"]):
            "loaded":
                resource = KAYKIT_LOADED_PALLET
                tint = cargo_tint
            "pallet":
                resource = KAYKIT_PALLET
                tint = pallet_tint
        var prop := _vendor_mesh(resource, tint, Vector3.ONE * float(spec["scale"]))
        prop.position = pos
        prop.rotation.y = float(spec["rot"])
        _add_decor(parent, prop)

    for x in [-3.72, 3.72]:
        var tank_pos := Vector3(float(x), 0.42, 0.1)
        if not _clears(tank_pos, occupied):
            continue
        var tank := _cylinder(0.34, 1.12, Color("#AAB6B7"), 0.70, 0.0, 0.04)
        tank.position = tank_pos
        _add_decor(parent, tank)
        var tank_cap := _cylinder(0.20, 0.12, GREEN_ACCENT if x < 0 else ORANGE_ACCENT, 0.40, 0.14)
        tank_cap.position = Vector3(float(x), 1.02, 0.1)
        _add_decor(parent, tank_cap)

    for x in [-3.45, 3.45]:
        var inner := float(x + (0.72 if x < 0 else -0.72))
        var post_a_pos := Vector3(float(x), 0.16, 6.35)
        var post_b_pos := Vector3(inner, 0.16, 6.35)
        if not _clears(post_a_pos, occupied) or not _clears(post_b_pos, occupied):
            continue
        var post_a := _box(Vector3(0.12, 0.52, 0.12), MACHINE_DARK, 0.68)
        post_a.position = post_a_pos
        _add_decor(parent, post_a)
        var post_b := _box(Vector3(0.12, 0.52, 0.12), MACHINE_DARK, 0.68)
        post_b.position = post_b_pos
        _add_decor(parent, post_b)
        var bar := _box(Vector3(0.82, 0.12, 0.12), YELLOW, 0.50)
        bar.position = Vector3(float(x + (0.36 if x < 0 else -0.36)), 0.34, 6.35)
        _add_decor(parent, bar)

    for x in [-4.12, 4.12]:
        var pole_pos := Vector3(float(x), 0.34, 6.35)
        if not _clears(pole_pos, occupied):
            continue
        var pole := _cylinder(0.07, 0.94, Color("#6B7478"), 0.58, 0.0, 0.12)
        pole.position = pole_pos
        _add_decor(parent, pole)
        var lamp := _sphere(0.13, GREEN_ACCENT, 0.28, 0.30)
        lamp.position = Vector3(float(x), 0.88, 6.35)
        _add_decor(parent, lamp)


static func _clears(pos: Vector3, occupied: Array) -> bool:
    var flat := Vector2(pos.x, pos.z)
    for point in occupied:
        if flat.distance_to(point as Vector2) < DECOR_CLEARANCE:
            return false
    return true


static func _add_decor(parent: Node3D, node: Node3D) -> void:
    node.add_to_group(DECOR_GROUP)
    parent.add_child(node)


static func _vendor_mesh(resource: Resource, tint: Color, scale_value: Vector3) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = "CC0EnvironmentProp"
    if resource is Mesh:
        node.mesh = resource as Mesh
    node.material_override = material(tint, 0.70)
    node.scale = scale_value
    return node


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

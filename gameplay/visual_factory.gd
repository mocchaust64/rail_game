class_name VisualFactory
extends RefCounted

# Colours come from a resource so they can be edited without touching code.
# The names below stay as aliases so call sites read the same as before.
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

# Curated CC0 environment dressing. Gameplay-critical assets remain original.
const KAYKIT_PALLET = preload("res://assets/vendor/kaykit_prototype_bits/Pallet_Large_CC0_Derived.obj")
const KAYKIT_BARREL = preload("res://assets/vendor/kaykit_prototype_bits/Barrel_A_CC0_Derived.obj")
const KAYKIT_LOADED_PALLET = preload("res://assets/vendor/kaykit_prototype_bits/Pallet_Loaded_CC0_Derived.obj")

# CC0 gameplay geometry. These packs ship a single texture atlas each, which is
# what gives the pieces surface detail the procedural primitives never had.
# Chosen so each model's own atlas colour already is the gameplay colour. Tinting
# a coloured texture multiplies, it does not replace: a blue model tinted yellow
# came out green, which broke the one thing cargo colour has to do.
const CARGO_MODELS := {
    "red": "res://assets/vendor/kaykit_prototype_bits/gltf/Barrel_A.gltf",
    "blue": "res://assets/vendor/kaykit_space_base_bits/gltf/containers_C.gltf",
    "yellow": "res://assets/vendor/kaykit_prototype_bits/gltf/Coin_A.gltf",
}
const RECEIVER_MODEL := "res://assets/vendor/kaykit_space_base_bits/gltf/cargodepot_A.gltf"
const SOURCE_MODEL := "res://assets/vendor/kaykit_space_base_bits/gltf/basemodule_A.gltf"

static var _material_cache: Dictionary = {}

static func material(color: Color, roughness: float = 0.72, emission: float = 0.0, metallic: float = 0.0) -> StandardMaterial3D:
    var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, emission, metallic]
    if _material_cache.has(key):
        return _material_cache[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    mat.metallic = metallic
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = emission
    _material_cache[key] = mat
    return mat

# The two packs are authored at very different scales, so models are measured
# and fitted to a target size rather than each one carrying a magic multiplier.
static func vendor_scene(path: String, target_size: float, tint: Color = Color(0, 0, 0, 0)) -> Node3D:
    var packed: Resource = load(path)
    if packed == null or not (packed is PackedScene):
        push_error("vendor model missing: %s" % path)
        return Node3D.new()
    var instance := (packed as PackedScene).instantiate() as Node3D
    var bounds := _combined_aabb(instance)
    var largest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
    if largest > 0.0001:
        instance.scale = Vector3.ONE * (target_size / largest)
    # Sit the model on the origin plane so callers position by its base.
    instance.position.y = -bounds.position.y * instance.scale.y
    if tint.a > 0.0:
        _tint(instance, tint)
    return instance


static func _combined_aabb(node: Node) -> AABB:
    var box := AABB()
    var seeded := false
    for mesh_node in _mesh_children(node):
        var local := mesh_node.get_aabb()
        if not seeded:
            box = local
            seeded = true
        else:
            box = box.merge(local)
    return box


static func _mesh_children(node: Node) -> Array[MeshInstance3D]:
    var found: Array[MeshInstance3D] = []
    if node is MeshInstance3D:
        found.append(node as MeshInstance3D)
    for child in node.get_children():
        found.append_array(_mesh_children(child))
    return found


# Multiplies the pack texture by a colour instead of replacing the material, so
# the cargo reads in the game's palette while keeping its surface detail.
static func _tint(node: Node, colour: Color) -> void:
    for mesh_node in _mesh_children(node):
        var source := mesh_node.get_active_material(0)
        var tinted: StandardMaterial3D
        if source is StandardMaterial3D:
            tinted = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
        else:
            tinted = StandardMaterial3D.new()
        tinted.albedo_color = colour
        mesh_node.material_override = tinted


static func kind_color(kind: String) -> Color:
    return palette.cargo_colour(kind)


static func create_floor(parent: Node3D, occupied: Array = []) -> Node3D:
    var root := Node3D.new()
    root.name = "ToyFactoryBoard"
    parent.add_child(root)

    var floor := _box(Vector3(9.2, 0.28, 14.1), FLOOR_COLOR, 0.96)
    floor.position = Vector3(0, -0.34, 0)
    floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(floor)

    var inset := _box(Vector3(8.72, 0.05, 13.62), FLOOR_INSET, 0.98)
    inset.position = Vector3(0, -0.17, 0)
    inset.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(inset)

    # Soft tile seams make the board read like a manufactured toy table without textures.
    for x in [-2.9, 0.0, 2.9]:
        var seam := _box(Vector3(0.025, 0.012, 13.1), FLOOR_EDGE, 1.0)
        seam.position = Vector3(float(x), -0.135, 0)
        seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(seam)
    for z in [-4.5, 0.0, 4.5]:
        var seam := _box(Vector3(8.3, 0.012, 0.025), FLOOR_EDGE, 1.0)
        seam.position = Vector3(0, -0.135, float(z))
        seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(seam)

    # Raised edge rails keep the play space readable on a phone.
    for x in [-4.38, 4.38]:
        var rail := _box(Vector3(0.18, 0.38, 14.1), RAIL_COLOR, 0.9)
        rail.position = Vector3(float(x), 0.02, 0)
        root.add_child(rail)
    for z in [-6.95, 6.95]:
        var rail := _box(Vector3(9.0, 0.38, 0.18), RAIL_COLOR, 0.9)
        rail.position = Vector3(0, 0.02, float(z))
        root.add_child(rail)

    _create_decor(root, occupied)
    return root

static func create_track(parent: Node3D, from_pos: Vector3, to_pos: Vector3) -> Node3D:
    var root := Node3D.new()
    root.name = "Track"
    parent.add_child(root)

    var midpoint := (from_pos + to_pos) * 0.5
    var length := from_pos.distance_to(to_pos)
    var angle := atan2(to_pos.x - from_pos.x, to_pos.z - from_pos.z)

    var base := _box(Vector3(0.86, 0.20, length + 0.08), BELT_COLOR, 0.80)
    base.position = midpoint + Vector3(0, 0.03, 0)
    base.rotation.y = angle
    root.add_child(base)

    var inner := _box(Vector3(0.60, 0.08, max(0.10, length - 0.10)), BELT_INNER, 0.88)
    inner.position = midpoint + Vector3(0, 0.17, 0)
    inner.rotation.y = angle
    root.add_child(inner)

    # Rails and transverse slats make the path direction visible without a texture.
    for side in [-0.39, 0.39]:
        var rail := _box(Vector3(0.075, 0.16, max(0.10, length - 0.04)), RAIL_COLOR, 0.82)
        rail.position = midpoint + Vector3(0, 0.22, 0)
        rail.rotation.y = angle
        var local_side := Vector3(float(side), 0, 0).rotated(Vector3.UP, angle)
        rail.position += local_side
        root.add_child(rail)

    var slat_count := maxi(1, int(floor(length / 0.52)))
    for i in range(1, slat_count):
        var t := float(i) / float(slat_count)
        var slat_pos := from_pos.lerp(to_pos, t)
        var slat := _box(Vector3(0.53, 0.035, 0.055), BELT_SLAT, 0.9)
        slat.position = slat_pos + Vector3(0, 0.225, 0)
        slat.rotation.y = angle
        root.add_child(slat)

    # One small support keeps floating-looking long conveyors grounded.
    if length > 2.2:
        var support := _cylinder(0.14, 0.46, MACHINE_DARK, 0.85)
        support.position = midpoint + Vector3(0, -0.08, 0)
        root.add_child(support)

    return root

static func create_kind_visual(kind: String, scale_value: float = 0.38) -> Node3D:
    var root := Node3D.new()
    root.name = "CargoVisual_%s" % kind
    var path: String = CARGO_MODELS.get(kind, CARGO_MODELS["red"])
    # No tint: these models already carry the right colour in the pack atlas.
    var model := vendor_scene(path, scale_value * 2.1)
    model.position.y -= scale_value
    root.add_child(model)
    return root


static func create_source_shell(parent: Node3D) -> Node3D:
    var root := Node3D.new()
    root.name = "SourceShell"
    parent.add_child(root)

    var pad := _cylinder(0.72, 0.22, MACHINE_DARK, 0.80)
    pad.position.y = 0.08
    root.add_child(pad)
    var ring := _cylinder(0.55, 0.18, GREEN_ACCENT, 0.48, 0.08)
    ring.position.y = 0.25
    root.add_child(ring)
    var hopper := vendor_scene(SOURCE_MODEL, 1.30, MACHINE_BODY)
    hopper.position.y = 0.16
    root.add_child(hopper)
    return root

static func create_receiver_shell(parent: Node3D, kind: String) -> Dictionary:
    var root := Node3D.new()
    root.name = "ReceiverShell_%s" % kind
    parent.add_child(root)

    # Deliberately not a CC0 model: the receiver has to read as its cargo colour,
    # and every candidate carries baked colours of its own that fight that.
    var body := _box(Vector3(1.55, 0.98, 1.55), MACHINE_BODY, 0.76)
    body.position.y = 0.42
    root.add_child(body)

    var base := _box(Vector3(1.72, 0.20, 1.72), MACHINE_DARK, 0.85)
    base.position.y = -0.03
    root.add_child(base)

    var mouth := _box(Vector3(1.04, 0.18, 1.02), kind_color(kind), 0.42, 0.10)
    mouth.position = Vector3(0, 0.96, 0)
    root.add_child(mouth)

    var badge_anchor := Node3D.new()
    badge_anchor.position = Vector3(0, 1.48, 0)
    root.add_child(badge_anchor)
    var badge := create_kind_visual(kind, 0.30)
    badge_anchor.add_child(badge)

    var lamp := _cylinder(0.13, 0.22, kind_color(kind), 0.35, 0.65)
    lamp.position = Vector3(0.58, 1.04, -0.48)
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
    root.position = Vector3(3.72, 0.0, -3.45)
    parent.add_child(root)

    var base := _box(Vector3(1.10, 0.42, 1.10), MACHINE_DARK, 0.82)
    base.position.y = 0.12
    root.add_child(base)
    var tray := _box(Vector3(0.84, 0.13, 0.84), ORANGE_ACCENT, 0.44, 0.10)
    tray.position.y = 0.42
    root.add_child(tray)
    var lip := _box(Vector3(0.92, 0.26, 0.12), MACHINE_BODY, 0.78)
    lip.position = Vector3(0, 0.58, 0.38)
    root.add_child(lip)
    return root

static func create_spark_burst(parent: Node3D, origin: Vector3, color: Color) -> void:
    var root := Node3D.new()
    root.name = "SparkBurst"
    parent.add_child(root)
    root.global_position = origin
    var count := 8
    for i in range(count):
        var spark := _sphere(0.055, color, 0.34, 0.35)
        root.add_child(spark)
        var angle := TAU * float(i) / float(count)
        var target := Vector3(cos(angle) * 0.62, 0.20 + float(i % 3) * 0.12, sin(angle) * 0.62)
        var tween := Motion.tween(spark)
        tween.set_parallel(true)
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(spark, "position", target, 0.32)
        tween.tween_property(spark, "scale", Vector3.ONE * 0.12, 0.34)
    root.get_tree().create_timer(0.42).timeout.connect(root.queue_free)

static func create_win_confetti(parent: Node3D, origin: Vector3 = Vector3(0, 0.6, 0)) -> void:
    var root := Node3D.new()
    root.name = "WinConfetti"
    parent.add_child(root)
    root.position = origin
    var colors: Array[Color] = [RED, BLUE, YELLOW, GREEN_ACCENT, ORANGE_ACCENT]
    for i in range(20):
        var piece := _box(Vector3(0.10, 0.04, 0.18), colors[i % colors.size()], 0.44)
        root.add_child(piece)
        var angle := TAU * float(i) / 20.0
        var radius := 1.4 + float(i % 4) * 0.22
        var target := Vector3(cos(angle) * radius, 1.0 + float(i % 5) * 0.23, sin(angle) * radius)
        var tween := Motion.tween(piece)
        tween.set_parallel(true)
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(piece, "position", target, 0.46)
        tween.tween_property(piece, "rotation", Vector3(angle * 1.3, angle * 0.7, angle * 1.8), 0.46)
        tween.chain().tween_property(piece, "position:y", 0.15, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.parallel().tween_property(piece, "scale", Vector3.ONE * 0.05, 0.40)
    root.get_tree().create_timer(1.05).timeout.connect(root.queue_free)

# Every decoration node joins this group so the clearance check can measure
# what actually ends up in the scene, rather than guessing from node names.
const DECOR_GROUP := "decoration"

# Minimum distance from any receiver or source, in board units. Derived from the
# geometry: the receiver body is a 1.55 box, so 0.78 half extent, plus roughly
# 0.5 for the widest prop, plus margin. Retune here if actor sizes change.
const DECOR_CLEARANCE := 1.8

# Decoration lives in the two outer side lanes and the back corners. Those bands
# were chosen because they clear every actor position across all ten levels; the
# runtime filter below is the safety net for levels added later.
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


static func _add_decor(parent: Node3D, node: Node3D) -> void:
    node.add_to_group(DECOR_GROUP)
    parent.add_child(node)


static func _clears(pos: Vector3, occupied: Array) -> bool:
    var flat := Vector2(pos.x, pos.z)
    for point in occupied:
        if flat.distance_to(point as Vector2) < DECOR_CLEARANCE:
            return false
    return true


# occupied is an Array of Vector2 giving receiver and source positions in board XZ.
static func _create_decor(parent: Node3D, occupied: Array) -> void:
    # All decoration lives outside the actionable center so it never competes with
    # gameplay. CC0 vendor geometry is deliberately limited to environmental dressing.
    var pallet_tint := Color("#A97F62")
    var cargo_tint := Color("#B7C6CE")
    var barrel_tint := Color("#91A9B5")

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
        var scale_value: float = spec["scale"]
        var prop := _vendor_mesh(resource, tint, Vector3.ONE * scale_value)
        prop.position = pos
        prop.rotation.y = float(spec["rot"])
        _add_decor(parent, prop)

    # Custom tanks complement the imported props without multiplying external dependencies.
    for x in [-3.72, 3.72]:
        var tank_pos := Vector3(float(x), 0.42, 0.1)
        if not _clears(tank_pos, occupied):
            continue
        var tank := _cylinder(0.34, 1.12, Color("#AEBFC8"), 0.70, 0.0, 0.08)
        tank.position = tank_pos
        _add_decor(parent, tank)
        var tank_cap := _cylinder(0.20, 0.12, GREEN_ACCENT if x < 0 else ORANGE_ACCENT, 0.44, 0.22)
        tank_cap.position = Vector3(float(x), 1.02, 0.1)
        _add_decor(parent, tank_cap)

    # Compact safety barriers frame the back of the workspace, behind every receiver.
    for x in [-3.45, 3.45]:
        var inner := float(x + (0.72 if x < 0 else -0.72))
        var post_a_pos := Vector3(float(x), 0.16, 6.35)
        var post_b_pos := Vector3(inner, 0.16, 6.35)
        if not _clears(post_a_pos, occupied) or not _clears(post_b_pos, occupied):
            continue
        var post_a := _box(Vector3(0.12, 0.52, 0.12), MACHINE_DARK, 0.80)
        post_a.position = post_a_pos
        _add_decor(parent, post_a)
        var post_b := _box(Vector3(0.12, 0.52, 0.12), MACHINE_DARK, 0.80)
        post_b.position = post_b_pos
        _add_decor(parent, post_b)
        var bar := _box(Vector3(0.82, 0.12, 0.12), YELLOW, 0.62)
        bar.position = Vector3(float(x + (0.36 if x < 0 else -0.36)), 0.34, 6.35)
        _add_decor(parent, bar)

    # Corner status beacons provide subtle animation targets for the eye.
    for x in [-4.12, 4.12]:
        var pole_pos := Vector3(float(x), 0.34, 6.35)
        if not _clears(pole_pos, occupied):
            continue
        var pole := _cylinder(0.07, 0.94, MACHINE_DARK, 0.8)
        pole.position = pole_pos
        _add_decor(parent, pole)
        var lamp := _sphere(0.13, GREEN_ACCENT, 0.35, 0.55)
        lamp.position = Vector3(float(x), 0.88, 6.35)
        _add_decor(parent, lamp)


static func _vendor_mesh(resource: Resource, tint: Color, scale_value: Vector3) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = "CC0EnvironmentProp"
    if resource is Mesh:
        node.mesh = resource as Mesh
    node.material_override = material(tint, 0.68, 0.0, 0.02)
    node.scale = scale_value
    return node

static func _box(size: Vector3, color: Color, roughness: float = 0.72, emission: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = material(color, roughness, emission)
    return node

static func _sphere(radius: float, color: Color, roughness: float = 0.72, emission: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 16
    mesh.rings = 8
    node.mesh = mesh
    node.material_override = material(color, roughness, emission)
    return node

static func _cylinder(radius: float, height: float, color: Color, roughness: float = 0.72, emission: float = 0.0, metallic: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 18
    node.mesh = mesh
    node.material_override = material(color, roughness, emission, metallic)
    return node


# One-shot particle burst. CPUParticles3D rather than GPUParticles3D: the bursts
# are small, this behaves identically on every mobile GPU, and it needs no
# process material to be authored.
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
    particles.material_override = material(colour, 0.35, 0.55)

    parent.add_child(particles)
    particles.emitting = true
    # Freed by its own lifetime rather than by the caller remembering to.
    parent.get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)

class_name VisualFactory
extends RefCounted

const FLOOR_COLOR := Color("#DDE8EC")
const FLOOR_EDGE := Color("#C2D2D9")
const BELT_COLOR := Color("#28384C")
const BELT_INNER := Color("#51677C")
const BELT_SLAT := Color("#6E8294")
const RAIL_COLOR := Color("#E9F0F3")
const MACHINE_BODY := Color("#F7F9FB")
const MACHINE_DARK := Color("#26384C")
const RED := Color("#F45B69")
const BLUE := Color("#4F8EF7")
const YELLOW := Color("#F4C542")
const GREEN_ACCENT := Color("#59D3A5")
const ORANGE_ACCENT := Color("#FF9B62")

# Curated CC0 environment dressing. Gameplay-critical assets remain original.
const KAYKIT_PALLET = preload("res://assets/vendor/kaykit_prototype_bits/Pallet_Large_CC0_Derived.obj")
const KAYKIT_BARREL = preload("res://assets/vendor/kaykit_prototype_bits/Barrel_A_CC0_Derived.obj")
const KAYKIT_LOADED_PALLET = preload("res://assets/vendor/kaykit_prototype_bits/Pallet_Loaded_CC0_Derived.obj")

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

static func kind_color(kind: String) -> Color:
    match kind:
        "red": return RED
        "blue": return BLUE
        "yellow": return YELLOW
        _: return Color.WHITE

static func create_floor(parent: Node3D) -> Node3D:
    var root := Node3D.new()
    root.name = "ToyFactoryBoard"
    parent.add_child(root)

    var floor := _box(Vector3(9.2, 0.28, 14.1), FLOOR_COLOR, 0.96)
    floor.position = Vector3(0, -0.34, 0)
    floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(floor)

    var inset := _box(Vector3(8.72, 0.05, 13.62), Color("#EAF1F4"), 0.98)
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

    _create_decor(root)
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
    var visual := MeshInstance3D.new()
    match kind:
        "red":
            var sphere := SphereMesh.new()
            sphere.radius = scale_value
            sphere.height = scale_value * 2.0
            sphere.radial_segments = 20
            sphere.rings = 10
            visual.mesh = sphere
        "blue":
            var cube := BoxMesh.new()
            cube.size = Vector3.ONE * scale_value * 1.60
            visual.mesh = cube
        "yellow":
            var prism := CylinderMesh.new()
            prism.radial_segments = 3
            prism.top_radius = scale_value * 0.98
            prism.bottom_radius = scale_value * 0.98
            prism.height = scale_value * 1.62
            visual.mesh = prism
        _:
            var sphere := SphereMesh.new()
            sphere.radius = scale_value
            sphere.height = scale_value * 2.0
            visual.mesh = sphere
    visual.material_override = material(kind_color(kind), 0.38, 0.04)
    root.add_child(visual)

    # A tiny white cap gives the procedural pieces a premium toy-like highlight.
    var highlight := MeshInstance3D.new()
    var hmesh := SphereMesh.new()
    hmesh.radius = scale_value * 0.13
    hmesh.height = scale_value * 0.26
    hmesh.radial_segments = 12
    hmesh.rings = 6
    highlight.mesh = hmesh
    highlight.material_override = material(Color("#FFFFFF"), 0.30, 0.05)
    highlight.position = Vector3(-scale_value * 0.20, scale_value * 0.34, -scale_value * 0.16)
    root.add_child(highlight)
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
    var hopper := _cylinder(0.46, 0.52, MACHINE_BODY, 0.76)
    hopper.position.y = 0.52
    root.add_child(hopper)
    var cap := _cylinder(0.34, 0.10, MACHINE_DARK, 0.75)
    cap.position.y = 0.82
    root.add_child(cap)
    return root

static func create_receiver_shell(parent: Node3D, kind: String) -> Dictionary:
    var root := Node3D.new()
    root.name = "ReceiverShell_%s" % kind
    parent.add_child(root)

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
        var tween := spark.create_tween()
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
        var tween := piece.create_tween()
        tween.set_parallel(true)
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(piece, "position", target, 0.46)
        tween.tween_property(piece, "rotation", Vector3(angle * 1.3, angle * 0.7, angle * 1.8), 0.46)
        tween.chain().tween_property(piece, "position:y", 0.15, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.parallel().tween_property(piece, "scale", Vector3.ONE * 0.05, 0.40)
    root.get_tree().create_timer(1.05).timeout.connect(root.queue_free)

static func _create_decor(parent: Node3D) -> void:
    # All decoration lives outside the actionable center so it never competes with gameplay.
    # CC0 vendor geometry is deliberately limited to environmental dressing.
    var pallet_tint := Color("#A97F62")
    var cargo_tint := Color("#B7C6CE")
    var barrel_tint := Color("#91A9B5")

    # Two loaded pallets anchor the lower factory corners. The low-poly silhouette reads
    # much richer than primitive cubes without stealing attention from the puzzle.
    var loaded_left := _vendor_mesh(KAYKIT_LOADED_PALLET, cargo_tint, Vector3.ONE * 0.215)
    loaded_left.position = Vector3(-3.65, -0.12, -5.42)
    loaded_left.rotation.y = 0.12
    parent.add_child(loaded_left)

    var loaded_right := _vendor_mesh(KAYKIT_LOADED_PALLET, cargo_tint, Vector3.ONE * 0.195)
    loaded_right.position = Vector3(3.66, -0.12, 5.42)
    loaded_right.rotation.y = PI + 0.08
    parent.add_child(loaded_right)

    # Bare pallets make the scene feel like a working toy factory while keeping a clear
    # center lane for gameplay.
    for spec in [
        [Vector3(3.72, -0.12, -5.48), -0.08],
        [Vector3(-3.72, -0.12, 5.48), PI + 0.10],
    ]:
        var pallet := _vendor_mesh(KAYKIT_PALLET, pallet_tint, Vector3.ONE * 0.205)
        pallet.position = spec[0]
        pallet.rotation.y = spec[1]
        parent.add_child(pallet)

    # CC0 barrel props are placed in pairs. Their original low-poly faceting is preserved,
    # but the project material unifies them with Flow Factory's palette.
    for pos in [
        Vector3(-3.78, 0.33, -4.35),
        Vector3(-3.18, 0.33, -4.55),
        Vector3(3.75, 0.33, 4.22),
        Vector3(3.18, 0.33, 4.47),
    ]:
        var barrel := _vendor_mesh(KAYKIT_BARREL, barrel_tint, Vector3.ONE * 0.82)
        barrel.position = pos
        parent.add_child(barrel)

    # Custom tanks complement the imported props without multiplying external dependencies.
    for x in [-3.72, 3.72]:
        var tank := _cylinder(0.34, 1.12, Color("#AEBFC8"), 0.70, 0.0, 0.08)
        tank.position = Vector3(float(x), 0.42, 0.1)
        parent.add_child(tank)
        var tank_cap := _cylinder(0.20, 0.12, GREEN_ACCENT if x < 0 else ORANGE_ACCENT, 0.44, 0.22)
        tank_cap.position = Vector3(float(x), 1.02, 0.1)
        parent.add_child(tank_cap)

    # Compact safety barriers visually frame the upper workspace.
    for x in [-3.45, 3.45]:
        var post_a := _box(Vector3(0.12, 0.52, 0.12), MACHINE_DARK, 0.80)
        post_a.position = Vector3(float(x), 0.16, 5.02)
        parent.add_child(post_a)
        var post_b := _box(Vector3(0.12, 0.52, 0.12), MACHINE_DARK, 0.80)
        post_b.position = Vector3(float(x + (0.72 if x < 0 else -0.72)), 0.16, 5.02)
        parent.add_child(post_b)
        var bar := _box(Vector3(0.82, 0.12, 0.12), YELLOW, 0.62)
        bar.position = Vector3(float(x + (0.36 if x < 0 else -0.36)), 0.34, 5.02)
        parent.add_child(bar)

    # Corner status beacons provide subtle animation targets for the eye.
    for x in [-4.0, 4.0]:
        var pole := _cylinder(0.07, 0.94, MACHINE_DARK, 0.8)
        pole.position = Vector3(float(x), 0.34, 4.9)
        parent.add_child(pole)
        var lamp := _sphere(0.13, GREEN_ACCENT, 0.35, 0.55)
        lamp.position = Vector3(float(x), 0.88, 4.9)
        parent.add_child(lamp)

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

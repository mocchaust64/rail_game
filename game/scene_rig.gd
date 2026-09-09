class_name SceneRig
extends Node3D
# Camera, lights and environment, plus the shake that rides on the camera.
# Tuned against the reference: warm full-bleed ground, close toy camera and soft
# contact shadows. Camera framing adapts to the graph rather than using one zoom
# for ten differently-sized puzzles.

const KEY_LIGHT_EULER := Vector3(-51, 28, -8)
const KEY_LIGHT_ENERGY := 1.55
const KEY_LIGHT_COLOR := Color("#FFF4DE")
const KEY_LIGHT_SOFTNESS := 2.2
const SHADOW_BIAS := 0.022
const SHADOW_NORMAL_BIAS := 0.72
const SHADOW_MAX_DISTANCE := 42.0
const AMBIENT_ENERGY := 0.62

const CAMERA_FOV := 34.0
const CAMERA_POSITION := Vector3(0.0, 16.2, 12.6)
const CAMERA_TARGET := Vector3(0, 0.25, 0.15)
const FRAME_WIDTH := 6.4
const FRAME_DEPTH := 9.4
const FRAME_SIDE_PADDING := 1.75
const MIN_FRAME_SCALE := 0.82
const MAX_FRAME_SCALE := 1.60

const BOUNCE_POSITION := Vector3(-3.8, 4.2, 5.0)
const BOUNCE_ENERGY := 0.42
const BOUNCE_COLOR := Color("#FFDDBE")

var camera: Camera3D
var world: Node3D

var _shake := ScreenShake.new()
var _base_camera_position := CAMERA_POSITION
var _base_camera_target := CAMERA_TARGET


func _ready() -> void:
    world = Node3D.new()
    world.name = "World"
    add_child(world)

    camera = Camera3D.new()
    camera.name = "GameCamera"
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    camera.fov = CAMERA_FOV
    camera.position = _base_camera_position
    add_child(camera)
    camera.look_at(_base_camera_target, Vector3.UP)

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = KEY_LIGHT_EULER
    key_light.light_energy = KEY_LIGHT_ENERGY
    key_light.light_color = KEY_LIGHT_COLOR
    key_light.shadow_enabled = true
    key_light.light_angular_distance = KEY_LIGHT_SOFTNESS
    key_light.shadow_bias = SHADOW_BIAS
    key_light.shadow_normal_bias = SHADOW_NORMAL_BIAS
    key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    key_light.directional_shadow_max_distance = SHADOW_MAX_DISTANCE
    add_child(key_light)

    var bounce := OmniLight3D.new()
    bounce.position = BOUNCE_POSITION
    bounce.omni_range = 20.0
    bounce.light_energy = BOUNCE_ENERGY
    bounce.light_color = BOUNCE_COLOR
    bounce.shadow_enabled = false
    add_child(bounce)

    var holder := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#F1E4D3")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#FFF0DC")
    env.ambient_light_energy = AMBIENT_ENERGY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_white = 1.22
    env.glow_enabled = true
    env.glow_intensity = 0.30
    env.glow_bloom = 0.035
    env.glow_hdr_threshold = 1.18
    holder.environment = env
    add_child(holder)


# Called after level node positions are known. Only gameplay anchors matter;
# floor/decor are intentionally excluded or they would force every level to the
# same far-away overview shot again.
func frame_positions(positions: Dictionary) -> void:
    if positions.is_empty():
        _base_camera_position = CAMERA_POSITION
        _base_camera_target = CAMERA_TARGET
        return

    var first := true
    var min_x := 0.0
    var max_x := 0.0
    var min_z := 0.0
    var max_z := 0.0
    for raw in positions.values():
        var p: Vector3 = raw
        if first:
            min_x = p.x
            max_x = p.x
            min_z = p.z
            max_z = p.z
            first = false
        else:
            min_x = minf(min_x, p.x)
            max_x = maxf(max_x, p.x)
            min_z = minf(min_z, p.z)
            max_z = maxf(max_z, p.z)

    # Perspective enlarges the receiver row nearest the camera. Padding the
    # graph's horizontal bounds keeps the machines visible without letting
    # environment props affect framing.
    var width := maxf(1.0, max_x - min_x + FRAME_SIDE_PADDING * 2.0)
    var depth := maxf(1.0, max_z - min_z)
    var scale := clampf(maxf(width / FRAME_WIDTH, depth / FRAME_DEPTH), MIN_FRAME_SCALE, MAX_FRAME_SCALE)
    var centre_x := (min_x + max_x) * 0.5
    var centre_z := (min_z + max_z) * 0.5

    # Bias slightly towards the receiver half of the board; the foreground
    # source is visually taller and needs less empty space beneath it.
    _base_camera_target = Vector3(centre_x, 0.25, centre_z + 0.28)
    _base_camera_position = Vector3(
        centre_x,
        CAMERA_POSITION.y * scale,
        centre_z + CAMERA_POSITION.z * scale
    )


func _process(delta: float) -> void:
    _shake.advance(delta)
    camera.position = _base_camera_position + _shake.offset()
    camera.look_at(_base_camera_target, Vector3.UP)
    camera.rotation.z += _shake.roll()


func add_trauma(amount: float) -> void:
    _shake.add_trauma(amount)


func clear_world() -> void:
    for child in world.get_children():
        world.remove_child(child)
        child.queue_free()

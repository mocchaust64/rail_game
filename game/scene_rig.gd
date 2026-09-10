class_name SceneRig
extends Node3D
# Camera/light rig tuned to the vertical reference shot: feeder lanes remain in
# frame at the top, the three destination machines dominate the lower third and
# the bottom buffer can appear without forcing a far-away board view.

const KEY_LIGHT_EULER := Vector3(-51, 28, -8)
const KEY_LIGHT_ENERGY := 1.14
const KEY_LIGHT_COLOR := Color("#FFEED8")
const KEY_LIGHT_SOFTNESS := 2.35
const SHADOW_BIAS := 0.022
const SHADOW_NORMAL_BIAS := 0.70
const SHADOW_MAX_DISTANCE := 42.0
const AMBIENT_ENERGY := 0.44

const CAMERA_FOV := 21.0
const CAMERA_POSITION := Vector3(0.0, 16.2, 12.6)
const CAMERA_TARGET := Vector3(0, 0.28, -0.20)
const FRAME_WIDTH := 7.2
const FRAME_DEPTH := 13.6
# Node positions are centre points; receivers extend ~0.8 world units sideways.
# A 2.05 margin keeps the full silhouettes plus a touch-safe gutter visible on
# 9:16 and taller portrait screens instead of clipping the outer machines.
const FRAME_SIDE_PADDING := 2.05
const FRAME_TOP_PADDING := 2.70
const FRAME_BOTTOM_PADDING := 2.10
const MIN_FRAME_SCALE := 0.82
const MAX_FRAME_SCALE := 1.48

const BOUNCE_POSITION := Vector3(-3.8, 4.2, 5.0)
const BOUNCE_ENERGY := 0.28
const BOUNCE_COLOR := Color("#FFD5B5")

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
    camera.keep_aspect = Camera3D.KEEP_WIDTH
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
    env.background_color = Color("#E6D4BC")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#EEDCC5")
    env.ambient_light_energy = AMBIENT_ENERGY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_white = 1.30
    env.glow_enabled = true
    env.glow_intensity = 0.08
    env.glow_bloom = 0.010
    env.glow_hdr_threshold = 1.55
    holder.environment = env
    add_child(holder)


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

    var visual_min_z := min_z - FRAME_TOP_PADDING
    var visual_max_z := max_z + FRAME_BOTTOM_PADDING
    var width := maxf(1.0, max_x - min_x + FRAME_SIDE_PADDING * 2.0)
    var depth := maxf(1.0, visual_max_z - visual_min_z)
    var scale := clampf(maxf(width / FRAME_WIDTH, depth / FRAME_DEPTH), MIN_FRAME_SCALE, MAX_FRAME_SCALE)
    var centre_x := (min_x + max_x) * 0.5
    var centre_z := (visual_min_z + visual_max_z) * 0.5

    _base_camera_target = Vector3(centre_x, 0.28, centre_z + 0.16)
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

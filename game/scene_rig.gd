class_name SceneRig
extends Node3D
# Camera, lights and environment, plus the shake that rides on the camera.
# Visual pass is tuned against the user's reference video: warm background,
# close toy-diorama camera and stronger contact shadows.

const KEY_LIGHT_EULER := Vector3(-51, 28, -8)
const KEY_LIGHT_ENERGY := 1.55
const KEY_LIGHT_COLOR := Color("#FFF4DE")
const KEY_LIGHT_SOFTNESS := 2.2
const SHADOW_BIAS := 0.022
const SHADOW_NORMAL_BIAS := 0.72
const SHADOW_MAX_DISTANCE := 42.0
const AMBIENT_ENERGY := 0.62

# Closer and lower than the previous overview shot. The reference fills the
# portrait with the machines and belt, rather than showing an entire white board.
const CAMERA_FOV := 34.0
const CAMERA_POSITION := Vector3(0.0, 16.2, 12.6)
const CAMERA_TARGET := Vector3(0, 0.25, 0.15)

const BOUNCE_POSITION := Vector3(-3.8, 4.2, 5.0)
const BOUNCE_ENERGY := 0.42
const BOUNCE_COLOR := Color("#FFDDBE")

var camera: Camera3D
var world: Node3D

var _shake := ScreenShake.new()


func _ready() -> void:
    world = Node3D.new()
    world.name = "World"
    add_child(world)

    camera = Camera3D.new()
    camera.name = "GameCamera"
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    camera.fov = CAMERA_FOV
    camera.position = CAMERA_POSITION
    add_child(camera)
    camera.look_at(CAMERA_TARGET, Vector3.UP)

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


func _process(delta: float) -> void:
    _shake.advance(delta)
    camera.position = CAMERA_POSITION + _shake.offset()
    camera.rotation.z = _shake.roll()


func add_trauma(amount: float) -> void:
    _shake.add_trauma(amount)


func clear_world() -> void:
    for child in world.get_children():
        world.remove_child(child)
        child.queue_free()

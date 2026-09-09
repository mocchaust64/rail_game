class_name SceneRig
extends Node3D
# Camera, lights and environment, plus the shake that rides on the camera.
#
# Split out of GameController because none of it depends on the rules of the
# game: it is the look of the board, and it is the part most often retuned.
# Every value that needs tuning against a real render is a constant here.

# The board is roughly 9.2 by 14.1 units. Engine defaults assume a much larger
# world, so these are tuned to that scale rather than left at their defaults.
const KEY_LIGHT_EULER := Vector3(-48, 32, 0)
const KEY_LIGHT_ENERGY := 1.45
const KEY_LIGHT_COLOR := Color("#FFF6E8")
const KEY_LIGHT_SOFTNESS := 1.4
const SHADOW_BIAS := 0.024
const SHADOW_NORMAL_BIAS := 0.85
const SHADOW_MAX_DISTANCE := 60.0
const AMBIENT_ENERGY := 0.55

# Mild perspective. Note this is not only a depth cue: directional shadows do
# not render at all under an orthographic camera in this engine build.
const CAMERA_FOV := 30.0
const CAMERA_POSITION := Vector3(0.0, 23.3, 16.9)
const CAMERA_TARGET := Vector3(0, 0, 0.25)

const BOUNCE_POSITION := Vector3(-3.4, 3.6, 7.4)
const BOUNCE_ENERGY := 0.38
const BOUNCE_COLOR := Color("#FFE2C4")

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

    # Warm bounce from the front-lower quadrant. Without it the shadowed faces of
    # the white machines read as flat grey once ambient is turned down.
    var bounce := OmniLight3D.new()
    bounce.position = BOUNCE_POSITION
    bounce.omni_range = 22.0
    bounce.light_energy = BOUNCE_ENERGY
    bounce.light_color = BOUNCE_COLOR
    bounce.shadow_enabled = false
    add_child(bounce)

    var holder := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#BDD0D9")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#EAF3F8")
    env.ambient_light_energy = AMBIENT_ENERGY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_white = 1.35
    env.glow_enabled = true
    env.glow_intensity = 0.5
    env.glow_bloom = 0.06
    env.glow_hdr_threshold = 1.05
    holder.environment = env
    add_child(holder)


func _process(delta: float) -> void:
    _shake.advance(delta)
    camera.position = CAMERA_POSITION + _shake.offset()
    camera.rotation.z = _shake.roll()


func add_trauma(amount: float) -> void:
    _shake.add_trauma(amount)


# Clears everything the level built, leaving the rig itself intact.
func clear_world() -> void:
    for child in world.get_children():
        world.remove_child(child)
        child.queue_free()

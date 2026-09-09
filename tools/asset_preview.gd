extends Node3D
# Lays every candidate CC0 mesh out in a grid so they can be judged on screen
# instead of by filename. Not shipped with the game; a authoring tool only.

const MODELS := [
	"res://assets/vendor/kaykit_prototype_bits/gltf/Barrel_A.gltf",
	"res://assets/vendor/kaykit_prototype_bits/gltf/Coin_A.gltf",
	"res://assets/vendor/kaykit_space_base_bits/gltf/containers_C.gltf",
	"res://assets/vendor/kaykit_space_base_bits/gltf/basemodule_A.gltf",
]
const COLUMNS := 4
const SPACING := 2.4


func _ready() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#CBD8DF")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#EAF3F8")
	environment.ambient_light_energy = 0.55
	env.environment = environment
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, 32, 0)
	key.light_energy = 1.45
	key.shadow_enabled = true
	add_child(key)

	for i in range(MODELS.size()):
		var scene: PackedScene = load(MODELS[i])
		if scene == null:
			push_error("failed to load %s" % MODELS[i])
			continue
		var instance := scene.instantiate()
		var column := i % COLUMNS
		var row := i / COLUMNS
		instance.position = Vector3((column - 1.5) * SPACING, 0.0, (row - 1.2) * SPACING)
		add_child(instance)

		var label := Label3D.new()
		label.text = MODELS[i].get_file().get_basename()
		label.font_size = 96
		label.pixel_size = 0.0016
		label.position = instance.position + Vector3(0, 1.35, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("#20303F")
		add_child(label)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 7.0, 7.4)
	add_child(camera)
	camera.look_at(Vector3(0, 0.4, 0), Vector3.UP)

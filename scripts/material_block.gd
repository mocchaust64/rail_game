extends RigidBody3D
class_name MaterialBlock

enum BlockType { WOOD, STONE, ICE }

@export var block_type: BlockType = BlockType.WOOD
@export var break_impact_speed: float = 8.0
@export var despawn_below_y: float = -6.0
@export var required_ammo: int = 0

var _broken := false
var _last_speed := 0.0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	_update_color()

func _physics_process(_delta: float) -> void:
	_last_speed = linear_velocity.length()
	if global_position.y < despawn_below_y:
		break_block(false)

func can_break_with(ammo_type: int) -> bool:
	return ammo_type == required_ammo or ammo_type == GameManager.AmmoType.WILD

func hit_with(ammo_type: int, _hit_point: Vector3, _impulse_strength: float = 5.0) -> bool:
	if _broken:
		return false
	if not can_break_with(ammo_type):
		return false
	break_block(true)
	return true

func break_block(from_shot: bool = false) -> void:
	if _broken:
		return
	_broken = true
	_spawn_debris()
	if from_shot:
		GameEvents.block_broken.emit(global_position)
	queue_free()

func _on_body_entered(body: Node) -> void:
	if _broken:
		return
	if body.is_in_group("ground") or _last_speed >= break_impact_speed:
		break_block(false)

func _spawn_debris() -> void:
	var count := 6
	for i in range(count):
		var piece := RigidBody3D.new()
		piece.collision_layer = 0
		piece.collision_mask = 1
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.18, 0.18)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _get_color()
		mat.roughness = 0.55
		mesh.material_override = mat
		piece.add_child(mesh)
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(0.18, 0.18, 0.18)
		shape.shape = box_shape
		piece.add_child(shape)
		get_tree().current_scene.add_child(piece)
		piece.global_position = global_position + Vector3(randf_range(-0.25,0.25), randf_range(-0.15,0.3), randf_range(-0.25,0.25))
		piece.linear_velocity = Vector3(randf_range(-2.5,2.5), randf_range(1.5,4.0), randf_range(-2.5,2.5))
		piece.angular_velocity = Vector3(randf_range(-6,6), randf_range(-6,6), randf_range(-6,6))
		var timer := get_tree().create_timer(0.8 + randf_range(0.0,0.5))
		timer.timeout.connect(piece.queue_free)

func _update_color() -> void:
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _get_color()
		mat.roughness = 0.45
		mesh.material_override = mat

func _get_color() -> Color:
	match block_type:
		BlockType.WOOD: return Color("e6a14a")
		BlockType.STONE: return Color("7d8397")
		BlockType.ICE: return Color("70d7ff")
	return Color.WHITE

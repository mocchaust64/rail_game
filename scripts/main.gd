extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var manager: GameManager = $GameManager
@onready var status_label: Label = $UI/Status
@onready var ammo_label: Label = $UI/Ammo
@onready var win_panel: Control = $UI/WinPanel
@onready var lose_panel: Control = $UI/LosePanel

func _ready() -> void:
	GameEvents.level_won.connect(_on_level_won)
	GameEvents.level_lost.connect(_on_level_lost)
	GameEvents.ball_cleared.connect(func(_p): _refresh_ui())
	_build_level_01()
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_shoot_at_screen(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_shoot_at_screen(event.position)

func _shoot_at_screen(screen_pos: Vector2) -> void:
	if manager.level_finished:
		return
	var origin := camera.project_ray_origin(screen_pos)
	var end := origin + camera.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider := hit.get("collider")
	if collider is MaterialBlock:
		if not manager.try_use_ammo():
			_check_out_of_ammo()
			return
		GameEvents.shot_fired.emit(hit.position)
		var ok := collider.hit_with(manager.selected_ammo, hit.position)
		if not ok:
			GameEvents.wrong_ammo.emit(hit.position)
		_refresh_ui()
		_schedule_out_of_ammo_check()

func _check_out_of_ammo() -> void:
	_schedule_out_of_ammo_check()

func _schedule_out_of_ammo_check() -> void:
	var left := 0
	for value in manager.ammo.values():
		left += int(value)
	if left > 0 or manager.level_finished:
		return
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(_finish_out_of_ammo_check)

func _finish_out_of_ammo_check() -> void:
	if manager.level_finished:
		return
	if manager.cleared_balls < manager.total_balls:
		manager.level_finished = true
		GameEvents.level_lost.emit()

func _build_level_01() -> void:
	var balls := 0
	_create_block(Vector3(-1.8, 1.0, 0), Vector3(0.7,2.0,0.7), MaterialBlock.BlockType.WOOD, GameManager.AmmoType.WOOD)
	_create_block(Vector3(1.8, 1.0, 0), Vector3(0.7,2.0,0.7), MaterialBlock.BlockType.WOOD, GameManager.AmmoType.WOOD)
	_create_block(Vector3(0, 2.3, 0), Vector3(4.6,0.45,0.9), MaterialBlock.BlockType.STONE, GameManager.AmmoType.STONE)
	_create_block(Vector3(-1.2, 3.0, 0), Vector3(1.0,0.7,0.9), MaterialBlock.BlockType.ICE, GameManager.AmmoType.FIRE)
	_create_block(Vector3(1.2, 3.0, 0), Vector3(1.0,0.7,0.9), MaterialBlock.BlockType.ICE, GameManager.AmmoType.FIRE)
	for x in [-1.6, -0.8, 0.0, 0.8, 1.6]:
		_create_ball(Vector3(x, 4.0 + randf_range(0.0,0.25), 0))
		balls += 1
	manager.start_level(balls)

func _create_block(pos: Vector3, size: Vector3, type: int, ammo_type: int) -> void:
	var body := MaterialBlock.new()
	body.block_type = type
	body.required_ammo = ammo_type
	body.mass = 1.7 if type == MaterialBlock.BlockType.STONE else 1.0
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	$Level.add_child(body)
	body.global_position = pos

func _create_ball(pos: Vector3) -> void:
	var body := SmashBall.new()
	body.mass = 0.7
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f7f7f7")
	mat.roughness = 0.3
	mesh.material_override = mat
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.35
	collision.shape = shape
	body.add_child(collision)
	$Level.add_child(body)
	body.global_position = pos

func _refresh_ui() -> void:
	status_label.text = "BALLS  %d / %d" % [manager.cleared_balls, manager.total_balls]
	ammo_label.text = "WOOD %d   STONE %d   FIRE %d   WILD %d" % [
		manager.ammo[GameManager.AmmoType.WOOD], manager.ammo[GameManager.AmmoType.STONE],
		manager.ammo[GameManager.AmmoType.FIRE], manager.ammo[GameManager.AmmoType.WILD]
	]

func _on_level_won(stars: int) -> void:
	win_panel.visible = true
	$UI/WinPanel/Center/Box/Title.text = "LEVEL COMPLETE"
	$UI/WinPanel/Center/Box/Stars.text = "★".repeat(stars) + "☆".repeat(3-stars)

func _on_level_lost() -> void:
	lose_panel.visible = true

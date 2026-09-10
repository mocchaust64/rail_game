extends RigidBody3D
class_name SmashBall

@export var despawn_below_y := -6.0
var _counted := false

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	if not _counted and global_position.y < despawn_below_y:
		_clear_ball()

func _on_body_entered(body: Node) -> void:
	if _counted:
		return
	if body.is_in_group("ground"):
		_clear_ball()

func _clear_ball() -> void:
	if _counted:
		return
	_counted = true
	GameEvents.ball_cleared.emit(global_position)
	queue_free()

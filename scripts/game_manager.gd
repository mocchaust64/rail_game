extends Node
class_name GameManager

enum AmmoType { WOOD, STONE, FIRE, WILD }

var ammo := {
	AmmoType.WOOD: 5,
	AmmoType.STONE: 4,
	AmmoType.FIRE: 4,
	AmmoType.WILD: 1,
}
var selected_ammo: AmmoType = AmmoType.WOOD
var total_balls := 0
var cleared_balls := 0
var shots_used := 0
var level_finished := false

func _ready() -> void:
	GameEvents.ball_cleared.connect(_on_ball_cleared)

func start_level(ball_count: int) -> void:
	total_balls = ball_count
	cleared_balls = 0
	shots_used = 0
	level_finished = false

func set_selected_ammo(ammo_type: AmmoType) -> void:
	selected_ammo = ammo_type

func try_use_ammo() -> bool:
	if level_finished:
		return false
	if ammo.get(selected_ammo, 0) <= 0:
		return false
	ammo[selected_ammo] -= 1
	shots_used += 1
	return true

func _on_ball_cleared(_position: Vector3) -> void:
	if level_finished:
		return
	cleared_balls += 1
	if cleared_balls >= total_balls:
		level_finished = true
		var stars := 1
		if shots_used <= 4: stars = 3
		elif shots_used <= 7: stars = 2
		GameEvents.level_won.emit(stars)

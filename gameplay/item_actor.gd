class_name ItemActor
extends Node3D

signal finished(item: ItemActor)

enum ItemState { SPAWNING, TRAVELING, DELIVERING, BUFFERING, DEAD }

var kind: String = "red"
var origin_source: String = ""
var from_id: String = ""
var to_id: String = ""
var from_pos: Vector3
var to_pos: Vector3
var progress: float = 0.0
var speed: float = 1.8
var segment_length: float = 1.0
var state: ItemState = ItemState.SPAWNING

var _visual: Node3D
var _travel_clock: float = 0.0
var _roll_angle: float = 0.0

func configure(item_kind: String, source_id: String, start_id: String, next_id: String, start_pos: Vector3, next_pos: Vector3, move_speed: float) -> void:
	kind = item_kind
	origin_source = source_id
	speed = move_speed
	_build_visual()
	start_segment(start_id, next_id, start_pos, next_pos)
	scale = Vector3.ONE * 0.2
	var spawn_tween := Motion.tween(self)
	spawn_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	spawn_tween.tween_property(self, "scale", Vector3.ONE, 0.16)
	state = ItemState.TRAVELING

func _build_visual() -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
	_visual = VisualFactory.create_kind_visual(kind, 0.34)
	add_child(_visual)

func prepare_for_reuse() -> void:
	progress = 0.0
	_travel_clock = 0.0
	_roll_angle = 0.0
	from_id = ""
	to_id = ""
	scale = Vector3.ONE
	rotation = Vector3.ZERO
	modulate_visual(1.0)

func modulate_visual(alpha: float) -> void:
	if _visual == null or not is_instance_valid(_visual):
		return
	_visual.visible = alpha > 0.0

func start_segment(start_id: String, next_id: String, start_pos: Vector3, next_pos: Vector3) -> void:
	from_id = start_id
	to_id = next_id
	from_pos = start_pos
	to_pos = next_pos
	progress = 0.0
	segment_length = max(0.001, from_pos.distance_to(to_pos))
	global_position = from_pos + Vector3(0, 0.52, 0)
	state = ItemState.TRAVELING
	if _visual != null:
		_visual.rotation = Vector3.ZERO

func advance(delta: float) -> bool:
	if state != ItemState.TRAVELING:
		return false
	_travel_clock += delta
	progress += (speed * delta) / segment_length
	var t := clampf(progress, 0.0, 1.0)
	global_position = from_pos.lerp(to_pos, t) + Vector3(0, 0.52, 0)

	# Reference cargo rolls along the track rather than hovering/bobbing. Rotate
	# around the axis perpendicular to travel so the motion reads physically.
	if _visual != null:
		var distance := speed * delta
		_roll_angle += distance / 0.34
		var dir := (to_pos - from_pos).normalized()
		var axis := Vector3(dir.z, 0.0, -dir.x).normalized()
		_visual.rotate(axis, _roll_angle - _visual.rotation.length())
	return progress >= 1.0

func animate_delivered() -> void:
	state = ItemState.DELIVERING
	var tween := Motion.tween(self)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector3.ONE * 0.08, 0.16)
	tween.tween_property(self, "position:y", position.y + 0.28, 0.16)
	tween.finished.connect(_finish)

func animate_buffered(target_global: Vector3) -> void:
	state = ItemState.BUFFERING
	var tween := Motion.tween(self)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target_global, 0.22)
	tween.tween_property(self, "scale", Vector3.ONE * 0.38, 0.22)
	tween.finished.connect(_finish)

func _finish() -> void:
	state = ItemState.DEAD
	finished.emit(self)

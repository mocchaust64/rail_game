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
var _path := PackedVector3Array()


func configure(item_kind: String, source_id: String, start_id: String, next_id: String, start_pos: Vector3, next_pos: Vector3, move_speed: float) -> void:
    kind = item_kind
    origin_source = source_id
    speed = move_speed
    _build_visual()
    start_segment(start_id, next_id, start_pos, next_pos)

    # Fast toy-like pop: readable on a phone, short enough not to block the line.
    scale = Vector3.ONE * 0.20
    var spawn_tween := Motion.tween(self)
    spawn_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    spawn_tween.tween_property(self, "scale", Vector3(1.06, 0.90, 1.06), 0.12)
    spawn_tween.tween_property(self, "scale", Vector3.ONE, 0.07)
    state = ItemState.TRAVELING


func _build_visual() -> void:
    if _visual != null and is_instance_valid(_visual):
        _visual.queue_free()
    _visual = VisualFactory.create_kind_visual(kind, 0.34)
    add_child(_visual)


func prepare_for_reuse() -> void:
    progress = 0.0
    from_id = ""
    to_id = ""
    _path = PackedVector3Array()
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
    _path = TrackGeometry.path_for(start_id, next_id, start_pos, next_pos)
    segment_length = maxf(0.001, TrackGeometry.length(_path))

    var sampled := TrackGeometry.sample_distance(_path, 0.0)
    var p: Vector3 = sampled["position"]
    global_position = p + Vector3(0, 0.52, 0)
    state = ItemState.TRAVELING


func advance(delta: float) -> bool:
    if state != ItemState.TRAVELING:
        return false

    progress += (speed * delta) / segment_length
    var distance := clampf(progress, 0.0, 1.0) * segment_length
    var sampled := TrackGeometry.sample_distance(_path, distance)
    var p: Vector3 = sampled["position"]
    var tangent: Vector3 = sampled["tangent"]
    global_position = p + Vector3(0, 0.52, 0)

    # Roll in the current curve tangent, rather than around the straight edge's
    # original axis. This is the visual cue that the ball belongs to the belt.
    if _visual != null and tangent.length_squared() > 0.0001:
        var axis := Vector3(tangent.z, 0.0, -tangent.x).normalized()
        _visual.rotate(axis, (speed * delta) / 0.34)

    return progress >= 1.0


func animate_delivered() -> void:
    state = ItemState.DELIVERING
    var tween := Motion.tween(self)
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    # Receiver reads as swallowing the ball instead of the ball evaporating up.
    tween.tween_property(self, "scale", Vector3(0.18, 0.12, 0.18), 0.15)
    tween.tween_property(self, "position:y", position.y - 0.20, 0.15)
    tween.finished.connect(_finish)


func animate_buffered(target_global: Vector3) -> void:
    state = ItemState.BUFFERING
    var tween := Motion.tween(self)
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    tween.tween_property(self, "global_position", target_global, 0.24)
    tween.tween_property(self, "scale", Vector3.ONE * 0.42, 0.24)
    tween.finished.connect(_finish)


func _finish() -> void:
    state = ItemState.DEAD
    finished.emit(self)

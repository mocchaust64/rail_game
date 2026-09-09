class_name JunctionActor
extends Node3D

const SWITCH_REACH := 0.54

var junction_id: String = ""
var out_a: String = ""
var out_b: String = ""
var state: int = 0

var _switch_arm: Node3D
var _hint_ring: MeshInstance3D
var _pivot: MeshInstance3D
var _is_animating: bool = false
var _queued_toggle: bool = false
var _positions: Dictionary = {}
var _hint_active: bool = false
var _clock: float = 0.0


func configure(data: Dictionary, positions: Dictionary) -> void:
    junction_id = String(data["id"])
    out_a = String(data["out_a"])
    out_b = String(data["out_b"])
    state = int(data.get("initial_state", 0)) & 1
    _positions = positions
    _build_visual()
    _snap_switch()


func _process(delta: float) -> void:
    _clock += delta
    if _hint_ring != null:
        if _hint_active:
            var pulse := 1.0 + sin(_clock * 5.0) * 0.08
            _hint_ring.visible = true
            _hint_ring.scale = Vector3(pulse, 1.0, pulse)
        else:
            _hint_ring.visible = false


func current_output() -> String:
    return out_a if state == 0 else out_b


func request_toggle() -> void:
    if _is_animating:
        _queued_toggle = true
        return
    _perform_toggle()


func set_hint_active(value: bool) -> void:
    _hint_active = value


func _perform_toggle() -> void:
    state = 1 - state
    _is_animating = true
    AudioService.play("tap", 1.0, -4.0)
    HapticService.light()

    # There is no arrow or UI button. The piece of rail itself snaps to the
    # selected branch, which is the route feedback used by the reference game.
    var target_angle := _target_angle()
    var tween := Motion.tween(self)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_switch_arm, "rotation:y", target_angle, 0.14)
    tween.parallel().tween_property(_switch_arm, "scale", Vector3(1.03, 0.92, 1.03), 0.055)
    tween.chain().tween_property(_switch_arm, "scale", Vector3.ONE, 0.075)
    if _pivot != null:
        var pivot_tween := Motion.tween(_pivot)
        pivot_tween.tween_property(_pivot, "scale", Vector3(0.94, 0.84, 0.94), 0.055)
        pivot_tween.tween_property(_pivot, "scale", Vector3.ONE, 0.075)
    tween.finished.connect(_on_toggle_finished)


func _on_toggle_finished() -> void:
    _is_animating = false
    if _queued_toggle:
        _queued_toggle = false
        _perform_toggle()


func _target_angle() -> float:
    var target_id := current_output()
    if not _positions.has(target_id):
        return 0.0

    var start: Vector3 = _positions.get(junction_id, position)
    var finish: Vector3 = _positions[target_id]
    var path := TrackGeometry.path_for(junction_id, target_id, start, finish)
    var dir := finish - start
    if path.size() >= 2:
        var sample := TrackGeometry.sample_distance(path, minf(SWITCH_REACH, TrackGeometry.length(path)))
        dir = (sample["position"] as Vector3) - start
    if dir.length_squared() < 0.0001:
        return 0.0
    dir.y = 0.0
    dir = dir.normalized()
    return atan2(dir.x, dir.z)


func _snap_switch() -> void:
    if _switch_arm != null:
        _switch_arm.rotation.y = _target_angle()


func _build_visual() -> void:
    # Only a small mechanism is visible under the rails. It should disappear
    # into the track network, not read as a circular gameplay button.
    _pivot = MeshInstance3D.new()
    _pivot.name = "SwitchPivot"
    var pivot_mesh := CylinderMesh.new()
    pivot_mesh.top_radius = 0.31
    pivot_mesh.bottom_radius = 0.34
    pivot_mesh.height = 0.085
    pivot_mesh.radial_segments = 20
    _pivot.mesh = pivot_mesh
    _pivot.position.y = 0.075
    _pivot.material_override = VisualFactory.material(Color("#56595A"), 0.56, 0.0, 0.10)
    add_child(_pivot)

    _switch_arm = Node3D.new()
    _switch_arm.name = "PhysicalSwitchRail"
    add_child(_switch_arm)

    var local_points := PackedVector3Array([
        Vector3(0.0, 0.0, 0.0),
        Vector3(0.0, 0.0, 0.18),
        Vector3(0.0, 0.0, 0.36),
        Vector3(0.0, 0.0, SWITCH_REACH),
    ])
    TrackVisuals.create_path(_switch_arm, local_points)

    # Tutorial-only pulse; normal gameplay has no icon over the switch.
    _hint_ring = MeshInstance3D.new()
    var hint_mesh := TorusMesh.new()
    hint_mesh.inner_radius = 0.38
    hint_mesh.outer_radius = 0.44
    hint_mesh.rings = 20
    hint_mesh.ring_segments = 8
    _hint_ring.mesh = hint_mesh
    _hint_ring.position.y = 0.12
    _hint_ring.material_override = VisualFactory.material(Color("#FFF1A8"), 0.32, 0.50)
    _hint_ring.visible = false
    add_child(_hint_ring)

class_name JunctionActor
extends Node3D

const SWITCH_REACH := 1.50

var junction_id: String = ""
var out_a: String = ""
var out_b: String = ""
var state: int = 0

var _switch_arm: Node3D
var _hint_ring: MeshInstance3D
var _route_halo: MeshInstance3D
var _pivot: MeshInstance3D
var _is_animating: bool = false
var _route_locked: bool = false
var _target_state: int = 0
var _positions: Dictionary = {}
var _hint_active: bool = false
var _clock: float = 0.0


func configure(data: Dictionary, positions: Dictionary) -> void:
    junction_id = String(data["id"])
    out_a = String(data["out_a"])
    out_b = String(data["out_b"])
    state = int(data.get("initial_state", 0)) & 1
    _target_state = state
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


func selected_state() -> int:
    return _target_state if _is_animating else state


func is_switching() -> bool:
    return _is_animating


func is_route_locked() -> bool:
    return _route_locked


func set_route_locked(value: bool) -> void:
    _route_locked = value


func request_toggle() -> bool:
    # The player must choose before cargo enters the decision zone. Once a ball
    # is close to/on the moving bridge, the mechanism is physically unavailable.
    # This removes last-frame colour reaction and turns the route into a plan.
    if _is_animating or _route_locked:
        return false
    _perform_toggle(1 - state)
    return true


func set_hint_active(value: bool) -> void:
    _hint_active = value


func _perform_toggle(next_state: int) -> void:
    _target_state = next_state & 1
    _is_animating = true
    AudioService.play("tap", 1.0, -4.0)
    HapticService.light()

    if _route_halo != null:
        _route_halo.visible = true
        _route_halo.scale = Vector3(0.82, 1.0, 0.82)
        var halo_tween := Motion.tween(_route_halo)
        halo_tween.tween_property(_route_halo, "scale", Vector3.ONE * 1.06, 0.11)
        halo_tween.tween_property(_route_halo, "scale", Vector3.ONE, 0.11)

    var target_angle := _angle_for_state(_target_state)
    var tween := Motion.tween(self)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(_switch_arm, "rotation:y", target_angle, 0.24)
    tween.finished.connect(_on_toggle_finished)


func _on_toggle_finished() -> void:
    # Gameplay commits only once the long conveyor visibly reaches its new rails.
    state = _target_state
    _is_animating = false
    if _route_halo != null:
        var hide_tween := Motion.tween(_route_halo)
        hide_tween.tween_property(_route_halo, "scale", Vector3.ONE * 0.86, 0.09)
        hide_tween.finished.connect(func() -> void:
            if _route_halo != null:
                _route_halo.visible = false
                _route_halo.scale = Vector3.ONE
        )


func _target_angle() -> float:
    return _angle_for_state(selected_state())


func _angle_for_state(route_state: int) -> float:
    var target_id := out_a if route_state == 0 else out_b
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
        _switch_arm.rotation.y = _angle_for_state(state)


func _build_visual() -> void:
    _pivot = MeshInstance3D.new()
    _pivot.name = "SwitchPivot"
    var pivot_mesh := CylinderMesh.new()
    pivot_mesh.top_radius = 0.22
    pivot_mesh.bottom_radius = 0.25
    pivot_mesh.height = 0.06
    pivot_mesh.radial_segments = 20
    _pivot.mesh = pivot_mesh
    _pivot.position.y = 0.07
    _pivot.material_override = VisualFactory.material(Color("#666A6C"), 0.52, 0.0, 0.10)
    add_child(_pivot)

    _switch_arm = Node3D.new()
    _switch_arm.name = "PhysicalSwitchRail"
    add_child(_switch_arm)

    var local_points := PackedVector3Array([
        Vector3(0.0, 0.0, 0.0),
        Vector3(0.0, 0.0, SWITCH_REACH * 0.34),
        Vector3(0.0, 0.0, SWITCH_REACH * 0.68),
        Vector3(0.0, 0.0, SWITCH_REACH),
    ])
    TrackVisuals.create_path(_switch_arm, local_points, 0.0, 0.0, true, true)

    _route_halo = MeshInstance3D.new()
    _route_halo.name = "RouteChangeHalo"
    var halo_mesh := TorusMesh.new()
    halo_mesh.inner_radius = 0.42
    halo_mesh.outer_radius = 0.53
    halo_mesh.rings = 24
    halo_mesh.ring_segments = 10
    _route_halo.mesh = halo_mesh
    _route_halo.position.y = 0.09
    _route_halo.material_override = VisualFactory.material(Color("#76B8F4B0"), 0.24, 0.35)
    _route_halo.visible = false
    add_child(_route_halo)

    _hint_ring = MeshInstance3D.new()
    var hint_mesh := TorusMesh.new()
    hint_mesh.inner_radius = 0.38
    hint_mesh.outer_radius = 0.44
    hint_mesh.rings = 20
    hint_mesh.ring_segments = 8
    _hint_ring.mesh = hint_mesh
    _hint_ring.position.y = 0.10
    _hint_ring.material_override = VisualFactory.material(Color("#FFF1A8"), 0.32, 0.50)
    _hint_ring.visible = false
    add_child(_hint_ring)

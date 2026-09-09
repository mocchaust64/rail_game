class_name JunctionActor
extends Node3D

const SWITCH_REACH := 1.50
const DEFAULT_FILTERS := ["red", "blue", "yellow"]

var junction_id: String = ""
var out_a: String = ""
var out_b: String = ""
var state: int = 0
var filter_kind: String = "red"

var _switch_arm: Node3D
var _hint_ring: MeshInstance3D
var _route_halo: MeshInstance3D
var _pivot: MeshInstance3D
var _rule_markers: Node3D
var _is_animating: bool = false
var _target_state: int = 0
var _positions: Dictionary = {}
var _hint_active: bool = false
var _planning_mode: bool = true
var _clock: float = 0.0
var _filter_options: Array = []
var _route_requests: Array[Dictionary] = []


func configure(data: Dictionary, positions: Dictionary) -> void:
    junction_id = String(data["id"])
    out_a = String(data["out_a"])
    out_b = String(data["out_b"])
    state = int(data.get("initial_state", 0)) & 1
    _target_state = state
    _positions = positions

    _filter_options = []
    var raw_options: Array = data.get("filter_options", DEFAULT_FILTERS)
    for raw in raw_options:
        var option := String(raw)
        if option in DEFAULT_FILTERS and option not in _filter_options:
            _filter_options.append(option)
    if _filter_options.is_empty():
        _filter_options = DEFAULT_FILTERS.duplicate()

    filter_kind = String(data.get("filter_kind", _filter_options[0]))
    if filter_kind not in _filter_options:
        filter_kind = String(_filter_options[0])

    _build_visual()
    _snap_switch()
    _rebuild_rule_markers()


func _process(delta: float) -> void:
    _clock += delta
    if _hint_ring != null:
        if _hint_active and _planning_mode:
            var pulse := 1.0 + sin(_clock * 5.0) * 0.08
            _hint_ring.visible = true
            _hint_ring.scale = Vector3(pulse, 1.0, pulse)
        else:
            _hint_ring.visible = false


func set_planning_mode(value: bool) -> void:
    _planning_mode = value
    if _rule_markers != null:
        _rule_markers.visible = true
    if not value:
        _hint_active = false


func cycle_filter() -> bool:
    if not _planning_mode or _is_animating or _filter_options.is_empty():
        return false
    var index := _filter_options.find(filter_kind)
    filter_kind = String(_filter_options[(index + 1) % _filter_options.size()])
    AudioService.play("tap", 1.04, -5.0)
    HapticService.light()
    _rebuild_rule_markers()
    if _rule_markers != null:
        _rule_markers.scale = Vector3.ONE * 0.84
        var tween := Motion.tween(_rule_markers)
        tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(_rule_markers, "scale", Vector3.ONE, 0.14)
    return true


# Kept as a compatibility entry point for older test/tutorial code. In the new
# game this changes the programmed colour during planning; it never manually
# changes a live route while cargo is running.
func request_toggle() -> bool:
    return cycle_filter()


func route_for_kind(kind: String) -> String:
    return out_a if kind == filter_kind else out_b


func request_route_for_kind(kind: String, callback: Callable) -> void:
    _route_requests.append({"kind": kind, "callback": callback})
    _pump_route_requests()


func current_output() -> String:
    return out_a if state == 0 else out_b


func selected_state() -> int:
    return _target_state if _is_animating else state


func is_switching() -> bool:
    return _is_animating


func is_route_locked() -> bool:
    return not _planning_mode


func set_route_locked(_value: bool) -> void:
    # Runtime input is no longer a mechanic. Planning/run phase owns locking.
    pass


func set_hint_active(value: bool) -> void:
    _hint_active = value


func _pump_route_requests() -> void:
    if _is_animating or _route_requests.is_empty():
        return

    var request: Dictionary = _route_requests[0]
    var kind := String(request["kind"])
    var desired_state := 0 if kind == filter_kind else 1
    if desired_state == state:
        _finish_front_request()
        return
    _animate_to_state(desired_state)


func _finish_front_request() -> void:
    if _route_requests.is_empty():
        return
    var request: Dictionary = _route_requests.pop_front()
    var callback: Callable = request["callback"]
    if callback.is_valid():
        callback.call(current_output())
    call_deferred("_pump_route_requests")


func _animate_to_state(next_state: int) -> void:
    _target_state = next_state & 1
    _is_animating = true
    AudioService.play("tap", 0.92, -10.0)

    if _route_halo != null:
        _route_halo.visible = true
        _route_halo.scale = Vector3(0.86, 1.0, 0.86)
        var halo_tween := Motion.tween(_route_halo)
        halo_tween.tween_property(_route_halo, "scale", Vector3.ONE * 1.04, 0.10)
        halo_tween.tween_property(_route_halo, "scale", Vector3.ONE, 0.08)

    var target_angle := _angle_for_state(_target_state)
    var tween := Motion.tween(self)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(_switch_arm, "rotation:y", target_angle, 0.20)
    tween.finished.connect(_on_route_animation_finished)


# Compatibility helper used by the existing visual test.
func _perform_toggle(next_state: int) -> void:
    if _is_animating:
        return
    _animate_to_state(next_state)


func _on_route_animation_finished() -> void:
    state = _target_state
    _is_animating = false
    if _route_halo != null:
        var hide_tween := Motion.tween(_route_halo)
        hide_tween.tween_property(_route_halo, "scale", Vector3.ONE * 0.88, 0.07)
        hide_tween.finished.connect(func() -> void:
            if _route_halo != null:
                _route_halo.visible = false
                _route_halo.scale = Vector3.ONE
        )
    _finish_front_request()


# Compatibility alias for old tests.
func _on_toggle_finished() -> void:
    if _is_animating:
        state = _target_state
        _is_animating = false
    _finish_front_request()


func _target_angle() -> float:
    return _angle_for_state(selected_state())


func _angle_for_state(route_state: int) -> float:
    var direction := _direction_for_state(route_state)
    return atan2(direction.x, direction.z)


func _direction_for_state(route_state: int) -> Vector3:
    var target_id := out_a if route_state == 0 else out_b
    if not _positions.has(target_id):
        return Vector3.FORWARD

    var start: Vector3 = _positions.get(junction_id, position)
    var finish: Vector3 = _positions[target_id]
    var path := TrackGeometry.path_for(junction_id, target_id, start, finish)
    var dir := finish - start
    if path.size() >= 2:
        var sample := TrackGeometry.sample_distance(path, minf(SWITCH_REACH, TrackGeometry.length(path)))
        dir = (sample["position"] as Vector3) - start
    dir.y = 0.0
    if dir.length_squared() < 0.0001:
        return Vector3.FORWARD
    return dir.normalized()


func _snap_switch() -> void:
    if _switch_arm != null:
        _switch_arm.rotation.y = _angle_for_state(state)


func _rebuild_rule_markers() -> void:
    if _rule_markers == null:
        return
    for child in _rule_markers.get_children():
        _rule_markers.remove_child(child)
        child.queue_free()

    var a_dir := _direction_for_state(0)
    var b_dir := _direction_for_state(1)
    _add_rule_dot(_rule_markers, a_dir * 0.86 + Vector3(0, 0.36, 0), filter_kind, 0.18, true)

    var others: Array = []
    for option in _filter_options:
        if String(option) != filter_kind:
            others.append(String(option))
    var side := Vector3(b_dir.z, 0.0, -b_dir.x).normalized()
    if others.size() == 1:
        _add_rule_dot(_rule_markers, b_dir * 0.86 + Vector3(0, 0.34, 0), String(others[0]), 0.15, false)
    else:
        for i in range(others.size()):
            var offset := (float(i) - float(others.size() - 1) * 0.5) * 0.27
            _add_rule_dot(_rule_markers, b_dir * 0.86 + side * offset + Vector3(0, 0.34, 0), String(others[i]), 0.13, false)


func _add_rule_dot(parent: Node3D, pos: Vector3, kind: String, radius: float, primary: bool) -> void:
    if primary:
        var ring := MeshInstance3D.new()
        var ring_mesh := CylinderMesh.new()
        ring_mesh.top_radius = radius * 1.38
        ring_mesh.bottom_radius = radius * 1.38
        ring_mesh.height = 0.035
        ring_mesh.radial_segments = 20
        ring.mesh = ring_mesh
        ring.position = pos + Vector3(0, -0.025, 0)
        ring.material_override = VisualFactory.material(Color("#FFF7EA"), 0.55)
        parent.add_child(ring)

    var dot := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 16
    mesh.rings = 8
    dot.mesh = mesh
    dot.position = pos
    dot.material_override = VisualFactory.material(VisualFactory.kind_color(kind), 0.24)
    parent.add_child(dot)


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

    _rule_markers = Node3D.new()
    _rule_markers.name = "RoutingRuleMarkers"
    add_child(_rule_markers)

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

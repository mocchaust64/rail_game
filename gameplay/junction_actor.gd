class_name JunctionActor
extends Node3D

var junction_id: String = ""
var out_a: String = ""
var out_b: String = ""
var state: int = 0

var _pointer: Node3D
var _hint_ring: MeshInstance3D
var _base_disc: MeshInstance3D
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
    _snap_pointer()


func _process(delta: float) -> void:
    _clock += delta
    if _hint_ring != null:
        if _hint_active:
            var pulse := 1.0 + sin(_clock * 5.0) * 0.10
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

    if _base_disc != null:
        var press_tween := Motion.tween(_base_disc)
        press_tween.tween_property(_base_disc, "scale", Vector3(0.93, 0.84, 0.93), 0.055)
        press_tween.tween_property(_base_disc, "scale", Vector3.ONE, 0.085)

    var target_angle := _target_angle()
    var tween := Motion.tween(self)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_pointer, "rotation:y", target_angle, 0.145)
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
        dir = path[1] - path[0]
    if dir.length_squared() < 0.0001:
        return 0.0
    dir = dir.normalized()
    return atan2(dir.x, dir.z)


func _snap_pointer() -> void:
    if _pointer != null:
        _pointer.rotation.y = _target_angle()


func _build_visual() -> void:
    # Compact turntable integrated into the conveyor rather than a large glowing
    # gameplay disc. The arrow remains high-contrast because it is the tap target.
    _base_disc = MeshInstance3D.new()
    var base_mesh := CylinderMesh.new()
    base_mesh.top_radius = 0.46
    base_mesh.bottom_radius = 0.49
    base_mesh.height = 0.18
    base_mesh.radial_segments = 24
    _base_disc.mesh = base_mesh
    _base_disc.position.y = 0.18
    _base_disc.material_override = VisualFactory.material(Color("#555754"), 0.48, 0.0, 0.12)
    add_child(_base_disc)

    var cap := MeshInstance3D.new()
    var cap_mesh := CylinderMesh.new()
    cap_mesh.top_radius = 0.34
    cap_mesh.bottom_radius = 0.34
    cap_mesh.height = 0.08
    cap_mesh.radial_segments = 24
    cap.mesh = cap_mesh
    cap.position.y = 0.31
    cap.material_override = VisualFactory.material(Color("#B8B6AF"), 0.34, 0.0, 0.20)
    add_child(cap)

    # Four small roller dots make this read as part of a conveyor mechanism.
    for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
        var roller := MeshInstance3D.new()
        var roller_mesh := CylinderMesh.new()
        roller_mesh.top_radius = 0.055
        roller_mesh.bottom_radius = 0.055
        roller_mesh.height = 0.055
        roller_mesh.radial_segments = 12
        roller.mesh = roller_mesh
        roller.position = Vector3(sin(angle) * 0.31, 0.365, cos(angle) * 0.31)
        roller.material_override = VisualFactory.material(Color("#777A76"), 0.30, 0.0, 0.18)
        add_child(roller)

    _hint_ring = MeshInstance3D.new()
    var hint_mesh := TorusMesh.new()
    hint_mesh.inner_radius = 0.54
    hint_mesh.outer_radius = 0.61
    hint_mesh.rings = 24
    hint_mesh.ring_segments = 8
    _hint_ring.mesh = hint_mesh
    _hint_ring.position.y = 0.22
    _hint_ring.material_override = VisualFactory.material(Color("#FFF1A8"), 0.32, 0.55)
    _hint_ring.visible = false
    add_child(_hint_ring)

    _pointer = Node3D.new()
    _pointer.position.y = 0.30
    add_child(_pointer)

    var stem := MeshInstance3D.new()
    var stem_mesh := BoxMesh.new()
    stem_mesh.size = Vector3(0.12, 0.09, 0.48)
    stem.mesh = stem_mesh
    stem.position = Vector3(0, 0.055, 0.18)
    stem.material_override = VisualFactory.material(Color("#F7F4EC"), 0.28, 0.04)
    _pointer.add_child(stem)

    var tip := MeshInstance3D.new()
    var tip_mesh := CylinderMesh.new()
    tip_mesh.radial_segments = 3
    tip_mesh.top_radius = 0.19
    tip_mesh.bottom_radius = 0.19
    tip_mesh.height = 0.10
    tip.mesh = tip_mesh
    tip.position = Vector3(0, 0.055, 0.46)
    tip.rotation = Vector3(PI * 0.5, 0, 0)
    tip.material_override = VisualFactory.material(Color("#F7F4EC"), 0.28, 0.04)
    _pointer.add_child(tip)

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
    var target_pos: Vector3 = _positions[target_id]
    var dir := (target_pos - global_position).normalized()
    return atan2(dir.x, dir.z)

func _snap_pointer() -> void:
    if _pointer != null:
        _pointer.rotation.y = _target_angle()

func _build_visual() -> void:
    # Compact mechanical turntable. The old 0.72-unit green disc was visually
    # larger than the cargo and became the main subject of the frame.
    _base_disc = MeshInstance3D.new()
    var base_mesh := CylinderMesh.new()
    base_mesh.top_radius = 0.46
    base_mesh.bottom_radius = 0.49
    base_mesh.height = 0.18
    base_mesh.radial_segments = 24
    _base_disc.mesh = base_mesh
    _base_disc.position.y = 0.18
    _base_disc.material_override = VisualFactory.material(Color("#5B5B58"), 0.50, 0.0, 0.10)
    add_child(_base_disc)

    var cap := MeshInstance3D.new()
    var cap_mesh := CylinderMesh.new()
    cap_mesh.top_radius = 0.34
    cap_mesh.bottom_radius = 0.34
    cap_mesh.height = 0.08
    cap_mesh.radial_segments = 24
    cap.mesh = cap_mesh
    cap.position.y = 0.31
    cap.material_override = VisualFactory.material(Color("#B5B4AE"), 0.36, 0.0, 0.18)
    add_child(cap)

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
    stem.material_override = VisualFactory.material(Color("#F4F1E9"), 0.30)
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
    tip.material_override = VisualFactory.material(Color("#F4F1E9"), 0.30)
    _pointer.add_child(tip)

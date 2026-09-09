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
            var pulse := 1.0 + sin(_clock * 5.0) * 0.12
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
        var press_tween := _base_disc.create_tween()
        press_tween.tween_property(_base_disc, "scale", Vector3(0.93, 0.82, 0.93), 0.055)
        press_tween.tween_property(_base_disc, "scale", Vector3.ONE, 0.085)

    var target_angle := _target_angle()
    var tween := create_tween()
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
    _base_disc = MeshInstance3D.new()
    var base_mesh := CylinderMesh.new()
    base_mesh.top_radius = 0.72
    base_mesh.bottom_radius = 0.72
    base_mesh.height = 0.22
    base_mesh.radial_segments = 24
    _base_disc.mesh = base_mesh
    _base_disc.position.y = 0.19
    _base_disc.material_override = VisualFactory.material(VisualFactory.MACHINE_DARK, 0.62)
    add_child(_base_disc)

    var accent := MeshInstance3D.new()
    var accent_mesh := CylinderMesh.new()
    accent_mesh.top_radius = 0.58
    accent_mesh.bottom_radius = 0.58
    accent_mesh.height = 0.10
    accent_mesh.radial_segments = 24
    accent.mesh = accent_mesh
    accent.position.y = 0.35
    accent.material_override = VisualFactory.material(VisualFactory.GREEN_ACCENT, 0.38, 0.14)
    add_child(accent)

    _hint_ring = MeshInstance3D.new()
    var hint_mesh := CylinderMesh.new()
    hint_mesh.top_radius = 0.88
    hint_mesh.bottom_radius = 0.88
    hint_mesh.height = 0.035
    hint_mesh.radial_segments = 32
    _hint_ring.mesh = hint_mesh
    _hint_ring.position.y = 0.31
    _hint_ring.material_override = VisualFactory.material(Color("#FFF5C8"), 0.45, 0.30)
    _hint_ring.visible = false
    add_child(_hint_ring)

    _pointer = Node3D.new()
    _pointer.position.y = 0.10
    add_child(_pointer)

    var stem := MeshInstance3D.new()
    var stem_mesh := BoxMesh.new()
    stem_mesh.size = Vector3(0.18, 0.14, 0.72)
    stem.mesh = stem_mesh
    stem.position = Vector3(0, 0.34, 0.27)
    stem.material_override = VisualFactory.material(Color("#FFFFFF"), 0.35, 0.12)
    _pointer.add_child(stem)

    var tip := MeshInstance3D.new()
    var tip_mesh := CylinderMesh.new()
    tip_mesh.radial_segments = 3
    tip_mesh.top_radius = 0.30
    tip_mesh.bottom_radius = 0.30
    tip_mesh.height = 0.16
    tip.mesh = tip_mesh
    tip.position = Vector3(0, 0.34, 0.68)
    tip.rotation = Vector3(PI * 0.5, 0, 0)
    tip.material_override = VisualFactory.material(Color("#FFFFFF"), 0.35, 0.12)
    _pointer.add_child(tip)

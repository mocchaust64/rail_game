class_name JunctionActor
extends Node3D

const KENNEY_CONVEYOR: Mesh = preload("res://assets/vendor/kenney_factory_kit/conveyor_middle_cc0.obj")

var junction_id: String = ""
var out_a: String = ""
var out_b: String = ""
var state: int = 0

var _switch_arm: Node3D
var _hint_ring: MeshInstance3D
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

    # The rail itself changes route. There is deliberately no arrow icon: the
    # physical connection is the route indicator, matching the reference game.
    var target_angle := _target_angle()
    var tween := Motion.tween(self)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_switch_arm, "rotation:y", target_angle, 0.14)
    tween.parallel().tween_property(_switch_arm, "scale", Vector3(1.04, 0.92, 1.04), 0.06)
    tween.chain().tween_property(_switch_arm, "scale", Vector3.ONE, 0.08)
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


func _snap_switch() -> void:
    if _switch_arm != null:
        _switch_arm.rotation.y = _target_angle()


func _build_visual() -> void:
    # Small neutral pivot under the conveyor. It is intentionally quieter than
    # cargo/receivers so the selected physical rail, not a button, reads first.
    var hub := MeshInstance3D.new()
    var hub_mesh := CylinderMesh.new()
    hub_mesh.top_radius = 0.30
    hub_mesh.bottom_radius = 0.33
    hub_mesh.height = 0.11
    hub_mesh.radial_segments = 24
    hub.mesh = hub_mesh
    hub.position.y = 0.13
    hub.material_override = VisualFactory.material(Color("#565954"), 0.52, 0.0, 0.10)
    add_child(hub)

    _switch_arm = Node3D.new()
    _switch_arm.name = "PhysicalSwitchRail"
    add_child(_switch_arm)

    # Kenney's authored conveyor segment is the visible hardware base. It is
    # scaled into the 0.52-unit visual gap left by LevelBuilder.
    var authored := MeshInstance3D.new()
    authored.name = "KenneySwitchHardware"
    authored.mesh = KENNEY_CONVEYOR
    authored.scale = Vector3(1.42, 0.30, 0.56)
    authored.position = Vector3(0, 0.115, 0.27)
    authored.material_override = VisualFactory.material(Color("#777A76"), 0.40, 0.0, 0.15)
    _switch_arm.add_child(authored)

    var belt := MeshInstance3D.new()
    var belt_mesh := BoxMesh.new()
    belt_mesh.size = Vector3(0.64, 0.10, 0.58)
    belt.mesh = belt_mesh
    belt.position = Vector3(0, 0.245, 0.28)
    belt.material_override = VisualFactory.material(VisualFactory.BELT_COLOR, 0.66)
    _switch_arm.add_child(belt)

    for side in [-0.43, 0.43]:
        var rail := MeshInstance3D.new()
        var rail_mesh := BoxMesh.new()
        rail_mesh.size = Vector3(0.075, 0.15, 0.60)
        rail.mesh = rail_mesh
        rail.position = Vector3(float(side), 0.325, 0.28)
        rail.material_override = VisualFactory.material(VisualFactory.RAIL_COLOR, 0.30, 0.0, 0.20)
        _switch_arm.add_child(rail)

    for z in [0.11, 0.29, 0.47]:
        var slat := MeshInstance3D.new()
        var slat_mesh := BoxMesh.new()
        slat_mesh.size = Vector3(0.55, 0.022, 0.04)
        slat.mesh = slat_mesh
        slat.position = Vector3(0, 0.305, float(z))
        slat.material_override = VisualFactory.material(VisualFactory.BELT_SLAT, 0.56)
        _switch_arm.add_child(slat)

    # Tutorial-only pulse. The normal game has no floating arrow or giant disc.
    _hint_ring = MeshInstance3D.new()
    var hint_mesh := TorusMesh.new()
    hint_mesh.inner_radius = 0.43
    hint_mesh.outer_radius = 0.50
    hint_mesh.rings = 24
    hint_mesh.ring_segments = 8
    _hint_ring.mesh = hint_mesh
    _hint_ring.position.y = 0.20
    _hint_ring.material_override = VisualFactory.material(Color("#FFF1A8"), 0.32, 0.55)
    _hint_ring.visible = false
    add_child(_hint_ring)

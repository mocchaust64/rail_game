class_name SourceActor
extends Node3D

var source_id: String = ""
var _shell: Node3D
var _ring: MeshInstance3D
var _preview_anchor: Node3D
var _preview_visual: Node3D
var _feeder: Node3D
var _clock: float = 0.0


func configure(id_value: String) -> void:
    source_id = id_value
    _shell = MachineVisuals.create_source_shell(self)
    _ring = _shell.get_node_or_null("LaunchRing") as MeshInstance3D

    _build_feeder()

    _preview_anchor = Node3D.new()
    _preview_anchor.name = "NextCargoPreview"
    _preview_anchor.position = Vector3(0, 0.53, -0.62)
    add_child(_preview_anchor)


func set_preview(kind: String) -> void:
    if _preview_anchor == null:
        return
    if _preview_visual != null and is_instance_valid(_preview_visual):
        _preview_anchor.remove_child(_preview_visual)
        _preview_visual.queue_free()
        _preview_visual = null
    if kind.is_empty():
        return
    _preview_visual = VisualFactory.create_kind_visual(kind, 0.25)
    _preview_anchor.add_child(_preview_visual)


func _process(delta: float) -> void:
    _clock += delta
    if _ring != null:
        var pulse := 1.0 + sin(_clock * 2.4) * 0.025
        _ring.scale = Vector3(pulse, 1.0, pulse)
    if _preview_anchor != null:
        _preview_anchor.rotation.y = sin(_clock * 1.25) * 0.035


func react_launch() -> void:
    if _shell == null:
        return
    var tween := Motion.tween(_shell)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_shell, "scale", Vector3(1.035, 0.91, 1.035), 0.065)
    tween.tween_property(_shell, "scale", Vector3.ONE, 0.11)


func _build_feeder() -> void:
    _feeder = Node3D.new()
    _feeder.name = "FeederLane"
    add_child(_feeder)

    var lane := MeshInstance3D.new()
    var lane_mesh := BoxMesh.new()
    lane_mesh.size = Vector3(0.92, 0.13, 2.25)
    lane.mesh = lane_mesh
    lane.position = Vector3(0, 0.17, -1.05)
    lane.material_override = VisualFactory.material(Color("#4E504D"), 0.64)
    _feeder.add_child(lane)

    var belt := MeshInstance3D.new()
    var belt_mesh := BoxMesh.new()
    belt_mesh.size = Vector3(0.64, 0.06, 2.06)
    belt.mesh = belt_mesh
    belt.position = Vector3(0, 0.27, -1.05)
    belt.material_override = VisualFactory.material(VisualFactory.BELT_COLOR, 0.68)
    _feeder.add_child(belt)

    for side in [-0.43, 0.43]:
        var rail := MeshInstance3D.new()
        var rail_mesh := BoxMesh.new()
        rail_mesh.size = Vector3(0.065, 0.15, 2.22)
        rail.mesh = rail_mesh
        rail.position = Vector3(float(side), 0.31, -1.05)
        rail.material_override = VisualFactory.material(VisualFactory.RAIL_COLOR, 0.30, 0.0, 0.18)
        _feeder.add_child(rail)

    for z in [-0.62, -1.13, -1.64]:
        var slot := MeshInstance3D.new()
        var slot_mesh := CylinderMesh.new()
        slot_mesh.top_radius = 0.25
        slot_mesh.bottom_radius = 0.25
        slot_mesh.height = 0.025
        slot_mesh.radial_segments = 20
        slot.mesh = slot_mesh
        slot.position = Vector3(0, 0.315, float(z))
        slot.material_override = VisualFactory.material(Color("#383A38"), 0.72)
        _feeder.add_child(slot)

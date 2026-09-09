class_name SourceActor
extends Node3D

const MAX_VISIBLE_QUEUE := 8

var source_id: String = ""
var _shell: Node3D
var _preview_layer: Node3D
var _preview_visuals: Array[Node3D] = []
var _feeder: Node3D
var _clock: float = 0.0


func configure(id_value: String) -> void:
    source_id = id_value

    _shell = Node3D.new()
    _shell.name = "FeederSource"
    add_child(_shell)
    _build_feeder()

    _preview_layer = Node3D.new()
    _preview_layer.name = "UpcomingCargoOnRails"
    add_child(_preview_layer)


func set_preview(kind: String) -> void:
    var kinds: Array = []
    if not kind.is_empty():
        kinds.append(kind)
    set_preview_queue(kinds)


func set_preview_queue(kinds: Array) -> void:
    if _preview_layer == null:
        return
    for visual in _preview_visuals:
        if visual != null and is_instance_valid(visual):
            visual.queue_free()
    _preview_visuals.clear()

    var lane_offsets := [-1.52, -0.76, 0.0, 0.76, 1.52]
    var visible_count := mini(MAX_VISIBLE_QUEUE, kinds.size())
    for i in range(visible_count):
        var lane_index := i % lane_offsets.size()
        var row := i / lane_offsets.size()
        var visual := VisualFactory.create_kind_visual(String(kinds[i]), 0.27)
        visual.position = Vector3(
            float(lane_offsets[lane_index]),
            0.47,
            -0.52 - float(row) * 0.62
        )
        _preview_layer.add_child(visual)
        _preview_visuals.append(visual)


func _process(delta: float) -> void:
    _clock += delta
    if _preview_layer != null:
        # Keep queued cargo physically planted. Only a barely visible turn stops
        # the bank feeling frozen while avoiding the old floating-preview look.
        _preview_layer.rotation.y = sin(_clock * 1.1) * 0.006


func react_launch() -> void:
    if _feeder == null:
        return
    var tween := Motion.tween(_feeder)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_feeder, "scale", Vector3(1.015, 0.94, 1.015), 0.055)
    tween.tween_property(_feeder, "scale", Vector3.ONE, 0.09)


func _build_feeder() -> void:
    _feeder = Node3D.new()
    _feeder.name = "FiveLaneFeederBank"
    _shell.add_child(_feeder)

    var lane_offsets := [-1.52, -0.76, 0.0, 0.76, 1.52]
    for raw_x in lane_offsets:
        var x := float(raw_x)
        var lane_root := Node3D.new()
        lane_root.position.x = x
        _feeder.add_child(lane_root)

        var bed := MeshInstance3D.new()
        var bed_mesh := BoxMesh.new()
        bed_mesh.size = Vector3(0.58, 0.11, 2.75)
        bed.mesh = bed_mesh
        bed.position = Vector3(0, 0.12, -1.22)
        bed.material_override = VisualFactory.material(Color("#4E5153"), 0.64, 0.0, 0.04)
        lane_root.add_child(bed)

        var inner := MeshInstance3D.new()
        var inner_mesh := BoxMesh.new()
        inner_mesh.size = Vector3(0.40, 0.045, 2.62)
        inner.mesh = inner_mesh
        inner.position = Vector3(0, 0.205, -1.22)
        inner.material_override = VisualFactory.material(Color("#343638"), 0.76)
        lane_root.add_child(inner)

        for side in [-0.25, 0.25]:
            var rail := MeshInstance3D.new()
            var rail_mesh := BoxMesh.new()
            rail_mesh.size = Vector3(0.055, 0.09, 2.72)
            rail.mesh = rail_mesh
            rail.position = Vector3(float(side), 0.265, -1.22)
            rail.material_override = VisualFactory.material(Color("#D7D4CC"), 0.24, 0.0, 0.34)
            lane_root.add_child(rail)

        for z in [-0.42, -0.92, -1.42, -1.92]:
            var sleeper := MeshInstance3D.new()
            var sleeper_mesh := BoxMesh.new()
            sleeper_mesh.size = Vector3(0.49, 0.028, 0.06)
            sleeper.mesh = sleeper_mesh
            sleeper.position = Vector3(0, 0.235, float(z))
            sleeper.material_override = VisualFactory.material(Color("#737576"), 0.54, 0.0, 0.08)
            lane_root.add_child(sleeper)

    var mouth_bar := MeshInstance3D.new()
    var mouth_mesh := BoxMesh.new()
    mouth_mesh.size = Vector3(3.62, 0.08, 0.18)
    mouth_bar.mesh = mouth_mesh
    mouth_bar.position = Vector3(0, 0.10, 0.13)
    mouth_bar.material_override = VisualFactory.material(Color("#55585A"), 0.62, 0.0, 0.04)
    _feeder.add_child(mouth_bar)

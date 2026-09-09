class_name SourceActor
extends Node3D

const MAX_VISIBLE_QUEUE := 8

var source_id: String = ""
var _source_style := "compact"
var _shell: Node3D
var _preview_layer: Node3D
var _preview_visuals: Array[Node3D] = []
var _feeder: Node3D
var _clock: float = 0.0


func configure(id_value: String, style: String = "compact") -> void:
    source_id = id_value
    _source_style = style

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

    var lane_offsets := _lane_offsets()
    var max_count := MAX_VISIBLE_QUEUE if _source_style == "bank" else 3
    var visible_count := mini(max_count, kinds.size())
    for i in range(visible_count):
        var lane_index := i % lane_offsets.size()
        var row := i / lane_offsets.size()
        var visual := VisualFactory.create_kind_visual(String(kinds[i]), 0.27)
        visual.position = Vector3(
            float(lane_offsets[lane_index]),
            0.44,
            -0.48 - float(row) * 0.58
        )
        _preview_layer.add_child(visual)
        _preview_visuals.append(visual)


func _process(delta: float) -> void:
    _clock += delta
    if _preview_layer != null:
        _preview_layer.rotation.y = sin(_clock * 1.1) * 0.004


func react_launch() -> void:
    if _feeder == null:
        return
    var tween := Motion.tween(_feeder)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(_feeder, "scale", Vector3(1.01, 0.96, 1.01), 0.05)
    tween.tween_property(_feeder, "scale", Vector3.ONE, 0.08)


func _lane_offsets() -> Array:
    if _source_style == "bank":
        return [-1.52, -0.76, 0.0, 0.76, 1.52]
    return [0.0]


func _build_feeder() -> void:
    _feeder = Node3D.new()
    _feeder.name = "ReferenceFeederBank" if _source_style == "bank" else "ReferenceFeederLane"
    _shell.add_child(_feeder)

    for raw_x in _lane_offsets():
        var lane_root := Node3D.new()
        lane_root.position.x = float(raw_x)
        _feeder.add_child(lane_root)
        var lane_points := PackedVector3Array([
            Vector3(0.0, 0.0, 0.08),
            Vector3(0.0, 0.0, -0.70),
            Vector3(0.0, 0.0, -1.55),
            Vector3(0.0, 0.0, -2.55),
        ])
        TrackVisuals.create_path(lane_root, lane_points, 0.0, 0.0, true, true)

    if _source_style == "bank":
        # A quiet shared footer visually groups the five lanes like the target.
        var footer := MeshInstance3D.new()
        var footer_mesh := BoxMesh.new()
        footer_mesh.size = Vector3(3.72, 0.07, 0.16)
        footer.mesh = footer_mesh
        footer.position = Vector3(0, 0.04, 0.10)
        footer.material_override = VisualFactory.material(Color("#707476"), 0.62, 0.0, 0.04)
        _feeder.add_child(footer)

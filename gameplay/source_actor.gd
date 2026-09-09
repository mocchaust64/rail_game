class_name SourceActor
extends Node3D

var source_id: String = ""
var _shell: Node3D
var _ring: MeshInstance3D
var _preview_anchor: Node3D
var _preview_visual: Node3D
var _clock: float = 0.0

func configure(id_value: String) -> void:
    source_id = id_value
    _shell = VisualFactory.create_source_shell(self)
    # The second child is the green launch ring created by the visual factory.
    if _shell.get_child_count() > 1:
        _ring = _shell.get_child(1) as MeshInstance3D

    _preview_anchor = Node3D.new()
    _preview_anchor.name = "NextCargoPreview"
    _preview_anchor.position = Vector3(0, 1.28, 0)
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
    _preview_visual = VisualFactory.create_kind_visual(kind, 0.22)
    _preview_visual.scale = Vector3.ONE * 0.92
    _preview_anchor.add_child(_preview_visual)

func _process(delta: float) -> void:
    _clock += delta
    if _ring != null:
        var pulse := 1.0 + sin(_clock * 2.5) * 0.035
        _ring.scale = Vector3(pulse, 1.0, pulse)
    if _preview_anchor != null:
        _preview_anchor.position.y = 1.28 + sin(_clock * 2.2) * 0.035
        _preview_anchor.rotation.y = sin(_clock * 1.45) * 0.10

func react_launch() -> void:
    if _shell == null:
        return
    var tween := _shell.create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(_shell, "scale", Vector3(1.04, 0.92, 1.04), 0.07)
    tween.tween_property(_shell, "scale", Vector3.ONE, 0.12)

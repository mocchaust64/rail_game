class_name ReceiverActor
extends Node3D

var receiver_id: String = ""
var kind: String = ""
var _mouth: MeshInstance3D
var _badge_anchor: Node3D
var _lamp: MeshInstance3D
var _reaction_tween: Tween
var _idle_clock: float = 0.0

func configure(id_value: String, kind_value: String) -> void:
    receiver_id = id_value
    kind = kind_value
    var parts := VisualFactory.create_receiver_shell(self, kind)
    _mouth = parts["mouth"] as MeshInstance3D
    _badge_anchor = parts["badge_anchor"] as Node3D
    _lamp = parts["lamp"] as MeshInstance3D

func _process(delta: float) -> void:
    _idle_clock += delta
    if _badge_anchor != null:
        _badge_anchor.rotation.y = sin(_idle_clock * 1.25) * 0.08
        _badge_anchor.position.y = 1.48 + sin(_idle_clock * 2.0) * 0.025

func accept() -> void:
    _kill_reaction_tween()
    var base_scale := Vector3.ONE
    _reaction_tween = Motion.tween(self)
    _reaction_tween.set_parallel(true)
    _reaction_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _reaction_tween.tween_property(self, "scale", base_scale * 1.065, 0.10)
    if _mouth != null:
        _reaction_tween.tween_property(_mouth, "scale", Vector3(1.10, 0.78, 1.10), 0.10)
    _reaction_tween.chain().tween_property(self, "scale", base_scale, 0.14)
    if _mouth != null:
        _reaction_tween.parallel().tween_property(_mouth, "scale", Vector3.ONE, 0.14)
    VisualFactory.create_spark_burst(get_parent() as Node3D, global_position + Vector3(0, 1.0, 0), VisualFactory.kind_color(kind))

func reject() -> void:
    _kill_reaction_tween()
    var start := position
    _reaction_tween = Motion.tween(self)
    _reaction_tween.set_trans(Tween.TRANS_SINE)
    _reaction_tween.tween_property(self, "position:x", start.x - 0.09, 0.05)
    _reaction_tween.tween_property(self, "position:x", start.x + 0.09, 0.07)
    _reaction_tween.tween_property(self, "position:x", start.x, 0.06)
    if _lamp != null:
        var lamp_tween := Motion.tween(_lamp)
        lamp_tween.tween_property(_lamp, "scale", Vector3.ONE * 1.35, 0.08)
        lamp_tween.tween_property(_lamp, "scale", Vector3.ONE, 0.12)

func _kill_reaction_tween() -> void:
    if _reaction_tween != null and _reaction_tween.is_valid():
        _reaction_tween.kill()
    scale = Vector3.ONE

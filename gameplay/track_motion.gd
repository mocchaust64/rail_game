class_name TrackMotion
extends Node3D
# Subtle moving panel seams on the dark conveyor. The reference belt moves, but
# its motion is dark-on-dark rather than bright railroad sleepers sliding along.

const FLOW_SPEED := 0.72
const FLOW_SPACING := 0.34

var _points := PackedVector3Array()
var _path_length := 0.0
var _phase := 0.0
var _multi: MultiMesh


func setup(points: PackedVector3Array) -> void:
    _points = points
    _path_length = TrackGeometry.length(points)
    if _points.size() < 2 or _path_length < 0.08:
        return

    var count := maxi(2, int(ceil(_path_length / FLOW_SPACING)))
    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE
    mesh.material = VisualFactory.material(Color("#45484C"), 0.68)

    _multi = MultiMesh.new()
    _multi.transform_format = MultiMesh.TRANSFORM_3D
    _multi.mesh = mesh
    _multi.instance_count = count

    var instance := MultiMeshInstance3D.new()
    instance.name = "MovingBeltSeams"
    instance.multimesh = _multi
    add_child(instance)
    _update_transforms()


func _process(delta: float) -> void:
    if _multi == null or _path_length <= 0.0:
        return
    _phase = fmod(_phase + FLOW_SPEED * delta, _path_length)
    _update_transforms()


func _update_transforms() -> void:
    var count := _multi.instance_count
    for i in range(count):
        var distance := fmod(_phase + float(i) * _path_length / float(count), _path_length)
        var sample := TrackGeometry.sample_distance(_points, distance)
        var p: Vector3 = sample["position"]
        var tangent: Vector3 = sample["tangent"]
        var angle := atan2(tangent.x, tangent.z)
        var basis := Basis(Vector3.UP, angle).scaled(Vector3(0.56, 0.010, 0.028))
        _multi.set_instance_transform(i, Transform3D(basis, p + Vector3(0, 0.162, 0)))

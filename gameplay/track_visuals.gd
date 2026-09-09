class_name TrackVisuals
extends RefCounted
# Cheap curved conveyor renderer. A path is sampled into short boxes, but each
# layer is one MultiMeshInstance3D so a smooth curve does not become hundreds of
# scene nodes on mobile.

const BASE_WIDTH := 0.92
const BELT_WIDTH := 0.66
const RAIL_OFFSET := 0.43
const RAIL_WIDTH := 0.075


static func create_path(parent: Node3D, points: PackedVector3Array) -> Node3D:
    var root := Node3D.new()
    root.name = "CurvedConveyor"
    parent.add_child(root)
    if points.size() < 2:
        return root

    _segment_layer(
        root, "Base", points, BASE_WIDTH, 0.16, 0.025, 0.0, 0.08,
        VisualFactory.material(VisualFactory.MACHINE_DARK, 0.62, 0.0, 0.05)
    )
    _segment_layer(
        root, "Belt", points, BELT_WIDTH, 0.105, 0.145, 0.0, 0.025,
        VisualFactory.material(VisualFactory.BELT_COLOR, 0.68)
    )
    _rail_layer(root, points)
    _slat_layer(root, points)
    return root


static func _segment_layer(
    parent: Node3D,
    name_value: String,
    points: PackedVector3Array,
    width: float,
    height: float,
    y: float,
    lateral: float,
    overlap: float,
    mat: Material
) -> void:
    var count := points.size() - 1
    if count <= 0:
        return

    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE
    mesh.material = mat

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = count

    for i in range(count):
        var a := points[i]
        var b := points[i + 1]
        var delta := b - a
        var length := maxf(0.001, delta.length())
        var angle := atan2(delta.x, delta.z)
        var midpoint := (a + b) * 0.5
        var local_side := Vector3(lateral, 0, 0).rotated(Vector3.UP, angle)
        var basis := Basis(Vector3.UP, angle).scaled(Vector3(width, height, length + overlap))
        multi.set_instance_transform(i, Transform3D(basis, midpoint + Vector3(0, y, 0) + local_side))

    var instance := MultiMeshInstance3D.new()
    instance.name = name_value
    instance.multimesh = multi
    parent.add_child(instance)


static func _rail_layer(parent: Node3D, points: PackedVector3Array) -> void:
    var segment_count := points.size() - 1
    if segment_count <= 0:
        return

    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE
    mesh.material = VisualFactory.material(VisualFactory.RAIL_COLOR, 0.30, 0.0, 0.20)

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = segment_count * 2

    var index := 0
    for i in range(segment_count):
        var a := points[i]
        var b := points[i + 1]
        var delta := b - a
        var length := maxf(0.001, delta.length())
        var angle := atan2(delta.x, delta.z)
        var midpoint := (a + b) * 0.5
        for side in [-RAIL_OFFSET, RAIL_OFFSET]:
            var offset := Vector3(float(side), 0, 0).rotated(Vector3.UP, angle)
            var basis := Basis(Vector3.UP, angle).scaled(Vector3(RAIL_WIDTH, 0.15, length + 0.08))
            multi.set_instance_transform(index, Transform3D(basis, midpoint + Vector3(0, 0.235, 0) + offset))
            index += 1

    var instance := MultiMeshInstance3D.new()
    instance.name = "Rails"
    instance.multimesh = multi
    parent.add_child(instance)


static func _slat_layer(parent: Node3D, points: PackedVector3Array) -> void:
    # Every other sample is enough to read the belt direction, and halves the
    # instance count compared with a slat at every curve point.
    var indices: Array[int] = []
    for i in range(1, points.size() - 1, 2):
        indices.append(i)
    if indices.is_empty():
        return

    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE
    mesh.material = VisualFactory.material(VisualFactory.BELT_SLAT, 0.58)

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = indices.size()

    for instance_index in range(indices.size()):
        var i := indices[instance_index]
        var tangent := points[min(i + 1, points.size() - 1)] - points[max(i - 1, 0)]
        var angle := atan2(tangent.x, tangent.z)
        var basis := Basis(Vector3.UP, angle).scaled(Vector3(0.56, 0.025, 0.045))
        multi.set_instance_transform(instance_index, Transform3D(basis, points[i] + Vector3(0, 0.205, 0)))

    var instance := MultiMeshInstance3D.new()
    instance.name = "Slats"
    instance.multimesh = multi
    parent.add_child(instance)

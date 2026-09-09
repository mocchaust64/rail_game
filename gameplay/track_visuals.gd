class_name TrackVisuals
extends RefCounted
# Cheap curved conveyor renderer. Structural layers are continuous native strip
# meshes so curve samples cannot expose box corners; repeated slats stay batched.

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

    _strip_layer(
        root, "Base", points, BASE_WIDTH, 0.16, 0.025, [0.0],
        VisualFactory.material(VisualFactory.MACHINE_DARK, 0.62, 0.0, 0.05)
    )
    _strip_layer(
        root, "Belt", points, BELT_WIDTH, 0.105, 0.145, [0.0],
        VisualFactory.material(VisualFactory.BELT_COLOR, 0.68)
    )
    _strip_layer(
        root, "Rails", points, RAIL_WIDTH, 0.15, 0.235, [-RAIL_OFFSET, RAIL_OFFSET],
        VisualFactory.material(VisualFactory.RAIL_COLOR, 0.30, 0.0, 0.20)
    )
    _slat_layer(root, points)
    return root


static func _strip_layer(
    parent: Node3D,
    name_value: String,
    points: PackedVector3Array,
    width: float,
    height: float,
    y: float,
    laterals: Array,
    mat: Material
) -> void:
    if points.size() < 2:
        return

    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    tool.set_material(mat)
    for raw_lateral in laterals:
        _add_strip(tool, points, width, height, y, float(raw_lateral))
    tool.generate_normals()

    var instance := MeshInstance3D.new()
    instance.name = name_value
    instance.mesh = tool.commit()
    parent.add_child(instance)


static func _add_strip(tool: SurfaceTool, points: PackedVector3Array, width: float, height: float, y: float, lateral: float) -> void:
    var half_width := width * 0.5
    var half_height := height * 0.5
    var sections: Array[PackedVector3Array] = []
    for i in range(points.size()):
        var previous := points[maxi(0, i - 1)]
        var following := points[mini(points.size() - 1, i + 1)]
        var tangent := (following - previous).normalized()
        var side := Vector3(tangent.z, 0.0, -tangent.x).normalized()
        var centre := points[i] + side * lateral + Vector3(0.0, y, 0.0)
        sections.append(PackedVector3Array([
            centre - side * half_width + Vector3.DOWN * half_height,
            centre + side * half_width + Vector3.DOWN * half_height,
            centre - side * half_width + Vector3.UP * half_height,
            centre + side * half_width + Vector3.UP * half_height,
        ]))

    for i in range(sections.size() - 1):
        var a := sections[i]
        var b := sections[i + 1]
        _add_quad(tool, a[2], b[2], b[3], a[3])
        _add_quad(tool, a[1], b[1], b[0], a[0])
        _add_quad(tool, a[0], b[0], b[2], a[2])
        _add_quad(tool, a[3], b[3], b[1], a[1])
    var first := sections[0]
    var last := sections[sections.size() - 1]
    _add_quad(tool, first[1], first[0], first[2], first[3])
    _add_quad(tool, last[0], last[1], last[3], last[2])


static func _add_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    for vertex in [a, b, c, a, c, d]:
        tool.add_vertex(vertex)


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

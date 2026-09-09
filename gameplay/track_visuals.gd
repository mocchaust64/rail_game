class_name TrackVisuals
extends RefCounted
# Curved conveyor renderer. The continuous dark core keeps arbitrary curves
# smooth, while a CC0 Kenney conveyor mesh adds the authored factory detail the
# previous code-built rail was missing.

const KENNEY_CONVEYOR: Mesh = preload("res://assets/vendor/kenney_factory_kit/conveyor_middle_cc0.obj")

const BASE_WIDTH := 0.92
const BELT_WIDTH := 0.66
const RAIL_OFFSET := 0.43
const RAIL_WIDTH := 0.075
const KENNEY_SPACING := 0.72


static func create_path(parent: Node3D, points: PackedVector3Array, trim_start: float = 0.0, trim_end: float = 0.0) -> Node3D:
    var root := Node3D.new()
    root.name = "CurvedConveyor"
    parent.add_child(root)

    var visible_points := _trim_path(points, trim_start, trim_end)
    if visible_points.size() < 2:
        return root

    _strip_layer(
        root, "Base", visible_points, BASE_WIDTH, 0.16, 0.025, [0.0],
        VisualFactory.material(VisualFactory.MACHINE_DARK, 0.62, 0.0, 0.05)
    )
    _strip_layer(
        root, "Belt", visible_points, BELT_WIDTH, 0.105, 0.145, [0.0],
        VisualFactory.material(VisualFactory.BELT_COLOR, 0.68)
    )
    _strip_layer(
        root, "Rails", visible_points, RAIL_WIDTH, 0.15, 0.235, [-RAIL_OFFSET, RAIL_OFFSET],
        VisualFactory.material(VisualFactory.RAIL_COLOR, 0.30, 0.0, 0.20)
    )
    _slat_layer(root, visible_points)
    _kenney_detail_layer(root, visible_points)
    return root


static func _trim_path(points: PackedVector3Array, trim_start: float, trim_end: float) -> PackedVector3Array:
    if points.size() < 2 or (trim_start <= 0.001 and trim_end <= 0.001):
        return points

    var total := TrackGeometry.length(points)
    var start_distance := clampf(trim_start, 0.0, total)
    var end_distance := clampf(total - trim_end, 0.0, total)
    if end_distance - start_distance < 0.18:
        return points

    var result := PackedVector3Array()
    var start_sample := TrackGeometry.sample_distance(points, start_distance)
    result.append(start_sample["position"] as Vector3)

    var walked := 0.0
    for i in range(1, points.size()):
        walked += points[i - 1].distance_to(points[i])
        if walked > start_distance + 0.01 and walked < end_distance - 0.01:
            result.append(points[i])

    var end_sample := TrackGeometry.sample_distance(points, end_distance)
    result.append(end_sample["position"] as Vector3)
    return result


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


static func _kenney_detail_layer(parent: Node3D, points: PackedVector3Array) -> void:
    var total := TrackGeometry.length(points)
    var count := maxi(1, int(floor(total / KENNEY_SPACING)))
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = KENNEY_CONVEYOR
    multi.instance_count = count

    for i in range(count):
        var distance := (float(i) + 0.5) * total / float(count)
        var sample := TrackGeometry.sample_distance(points, distance)
        var p: Vector3 = sample["position"]
        var tangent: Vector3 = sample["tangent"]
        var angle := atan2(tangent.x, tangent.z)
        # The authored piece is used as subtle raised factory hardware over the
        # continuous rail, not as disconnected blocks. Keep it low and narrow.
        var basis := Basis(Vector3.UP, angle).scaled(Vector3(1.42, 0.26, maxf(0.34, total / float(count))))
        multi.set_instance_transform(i, Transform3D(basis, p + Vector3(0, 0.12, 0)))

    var instance := MultiMeshInstance3D.new()
    instance.name = "KenneyConveyorDetail"
    instance.multimesh = multi
    instance.material_override = VisualFactory.material(Color("#777A76"), 0.42, 0.0, 0.12)
    parent.add_child(instance)

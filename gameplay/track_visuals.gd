class_name TrackVisuals
extends RefCounted
# Reference track language:
# - smooth pale metal guide rails show every possible route
# - a dark conveyor belt occupies the connected route
# - no railroad sleepers/bolts
# - belt seams move continuously so the factory never feels static

const BELT_WIDTH := 0.64
const BELT_BASE_WIDTH := 0.74
const RAIL_OFFSET := 0.39
const RAIL_RADIUS := 0.055
const RAIL_HEIGHT := 0.19


static func create_path(
    parent: Node3D,
    points: PackedVector3Array,
    belt_trim_start: float = 0.0,
    belt_trim_end: float = 0.0,
    show_belt: bool = true,
    show_guides: bool = true
) -> Node3D:
    var root := Node3D.new()
    root.name = "ReferenceConveyorRoute"
    parent.add_child(root)
    if points.size() < 2:
        return root

    if show_guides:
        _tube_layer(
            root,
            "GuideRails",
            points,
            [-RAIL_OFFSET, RAIL_OFFSET],
            RAIL_RADIUS,
            RAIL_HEIGHT,
            VisualFactory.material(Color("#D6D8D5"), 0.25, 0.0, 0.24)
        )

    if show_belt:
        var belt_points := _trim_path(points, belt_trim_start, belt_trim_end)
        if belt_points.size() >= 2:
            _strip_layer(
                root,
                "BeltBase",
                belt_points,
                BELT_BASE_WIDTH,
                0.09,
                0.065,
                VisualFactory.material(Color("#6B6E70"), 0.62, 0.0, 0.04)
            )
            _strip_layer(
                root,
                "MovingBelt",
                belt_points,
                BELT_WIDTH,
                0.055,
                0.125,
                VisualFactory.material(Color("#34373B"), 0.72)
            )
            var motion := TrackMotion.new()
            motion.name = "BeltMotion"
            root.add_child(motion)
            motion.setup(belt_points)

    return root


static func _trim_path(points: PackedVector3Array, trim_start: float, trim_end: float) -> PackedVector3Array:
    if points.size() < 2 or (trim_start <= 0.001 and trim_end <= 0.001):
        return points

    var total := TrackGeometry.length(points)
    var start_distance := clampf(trim_start, 0.0, total)
    var end_distance := clampf(total - trim_end, 0.0, total)
    if end_distance - start_distance < 0.16:
        return PackedVector3Array()

    var result := PackedVector3Array()
    result.append((TrackGeometry.sample_distance(points, start_distance)["position"] as Vector3))

    var walked := 0.0
    for i in range(1, points.size()):
        walked += points[i - 1].distance_to(points[i])
        if walked > start_distance + 0.01 and walked < end_distance - 0.01:
            result.append(points[i])

    result.append((TrackGeometry.sample_distance(points, end_distance)["position"] as Vector3))
    return result


static func _strip_layer(
    parent: Node3D,
    name_value: String,
    points: PackedVector3Array,
    width: float,
    height: float,
    y: float,
    mat: Material
) -> void:
    if points.size() < 2:
        return

    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    tool.set_material(mat)
    _add_strip(tool, points, width, height, y)
    tool.generate_normals()

    var instance := MeshInstance3D.new()
    instance.name = name_value
    instance.mesh = tool.commit()
    parent.add_child(instance)


static func _add_strip(tool: SurfaceTool, points: PackedVector3Array, width: float, height: float, y: float) -> void:
    var half_width := width * 0.5
    var half_height := height * 0.5
    var sections: Array[PackedVector3Array] = []

    for i in range(points.size()):
        var tangent := _tangent_at(points, i)
        var side := Vector3(tangent.z, 0.0, -tangent.x).normalized()
        var centre := points[i] + Vector3(0.0, y, 0.0)
        sections.append(PackedVector3Array([
            centre - side * half_width + Vector3.DOWN * half_height,
            centre + side * half_width + Vector3.DOWN * half_height,
            centre - side * half_width + Vector3.UP * half_height,
            centre + side * half_width + Vector3.UP * half_height,
        ]))

    for i in range(sections.size() - 1):
        var a := sections[i]
        var b := sections[i + 1]
        _quad(tool, a[2], b[2], b[3], a[3])
        _quad(tool, a[1], b[1], b[0], a[0])
        _quad(tool, a[0], b[0], b[2], a[2])
        _quad(tool, a[3], b[3], b[1], a[1])

    var first := sections[0]
    var last := sections[sections.size() - 1]
    _quad(tool, first[1], first[0], first[2], first[3])
    _quad(tool, last[0], last[1], last[3], last[2])


static func _tube_layer(
    parent: Node3D,
    name_value: String,
    points: PackedVector3Array,
    laterals: Array,
    radius: float,
    y: float,
    mat: Material
) -> void:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    tool.set_material(mat)

    for raw_lateral in laterals:
        _add_tube(tool, points, float(raw_lateral), radius, y)

    tool.generate_normals()
    var instance := MeshInstance3D.new()
    instance.name = name_value
    instance.mesh = tool.commit()
    parent.add_child(instance)


static func _add_tube(tool: SurfaceTool, points: PackedVector3Array, lateral: float, radius: float, y: float) -> void:
    const SIDES := 8
    var rings: Array[PackedVector3Array] = []

    for i in range(points.size()):
        var tangent := _tangent_at(points, i)
        var side := Vector3(tangent.z, 0.0, -tangent.x).normalized()
        var centre := points[i] + side * lateral + Vector3(0.0, y, 0.0)
        var ring := PackedVector3Array()
        for s in range(SIDES):
            var angle := TAU * float(s) / float(SIDES)
            ring.append(centre + side * cos(angle) * radius + Vector3.UP * sin(angle) * radius)
        rings.append(ring)

    for i in range(rings.size() - 1):
        var a := rings[i]
        var b := rings[i + 1]
        for s in range(SIDES):
            var n := (s + 1) % SIDES
            _quad(tool, a[s], b[s], b[n], a[n])


static func _tangent_at(points: PackedVector3Array, index: int) -> Vector3:
    var previous := points[maxi(0, index - 1)]
    var following := points[mini(points.size() - 1, index + 1)]
    var tangent := following - previous
    tangent.y = 0.0
    if tangent.length_squared() < 0.0001:
        tangent = Vector3.FORWARD
    return tangent.normalized()


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    for vertex in [a, b, c, a, c, d]:
        tool.add_vertex(vertex)

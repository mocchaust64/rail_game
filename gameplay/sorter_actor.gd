class_name SorterActor
extends Node3D

const KINDS := ["red", "blue", "yellow"]

var sorter_id: String = ""
var is_built: bool = false
var build_cost: int = 3

var _outputs: Array[String] = ["", "", ""]
var _mapping: Array[String] = ["red", "blue", "yellow"]
var _positions: Dictionary = {}
var _planning_mode: bool = true
var _selected: bool = false
var _foundation: Node3D
var _house: Node3D
var _active_tracks: Node3D
var _marker_root: Node3D
var _selection_ring: MeshInstance3D
var _route_queue: Array[Dictionary] = []
var _is_routing: bool = false


func configure(data: Dictionary, positions: Dictionary, default_cost: int) -> void:
    sorter_id = String(data["id"])
    build_cost = int(data.get("build_cost", default_cost))
    _positions = positions
    _outputs = [
        String(data["out_1"]),
        String(data["out_2"]),
        String(data["out_3"]),
    ]

    var raw_mapping: Array = data.get("mapping", KINDS)
    _mapping = []
    for kind in raw_mapping:
        _mapping.append(String(kind))
    if _mapping.size() != 3 or not _mapping_is_valid():
        _mapping = ["red", "blue", "yellow"]

    _build_foundation()
    _build_selection_ring()

    if bool(data.get("prebuilt", false)):
        build()
    else:
        _refresh_selection()


func set_planning_mode(value: bool) -> void:
    _planning_mode = value
    if not value:
        set_selected(false)


func set_selected(value: bool) -> void:
    _selected = value
    _refresh_selection()


func build() -> bool:
    if is_built:
        return false
    is_built = true
    if _foundation != null:
        _foundation.visible = false

    _house = Node3D.new()
    _house.name = "SorterHouse"
    _house.scale = Vector3.ONE * 0.15
    add_child(_house)
    _build_house_visual(_house)

    _active_tracks = Node3D.new()
    _active_tracks.name = "ActiveSorterBelts"
    add_child(_active_tracks)
    _build_active_tracks()

    _marker_root = Node3D.new()
    _marker_root.name = "SorterLaneMarkers"
    add_child(_marker_root)
    _rebuild_markers()

    var tween := Motion.tween(_house)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_house, "scale", Vector3.ONE, 0.22)
    AudioService.play("tap", 0.88, -5.0)
    HapticService.medium()
    _refresh_selection()
    return true


func demolish() -> bool:
    if not is_built or not _planning_mode:
        return false
    is_built = false
    _route_queue.clear()
    _is_routing = false
    for node in [_house, _active_tracks, _marker_root]:
        if node != null and is_instance_valid(node):
            node.queue_free()
    _house = null
    _active_tracks = null
    _marker_root = null
    if _foundation != null:
        _foundation.visible = true
    AudioService.play("tap", 0.78, -8.0)
    HapticService.light()
    _refresh_selection()
    return true


func cycle_lane(output_index: int) -> bool:
    if not _planning_mode or not is_built:
        return false
    if output_index < 0 or output_index >= 3:
        return false

    var current := _mapping[output_index]
    var current_kind_index := KINDS.find(current)
    var next_kind := KINDS[(current_kind_index + 1) % KINDS.size()]
    var swap_index := _mapping.find(next_kind)
    if swap_index < 0:
        return false

    _mapping[output_index] = next_kind
    _mapping[swap_index] = current
    _rebuild_markers()
    AudioService.play("tap", 1.04, -5.0)
    HapticService.light()
    return true


func mapping_for_ui() -> Array:
    return _mapping.duplicate()


func route_for_kind(kind: String) -> String:
    if not is_built:
        return ""
    var index := _mapping.find(kind)
    if index < 0 or index >= _outputs.size():
        return ""
    return _outputs[index]


func request_route_for_kind(kind: String, callback: Callable) -> void:
    _route_queue.append({"kind": kind, "callback": callback})
    _pump_route_queue()


func _pump_route_queue() -> void:
    if _is_routing or _route_queue.is_empty():
        return
    _is_routing = true

    var request: Dictionary = _route_queue[0]
    var kind := String(request["kind"])
    var lane := _mapping.find(kind)
    if lane < 0:
        _complete_front_route()
        return

    var marker: Node3D = null
    if _marker_root != null and lane < _marker_root.get_child_count():
        marker = _marker_root.get_child(lane) as Node3D

    if marker == null:
        call_deferred("_complete_front_route")
        return

    marker.scale = Vector3.ONE
    var tween := Motion.tween(marker)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(marker, "scale", Vector3.ONE * 1.32, 0.07)
    tween.tween_property(marker, "scale", Vector3.ONE, 0.09)
    tween.finished.connect(_complete_front_route)


func _complete_front_route() -> void:
    if _route_queue.is_empty():
        _is_routing = false
        return
    var request: Dictionary = _route_queue.pop_front()
    var kind := String(request["kind"])
    var callback: Callable = request["callback"]
    var target := route_for_kind(kind)
    _is_routing = false
    if callback.is_valid():
        callback.call(target)
    call_deferred("_pump_route_queue")


func _build_foundation() -> void:
    _foundation = Node3D.new()
    _foundation.name = "SorterFoundation"
    add_child(_foundation)

    var pad := MeshInstance3D.new()
    var pad_mesh := CylinderMesh.new()
    pad_mesh.top_radius = 0.62
    pad_mesh.bottom_radius = 0.68
    pad_mesh.height = 0.10
    pad_mesh.radial_segments = 24
    pad.mesh = pad_mesh
    pad.position.y = 0.05
    pad.material_override = VisualFactory.material(Color("#D5C5AF"), 0.60, 0.0, 0.02)
    _foundation.add_child(pad)

    var inner := MeshInstance3D.new()
    var inner_mesh := CylinderMesh.new()
    inner_mesh.top_radius = 0.48
    inner_mesh.bottom_radius = 0.48
    inner_mesh.height = 0.035
    inner_mesh.radial_segments = 24
    inner.mesh = inner_mesh
    inner.position.y = 0.115
    inner.material_override = VisualFactory.material(Color("#F5E7D5"), 0.72)
    _foundation.add_child(inner)

    _add_plus(_foundation)

    var coin_count := clampi(build_cost, 1, 5)
    for i in range(coin_count):
        var coin := MeshInstance3D.new()
        var coin_mesh := CylinderMesh.new()
        coin_mesh.top_radius = 0.075
        coin_mesh.bottom_radius = 0.075
        coin_mesh.height = 0.025
        coin_mesh.radial_segments = 16
        coin.mesh = coin_mesh
        coin.position = Vector3((float(i) - float(coin_count - 1) * 0.5) * 0.18, 0.16, 0.34)
        coin.material_override = VisualFactory.material(Color("#E2AE3E"), 0.30, 0.20)
        _foundation.add_child(coin)


func _add_plus(parent: Node3D) -> void:
    for size in [Vector3(0.36, 0.035, 0.09), Vector3(0.09, 0.035, 0.36)]:
        var bar := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = size
        bar.mesh = mesh
        bar.position = Vector3(0, 0.15, -0.05)
        bar.material_override = VisualFactory.material(Color("#85786C"), 0.62)
        parent.add_child(bar)


func _build_selection_ring() -> void:
    _selection_ring = MeshInstance3D.new()
    _selection_ring.name = "SorterSelectionRing"
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.73
    mesh.outer_radius = 0.82
    mesh.rings = 28
    mesh.ring_segments = 10
    _selection_ring.mesh = mesh
    _selection_ring.position.y = 0.08
    _selection_ring.material_override = VisualFactory.material(Color("#E3AC42"), 0.30, 0.18)
    _selection_ring.visible = false
    add_child(_selection_ring)


func _refresh_selection() -> void:
    if _selection_ring != null:
        _selection_ring.visible = _selected and _planning_mode


func _build_house_visual(parent: Node3D) -> void:
    _add_box(parent, "Body", Vector3(1.42, 0.72, 1.02), Vector3(0, 0.47, 0), Color("#D8D2C8"), 0.46)
    _add_box(parent, "Roof", Vector3(1.18, 0.20, 0.86), Vector3(0, 0.94, 0), Color("#4E7FA0"), 0.34)
    _add_box(parent, "Front", Vector3(0.92, 0.42, 0.08), Vector3(0, 0.48, -0.55), Color("#5C6163"), 0.60)
    _add_box(parent, "Mouth", Vector3(0.56, 0.24, 0.05), Vector3(0, 0.44, -0.605), Color("#272B2F"), 0.72)

    var lamp := MeshInstance3D.new()
    var lamp_mesh := SphereMesh.new()
    lamp_mesh.radius = 0.12
    lamp_mesh.height = 0.24
    lamp_mesh.radial_segments = 16
    lamp_mesh.rings = 8
    lamp.mesh = lamp_mesh
    lamp.position = Vector3(0, 1.10, 0)
    lamp.material_override = VisualFactory.material(Color("#F2C65C"), 0.22, 0.30)
    parent.add_child(lamp)

    for i in range(3):
        var dir := _direction_for_output(i)
        var port := MeshInstance3D.new()
        var port_mesh := CylinderMesh.new()
        port_mesh.top_radius = 0.17
        port_mesh.bottom_radius = 0.19
        port_mesh.height = 0.10
        port_mesh.radial_segments = 18
        port.mesh = port_mesh
        port.position = dir * 0.62 + Vector3(0, 0.30, 0)
        port.material_override = VisualFactory.material(Color("#454A4D"), 0.66)
        parent.add_child(port)


func _add_box(parent: Node3D, name_value: String, size: Vector3, pos: Vector3, color: Color, roughness: float) -> void:
    var part := MeshInstance3D.new()
    part.name = name_value
    var mesh := BoxMesh.new()
    mesh.size = size
    part.mesh = mesh
    part.position = pos
    part.material_override = VisualFactory.material(color, roughness)
    parent.add_child(part)


func _build_active_tracks() -> void:
    if _active_tracks == null or not _positions.has(sorter_id):
        return
    var origin: Vector3 = _positions[sorter_id]
    for i in range(3):
        var target := _outputs[i]
        if target.is_empty() or not _positions.has(target):
            continue
        var world_points := TrackGeometry.path_for(sorter_id, target, origin, _positions[target])
        var local_points := PackedVector3Array()
        for point in world_points:
            local_points.append(point - origin)
        TrackVisuals.create_path(_active_tracks, local_points, 0.0, 0.0, true, false)


func _rebuild_markers() -> void:
    if _marker_root == null:
        return
    for child in _marker_root.get_children():
        _marker_root.remove_child(child)
        child.queue_free()

    for i in range(3):
        var lane := Node3D.new()
        lane.name = "Lane%d" % (i + 1)
        _marker_root.add_child(lane)

        var dir := _direction_for_output(i)
        var ring := MeshInstance3D.new()
        var ring_mesh := CylinderMesh.new()
        ring_mesh.top_radius = 0.20
        ring_mesh.bottom_radius = 0.20
        ring_mesh.height = 0.035
        ring_mesh.radial_segments = 18
        ring.mesh = ring_mesh
        ring.position = dir * 0.88 + Vector3(0, 0.34, 0)
        ring.material_override = VisualFactory.material(Color("#FFF4E3"), 0.58)
        lane.add_child(ring)

        var dot := MeshInstance3D.new()
        var dot_mesh := SphereMesh.new()
        dot_mesh.radius = 0.14
        dot_mesh.height = 0.28
        dot_mesh.radial_segments = 16
        dot_mesh.rings = 8
        dot.mesh = dot_mesh
        dot.position = dir * 0.88 + Vector3(0, 0.42, 0)
        dot.material_override = VisualFactory.material(VisualFactory.kind_color(_mapping[i]), 0.22, 0.18)
        lane.add_child(dot)


func _direction_for_output(index: int) -> Vector3:
    if index < 0 or index >= _outputs.size():
        return Vector3.FORWARD
    var target := _outputs[index]
    if not _positions.has(sorter_id) or not _positions.has(target):
        return Vector3.FORWARD
    var start: Vector3 = _positions[sorter_id]
    var finish: Vector3 = _positions[target]
    var path := TrackGeometry.path_for(sorter_id, target, start, finish)
    var dir := finish - start
    if path.size() >= 2:
        var sample := TrackGeometry.sample_distance(path, minf(1.0, TrackGeometry.length(path)))
        dir = (sample["position"] as Vector3) - start
    dir.y = 0.0
    if dir.length_squared() < 0.0001:
        return Vector3.FORWARD
    return dir.normalized()


func _mapping_is_valid() -> bool:
    if _mapping.size() != 3:
        return false
    var unique: Dictionary = {}
    for kind in _mapping:
        if kind not in KINDS:
            return false
        unique[kind] = true
    return unique.size() == 3

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
var _clock: float = 0.0
var _port_lights: Array[MeshInstance3D] = []


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


func _process(delta: float) -> void:
    _clock += delta

    # Empty build pads should read as actionable without needing a tutorial arrow.
    # The pulse is deliberately subtle so a board with decoy pads does not flicker.
    if _foundation != null and is_instance_valid(_foundation):
        if _planning_mode and not is_built:
            var pulse := 1.0 + sin(_clock * 2.35) * 0.018
            _foundation.scale = Vector3.ONE * pulse
        else:
            _foundation.scale = Vector3.ONE

    if _selection_ring != null and _selection_ring.visible:
        var ring_pulse := 1.0 + sin(_clock * 4.2) * 0.035
        _selection_ring.scale = Vector3(ring_pulse, 1.0, ring_pulse)


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
        _foundation.scale = Vector3.ONE

    _house = Node3D.new()
    _house.name = "SorterHouse"
    _house.scale = Vector3.ONE * 0.14
    add_child(_house)
    _build_house_visual(_house)

    _active_tracks = Node3D.new()
    _active_tracks.name = "ActiveSorterBelts"
    _active_tracks.scale = Vector3(0.94, 1.0, 0.94)
    add_child(_active_tracks)
    _build_active_tracks()

    _marker_root = Node3D.new()
    _marker_root.name = "SorterLaneMarkers"
    _marker_root.scale = Vector3.ONE * 0.82
    add_child(_marker_root)
    _rebuild_markers()

    var house_tween := Motion.tween(_house)
    house_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    house_tween.tween_property(_house, "scale", Vector3.ONE, 0.22)

    var track_tween := Motion.tween(_active_tracks)
    track_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    track_tween.tween_property(_active_tracks, "scale", Vector3.ONE, 0.20)

    var marker_tween := Motion.tween(_marker_root)
    marker_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    marker_tween.tween_property(_marker_root, "scale", Vector3.ONE, 0.20)

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
    _port_lights.clear()
    for node in [_house, _active_tracks, _marker_root]:
        if node != null and is_instance_valid(node):
            node.queue_free()
    _house = null
    _active_tracks = null
    _marker_root = null
    if _foundation != null:
        _foundation.visible = true
        _foundation.scale = Vector3.ONE * 0.92
        var tween := Motion.tween(_foundation)
        tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(_foundation, "scale", Vector3.ONE, 0.15)
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
    _refresh_port_colors()
    _pulse_lane(output_index)
    if swap_index != output_index:
        _pulse_lane(swap_index)
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


func flash_rejected() -> void:
    if _selection_ring == null:
        return
    _selection_ring.visible = true
    _selection_ring.material_override = VisualFactory.material(Color("#D96E59"), 0.28, 0.20)
    _selection_ring.scale = Vector3.ONE * 0.86
    var tween := Motion.tween(_selection_ring)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_selection_ring, "scale", Vector3.ONE * 1.12, 0.10)
    tween.tween_property(_selection_ring, "scale", Vector3.ONE, 0.10)
    tween.finished.connect(func() -> void:
        if _selection_ring != null:
            _selection_ring.material_override = VisualFactory.material(Color("#E3AC42"), 0.30, 0.18)
            _refresh_selection()
    )


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
    tween.tween_property(marker, "scale", Vector3.ONE * 1.30, 0.07)
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
    pad_mesh.top_radius = 0.68
    pad_mesh.bottom_radius = 0.73
    pad_mesh.height = 0.10
    pad_mesh.radial_segments = 28
    pad.mesh = pad_mesh
    pad.position.y = 0.05
    pad.material_override = VisualFactory.material(Color("#D2C1AA"), 0.58, 0.0, 0.02)
    _foundation.add_child(pad)

    var inner := MeshInstance3D.new()
    var inner_mesh := CylinderMesh.new()
    inner_mesh.top_radius = 0.52
    inner_mesh.bottom_radius = 0.52
    inner_mesh.height = 0.035
    inner_mesh.radial_segments = 28
    inner.mesh = inner_mesh
    inner.position.y = 0.115
    inner.material_override = VisualFactory.material(Color("#F7EAD9"), 0.72)
    _foundation.add_child(inner)

    # A small gold halo separates actionable foundations from decorative sockets.
    var halo := MeshInstance3D.new()
    var halo_mesh := TorusMesh.new()
    halo_mesh.inner_radius = 0.57
    halo_mesh.outer_radius = 0.62
    halo_mesh.rings = 24
    halo_mesh.ring_segments = 8
    halo.mesh = halo_mesh
    halo.position.y = 0.135
    halo.material_override = VisualFactory.material(Color("#D8A641A8"), 0.34, 0.12)
    _foundation.add_child(halo)

    _add_plus(_foundation)

    var coin_count := clampi(build_cost, 1, 5)
    for i in range(coin_count):
        var coin := MeshInstance3D.new()
        var coin_mesh := CylinderMesh.new()
        coin_mesh.top_radius = 0.085
        coin_mesh.bottom_radius = 0.085
        coin_mesh.height = 0.030
        coin_mesh.radial_segments = 18
        coin.mesh = coin_mesh
        coin.position = Vector3((float(i) - float(coin_count - 1) * 0.5) * 0.19, 0.18, 0.39)
        coin.material_override = VisualFactory.material(Color("#E1AD3F"), 0.28, 0.20)
        _foundation.add_child(coin)


func _add_plus(parent: Node3D) -> void:
    for size in [Vector3(0.40, 0.04, 0.10), Vector3(0.10, 0.04, 0.40)]:
        var bar := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = size
        bar.mesh = mesh
        bar.position = Vector3(0, 0.16, -0.04)
        bar.material_override = VisualFactory.material(Color("#776B61"), 0.56)
        parent.add_child(bar)


func _build_selection_ring() -> void:
    _selection_ring = MeshInstance3D.new()
    _selection_ring.name = "SorterSelectionRing"
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.77
    mesh.outer_radius = 0.86
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
    _port_lights.clear()

    _add_box(parent, "Body", Vector3(1.52, 0.76, 1.08), Vector3(0, 0.48, 0), Color("#D9D3C9"), 0.44)
    _add_box(parent, "Roof", Vector3(1.30, 0.19, 0.92), Vector3(0, 0.98, 0), Color("#4E7FA0"), 0.32)
    _add_box(parent, "Front", Vector3(0.98, 0.44, 0.08), Vector3(0, 0.49, -0.58), Color("#5C6163"), 0.58)
    _add_box(parent, "Mouth", Vector3(0.60, 0.25, 0.05), Vector3(0, 0.45, -0.635), Color("#272B2F"), 0.72)

    # Three small roof lamps make the object's purpose read as "colour sorter"
    # even before the player opens the setup panel.
    for i in range(3):
        var lamp := MeshInstance3D.new()
        var lamp_mesh := SphereMesh.new()
        lamp_mesh.radius = 0.10
        lamp_mesh.height = 0.20
        lamp_mesh.radial_segments = 14
        lamp_mesh.rings = 7
        lamp.mesh = lamp_mesh
        lamp.position = Vector3((float(i) - 1.0) * 0.28, 1.14, 0.0)
        lamp.material_override = VisualFactory.material(VisualFactory.kind_color(_mapping[i]), 0.20, 0.24)
        parent.add_child(lamp)

    for i in range(3):
        var dir := _direction_for_output(i)

        var housing := MeshInstance3D.new()
        var housing_mesh := CylinderMesh.new()
        housing_mesh.top_radius = 0.20
        housing_mesh.bottom_radius = 0.22
        housing_mesh.height = 0.11
        housing_mesh.radial_segments = 18
        housing.mesh = housing_mesh
        housing.position = dir * 0.64 + Vector3(0, 0.30, 0)
        housing.material_override = VisualFactory.material(Color("#454A4D"), 0.64)
        parent.add_child(housing)

        var light := MeshInstance3D.new()
        light.name = "LaneLight%d" % (i + 1)
        var light_mesh := SphereMesh.new()
        light_mesh.radius = 0.15
        light_mesh.height = 0.30
        light_mesh.radial_segments = 16
        light_mesh.rings = 8
        light.mesh = light_mesh
        light.position = dir * 0.69 + Vector3(0, 0.40, 0)
        light.material_override = VisualFactory.material(VisualFactory.kind_color(_mapping[i]), 0.20, 0.22)
        parent.add_child(light)
        _port_lights.append(light)


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
        var route := TrackVisuals.create_path(_active_tracks, local_points, 0.0, 0.0, true, false)
        route.name = "ActiveLane%d" % (i + 1)


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
        var kind := _mapping[i]

        # A short colour strip physically touches the outgoing black belt. This
        # is much easier to parse than three detached dots floating near a rail.
        var strip := MeshInstance3D.new()
        var strip_mesh := BoxMesh.new()
        strip_mesh.size = Vector3(0.20, 0.045, 0.52)
        strip.mesh = strip_mesh
        strip.position = dir * 0.78 + Vector3(0, 0.20, 0)
        strip.rotation.y = atan2(dir.x, dir.z)
        strip.material_override = VisualFactory.material(VisualFactory.kind_color(kind), 0.28, 0.12)
        lane.add_child(strip)

        var ring := MeshInstance3D.new()
        var ring_mesh := CylinderMesh.new()
        ring_mesh.top_radius = 0.23
        ring_mesh.bottom_radius = 0.23
        ring_mesh.height = 0.035
        ring_mesh.radial_segments = 18
        ring.mesh = ring_mesh
        ring.position = dir * 0.98 + Vector3(0, 0.34, 0)
        ring.material_override = VisualFactory.material(Color("#FFF4E3"), 0.58)
        lane.add_child(ring)

        var dot := MeshInstance3D.new()
        var dot_mesh := SphereMesh.new()
        dot_mesh.radius = 0.17
        dot_mesh.height = 0.34
        dot_mesh.radial_segments = 16
        dot_mesh.rings = 8
        dot.mesh = dot_mesh
        dot.position = dir * 0.98 + Vector3(0, 0.43, 0)
        dot.material_override = VisualFactory.material(VisualFactory.kind_color(kind), 0.20, 0.22)
        lane.add_child(dot)


func _refresh_port_colors() -> void:
    for i in range(mini(_port_lights.size(), _mapping.size())):
        var light := _port_lights[i]
        if light != null and is_instance_valid(light):
            light.material_override = VisualFactory.material(VisualFactory.kind_color(_mapping[i]), 0.20, 0.22)


func _pulse_lane(index: int) -> void:
    if _marker_root == null or index < 0 or index >= _marker_root.get_child_count():
        return
    var lane := _marker_root.get_child(index) as Node3D
    lane.scale = Vector3.ONE * 0.86
    var tween := Motion.tween(lane)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(lane, "scale", Vector3.ONE * 1.10, 0.08)
    tween.tween_property(lane, "scale", Vector3.ONE, 0.10)


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

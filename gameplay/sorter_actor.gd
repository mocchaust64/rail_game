class_name SorterActor
extends Node3D

const KINDS: Array[String] = ["red", "blue", "yellow"]

var sorter_id: String = ""
var is_built: bool = false
var build_cost: int = 3

var _outputs: Array[String] = ["", "", ""]
var _mapping: Array[String] = ["red", "blue", "yellow"]
var _positions: Dictionary = {}
var _planning_mode := true
var _selected := false
var _foundation: Node3D
var _house: Node3D
var _marker_root: Node3D
var _selection_ring: MeshInstance3D
var _route_queue: Array[Dictionary] = []
var _is_routing := false
var _clock := 0.0
var _port_lights: Array[MeshInstance3D] = []
var _roof_lights: Array[MeshInstance3D] = []


func configure(data: Dictionary, positions: Dictionary, default_cost: int) -> void:
    sorter_id = String(data["id"])
    build_cost = int(data.get("build_cost", default_cost))
    _positions = positions
    _outputs = [String(data["out_1"]), String(data["out_2"]), String(data["out_3"])]

    var raw_mapping: Array = data.get("mapping", KINDS)
    _mapping = []
    for kind in raw_mapping:
        _mapping.append(String(kind))
    if not _mapping_is_valid():
        _mapping = ["red", "blue", "yellow"]

    _build_foundation()
    _build_selection_ring()
    if bool(data.get("prebuilt", false)):
        build()
    else:
        _refresh_selection()


func _process(delta: float) -> void:
    _clock += delta
    if _foundation != null and is_instance_valid(_foundation):
        if _planning_mode and not is_built:
            var pulse := 1.0 + sin(_clock * 2.2) * 0.016
            _foundation.scale = Vector3.ONE * pulse
        else:
            _foundation.scale = Vector3.ONE
    if _selection_ring != null and _selection_ring.visible:
        var ring_pulse := 1.0 + sin(_clock * 4.0) * 0.030
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
    _house.scale = Vector3.ONE * 0.16
    add_child(_house)

    var directions: Array[Vector3] = []
    for i in range(3):
        directions.append(_direction_for_output(i))
    var parts := MachineVisuals.populate_sorter_shell(_house, _mapping, directions)
    _port_lights = parts.get("port_lights", [])
    _roof_lights = parts.get("roof_lights", [])

    _marker_root = Node3D.new()
    _marker_root.name = "SorterLaneMarkers"
    _marker_root.scale = Vector3.ONE * 0.84
    add_child(_marker_root)
    _rebuild_markers()

    var house_tween := Motion.tween(_house)
    house_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    house_tween.tween_property(_house, "scale", Vector3.ONE, 0.22)

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
    _roof_lights.clear()

    for node in [_house, _marker_root]:
        if node != null and is_instance_valid(node):
            node.queue_free()
    _house = null
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
    _selection_ring.material_override = VisualFactory.material(Color("#D96E59"), 0.34, 0.10)
    _selection_ring.scale = Vector3.ONE * 0.88
    var tween := Motion.tween(_selection_ring)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_selection_ring, "scale", Vector3.ONE * 1.12, 0.10)
    tween.tween_property(_selection_ring, "scale", Vector3.ONE, 0.10)
    tween.finished.connect(func() -> void:
        if _selection_ring != null:
            _selection_ring.material_override = VisualFactory.material(Color("#D7A84D"), 0.38, 0.08)
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
    tween.tween_property(marker, "scale", Vector3.ONE * 1.22, 0.07)
    tween.tween_property(marker, "scale", Vector3.ONE, 0.10)
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
    pad_mesh.top_radius = 0.70
    pad_mesh.bottom_radius = 0.75
    pad_mesh.height = 0.10
    pad_mesh.radial_segments = 28
    pad.mesh = pad_mesh
    pad.position.y = 0.05
    pad.material_override = VisualFactory.material(Color("#C8B59F"), 0.64)
    _foundation.add_child(pad)

    var inner := MeshInstance3D.new()
    var inner_mesh := CylinderMesh.new()
    inner_mesh.top_radius = 0.52
    inner_mesh.bottom_radius = 0.52
    inner_mesh.height = 0.035
    inner_mesh.radial_segments = 28
    inner.mesh = inner_mesh
    inner.position.y = 0.115
    inner.material_override = VisualFactory.material(Color("#EEDFCB"), 0.78)
    _foundation.add_child(inner)

    var halo := MeshInstance3D.new()
    var halo_mesh := TorusMesh.new()
    halo_mesh.inner_radius = 0.57
    halo_mesh.outer_radius = 0.62
    halo_mesh.rings = 24
    halo_mesh.ring_segments = 8
    halo.mesh = halo_mesh
    halo.position.y = 0.135
    halo.material_override = VisualFactory.material(Color("#D5A74A"), 0.40, 0.08)
    _foundation.add_child(halo)

    _add_plus(_foundation)
    var coin_count := clampi(build_cost, 1, 5)
    for i in range(coin_count):
        var coin := MeshInstance3D.new()
        var coin_mesh := CylinderMesh.new()
        coin_mesh.top_radius = 0.078
        coin_mesh.bottom_radius = 0.078
        coin_mesh.height = 0.028
        coin_mesh.radial_segments = 18
        coin.mesh = coin_mesh
        coin.position = Vector3((float(i) - float(coin_count - 1) * 0.5) * 0.18, 0.18, 0.38)
        coin.material_override = VisualFactory.material(Color("#D9AA43"), 0.36, 0.08)
        _foundation.add_child(coin)


func _add_plus(parent: Node3D) -> void:
    for size in [Vector3(0.38, 0.04, 0.09), Vector3(0.09, 0.04, 0.38)]:
        var bar := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = size
        bar.mesh = mesh
        bar.position = Vector3(0, 0.16, -0.04)
        bar.material_override = VisualFactory.material(Color("#756A60"), 0.62)
        parent.add_child(bar)


func _build_selection_ring() -> void:
    _selection_ring = MeshInstance3D.new()
    _selection_ring.name = "SorterSelectionRing"
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.80
    mesh.outer_radius = 0.88
    mesh.rings = 28
    mesh.ring_segments = 10
    _selection_ring.mesh = mesh
    _selection_ring.position.y = 0.08
    _selection_ring.material_override = VisualFactory.material(Color("#D7A84D"), 0.38, 0.08)
    _selection_ring.visible = false
    add_child(_selection_ring)


func _refresh_selection() -> void:
    if _selection_ring != null:
        _selection_ring.visible = _selected and _planning_mode


func _rebuild_markers() -> void:
    if _marker_root == null or not _positions.has(sorter_id):
        return
    for child in _marker_root.get_children():
        _marker_root.remove_child(child)
        child.queue_free()

    var origin: Vector3 = _positions[sorter_id]
    for i in range(3):
        var target := _outputs[i]
        if target.is_empty() or not _positions.has(target):
            continue

        var lane := Node3D.new()
        lane.name = "Exit%d" % (i + 1)
        _marker_root.add_child(lane)

        var kind := _mapping[i]
        var colour := VisualFactory.kind_color(kind)
        var path := TrackGeometry.path_for(sorter_id, target, origin, _positions[target])
        var path_length := TrackGeometry.length(path)
        var marker_distance := minf(1.75, maxf(1.15, path_length * 0.36))
        marker_distance = minf(marker_distance, maxf(0.40, path_length - 0.30))
        var sample := TrackGeometry.sample_distance(path, marker_distance)
        var marker_pos: Vector3 = (sample["position"] as Vector3) - origin
        var tangent: Vector3 = sample["tangent"] as Vector3
        tangent.y = 0.0
        if tangent.length_squared() < 0.0001:
            tangent = _direction_for_output(i)
        tangent = tangent.normalized()

        # The gate sits on the actual belt after the three branches have had
        # enough distance to separate. This makes EXIT 1/2/3 readable spatially.
        var gate := MeshInstance3D.new()
        var gate_mesh := BoxMesh.new()
        gate_mesh.size = Vector3(0.46, 0.050, 0.62)
        gate.mesh = gate_mesh
        gate.position = marker_pos + Vector3(0, 0.19, 0)
        gate.rotation.y = atan2(tangent.x, tangent.z)
        gate.material_override = VisualFactory.material(colour, 0.34, 0.10)
        lane.add_child(gate)

        var badge := MeshInstance3D.new()
        var badge_mesh := CylinderMesh.new()
        badge_mesh.top_radius = 0.22
        badge_mesh.bottom_radius = 0.22
        badge_mesh.height = 0.038
        badge_mesh.radial_segments = 20
        badge.mesh = badge_mesh
        badge.position = marker_pos + Vector3(0, 0.31, 0)
        badge.material_override = VisualFactory.material(Color("#F7EFE4"), 0.58)
        lane.add_child(badge)

        var number := Label3D.new()
        number.text = str(i + 1)
        number.font_size = 68
        number.pixel_size = 0.0035
        number.modulate = Color("#35312E")
        number.outline_size = 7
        number.outline_modulate = colour.lightened(0.42)
        number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        number.position = marker_pos + Vector3(0, 0.50, 0)
        lane.add_child(number)


func _refresh_port_colors() -> void:
    for i in range(mini(_port_lights.size(), _mapping.size())):
        var port := _port_lights[i]
        if port != null and is_instance_valid(port):
            port.material_override = VisualFactory.material(VisualFactory.kind_color(_mapping[i]), 0.22, 0.14)
    for i in range(mini(_roof_lights.size(), _mapping.size())):
        var roof := _roof_lights[i]
        if roof != null and is_instance_valid(roof):
            roof.material_override = VisualFactory.material(VisualFactory.kind_color(_mapping[i]), 0.24, 0.14)


func _pulse_lane(index: int) -> void:
    if _marker_root == null or index < 0 or index >= _marker_root.get_child_count():
        return
    var lane := _marker_root.get_child(index) as Node3D
    lane.scale = Vector3.ONE * 0.88
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

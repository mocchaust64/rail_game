class_name GameController
extends Node3D

enum GameState { BOOT, LEVEL_LOADING, READY, PLAYING, PAUSED, FAILED, COMPLETED }

const LEVEL_COUNT := 10
const TAP_RADIUS_PX := 118.0
const SOURCE_CLEAR_PROGRESS := 0.38

var state: GameState = GameState.BOOT
var current_level_number: int = 1
var level: Dictionary = {}
var nodes_by_id: Dictionary = {}
var positions: Dictionary = {}
var junctions: Dictionary = {}
var receivers: Dictionary = {}
var sources: Dictionary = {}
var active_items: Array[ItemActor] = []
var buffered: Array[Dictionary] = []

var _world: Node3D
var _camera: Camera3D
var _hud: FlowHud
var _buffer_chute: Node3D
var _spawn_index: int = 0
var _spawn_clock: float = 0.0
var _elapsed: float = 0.0
var _attempt: int = 1
var _mistakes: int = 0
var _junction_taps: int = 0
var _empty_hold: float = 0.0
var _tutorial_junction: JunctionActor

func _ready() -> void:
    _setup_scene()
    current_level_number = clamp(SaveService.highest_unlocked_level, 1, LEVEL_COUNT)
    load_level(current_level_number)

func _setup_scene() -> void:
    _world = Node3D.new()
    _world.name = "World"
    add_child(_world)

    _camera = Camera3D.new()
    _camera.name = "GameCamera"
    _camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    _camera.size = 15.4
    _camera.position = Vector3(0.0, 14.8, 10.8)
    add_child(_camera)
    _camera.look_at(Vector3(0, 0, 0.25), Vector3.UP)

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-56, -28, 0)
    key_light.light_energy = 1.18
    key_light.shadow_enabled = true
    key_light.directional_shadow_max_distance = 24.0
    add_child(key_light)

    var fill := OmniLight3D.new()
    fill.position = Vector3(-4.0, 8.0, -2.0)
    fill.omni_range = 20.0
    fill.light_energy = 0.28
    fill.light_color = Color("#D8EEFF")
    fill.shadow_enabled = false
    add_child(fill)

    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#BDD0D9")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#F3FAFD")
    env.ambient_light_energy = 0.82
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.environment = env
    add_child(environment)

    _hud = FlowHud.new()
    add_child(_hud)
    _hud.restart_requested.connect(_on_restart_requested)
    _hud.next_requested.connect(_on_next_requested)
    _hud.pause_requested.connect(_on_pause_requested)
    _hud.resume_requested.connect(_on_resume_requested)
    _hud.debug_previous_requested.connect(_on_debug_previous)
    _hud.debug_next_requested.connect(_on_debug_next)

func load_level(level_number: int) -> void:
    state = GameState.LEVEL_LOADING
    current_level_number = clamp(level_number, 1, LEVEL_COUNT)
    _clear_runtime()

    var path := "res://levels/level_%02d.json" % current_level_number
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        _handle_level_error("Unable to load %s" % path)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        _handle_level_error("Invalid JSON in %s" % path)
        return
    level = parsed

    var errors := LevelValidator.validate(level)
    if not errors.is_empty():
        for error in errors:
            push_error("Level validation: %s" % error)
        _handle_level_error("Level data failed validation.")
        return

    _build_level()
    _hud.set_level(current_level_number, String(level.get("title", "FLOW")))
    _hud.set_buffer([], int(level["buffer_capacity"]))
    _refresh_upcoming()
    _hud.hide_overlay()

    _spawn_clock = max(0.0, float(level["spawn_interval"]) - 0.72)
    _elapsed = 0.0
    _mistakes = 0
    _junction_taps = 0
    _empty_hold = 0.0

    _setup_tutorial_hint()
    state = GameState.PLAYING
    AnalyticsService.track("level_start", {"level": current_level_number, "attempt": _attempt})

func _handle_level_error(message: String) -> void:
    push_error(message)
    state = GameState.FAILED
    _hud.show_fail("This level could not be loaded. Check the Godot output log.")

func _clear_runtime() -> void:
    if _tutorial_junction != null and is_instance_valid(_tutorial_junction):
        _tutorial_junction.set_hint_active(false)
    _tutorial_junction = null

    for child in _world.get_children():
        _world.remove_child(child)
        child.queue_free()
    active_items.clear()
    buffered.clear()
    junctions.clear()
    receivers.clear()
    sources.clear()
    nodes_by_id.clear()
    positions.clear()
    _spawn_index = 0
    _buffer_chute = null

func _build_level() -> void:
    # Node positions are parsed first: the floor decoration needs them so props
    # can be filtered away from wherever this level puts its receivers and sources.
    var occupied: Array[Vector2] = []
    for raw_node in level["nodes"]:
        var node: Dictionary = raw_node
        var id := String(node["id"])
        nodes_by_id[id] = node
        var p: Array = node["pos"]
        positions[id] = Vector3(float(p[0]), 0.0, float(p[1]))
        if String(node.get("type", "normal")) in ["receiver", "source"]:
            occupied.append(Vector2(float(p[0]), float(p[1])))

    VisualFactory.create_floor(_world, occupied)
    _buffer_chute = VisualFactory.create_buffer_chute(_world)

    var drawn: Dictionary = {}
    for id in nodes_by_id:
        var node: Dictionary = nodes_by_id[id]
        var targets: Array[String] = []
        if String(node.get("type", "normal")) == "junction":
            targets.append(String(node["out_a"]))
            targets.append(String(node["out_b"]))
        elif String(node.get("type", "normal")) != "receiver":
            targets.append(String(node.get("next", "")))
        for target in targets:
            if target.is_empty():
                continue
            var key := "%s>%s" % [id, target]
            if not drawn.has(key):
                VisualFactory.create_track(_world, positions[id], positions[target])
                drawn[key] = true

    for id in nodes_by_id:
        var node: Dictionary = nodes_by_id[id]
        var node_type := String(node.get("type", "normal"))
        match node_type:
            "source":
                var source := SourceActor.new()
                source.position = positions[id]
                _world.add_child(source)
                source.configure(String(id))
                sources[id] = source
            "receiver":
                var receiver := ReceiverActor.new()
                receiver.position = positions[id]
                _world.add_child(receiver)
                receiver.configure(String(id), String(node["kind"]))
                receivers[id] = receiver
            "junction":
                var junction := JunctionActor.new()
                junction.position = positions[id]
                _world.add_child(junction)
                junction.configure(node, positions)
                junctions[id] = junction

func _setup_tutorial_hint() -> void:
    _hud.set_tutorial_visible(false)
    if current_level_number != 1 or SaveService.tutorial_seen or junctions.is_empty():
        return
    var first_id := String(junctions.keys()[0])
    _tutorial_junction = junctions[first_id] as JunctionActor
    _tutorial_junction.set_hint_active(true)
    _hud.set_tutorial_visible(true)

func _physics_process(delta: float) -> void:
    if state != GameState.PLAYING:
        return
    _elapsed += delta
    # Returning cargo gets first claim on a newly-open source slot. This prevents an unfair
    # buffer-full loss on the exact frame a slot should have returned to the line.
    _update_buffer()
    _update_spawning(delta)
    _update_items(delta)
    _check_win(delta)

func _update_spawning(delta: float) -> void:
    if _spawn_index >= level["spawns"].size():
        return
    _spawn_clock += delta
    var interval := float(level["spawn_interval"])
    if _spawn_clock < interval:
        return

    var spawn: Dictionary = level["spawns"][_spawn_index]
    var source_id := String(spawn["source"])
    if not _can_spawn_from_source(source_id):
        _spawn_clock = min(_spawn_clock, interval + 0.10)
        return

    _spawn_clock -= interval
    _spawn_index += 1
    _refresh_upcoming()
    _spawn_item(String(spawn["kind"]), source_id, false)

func _spawn_item(kind: String, source_id: String, returning: bool) -> void:
    if state != GameState.PLAYING or not nodes_by_id.has(source_id):
        return
    var next_id := _route_from(source_id)
    if next_id.is_empty():
        _fail("A route ended unexpectedly.")
        return

    var item := ItemActor.new()
    _world.add_child(item)
    item.configure(kind, source_id, source_id, next_id, positions[source_id], positions[next_id], float(level["item_speed"]))
    active_items.append(item)

    if sources.has(source_id):
        var source := sources[source_id] as SourceActor
        source.react_launch()
    if returning:
        AudioService.play("buffer_return", 1.0, -6.0)
    else:
        AudioService.play("spawn", 1.0, -13.0)

func _can_spawn_from_source(source_id: String) -> bool:
    for item in active_items:
        if not is_instance_valid(item):
            continue
        if item.from_id == source_id and item.progress < SOURCE_CLEAR_PROGRESS:
            return false
    return true

func _update_items(delta: float) -> void:
    for item in active_items.duplicate():
        if not is_instance_valid(item):
            active_items.erase(item)
            continue
        if item.advance(delta):
            _on_item_reached_node(item)

func _on_item_reached_node(item: ItemActor) -> void:
    var arrived_id := item.to_id
    if not nodes_by_id.has(arrived_id):
        _fail("Cargo reached an invalid route.")
        return

    var node: Dictionary = nodes_by_id[arrived_id]
    var node_type := String(node.get("type", "normal"))
    if node_type == "receiver":
        if String(node["kind"]) == item.kind:
            _deliver_item(item, arrived_id)
        else:
            _buffer_item(item, arrived_id)
        return

    var next_id := _route_from(arrived_id)
    if next_id.is_empty():
        _fail("Cargo reached a dead end.")
        return
    # The route is committed at this exact moment. A later junction tap only affects
    # cargo that has not yet reached this node.
    item.start_segment(arrived_id, next_id, positions[arrived_id], positions[next_id])

func _route_from(node_id: String) -> String:
    var node: Dictionary = nodes_by_id[node_id]
    if String(node.get("type", "normal")) == "junction":
        var junction := junctions[node_id] as JunctionActor
        return junction.current_output()
    return String(node.get("next", ""))

func _deliver_item(item: ItemActor, receiver_id: String) -> void:
    active_items.erase(item)
    if receivers.has(receiver_id):
        var receiver := receivers[receiver_id] as ReceiverActor
        receiver.accept()
    AudioService.play("correct", 1.0 + min(0.16, float(_junction_taps % 5) * 0.018), -3.0)
    HapticService.light()
    item.animate_delivered()

func _buffer_item(item: ItemActor, receiver_id: String) -> void:
    active_items.erase(item)
    _mistakes += 1

    if receivers.has(receiver_id):
        var receiver := receivers[receiver_id] as ReceiverActor
        receiver.reject()

    if buffered.size() >= int(level["buffer_capacity"]):
        AudioService.play("wrong", 0.86, -1.0)
        item.animate_buffered(_buffer_target_position())
        _fail("One more wrong delivery overflowed the waiting buffer.")
        return

    buffered.append({
        "kind": item.kind,
        "source": item.origin_source,
        "return_at": _elapsed + float(level.get("buffer_return_delay", 2.8)),
    })
    item.animate_buffered(_buffer_target_position())
    AudioService.play("wrong", 1.0, -2.0)
    HapticService.medium()
    AnalyticsService.track("item_wrong", {"level": current_level_number, "buffer": buffered.size()})
    _refresh_buffer_ui()
    _hud.flash_buffer()

func _buffer_target_position() -> Vector3:
    if _buffer_chute != null and is_instance_valid(_buffer_chute):
        return _buffer_chute.global_position + Vector3(0, 0.70, 0)
    return Vector3(3.7, 0.7, -4.8)

func _update_buffer() -> void:
    if buffered.is_empty():
        return
    var entry: Dictionary = buffered[0]
    if _elapsed < float(entry["return_at"]):
        return
    var source_id := String(entry["source"])
    if not _can_spawn_from_source(source_id):
        return
    buffered.pop_front()
    _refresh_buffer_ui()
    _spawn_item(String(entry["kind"]), source_id, true)

func _refresh_buffer_ui() -> void:
    var kinds: Array = []
    for entry in buffered:
        kinds.append(String(entry["kind"]))
    _hud.set_buffer(kinds, int(level["buffer_capacity"]))

func _refresh_upcoming() -> void:
    var kinds: Array = []
    var spawns: Array = level.get("spawns", [])
    for i in range(_spawn_index, min(_spawn_index + 4, spawns.size())):
        var entry: Dictionary = spawns[i]
        kinds.append(String(entry["kind"]))
    _hud.set_upcoming(kinds)
    _refresh_source_previews(spawns)

func _refresh_source_previews(spawns: Array) -> void:
    # In two-source levels the global NEXT row alone is ambiguous. Showing the next piece
    # physically above each hopper preserves planning and prevents the game becoming reflex-based.
    for source_id in sources:
        var source := sources[source_id] as SourceActor
        source.set_preview("")
    for i in range(_spawn_index, spawns.size()):
        var entry: Dictionary = spawns[i]
        var source_id := String(entry["source"])
        if not sources.has(source_id):
            continue
        var source := sources[source_id] as SourceActor
        if source.has_meta("preview_assigned"):
            continue
        source.set_preview(String(entry["kind"]))
        source.set_meta("preview_assigned", true)
    for source_id in sources:
        var source := sources[source_id] as SourceActor
        source.remove_meta("preview_assigned")

func _check_win(delta: float) -> void:
    if state != GameState.PLAYING:
        return
    if _spawn_index < level["spawns"].size() or not active_items.is_empty() or not buffered.is_empty():
        _empty_hold = 0.0
        return
    _empty_hold += delta
    if _empty_hold < 0.30:
        return

    state = GameState.COMPLETED
    AudioService.play("win", 1.0, -1.0)
    HapticService.medium()
    VisualFactory.create_win_confetti(_world)
    SaveService.unlock_level(min(LEVEL_COUNT, current_level_number + 1))
    AnalyticsService.track("level_complete", {
        "level": current_level_number,
        "duration": snapped(_elapsed, 0.01),
        "mistakes": _mistakes,
        "junction_taps": _junction_taps,
        "attempt": _attempt,
    })
    _hud.show_win(_elapsed, _mistakes)

func _fail(reason: String) -> void:
    if state != GameState.PLAYING:
        return
    state = GameState.FAILED
    AudioService.play("fail", 1.0, -1.0)
    HapticService.heavy()
    AnalyticsService.track("level_fail", {
        "level": current_level_number,
        "duration": snapped(_elapsed, 0.01),
        "mistakes": _mistakes,
        "junction_taps": _junction_taps,
        "attempt": _attempt,
    })
    _hud.show_fail(reason)

func _unhandled_input(event: InputEvent) -> void:
    if state != GameState.PLAYING:
        return

    var screen_pos := Vector2.ZERO
    var pressed := false
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            screen_pos = touch.position
            pressed = true
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
            screen_pos = mouse.position
            pressed = true
    if not pressed:
        return

    var best: JunctionActor = null
    var best_distance := TAP_RADIUS_PX
    for id in junctions:
        var junction := junctions[id] as JunctionActor
        var projected := _camera.unproject_position(junction.global_position + Vector3(0, 0.38, 0))
        var distance := projected.distance_to(screen_pos)
        if distance < best_distance:
            best = junction
            best_distance = distance

    if best == null:
        return

    if _tutorial_junction != null:
        _tutorial_junction.set_hint_active(false)
        _tutorial_junction = null
        _hud.set_tutorial_visible(false)
        SaveService.mark_tutorial_seen()

    best.request_toggle()
    _junction_taps += 1
    AnalyticsService.track("junction_tap", {
        "level": current_level_number,
        "junction": best.junction_id,
        "state": best.state,
    })

func _on_restart_requested() -> void:
    _attempt += 1
    load_level(current_level_number)

func _on_next_requested() -> void:
    _attempt = 1
    if current_level_number >= LEVEL_COUNT:
        load_level(1)
    else:
        load_level(current_level_number + 1)

func _on_pause_requested() -> void:
    if state != GameState.PLAYING:
        return
    state = GameState.PAUSED
    AnalyticsService.track("level_pause", {"level": current_level_number, "duration": snapped(_elapsed, 0.01)})
    _hud.show_pause()

func _on_resume_requested() -> void:
    if state != GameState.PAUSED:
        return
    state = GameState.PLAYING
    _hud.hide_overlay()

func _on_debug_previous() -> void:
    if not OS.is_debug_build():
        return
    _attempt = 1
    load_level(max(1, current_level_number - 1))

func _on_debug_next() -> void:
    if not OS.is_debug_build():
        return
    _attempt = 1
    load_level(min(LEVEL_COUNT, current_level_number + 1))

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED and state == GameState.PLAYING:
        call_deferred("_on_pause_requested")

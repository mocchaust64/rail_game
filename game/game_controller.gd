class_name GameController
extends Node3D

enum GameState { BOOT, LEVEL_LOADING, READY, PLAYING, PAUSED, FAILED, COMPLETED }

const LEVEL_COUNT := 10
const MAX_POOLED_ITEMS := 24

const TRAUMA_CORRECT := 0.12
const TRAUMA_WRONG := 0.40
const TRAUMA_FAIL := 0.85
const HITSTOP_WRONG := 0.07
const HITSTOP_FAIL := 0.16
const TAP_RADIUS_UNITS := 0.95
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
var _item_pool: ItemPool
var _rig: SceneRig
var _hitstop_remaining := 0.0
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
    _rig = SceneRig.new()
    _rig.name = "SceneRig"
    add_child(_rig)
    _camera = _rig.camera
    _world = _rig.world

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

    level = LevelBuilder.load_data(current_level_number)
    if level.is_empty():
        _handle_level_error("Level %d could not be loaded." % current_level_number)
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
    Engine.time_scale = 1.0
    _hitstop_remaining = 0.0
    if _tutorial_junction != null and is_instance_valid(_tutorial_junction):
        _tutorial_junction.set_hint_active(false)
    _tutorial_junction = null

    _rig.clear_world()
    active_items.clear()
    buffered.clear()
    junctions.clear()
    receivers.clear()
    sources.clear()
    nodes_by_id.clear()
    positions.clear()
    _spawn_index = 0
    _buffer_chute = null
    _item_pool = null


func _build_level() -> void:
    var built := LevelBuilder.build(level, _world, MAX_POOLED_ITEMS)
    nodes_by_id = built["nodes_by_id"]
    positions = built["positions"]
    sources = built["sources"]
    receivers = built["receivers"]
    junctions = built["junctions"]
    _buffer_chute = built["buffer_chute"]
    _item_pool = built["item_pool"]


func _setup_tutorial_hint() -> void:
    _hud.set_tutorial_visible(false)
    if current_level_number != 1 or SaveService.tutorial_seen or junctions.is_empty():
        return
    var first_id := String(junctions.keys()[0])
    _tutorial_junction = junctions[first_id] as JunctionActor
    _tutorial_junction.set_hint_active(true)
    _hud.set_tutorial_visible(true)


func _process(delta: float) -> void:
    if _hitstop_remaining > 0.0:
        _hitstop_remaining -= delta / maxf(0.05, Engine.time_scale)
        if _hitstop_remaining <= 0.0:
            Engine.time_scale = 1.0


func _hitstop(seconds: float) -> void:
    if SaveService.reduced_motion:
        return
    Engine.time_scale = 0.12
    _hitstop_remaining = seconds


func _physics_process(delta: float) -> void:
    if state != GameState.PLAYING:
        return
    _elapsed += delta
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

    var item := _item_pool.acquire()
    if item == null:
        return
    if not item.finished.is_connected(_on_item_finished):
        item.finished.connect(_on_item_finished)
    item.configure(kind, source_id, source_id, next_id, positions[source_id], positions[next_id], SaveService.scaled_speed(float(level["item_speed"])))
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
    _rig.add_trauma(TRAUMA_CORRECT)
    VisualFactory.burst(_world, positions[receiver_id] + Vector3(0, 1.0, 0), VisualFactory.kind_color(item.kind), 26, 3.2)
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
    AudioService.duck_music()
    HapticService.medium()
    _rig.add_trauma(TRAUMA_WRONG)
    _hitstop(HITSTOP_WRONG)
    VisualFactory.burst(_world, positions[receiver_id] + Vector3(0, 1.0, 0), Color("#8C9BA6"), 18, 2.2)
    AnalyticsService.track("item_wrong", {"level": current_level_number, "buffer": buffered.size()})
    _refresh_buffer_ui()
    _hud.flash_buffer()


func _buffer_target_position() -> Vector3:
    if _buffer_chute != null and is_instance_valid(_buffer_chute):
        return _buffer_chute.global_position + Vector3(0, 0.70, 0)
    return Vector3(0.0, 0.7, 6.35)


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
    # Put the real future sequence directly onto each source's physical feeder.
    # The reference video shows many balls waiting in the world, so planning no
    # longer depends on a floating NEXT card.
    var queues: Dictionary = {}
    for source_id in sources:
        queues[source_id] = []

    for i in range(_spawn_index, spawns.size()):
        var entry: Dictionary = spawns[i]
        var source_id := String(entry["source"])
        if not sources.has(source_id):
            continue
        var queue: Array = queues[source_id]
        if queue.size() >= SourceActor.MAX_VISIBLE_QUEUE:
            continue
        queue.append(String(entry["kind"]))
        queues[source_id] = queue

    for source_id in sources:
        var source := sources[source_id] as SourceActor
        source.set_preview_queue(queues[source_id] as Array)


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
    AudioService.duck_music(12.0, 0.7)
    HapticService.heavy()
    _rig.add_trauma(TRAUMA_FAIL)
    _hitstop(HITSTOP_FAIL)
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
    var best_score := 1.0
    for id in junctions:
        var junction := junctions[id] as JunctionActor
        var anchor := junction.global_position + Vector3(0, 0.38, 0)
        var projected := _camera.unproject_position(anchor)
        var radius_px := screen_radius(_camera, anchor, TAP_RADIUS_UNITS)
        if radius_px <= 0.0:
            continue
        var score := projected.distance_to(screen_pos) / radius_px
        if score < best_score:
            best = junction
            best_score = score

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


static func screen_radius(camera: Camera3D, anchor: Vector3, units: float) -> float:
    var edge := anchor + camera.global_transform.basis.x * units
    return camera.unproject_position(anchor).distance_to(camera.unproject_position(edge))


func _on_item_finished(item: ItemActor) -> void:
    if _item_pool != null:
        _item_pool.release(item)

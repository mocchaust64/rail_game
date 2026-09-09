class_name GameController
extends Node3D

enum GameState { BOOT, LEVEL_LOADING, PLANNING, PLAYING, PAUSED, FAILED, COMPLETED }

# Vertical slice: prove the economy + sorter puzzle on three polished levels
# before scaling the authoring system to the full campaign.
const LEVEL_COUNT := 3
const MAX_POOLED_ITEMS := 24
const TAP_RADIUS_UNITS := 1.15
const SOURCE_CLEAR_PROGRESS := 0.38
const TRAUMA_CORRECT := 0.10
const TRAUMA_WRONG := 0.34
const TRAUMA_FAIL := 0.72
const HITSTOP_WRONG := 0.05
const HITSTOP_FAIL := 0.12

var state: GameState = GameState.BOOT
var current_level_number: int = 1
var level: Dictionary = {}
var nodes_by_id: Dictionary = {}
var positions: Dictionary = {}
var receivers: Dictionary = {}
var sources: Dictionary = {}
var sorters: Dictionary = {}
var active_items: Array[ItemActor] = []
var buffered: Array[Dictionary] = []

var _world: Node3D
var _camera: Camera3D
var _item_pool: ItemPool
var _rig: SceneRig
var _hud: FlowHud
var _planning_hud: PlanningHud
var _buffer_chute: Node3D

var _spawn_index := 0
var _spawn_clock := 0.0
var _elapsed := 0.0
var _attempt := 1
var _mistakes := 0
var _setup_taps := 0
var _empty_hold := 0.0
var _hitstop_remaining := 0.0
var _waiting_items: Dictionary = {}
var _state_before_pause: GameState = GameState.PLANNING

var _gold_budget := 0
var _gold_remaining := 0
var _spent_gold := 0
var _optimal_cost := 0
var _two_star_cost := 0
var _sorter_cost := 3
var _selected_sorter: SorterActor

var _last_plan_tap_ms := -1000
var _last_plan_tap_pos := Vector2(-9999, -9999)


func _ready() -> void:
    _setup_scene()
    current_level_number = clampi(SaveService.highest_unlocked_level, 1, LEVEL_COUNT)
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

    _planning_hud = PlanningHud.new()
    add_child(_planning_hud)
    _planning_hud.run_requested.connect(_on_run_requested)
    _planning_hud.lane_requested.connect(_on_lane_requested)
    _planning_hud.remove_requested.connect(_on_remove_requested)
    _planning_hud.next_requested.connect(_on_next_requested)
    _planning_hud.replay_requested.connect(_on_restart_requested)


func load_level(level_number: int) -> void:
    state = GameState.LEVEL_LOADING
    current_level_number = clampi(level_number, 1, LEVEL_COUNT)
    _clear_runtime()

    level = LevelBuilder.load_data(current_level_number)
    if level.is_empty():
        _handle_level_error("Level %d could not be loaded." % current_level_number)
        return

    _build_level()
    _hud.set_level(current_level_number, String(level.get("title", "FLOW")))
    _hud.set_buffer([], int(level["buffer_capacity"]))
    _hud.hide_overlay()

    _gold_budget = int(level.get("gold_budget", 0))
    _gold_remaining = _gold_budget
    _spent_gold = 0
    _optimal_cost = int(level.get("optimal_cost", 0))
    _two_star_cost = int(level.get("two_star_cost", _gold_budget))
    _sorter_cost = int(level.get("sorter_cost", 3))

    _spawn_index = 0
    _spawn_clock = 0.0
    _elapsed = 0.0
    _mistakes = 0
    _setup_taps = 0
    _empty_hold = 0.0
    _waiting_items.clear()

    _refresh_upcoming()
    for id in sorters:
        (sorters[id] as SorterActor).set_planning_mode(true)

    _planning_hud.show_planning(_gold_remaining, _spent_gold, _optimal_cost, _sorter_cost)
    _update_plan_hud()
    state = GameState.PLANNING
    AnalyticsService.track("level_plan_start", {
        "level": current_level_number,
        "attempt": _attempt,
        "gold_budget": _gold_budget,
        "optimal_cost": _optimal_cost,
    })


func _handle_level_error(message: String) -> void:
    push_error(message)
    state = GameState.FAILED
    if _planning_hud != null:
        _planning_hud.show_running()
    _hud.show_fail("This level could not be loaded. Check the Godot output log.")


func _clear_runtime() -> void:
    Engine.time_scale = 1.0
    _hitstop_remaining = 0.0
    _selected_sorter = null

    if _rig != null:
        _rig.clear_world()
    active_items.clear()
    buffered.clear()
    _waiting_items.clear()
    receivers.clear()
    sources.clear()
    sorters.clear()
    nodes_by_id.clear()
    positions.clear()
    _buffer_chute = null
    _item_pool = null


func _build_level() -> void:
    var built := LevelBuilder.build(level, _world, MAX_POOLED_ITEMS)
    nodes_by_id = built["nodes_by_id"]
    positions = built["positions"]
    sources = built["sources"]
    receivers = built["receivers"]
    sorters = built["sorters"]
    _buffer_chute = built["buffer_chute"]
    _item_pool = built["item_pool"]


func _on_run_requested() -> void:
    if state != GameState.PLANNING:
        return
    if _built_sorter_count() <= 0:
        _planning_hud.flash_message("Build at least one sorter before RUN")
        return

    _clear_sorter_selection()
    for id in sorters:
        (sorters[id] as SorterActor).set_planning_mode(false)

    _planning_hud.show_running()
    _spawn_clock = maxf(0.0, float(level["spawn_interval"]) - 0.35)
    _elapsed = 0.0
    _empty_hold = 0.0
    state = GameState.PLAYING

    AnalyticsService.track("run_start", {
        "level": current_level_number,
        "setup_taps": _setup_taps,
        "spent_gold": _spent_gold,
        "built_sorters": _built_sorter_count(),
        "attempt": _attempt,
    })


func _on_lane_requested(lane_index: int) -> void:
    if state != GameState.PLANNING or _selected_sorter == null:
        return
    if not is_instance_valid(_selected_sorter) or not _selected_sorter.is_built:
        return
    if _selected_sorter.cycle_lane(lane_index):
        _setup_taps += 1
        _planning_hud.show_sorter(
            _selected_sorter.sorter_id,
            _selected_sorter.mapping_for_ui(),
            _selected_sorter.build_cost
        )
        AnalyticsService.track("sorter_program", {
            "level": current_level_number,
            "sorter": _selected_sorter.sorter_id,
            "lane": lane_index + 1,
            "mapping": _selected_sorter.mapping_for_ui(),
        })


func _on_remove_requested() -> void:
    if state != GameState.PLANNING or _selected_sorter == null:
        return
    if not is_instance_valid(_selected_sorter) or not _selected_sorter.is_built:
        return

    var refund := _selected_sorter.build_cost
    var sorter_id := _selected_sorter.sorter_id
    if not _selected_sorter.demolish():
        return

    _gold_remaining += refund
    _spent_gold = maxi(0, _spent_gold - refund)
    _selected_sorter.set_selected(false)
    _selected_sorter = null
    _update_plan_hud()
    _planning_hud.flash_message("Sorter %s removed • %d gold refunded" % [sorter_id, refund])
    AnalyticsService.track("sorter_remove", {
        "level": current_level_number,
        "sorter": sorter_id,
        "refund": refund,
        "spent_gold": _spent_gold,
    })


func _try_build_sorter(sorter: SorterActor) -> bool:
    if sorter == null or not is_instance_valid(sorter):
        return false
    if sorter.is_built:
        _select_sorter(sorter)
        return true
    if _gold_remaining < sorter.build_cost:
        _select_sorter(sorter)
        _planning_hud.flash_message("Not enough gold • Need %d" % sorter.build_cost)
        return false
    if not sorter.build():
        return false

    _gold_remaining -= sorter.build_cost
    _spent_gold += sorter.build_cost
    _setup_taps += 1
    _select_sorter(sorter)
    _update_plan_hud()

    AnalyticsService.track("sorter_build", {
        "level": current_level_number,
        "sorter": sorter.sorter_id,
        "cost": sorter.build_cost,
        "spent_gold": _spent_gold,
        "gold_remaining": _gold_remaining,
    })
    return true


func _select_sorter(sorter: SorterActor) -> void:
    if _selected_sorter != null and is_instance_valid(_selected_sorter):
        _selected_sorter.set_selected(false)
    _selected_sorter = sorter
    if sorter == null or not is_instance_valid(sorter):
        _planning_hud.clear_sorter()
        return

    sorter.set_selected(true)
    if sorter.is_built:
        _planning_hud.show_sorter(sorter.sorter_id, sorter.mapping_for_ui(), sorter.build_cost)
    else:
        _planning_hud.clear_sorter()


func _clear_sorter_selection() -> void:
    if _selected_sorter != null and is_instance_valid(_selected_sorter):
        _selected_sorter.set_selected(false)
    _selected_sorter = null
    if _planning_hud != null:
        _planning_hud.clear_sorter()


func _update_plan_hud() -> void:
    if _planning_hud == null:
        return
    _planning_hud.set_budget(_gold_remaining, _spent_gold, _optimal_cost)
    _planning_hud.set_run_enabled(_built_sorter_count() > 0)
    if _selected_sorter != null and is_instance_valid(_selected_sorter) and _selected_sorter.is_built:
        _planning_hud.show_sorter(
            _selected_sorter.sorter_id,
            _selected_sorter.mapping_for_ui(),
            _selected_sorter.build_cost
        )


func _built_sorter_count() -> int:
    var count := 0
    for id in sorters:
        if (sorters[id] as SorterActor).is_built:
            count += 1
    return count


func _process(delta: float) -> void:
    if _hitstop_remaining > 0.0:
        _hitstop_remaining -= delta / maxf(0.05, Engine.time_scale)
        if _hitstop_remaining <= 0.0:
            Engine.time_scale = 1.0


func _physics_process(delta: float) -> void:
    if state != GameState.PLAYING:
        return
    _elapsed += delta
    _update_spawning(delta)
    _update_items(delta)
    _check_run_end(delta)


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
        _spawn_clock = minf(_spawn_clock, interval + 0.10)
        return

    _spawn_clock -= interval
    _spawn_index += 1
    _refresh_upcoming()
    _spawn_item(String(spawn["kind"]), source_id)


func _spawn_item(kind: String, source_id: String) -> void:
    if state != GameState.PLAYING or not nodes_by_id.has(source_id):
        return

    var source_node: Dictionary = nodes_by_id[source_id]
    var next_id := String(source_node.get("next", ""))
    if next_id.is_empty() or not positions.has(next_id):
        _fail("A source has no valid route.")
        return

    var item := _item_pool.acquire()
    if item == null:
        return
    if not item.finished.is_connected(_on_item_finished):
        item.finished.connect(_on_item_finished)
    item.configure(
        kind,
        source_id,
        source_id,
        next_id,
        positions[source_id],
        positions[next_id],
        SaveService.scaled_speed(float(level["item_speed"]))
    )
    active_items.append(item)

    if sources.has(source_id):
        (sources[source_id] as SourceActor).react_launch()
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
        if _waiting_items.has(item.get_instance_id()):
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

    if node_type == "sorter_site":
        _wait_for_sorter(item, arrived_id)
        return

    var next_id := String(node.get("next", ""))
    if next_id.is_empty() or not positions.has(next_id):
        _fail("Cargo reached a dead end.")
        return
    item.start_segment(arrived_id, next_id, positions[arrived_id], positions[next_id])


func _wait_for_sorter(item: ItemActor, sorter_id: String) -> void:
    if not sorters.has(sorter_id):
        _fail("A sorter site is missing.")
        return
    var sorter := sorters[sorter_id] as SorterActor
    if not sorter.is_built:
        _fail("Cargo reached an empty sorter foundation. Build there or route around it.")
        return

    _waiting_items[item.get_instance_id()] = true
    var callback := Callable(self, "_resume_from_sorter").bind(item, sorter_id)
    sorter.request_route_for_kind(item.kind, callback)


func _resume_from_sorter(next_id: String, item: ItemActor, sorter_id: String) -> void:
    if not is_instance_valid(item) or state != GameState.PLAYING:
        return
    _waiting_items.erase(item.get_instance_id())
    if next_id.is_empty() or not positions.has(sorter_id) or not positions.has(next_id):
        _fail("A sorter route is incomplete.")
        return
    item.start_segment(sorter_id, next_id, positions[sorter_id], positions[next_id])


func _deliver_item(item: ItemActor, receiver_id: String) -> void:
    active_items.erase(item)
    _waiting_items.erase(item.get_instance_id())
    if receivers.has(receiver_id):
        (receivers[receiver_id] as ReceiverActor).accept()
    AudioService.play("correct", 1.0, -3.0)
    HapticService.light()
    _rig.add_trauma(TRAUMA_CORRECT)
    VisualFactory.burst(
        _world,
        positions[receiver_id] + Vector3(0, 1.0, 0),
        VisualFactory.kind_color(item.kind),
        22,
        2.9
    )
    item.animate_delivered()


func _buffer_item(item: ItemActor, receiver_id: String) -> void:
    active_items.erase(item)
    _waiting_items.erase(item.get_instance_id())
    _mistakes += 1

    if receivers.has(receiver_id):
        (receivers[receiver_id] as ReceiverActor).reject()

    if buffered.size() >= int(level["buffer_capacity"]):
        item.animate_buffered(_buffer_target_position())
        _fail("The waiting buffer overflowed.")
        return

    buffered.append({"kind": item.kind, "source": item.origin_source})
    item.animate_buffered(_buffer_target_position())
    AudioService.play("wrong", 1.0, -2.0)
    AudioService.duck_music()
    HapticService.medium()
    _rig.add_trauma(TRAUMA_WRONG)
    _hitstop(HITSTOP_WRONG)
    VisualFactory.burst(
        _world,
        positions[receiver_id] + Vector3(0, 1.0, 0),
        Color("#8C9BA6"),
        14,
        2.0
    )
    _refresh_buffer_ui()
    _hud.flash_buffer()


func _buffer_target_position() -> Vector3:
    if _buffer_chute != null and is_instance_valid(_buffer_chute):
        return _buffer_chute.global_position + Vector3(0, 0.70, 0)
    return Vector3(0.0, 0.7, 6.35)


func _refresh_buffer_ui() -> void:
    var kinds: Array = []
    for entry in buffered:
        kinds.append(String(entry["kind"]))
    _hud.set_buffer(kinds, int(level["buffer_capacity"]))


func _refresh_upcoming() -> void:
    var kinds: Array = []
    var spawns: Array = level.get("spawns", [])
    for i in range(_spawn_index, mini(_spawn_index + 4, spawns.size())):
        var entry: Dictionary = spawns[i]
        kinds.append(String(entry["kind"]))
    _hud.set_upcoming(kinds)
    _refresh_source_previews(spawns)


func _refresh_source_previews(spawns: Array) -> void:
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
        (sources[source_id] as SourceActor).set_preview_queue(queues[source_id] as Array)


func _check_run_end(delta: float) -> void:
    if _spawn_index < level["spawns"].size() or not active_items.is_empty() or not _waiting_items.is_empty():
        _empty_hold = 0.0
        return

    _empty_hold += delta
    if _empty_hold < 0.32:
        return

    if not buffered.is_empty():
        _fail("Some cargo reached the wrong machine. Adjust the sorter setup and try again.")
        return
    _win()


func _win() -> void:
    if state != GameState.PLAYING:
        return
    state = GameState.COMPLETED

    var stars := _stars_for_spend(_spent_gold)
    AudioService.play("win", 1.0, -1.0)
    HapticService.medium()
    VisualFactory.create_win_confetti(_world)
    SaveService.unlock_level(mini(LEVEL_COUNT, current_level_number + 1))

    AnalyticsService.track("level_complete", {
        "level": current_level_number,
        "duration": snapped(_elapsed, 0.01),
        "mistakes": _mistakes,
        "setup_taps": _setup_taps,
        "spent_gold": _spent_gold,
        "optimal_cost": _optimal_cost,
        "stars": stars,
        "attempt": _attempt,
    })

    _hud.hide_overlay()
    _planning_hud.show_result(stars, _spent_gold, _optimal_cost)


func _stars_for_spend(spent: int) -> int:
    if spent <= _optimal_cost:
        return 3
    if spent <= _two_star_cost:
        return 2
    return 1


func _fail(reason: String) -> void:
    if state not in [GameState.PLAYING, GameState.PLANNING]:
        return
    state = GameState.FAILED
    _planning_hud.show_running()
    AudioService.play("fail", 1.0, -1.0)
    AudioService.duck_music(12.0, 0.7)
    HapticService.heavy()
    _rig.add_trauma(TRAUMA_FAIL)
    _hitstop(HITSTOP_FAIL)

    AnalyticsService.track("level_fail", {
        "level": current_level_number,
        "duration": snapped(_elapsed, 0.01),
        "mistakes": _mistakes,
        "setup_taps": _setup_taps,
        "spent_gold": _spent_gold,
        "attempt": _attempt,
    })
    _hud.show_fail(reason)


func _unhandled_input(event: InputEvent) -> void:
    if state != GameState.PLANNING:
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

    var now := Time.get_ticks_msec()
    if now - _last_plan_tap_ms < 120 and screen_pos.distance_to(_last_plan_tap_pos) < 18.0:
        return
    _last_plan_tap_ms = now
    _last_plan_tap_pos = screen_pos

    var best: SorterActor = null
    var best_score := 1.0
    for id in sorters:
        var sorter := sorters[id] as SorterActor
        var anchor := sorter.global_position + Vector3(0, 0.42, 0)
        var projected := _camera.unproject_position(anchor)
        var radius_px := screen_radius(_camera, anchor, TAP_RADIUS_UNITS)
        if radius_px <= 0.0:
            continue
        var score := projected.distance_to(screen_pos) / radius_px
        if score < best_score:
            best = sorter
            best_score = score

    if best == null:
        _clear_sorter_selection()
        _planning_hud.flash_message("Tap a round foundation to build a sorter")
        return

    if best.is_built:
        _select_sorter(best)
    else:
        _try_build_sorter(best)


func _hitstop(seconds: float) -> void:
    if SaveService.reduced_motion:
        return
    Engine.time_scale = 0.12
    _hitstop_remaining = seconds


func _on_restart_requested() -> void:
    _attempt += 1
    load_level(current_level_number)


func _on_next_requested() -> void:
    _attempt = 1
    load_level(1 if current_level_number >= LEVEL_COUNT else current_level_number + 1)


func _on_pause_requested() -> void:
    if state not in [GameState.PLANNING, GameState.PLAYING]:
        return
    _state_before_pause = state
    state = GameState.PAUSED
    _hud.show_pause()


func _on_resume_requested() -> void:
    if state != GameState.PAUSED:
        return
    state = _state_before_pause
    _hud.hide_overlay()


func _on_debug_previous() -> void:
    if not OS.is_debug_build():
        return
    _attempt = 1
    load_level(maxi(1, current_level_number - 1))


func _on_debug_next() -> void:
    if not OS.is_debug_build():
        return
    _attempt = 1
    load_level(mini(LEVEL_COUNT, current_level_number + 1))


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED and state in [GameState.PLANNING, GameState.PLAYING]:
        call_deferred("_on_pause_requested")


static func screen_radius(camera: Camera3D, anchor: Vector3, units: float) -> float:
    var edge := anchor + camera.global_transform.basis.x * units
    return camera.unproject_position(anchor).distance_to(camera.unproject_position(edge))


func _on_item_finished(item: ItemActor) -> void:
    _waiting_items.erase(item.get_instance_id())
    if _item_pool != null:
        _item_pool.release(item)

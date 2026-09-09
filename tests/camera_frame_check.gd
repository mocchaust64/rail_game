extends Node

const LEVELS := [1, 3, 7, 10]
const ACTOR_HALF_WIDTH := 0.92
const ACTOR_HALF_DEPTH := 0.92
const ACTOR_HEIGHT := 1.65
const SCREEN_MARGIN := 20.0


func _ready() -> void:
    var failures: Array[String] = []
    var viewport := SubViewport.new()
    viewport.size = Vector2i(1080, 1920)
    add_child(viewport)
    var rig := SceneRig.new()
    viewport.add_child(rig)
    rig.camera.current = true

    var viewport_size := rig.camera.get_viewport().get_visible_rect().size
    for level_number in LEVELS:
        _check_level(rig, level_number, viewport_size, failures)

    viewport.remove_child(rig)
    rig.free()
    remove_child(viewport)
    viewport.free()
    if failures.is_empty():
        print("camera frame: PASS (levels 1, 3, 7 and 10 actor bounds visible)")
        get_tree().quit(0)
        return
    for failure in failures:
        printerr(failure)
    printerr("camera frame: FAIL (%d cropped bounds)" % failures.size())
    get_tree().quit(1)


func _check_level(rig: SceneRig, level_number: int, viewport_size: Vector2, failures: Array[String]) -> void:
    var file := FileAccess.open("res://levels/level_%02d.json" % level_number, FileAccess.READ)
    var level: Dictionary = JSON.parse_string(file.get_as_text())
    var positions: Dictionary = {}
    for raw_node in level["nodes"]:
        var node: Dictionary = raw_node
        var p: Array = node["pos"]
        positions[String(node["id"])] = Vector3(float(p[0]), 0.0, float(p[1]))

    rig.frame_positions(positions)
    rig._process(0.0)
    var min_screen_y := viewport_size.y
    var max_screen_y := 0.0
    for raw_node in level["nodes"]:
        var node: Dictionary = raw_node
        if String(node["type"]) not in ["source", "receiver"]:
            continue
        var centre: Vector3 = positions[String(node["id"])]
        for x in [-ACTOR_HALF_WIDTH, ACTOR_HALF_WIDTH]:
            for z in [-ACTOR_HALF_DEPTH, ACTOR_HALF_DEPTH]:
                for y in [0.0, ACTOR_HEIGHT]:
                    var screen := rig.camera.unproject_position(centre + Vector3(float(x), float(y), float(z)))
                    min_screen_y = minf(min_screen_y, screen.y)
                    max_screen_y = maxf(max_screen_y, screen.y)
                    if screen.x < SCREEN_MARGIN or screen.x > viewport_size.x - SCREEN_MARGIN or screen.y < SCREEN_MARGIN or screen.y > viewport_size.y - SCREEN_MARGIN:
                        failures.append("level %d %s projects outside the safe frame at %s" % [level_number, node["id"], screen])
    var vertical_coverage := (max_screen_y - min_screen_y) / viewport_size.y
    if vertical_coverage < 0.55:
        failures.append("level %d fills only %.1f%% of portrait height" % [level_number, vertical_coverage * 100.0])

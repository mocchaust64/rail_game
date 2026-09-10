extends Node

const OUTPUT_DIR := "res://build/visual_qa"
const LEVEL_COUNT := 3

var _failures: Array[String] = []


func _ready() -> void:
    get_window().size = Vector2i(1080, 1920)
    var absolute_output := ProjectSettings.globalize_path(OUTPUT_DIR)
    var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_output)
    if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
        printerr("visual capture: could not create %s (error %d)" % [absolute_output, mkdir_error])
        get_tree().quit(1)
        return

    SaveService.highest_unlocked_level = 1
    SaveService.tutorial_seen = true

    var controller := preload("res://app/main.tscn").instantiate() as GameController
    add_child(controller)
    await _settle(5)

    for level_number in range(1, LEVEL_COUNT + 1):
        controller.load_level(level_number)
        await _settle(5)
        await _capture("level_%02d_plan" % level_number)

        var build_ids: Array[String] = []
        if level_number == 3:
            build_ids = ["A", "C"]
        else:
            build_ids = ["A"]

        for sorter_id in build_ids:
            if not controller.sorters.has(sorter_id):
                _failures.append("level %d missing expected sorter %s" % [level_number, sorter_id])
                continue
            var sorter := controller.sorters[sorter_id] as SorterActor
            if not controller._try_build_sorter(sorter):
                _failures.append("level %d could not build sorter %s for visual capture" % [level_number, sorter_id])

        await _settle(12)
        await _capture("level_%02d_built" % level_number)

    controller.queue_free()
    await get_tree().process_frame

    if _failures.is_empty():
        print("visual capture: PASS (L1-L3 plan + built screenshots)")
        get_tree().quit(0)
        return

    for failure in _failures:
        printerr(failure)
    printerr("visual capture: FAIL (%d)" % _failures.size())
    get_tree().quit(1)


func _settle(frames: int) -> void:
    for _i in range(frames):
        await get_tree().process_frame
    await RenderingServer.frame_post_draw


func _capture(stem: String) -> void:
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    if image == null or image.is_empty():
        _failures.append("%s produced an empty viewport image" % stem)
        return

    var path := ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, stem])
    var error := image.save_png(path)
    if error != OK:
        _failures.append("%s could not be saved (error %d)" % [stem, error])
        return
    print("visual capture: wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])

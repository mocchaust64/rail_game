extends Node

const LEVEL_COUNT := 3


func _ready() -> void:
    var failures: Array[String] = []
    var controller := preload("res://app/main.tscn").instantiate() as GameController
    add_child(controller)
    await get_tree().process_frame
    await get_tree().physics_frame

    for level_number in range(1, LEVEL_COUNT + 1):
        controller.load_level(level_number)
        await get_tree().physics_frame
        if controller.current_level_number != level_number:
            failures.append("load_level(%d) ended on level %d" % [level_number, controller.current_level_number])
        if controller.state != GameController.GameState.PLANNING:
            failures.append("level %d did not open in PLANNING" % level_number)
        if controller.sorters.is_empty():
            failures.append("level %d has no sorter sites" % level_number)

    controller.load_level(1)
    await get_tree().physics_frame

    controller._on_run_requested()
    if controller.state != GameController.GameState.PLANNING:
        failures.append("RUN started without any built sorter")

    var first := controller.sorters[controller.sorters.keys()[0]] as SorterActor
    var starting_gold := controller._gold_remaining
    if not controller._try_build_sorter(first):
        failures.append("could not build first sorter")
    if controller._gold_remaining != starting_gold - first.build_cost:
        failures.append("building sorter did not deduct gold")
    if controller._spent_gold != first.build_cost:
        failures.append("spent gold did not track build cost")

    var mapping_before := first.mapping_for_ui()
    if not first.cycle_lane(0):
        failures.append("built sorter could not be configured during planning")
    if first.mapping_for_ui() == mapping_before:
        failures.append("sorter mapping did not change")

    controller._on_run_requested()
    if controller.state != GameController.GameState.PLAYING:
        failures.append("RUN did not reach PLAYING")
    if first.cycle_lane(0):
        failures.append("sorter accepted configuration changes during RUN")

    controller._on_pause_requested()
    if controller.state != GameController.GameState.PAUSED:
        failures.append("pause did not reach PAUSED")
    controller._on_resume_requested()
    if controller.state != GameController.GameState.PLAYING:
        failures.append("resume did not return to PLAYING")

    controller._fail("test")
    if controller.state != GameController.GameState.FAILED:
        failures.append("_fail did not reach FAILED")
    controller._on_restart_requested()
    await get_tree().physics_frame
    if controller.state != GameController.GameState.PLANNING:
        failures.append("restart did not return to PLANNING")

    controller.load_level(1)
    controller._on_next_requested()
    await get_tree().physics_frame
    if controller.current_level_number != 2:
        failures.append("next level did not advance")
    if controller.state != GameController.GameState.PLANNING:
        failures.append("next level did not open in PLANNING")

    controller.queue_free()

    if failures.is_empty():
        print("game flow: PASS (gold build -> configure -> run -> locked runtime)")
        get_tree().quit(0)
        return

    for line in failures:
        printerr(line)
    printerr("game flow: FAIL (%d)" % failures.size())
    get_tree().quit(1)

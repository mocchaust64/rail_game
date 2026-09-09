extends Node

const LEVEL_COUNT := 10


func _ready() -> void:
    var failures: Array[String] = []
    var controller := preload("res://app/main.tscn").instantiate() as GameController
    add_child(controller)
    await get_tree().process_frame
    await get_tree().physics_frame

    # Every shipped level now opens in PLANNING, never live reflex play.
    for level_number in range(1, LEVEL_COUNT + 1):
        controller.load_level(level_number)
        await get_tree().physics_frame
        if controller.current_level_number != level_number:
            failures.append("load_level(%d) ended on level %d" % [level_number, controller.current_level_number])
        if controller.state != GameController.GameState.PLANNING:
            failures.append("level %d did not reach PLANNING, state is %d" % [level_number, controller.state])

    # RUN is the only transition into live cargo movement.
    controller.load_level(1)
    await get_tree().physics_frame
    controller._on_run_requested()
    if controller.state != GameController.GameState.PLAYING:
        failures.append("RUN did not reach PLAYING")

    # Programmed routers are locked against manual setup changes during RUN.
    if not controller.junctions.is_empty():
        var first := controller.junctions[controller.junctions.keys()[0]] as JunctionActor
        var before := first.filter_kind
        if first.cycle_filter():
            failures.append("router accepted manual reprogramming during RUN")
        if first.filter_kind != before:
            failures.append("router filter changed during RUN")

    # Pause/resume preserves the phase that was active.
    controller._on_pause_requested()
    if controller.state != GameController.GameState.PAUSED:
        failures.append("pause did not reach PAUSED")
    controller._on_resume_requested()
    if controller.state != GameController.GameState.PLAYING:
        failures.append("resume did not return to PLAYING")

    # Failure/restart returns to planning, not immediately to moving cargo.
    controller._fail("test")
    if controller.state != GameController.GameState.FAILED:
        failures.append("_fail did not reach FAILED")
    controller._on_restart_requested()
    await get_tree().physics_frame
    if controller.state != GameController.GameState.PLANNING:
        failures.append("restart did not return to PLANNING")

    # Hitstop must never survive a level change.
    controller.load_level(1)
    controller._on_run_requested()
    controller._hitstop(5.0)
    controller.load_level(2)
    await get_tree().physics_frame
    if absf(Engine.time_scale - 1.0) > 0.001:
        failures.append("time scale stranded at %.2f after a level change" % Engine.time_scale)

    # Next still advances to the next puzzle, which starts in planning.
    controller.load_level(1)
    controller._on_next_requested()
    await get_tree().physics_frame
    if controller.current_level_number != 2:
        failures.append("next level did not advance, on %d" % controller.current_level_number)
    if controller.state != GameController.GameState.PLANNING:
        failures.append("next level did not open in PLANNING")

    controller.queue_free()

    if failures.is_empty():
        print("game flow: PASS (plan -> run, runtime lock, pause, fail, restart, advance)")
        get_tree().quit(0)
        return
    for line in failures:
        printerr(line)
    printerr("game flow: FAIL (%d)" % failures.size())
    get_tree().quit(1)

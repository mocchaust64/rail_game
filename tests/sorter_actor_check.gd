extends Node3D


func _ready() -> void:
    var failures: Array[String] = []
    var nodes := {
        "A": {
            "id": "A",
            "type": "sorter_site",
            "out_1": "R",
            "out_2": "B",
            "out_3": "Y",
            "mapping": ["red", "blue", "yellow"],
            "build_cost": 3,
        },
        "R": {"id": "R", "type": "receiver", "kind": "red"},
        "B": {"id": "B", "type": "receiver", "kind": "blue"},
        "Y": {"id": "Y", "type": "receiver", "kind": "yellow"},
    }
    var positions := {
        "A": Vector3.ZERO,
        "R": Vector3(-2.5, 0, 3.5),
        "B": Vector3(0, 0, 4.0),
        "Y": Vector3(2.5, 0, 3.5),
    }
    TrackGeometry.rebuild(nodes, positions)

    var sorter := SorterActor.new()
    add_child(sorter)
    sorter.configure(nodes["A"], positions, 3)

    if sorter.is_built:
        failures.append("sorter should begin as a foundation")
    if not sorter.build():
        failures.append("sorter did not build")
    if sorter.get_node_or_null(NodePath("ActiveSorterBelts")) == null:
        failures.append("built sorter did not expose active black belts")

    var before := sorter.mapping_for_ui()
    if not sorter.cycle_lane(0):
        failures.append("planning could not change a lane")
    var after := sorter.mapping_for_ui()
    if before == after:
        failures.append("lane cycle did not change mapping")

    var unique: Dictionary = {}
    for kind in after:
        unique[String(kind)] = true
    if unique.size() != 3:
        failures.append("lane cycle duplicated a colour")

    sorter.set_planning_mode(false)
    if sorter.cycle_lane(1):
        failures.append("RUN mode allowed sorter reprogramming")
    sorter.set_planning_mode(true)

    if not sorter.demolish():
        failures.append("planning could not remove sorter")
    if sorter.is_built:
        failures.append("demolished sorter still reports built")

    sorter.queue_free()

    if failures.is_empty():
        print("sorter actor: PASS (build, black belts, unique mapping, runtime lock, remove)")
        get_tree().quit(0)
        return

    for line in failures:
        printerr(line)
    printerr("sorter actor: FAIL (%d)" % failures.size())
    get_tree().quit(1)

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

    # Conveyor geometry belongs to the level and is already visible before the
    # sorter is installed. The sorter must not duplicate three black belts.
    if sorter.get_node_or_null(NodePath("ActiveSorterBelts")) != null:
        failures.append("sorter must not spawn duplicate conveyor geometry")

    var house := sorter.get_node_or_null(NodePath("SorterHouse")) as Node3D
    if house == null:
        failures.append("built sorter has no toy-factory machine shell")

    var markers := sorter.get_node_or_null(NodePath("SorterLaneMarkers")) as Node3D
    if markers == null or markers.get_child_count() != 3:
        failures.append("sorter must show three physical exit markers")
    else:
        for i in range(3):
            if markers.get_child(i).name != "Exit%d" % (i + 1):
                failures.append("sorter exit %d has no stable numbered identity" % (i + 1))

    var before := sorter.mapping_for_ui()
    if not sorter.cycle_lane(0):
        failures.append("planning could not change an exit colour")
    var after := sorter.mapping_for_ui()
    if before == after:
        failures.append("exit colour cycle did not change mapping")

    var unique: Dictionary = {}
    for kind in after:
        unique[String(kind)] = true
    if unique.size() != 3:
        failures.append("exit colour cycle duplicated a colour")

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
        print("sorter actor: PASS (foundation, numbered exits, colour mapping, runtime lock, refund path)")
        get_tree().quit(0)
        return

    for line in failures:
        printerr(line)
    printerr("sorter actor: FAIL (%d)" % failures.size())
    get_tree().quit(1)

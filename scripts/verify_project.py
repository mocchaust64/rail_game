#!/usr/bin/env python3
"""Fast source-level verification for the sorter-economy vertical slice."""
from __future__ import annotations

import itertools
import json
import pathlib
import re
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parents[1]
ERRORS: list[str] = []
KINDS = ("red", "blue", "yellow")
SLICE_LEVELS = (1, 2, 3)


def fail(msg: str) -> None:
    ERRORS.append(msg)


def check_required_files() -> None:
    required = [
        "project.godot",
        "app/main.tscn",
        "game/game_controller.gd",
        "game/level_builder.gd",
        "game/scene_rig.gd",
        "gameplay/sorter_actor.gd",
        "gameplay/item_actor.gd",
        "gameplay/item_pool.gd",
        "gameplay/receiver_actor.gd",
        "gameplay/source_actor.gd",
        "gameplay/visual_factory.gd",
        "gameplay/track_geometry.gd",
        "gameplay/track_visuals.gd",
        "gameplay/track_motion.gd",
        "gameplay/level_validator.gd",
        "ui/hud.gd",
        "ui/planning_hud.gd",
        "ui/cargo_icon.gd",
        "services/save_service.gd",
        "services/audio_service.gd",
        "services/haptic_service.gd",
        "services/analytics_service.gd",
        "assets/palette/toy_factory.tres",
    ]
    for rel in required:
        if not (ROOT / rel).exists():
            fail(f"missing required file: {rel}")


def check_resource_paths() -> None:
    pattern = re.compile(r'(?:preload|load)\(\s*["\']res://([^"\']+)["\']\s*\)')
    for path in ROOT.rglob("*.gd"):
        text = path.read_text(encoding="utf-8")
        for rel in pattern.findall(text):
            if not (ROOT / rel).exists():
                fail(f"{path.relative_to(ROOT)} references missing res://{rel}")


def check_custom_gameplay_visuals() -> None:
    core = [
        ROOT / "gameplay" / "sorter_actor.gd",
        ROOT / "gameplay" / "track_visuals.gd",
        ROOT / "gameplay" / "track_motion.gd",
        ROOT / "gameplay" / "machine_visuals.gd",
        ROOT / "gameplay" / "processor_visual.gd",
        ROOT / "gameplay" / "visual_factory.gd",
        ROOT / "gameplay" / "source_actor.gd",
    ]
    forbidden = ("kenney", "kaykit", "assets/vendor")
    for path in core:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8").lower()
        for token in forbidden:
            if token in text:
                fail(f"{path.relative_to(ROOT)} still depends on external gameplay assets: {token}")


def outputs(node: dict) -> list[str]:
    node_type = node["type"]
    if node_type == "receiver":
        return []
    if node_type == "sorter_site":
        return [node["out_1"], node["out_2"], node["out_3"]]
    if node_type == "junction":
        return [node["out_a"], node["out_b"]]
    return [node["next"]]


def graph_has_cycle(nodes: dict[str, dict]) -> bool:
    color = defaultdict(int)

    def visit(nid: str) -> bool:
        color[nid] = 1
        for nxt in outputs(nodes[nid]):
            if color[nxt] == 1:
                return True
            if color[nxt] == 0 and visit(nxt):
                return True
        color[nid] = 2
        return False

    return any(color[n] == 0 and visit(n) for n in nodes)


def simulate_spawn(
    nodes: dict[str, dict],
    spawn: dict,
    built: set[str],
    mappings: dict[str, tuple[str, str, str]],
) -> bool:
    current = spawn["source"]
    kind = spawn["kind"]
    visited: set[str] = set()

    while True:
        if current in visited or current not in nodes:
            return False
        visited.add(current)
        node = nodes[current]
        node_type = node["type"]

        if node_type in {"source", "normal"}:
            current = node["next"]
            continue

        if node_type == "sorter_site":
            if current not in built:
                return False
            mapping = mappings[current]
            try:
                lane = mapping.index(kind)
            except ValueError:
                return False
            current = node[f"out_{lane + 1}"]
            continue

        if node_type == "receiver":
            return node["kind"] == kind

        return False


def solve_sorter_level(level: dict) -> tuple[int | None, dict | None, int, int]:
    nodes = {node["id"]: node for node in level["nodes"]}
    sorter_ids = [node["id"] for node in level["nodes"] if node["type"] == "sorter_site"]
    permutations = list(itertools.permutations(KINDS))
    best_cost: int | None = None
    best_solution: dict | None = None
    valid_solutions = 0
    optimal_solutions = 0
    budget = int(level["gold_budget"])

    # A site has seven states: unbuilt, or built with one of six permutations.
    # Three slice levels are intentionally tiny enough to exhaustively prove.
    for state in itertools.product(range(7), repeat=len(sorter_ids)):
        built: set[str] = set()
        mappings: dict[str, tuple[str, str, str]] = {}
        cost = 0

        for sorter_id, option in zip(sorter_ids, state):
            if option == 0:
                continue
            built.add(sorter_id)
            mappings[sorter_id] = permutations[option - 1]
            node = nodes[sorter_id]
            cost += int(node.get("build_cost", level["sorter_cost"]))

        if cost > budget:
            continue

        if not all(simulate_spawn(nodes, spawn, built, mappings) for spawn in level["spawns"]):
            continue

        valid_solutions += 1
        if best_cost is None or cost < best_cost:
            best_cost = cost
            best_solution = {"built": sorted(built), "mappings": mappings}
            optimal_solutions = 1
        elif cost == best_cost:
            optimal_solutions += 1

    return best_cost, best_solution, valid_solutions, optimal_solutions


def initial_mapping_solves(level: dict) -> bool:
    nodes = {node["id"]: node for node in level["nodes"]}
    sorter_nodes = [node for node in level["nodes"] if node["type"] == "sorter_site"]
    built = {node["id"] for node in sorter_nodes}
    mappings = {
        node["id"]: tuple(node.get("mapping", KINDS))
        for node in sorter_nodes
    }
    return all(simulate_spawn(nodes, spawn, built, mappings) for spawn in level["spawns"])


def validate_level(level: dict, expected_id: int) -> None:
    name = f"level_{expected_id:02d}.json"
    if level.get("id") != expected_id:
        fail(f"{name}: id must be {expected_id}")

    for key in (
        "gold_budget",
        "sorter_cost",
        "optimal_cost",
        "two_star_cost",
        "item_speed",
        "spawn_interval",
        "buffer_capacity",
        "buffer_return_delay",
    ):
        if key not in level:
            fail(f"{name}: missing {key}")

    nodes_list = level.get("nodes", [])
    nodes = {node.get("id"): node for node in nodes_list}
    if len(nodes) != len(nodes_list) or None in nodes:
        fail(f"{name}: duplicate or missing node id")
        return

    sorter_count = 0
    for node_id, node in nodes.items():
        node_type = node.get("type")
        if node_type not in {"source", "normal", "sorter_site", "receiver"}:
            fail(f"{name}: unsupported node type {node_type} at {node_id}")
            continue

        if node_type == "sorter_site":
            sorter_count += 1
            targets = [node.get("out_1"), node.get("out_2"), node.get("out_3")]
            if len(set(targets)) != 3:
                fail(f"{name}: sorter {node_id} needs three distinct outputs")
            mapping = node.get("mapping", [])
            if sorted(mapping) != sorted(KINDS):
                fail(f"{name}: sorter {node_id} mapping must be a permutation of {KINDS}")

        for nxt in outputs(node):
            if nxt not in nodes:
                fail(f"{name}: {node_id} points to missing {nxt}")

    if sorter_count == 0:
        fail(f"{name}: vertical slice requires at least one sorter site")
    if graph_has_cycle(nodes):
        fail(f"{name}: graph contains a cycle")

    best_cost, solution, valid_count, optimal_count = solve_sorter_level(level)
    if best_cost is None:
        fail(f"{name}: no valid sorter configuration solves all cargo")
        return

    declared = int(level["optimal_cost"])
    budget = int(level["gold_budget"])
    two_star = int(level["two_star_cost"])
    if best_cost != declared:
        fail(f"{name}: declared optimal_cost={declared}, exhaustive solver proves {best_cost}")
    if budget < best_cost:
        fail(f"{name}: budget {budget} cannot fund optimal solution {best_cost}")
    if not (best_cost <= two_star <= budget):
        fail(f"{name}: two_star_cost must be between optimal and budget")

    optimal_builds = len(solution["built"]) if solution else 0
    decoys = sorter_count - optimal_builds
    print(
        f" - L{expected_id}: optimal={best_cost} gold, sites={sorter_count}, "
        f"optimal_builds={optimal_builds}, decoys={decoys}, "
        f"valid_plans={valid_count}, optimal_plans={optimal_count}"
    )

    # A polished puzzle should have a clear intended best answer, not several
    # equally-cheap configurations that teach different rules by accident.
    if optimal_count != 1:
        fail(f"{name}: expected one unique optimal plan, solver found {optimal_count}")

    # Curriculum contract: L1 teaches BUILD, L2 teaches CONFIGURE, L3 teaches
    # OPTIMIZE. This stops later level edits from silently ruining onboarding.
    if expected_id == 1:
        if sorter_count != 1 or budget != best_cost:
            fail("level_01.json: BUILD lesson must contain one required sorter and exact budget")
        if not initial_mapping_solves(level):
            fail("level_01.json: initial colours must already be correct; teach building first")

    if expected_id == 2:
        if sorter_count != 1 or budget != best_cost:
            fail("level_02.json: CONFIGURE lesson must use one required sorter")
        if initial_mapping_solves(level):
            fail("level_02.json: initial colours must be wrong so the player learns programming")

    if expected_id == 3:
        if decoys < 2:
            fail("level_03.json: OPTIMIZE lesson needs at least two unnecessary build sites")
        if budget <= best_cost:
            fail("level_03.json: OPTIMIZE lesson needs enough spare gold to allow a wasteful solution")


def check_slice_levels() -> None:
    for level_id in SLICE_LEVELS:
        path = ROOT / "levels" / f"level_{level_id:02d}.json"
        try:
            level = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            fail(f"{path.name}: invalid JSON: {exc}")
            continue
        validate_level(level, level_id)


def check_controller_contract() -> None:
    text = (ROOT / "game" / "game_controller.gd").read_text(encoding="utf-8")
    required = [
        "const LEVEL_COUNT := 3",
        "GameState.PLANNING",
        "_try_build_sorter",
        "_gold_remaining",
        "_optimal_cost",
        "_stars_for_spend",
        "node_type == \"sorter_site\"",
    ]
    for token in required:
        if token not in text:
            fail(f"game_controller.gd missing sorter-economy contract token: {token}")

    sorter_text = (ROOT / "gameplay" / "sorter_actor.gd").read_text(encoding="utf-8")
    for token in (
        "func build()",
        "func demolish()",
        "func cycle_lane",
        "ActiveSorterBelts",
        "SorterLaneMarkers",
    ):
        if token not in sorter_text:
            fail(f"sorter_actor.gd missing: {token}")

    planning_text = (ROOT / "ui" / "planning_hud.gd").read_text(encoding="utf-8")
    if '"BEST  %d"' in planning_text:
        fail("planning_hud.gd: do not reveal the optimal cost before the result")


def check_audio() -> None:
    for name in ("tap", "ui", "spawn", "correct", "wrong", "win", "fail", "ambient"):
        path = ROOT / "assets" / "audio" / f"{name}.wav"
        if not path.exists() or path.stat().st_size < 1000:
            fail(f"audio missing/too small: {path.relative_to(ROOT)}")


def main() -> int:
    check_required_files()
    check_resource_paths()
    check_custom_gameplay_visuals()
    print("SORTER ECONOMY SOLVER")
    check_slice_levels()
    check_controller_contract()
    check_audio()

    if ERRORS:
        print("FLOW FACTORY VERIFY: FAIL")
        for error in ERRORS:
            print(" -", error)
        return 1

    print("FLOW FACTORY VERIFY: PASS")
    print(" - L1 teaches BUILD, L2 teaches CONFIGURE, L3 teaches OPTIMIZE")
    print(" - exhaustive solver proves declared optimal gold costs")
    print(" - every slice level has exactly one cheapest solution")
    print(" - level 3 contains deliberate unnecessary build sites")
    print(" - optimal cost stays hidden until the result screen")
    print(" - custom visuals remain vendor-free")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
